local utils = require("projector.utils")

-- Table of configuration parameters
---@class Configuration
--- common:
---@field name string
---@field scope string
---@field group string
---@field dependencies string[]
---@field after string
---@field env { [string]: string }
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
---@alias Action { label: string, action: fun(), override: boolean, nested: Action[] } table of actions

-- What modes can the task run in
---@alias Mode "task"|"debug"|"database"

---@class Task
---@field meta { id: string, name: string, scope: string, group: string } id, name, scope (project or global), group (language group)
---@field modes Mode[] What can the task do (debug, task)
---@field last_mode Mode Mode that was selected previously
---@field configuration Configuration Configuration of the task (command, args, env, cwd...)
---@field dependencies { task: Task, status: "done"|"error"|"" }[] List of dependent tasks
---@field after Task a task to run after this one is finished
---@field output Output Output that's configured per task's mode
---@filed _expand_config_variables fun(configuration: Configuration): Configuration Function that gets assigned to a task by a loader
local Task = {}

---@param configuration Configuration
function Task:new(configuration, opts)
  if not configuration then
    return
  end
  opts = opts or {}

  -- modes
  local modes = {}
  if utils.is_in_table(configuration, { "command" }) then
    table.insert(modes, "task")
  end
  if utils.is_in_table(configuration, { "type", "request" }) then
    table.insert(modes, "debug")
  end
  if utils.is_in_table(configuration, { "databases" }) or utils.is_in_table(configuration, { "queries" }) then
    table.insert(modes, "database")
  end
  if vim.tbl_isempty(modes) then
    return
  end

  -- metadata
  local name = configuration.name or "[empty name]"
  local scope = opts.scope or "[empty scope]"
  local group = opts.group or "[empty group]"

  local o = {
    meta = {
      id = scope .. "." .. group .. "." .. name,
      name = name,
      scope = scope,
      group = group,
    },
    modes = modes,
    last_mode = nil,
    configuration = configuration,
    dependencies = {},
    after = nil,
    output = nil,
    _expand_config_variables = function() end,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Set a function for expanding config variables
---@param func function(config: Configuration): Configuration
function Task:set_expand_variables(func)
  self._expand_config_variables = func
end

-- Run a task and hadle it's dependencies
---@param mode? Mode
---@param on_success? fun()
---@param on_problem? fun()
function Task:run(mode, on_success, on_problem)
  -- check parameters
  if not on_success then
    on_success = function() end
  end
  if not on_problem then
    on_problem = function() end
  end
  if not mode and not self.last_mode then
    on_problem()
    return
  end
  mode = mode or self.last_mode
  self.last_mode = mode

  -- If any output is already live, return
  if self:is_live() then
    utils.log("info", "Already live.", "Task " .. self.meta.name)
    on_success()
    return
  end

  local revert_dep_statuses = function()
    for _, dep in pairs(self.dependencies) do
      dep.status = ""
    end
  end

  -- run the first not completed dependency
  for _, dep in pairs(self.dependencies) do
    if dep.status ~= "done" and dep.status ~= "error" then
      -- Set callbacks
      local callback_success = function()
        dep.status = "done"
        dep.task:hide_output()
        self:run(mode, on_success, on_problem)
      end
      local callback_problem = function()
        dep.status = "error"
        utils.log("error", 'Problem with dependency: "' .. dep.task.meta.id .. '".', "Task " .. self.meta.name)
        -- trigger on problem, stop further dependency execution and revert task's dependency statuses
        on_problem()
        revert_dep_statuses()
      end
      -- Run the dependency in task mode
      dep.task:run("task", callback_success, callback_problem)
      return
    end
  end
  -- revert dependency statuses if all dependencies are successfully finished
  revert_dep_statuses()

  -- create a new output
  local o = require("projector").config.outputs
  ---@type boolean, Output
  local ok, Output = pcall(require, "projector.outputs." .. o[mode])
  if not ok then
    utils.log("error", 'Output for "' .. mode .. '" mode could not be created.', "Task " .. self.meta.name)
    on_problem()
    return
  end

  -- handle post task with on_success output callback
  local callback_success = on_success
  if self.after then
    callback_success = function()
      self:hide_output()
      self.after:run("task")
      on_success()
    end
  end

  ---@type Output
  local output = Output:new {
    name = self.meta.name,
    on_success = callback_success,
    on_problem = on_problem,
  }

  if not output then
    on_problem()
    return
  end

  self.output = output

  -- run this task
  self.output:init(self._expand_config_variables(self.configuration))
end

---@return Mode[]
function Task:get_modes()
  return self.modes
end

function Task:is_live()
  local o = self.output
  if o and o.status ~= "inactive" and o.status ~= "" then
    return true
  end
  return false
end

function Task:is_visible()
  local o = self.output
  if o and o.status == "visible" then
    return true
  end
  return false
end

function Task:is_hidden()
  local o = self.output
  if o and o.status == "hidden" then
    return true
  end
  return false
end

function Task:show_output()
  local o = self.output
  if o and o.status == "hidden" then
    o:show()
  end
end

function Task:hide_output()
  local o = self.output
  if o and o.status == "visible" then
    o:hide()
  end
end

function Task:kill_output()
  local o = self.output
  if o then
    o:kill()
  end
end

---@return Action[]|nil
function Task:list_actions()
  local o = self.output
  if o and o.status ~= "inactive" and o.status ~= "" then
    return o:list_actions()
  end
end

return Task
