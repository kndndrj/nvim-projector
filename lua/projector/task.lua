local utils = require("projector.utils")

---@alias presentation "menuhidden"|""

-- Id of the task
---@alias task_id string

-- Table of configuration parameters
---@class task_configuration
--- common:
---@field name string
---@field scope string
---@field group string
---@field presentation presentation|presentation[]
---@field dependencies task_id[]
---@field after task_id
---@field env table<string, string>
---@field cwd string
---@field args string[]
---@field pattern string
--- task
---@field command string
--- debug
---@field type string
---@field request string
---@field program string
---@field port string|integer
--- + extra dap-specific parameters (see: https://github.com/mfussenegger/nvim-dap)
--- database
---@field databases { name: string, url: string }[]
---@field queries { [string]: {[string]: string } }

-- Table of actions
---@alias task_action { label: string, action: fun( ), override?: boolean, nested?: task_action[] }

-- What modes can the task run in
---@alias task_mode string

-- Metadata of a task
---@alias task_meta { id: string, name: string, scope: string, group: string }

---@class Task
---@field private meta task_meta
---@field private presentation { menu: { show: boolean } }
---@field private configuration task_configuration Configuration of the task (command, args, env, cwd...)
---@field private modes task_mode[] What can the task do (debug, task)
---@field private last_mode task_mode Mode that was selected previously
---@field private dependency_mode task_mode mode to run the dependencies in
---@field private dependencies { task: Task, status: "done"|"error"|"" }[] List of dependent tasks
---@field private after Task a task to run after this one is finished
---@field private output_builders table<task_mode, OutputBuilder> task builders per mode
---@field private output Output currently active output
---@field private expand_config_variables fun(configuration: task_configuration):task_configuration Function that gets assigned to a task by a loader
local Task = {}

---@param configuration task_configuration
---@param output_builders OutputBuilder[] map of available output builders
---@param opts? { dependency_mode: task_mode, expand_config: fun(config: task_configuration):task_configuration }
---@return Task|nil
function Task:new(configuration, output_builders, opts)
  if not configuration then
    return
  end
  if not output_builders or #output_builders == 0 then
    return
  end
  opts = opts or {}

  -- check output capabilities
  ---@type string[]
  local modes = {}
  local builders = {}
  for _, builder in ipairs(output_builders) do
    table.insert(modes, builder:mode_name())
    builders[builder:mode_name()] = builder
  end

  -- presentation
  local presentation = {
    menu = {
      show = true,
    },
  }
  if configuration.presentation then
    local present = configuration.presentation
    if type(present) == "string" then
      present = { present }
    end
    for _, p in ipairs(present) do
      if p == "menuhidden" then
        presentation.menu.show = false
      end
    end
  end

  -- metadata
  local name = configuration.name or "[empty name]"
  local scope = configuration.scope or "[empty scope]"
  local group = configuration.group or "[empty group]"

  local o = {
    meta = {
      id = scope .. "." .. group .. "." .. name,
      name = name,
      scope = scope,
      group = group,
    },
    configuration = configuration,
    presentation = presentation,
    modes = modes,
    last_mode = nil,
    dependency_mode = opts.dependency_mode,
    dependencies = {},
    after = nil,
    output_builders = builders,
    output = nil,
    expand_config_variables = opts.expand_config or function(c)
      return c
    end,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Run a task and hadle it's dependencies
---@param mode? task_mode
---@param callback? fun(success: boolean)
function Task:run(mode, callback)
  -- check parameters
  callback = callback or function(_) end
  mode = mode or self.last_mode or self.modes[1]
  self.last_mode = mode

  -- If any output is already live, return
  if self:is_live() then
    utils.log("info", "Already live.", "Task " .. self.meta.name)
    self:show_output()
    callback(true)
    return
  end

  -- check if task has the capability to run the selected mode
  if not utils.contains(self.modes, mode) then
    callback(false)
    return
  end

  local revert_dep_statuses = function()
    for _, dep in pairs(self.dependencies) do
      dep.status = ""
    end
  end

  -- run the first not completed dependency
  for _, dep in ipairs(self.dependencies) do
    if dep.status ~= "done" and dep.status ~= "error" then
      local cb = function(ok)
        if ok then
          dep.status = "done"
          dep.task:hide_output()
          self:run(mode, callback)
          return
        end

        dep.status = "error"
        utils.log("error", 'Problem with dependency: "' .. dep.task:metadata().id .. '".', "Task " .. self.meta.name)
        -- trigger callback, stop further dependency execution and revert task's dependency statuses
        callback(false)
        revert_dep_statuses()
      end

      -- Run the dependency in task mode (restart it if already running)
      dep.task:kill_output()
      dep.task:run(self.dependency_mode, cb)
      return
    end
  end
  -- revert dependency statuses if all dependencies are successfully finished
  revert_dep_statuses()

  -- handle post task with on_success output callback
  local cb = function(ok)
    if ok then
      if self.after then
        self:hide_output()
        self.after:run(self.dependency_mode)
      end
    end
    callback(ok)
  end

  -- build the output and run the task
  self.output = self.output_builders[mode]:build()
  self.output:init(self.expand_config_variables(self.configuration), cb)
end

---@return task_meta
function Task:metadata()
  return self.meta
end

---@return task_configuration
function Task:config()
  return self.configuration
end

---@param deps Task[]
function Task:set_dependencies(deps)
  self.dependencies = {}
  for _, dep in ipairs(deps) do
    table.insert(self.dependencies, { status = "", task = dep })
  end
end

---@param task Task
function Task:set_after(task)
  self.after = task
end

---@return task_mode[]
function Task:get_modes()
  return self.modes
end

function Task:is_live()
  local o = self.output
  if o and o:status() ~= "inactive" and o:status() ~= "" then
    return true
  end
  return false
end

function Task:is_visible()
  local o = self.output
  if o and o:status() == "visible" then
    return true
  end
  return false
end

function Task:show_output()
  local o = self.output
  if o and o:status() == "hidden" then
    o:show()
  end
end

function Task:hide_output()
  local o = self.output
  if o and o:status() == "visible" then
    o:hide()
  end
end

function Task:kill_output()
  local o = self.output
  if o and (o:status() == "visible" or o:status() == "hidden") then
    o:kill()
  end
end

---@return task_action[]
function Task:actions()
  local o = self.output
  if o and type(o.actions) == "function" and o:status() ~= "inactive" and o:status() ~= "" then
    return o:actions() or {}
  end
  return {}
end

return Task
