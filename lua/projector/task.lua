-- Table of configuration parameters
---@alias Configuration table<string, any>

-- Table of actions
---@alias Action { label: string, action: fun(), override: boolean } table of actions

-- What modes can the task run in
---@alias Capability "task"|"debug"|"database"


local utils = require 'projector.utils'


---@class Task
---@field meta { id: string, name: string, scope: string, lang: string } id, name, scope (project or global), lang (language group)
---@field capabilities Capability[] What can the task do (debug, task)
---@field configuration Configuration Configuration of the task (command, args, env, cwd...)
---@field dependencies { task: Task, status: "done"|"error"|"" } List of dependent tasks
---@field output Output Output that's configured per capability
---@filed _callback_success fun() Callback function mainly for handling dependencies
---@filed _callback_problem fun() Callback function mainly for handling dependencies
---@filed _expand_config_variables fun(configuration: Configuration): Configuration Function that gets assigned to a task by a loader
local Task = {}

---@param configuration Configuration
function Task:new(configuration, opts)
  if not configuration then
    return
  end
  opts = opts or {}

  -- capabilities
  local capabilities = {}
  if utils.is_in_table(configuration, { exact = { "command" } }) then
    table.insert(capabilities, "task")
  end
  if utils.is_in_table(configuration, { exact = { "type", "request" } }) then
    table.insert(capabilities, "debug")
  end
  if utils.is_in_table(configuration, { prefixes = { "db" } }) then
    table.insert(capabilities, "database")
  end
  if vim.tbl_isempty(capabilities) then
    return
  end


  local name = configuration.name or "[empty name]"
  local scope = opts.scope or "[empty scope]"
  local lang = opts.lang or "[empty lang]"

  local o = {
    meta = {
      id = scope .. "." .. lang .. "." .. name or utils.generate_table_id(configuration),
      name = name,
      scope = scope,
      lang = lang,
    },
    capabilities = capabilities,
    configuration = configuration,
    dependencies = {},
    output = nil,
    _callback_success = function() end,
    _callback_problem = function() end,
    _expand_config_variables = function() end
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Set a success callback function
---@param func fun()
function Task:set_callback_success(func)
  self._callback_success = function()
    func()
    self._callback_success = function() end
  end
end

-- Set a problem callback function
---@param func fun()
function Task:set_callback_problem(func)
  self._callback_problem = function()
    func()
    self._callback_problem = function() end
  end
end

-- Set a function for expanding config variables
---@param func function(config: Configuration): Configuration
function Task:set_expand_variables(func)
  self._expand_config_variables = func
end

-- Run a task and hadle it's dependencies
---@param cap Capability
function Task:run(cap)
  if not cap then
    self._callback_problem()
    return
  end
  -- If any output is already live, return
  if self:is_live() then
    print(self.meta.name .. " already running")
    self._callback_success()
    return
  end

  -- run the first not completed dependency
  for _, dep in pairs(self.dependencies) do
    if dep.status ~= "done" and dep.status ~= "error" then
      dep.task:set_callback_success(function() dep.status = "done"; self:run(cap) end)
      dep.task:set_callback_problem(function() dep.status = "error"; print("error running deps for: " .. self.meta.id) end)
      dep.task:run("task")
      return
    end
  end
  -- revert dependency statuses
  for _, dep in pairs(self.dependencies) do
    dep.status = ""
  end

  -- create a new output
  local Output = require 'projector.config'.outputs[cap]
  local output = Output:new {
    name = self.meta.name,
    on_success = function() self._callback_success() end,
    on_problem = function() self._callback_problem() end,
  }

  if not output then
    self._callback_problem()
    return
  end

  self.output = output

  -- run this task
  self.output:init(self._expand_config_variables(self.configuration))
end

---@return Capability[]
function Task:get_capabilities()
  return self.capabilities
end

function Task:is_live()
  local o = self.output
  if o and o.status ~= "inactive" and o.status ~= "" then
    return true
  end
  return false
end

function Task:is_active()
  local o = self.output
  if o and o.status == "active" then
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

function Task:open_output()
  local o = self.output
  if o and o.status == "hidden" then
    o:open()
    return
  end
end

function Task:close_output()
  local o = self.output
  if o and o.status == "active" then
    o:close()
    return
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
