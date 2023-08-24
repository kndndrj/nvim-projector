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

-- Presentation of the task in ui
---@alias task_presentation { menu: { show: boolean } }

---@class Task
---@field private meta task_meta
---@field private present task_presentation
---@field private configuration task_configuration Configuration of the task (command, args, env, cwd...)
---@field private modes task_mode[] What can the task do (debug, task)
---@field private last_mode task_mode Mode that was selected previously
---@field private dependency_mode task_mode mode to run the dependencies in
---@field private dependencies { task: Task, status: "done"|"error"|"" }[] List of dependent tasks
---@field private after? Task a task to run after this one is finished
---@field private output_builders table<task_mode, OutputBuilder> task builders per mode
---@field private output Output currently active output
---@field private expand_config_variables fun(configuration: task_configuration):task_configuration Function that gets assigned to a task by a loader
---@field private activator fun() callback function that sets this task as the active one
local Task = {}

---@param configuration task_configuration
---@param output_builders OutputBuilder[] map of available output builders
---@param opts? { dependency_mode: task_mode, activator: fun(), expand_config: fun(config: task_configuration):task_configuration }
---@return Task?
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

  local o = {
    meta = {},
    configuration = configuration,
    present = {},
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
    activator = opts.activator or function() end,
  }
  setmetatable(o, self)
  self.__index = self

  -- configure metadata and other config related stuff
  o:update_config(configuration)

  return o
end

-- updates task's config
---@param configuration task_configuration
function Task:update_config(configuration)
  -- presentation
  self.present = {
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
        self.present.menu.show = false
      end
    end
  end

  -- metadata
  local name = configuration.name or "[empty name]"
  local scope = configuration.scope or "[empty scope]"
  local group = configuration.group or "[empty group]"
  self.meta = {
    id = scope .. "." .. group .. "." .. name,
    name = name,
    scope = scope,
    group = group,
  }
end

-- Run a task and hadle it's dependencies
---@param opts? { mode: task_mode, callback: fun(success: boolean), restart: boolean }
function Task:run(opts)
  -- set task as active
  self.activator()

  -- setup options
  opts = opts or {}
  local mode = opts.mode or self.last_mode or self.modes[1]
  self.last_mode = mode
  local callback = opts.callback or function(_) end
  local restart = opts.restart or false

  -- If any output is already live, return
  if self:is_live() and not restart then
    self:show()
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
          self:run(opts)
          return
        end

        dep.status = "error"
        utils.log("error", 'Problem with dependency: "' .. dep.task:metadata().id .. '".', "Task " .. self.meta.name)
        -- trigger callback, stop further dependency execution and revert task's dependency statuses
        callback(false)
        revert_dep_statuses()
      end

      -- Run the dependency (restart it if already running)
      dep.task:run { mode = self.dependency_mode, callback = cb, restart = true }
      return
    end
  end
  -- revert dependency statuses if all dependencies are successfully finished
  revert_dep_statuses()

  -- handle post task with on_success output callback
  local cb = function(ok)
    if ok then
      if self.after then
        self.after:run { mode = self.dependency_mode }
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

-- sets dependencies and after tasks
---@param deps Task[]
---@param after? Task
function Task:set_accompanying_tasks(deps, after)
  self.dependencies = {}
  for _, dep in ipairs(deps) do
    table.insert(self.dependencies, { status = "", task = dep })
  end

  self.after = after
end

---@return task_mode[] all # all modes
---@return task_mode? latest # last mode that this task was ran in
function Task:get_modes()
  return self.modes, self.last_mode
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

function Task:show()
  -- set task as active
  self.activator()

  local o = self.output
  if o and o:status() == "hidden" then
    o:show()
  end
end

function Task:hide()
  local o = self.output
  if o and o:status() == "visible" then
    o:hide()
  end
end

function Task:kill()
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

---@return task_presentation
function Task:presentation()
  return self.present
end

return Task
