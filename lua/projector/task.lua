local utils = require 'projector.utils'

local Task = {}

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
  if utils.is_in_table(configuration, { exact = { "type", "request", "program" } }) then
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
      scope = scope, -- source of task (global or project)
      lang = lang, -- language group (go, python, lua...)
    },
    capabilities = capabilities, -- what can the task do (debug, task)
    configuration = configuration, --configuration of the task (command, args, env, cwd...)
    dependencies = { -- list of dependent tasks
      -- {
      --   task = <>,
      --   status = "",
      -- },
    },
    outputs = nil, -- output that's configured per capability
    _callback_success = function() end, -- callback function mainly for handling dependencies
    _callback_problem = function() end, -- callback function mainly for handling dependencies
    _expand_config_variables = function() end -- function that gets assigned to a task by a loader
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Task:set_callback_success(func)
  self._callback_success = function()
    func()
    self._callback_success = function() end
  end
end

function Task:set_callback_problem(func)
  self._callback_problem = function()
    func()
    self._callback_problem = function() end
  end
end

---@param func function(config: table): table
function Task:set_expand_variables(func)
  self._expand_config_variables = func
end

-- Run a task and hadle it's dependencies
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

function Task:list_actions()
  local o = self.output
  if o and o.status ~= "inactive" and o.status ~= "" then
    return o:list_actions()
  end
end

return Task
