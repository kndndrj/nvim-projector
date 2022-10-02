local utils = require 'projector.utils'

local Task = {}

function Task:new(configuration, opts)
  if not configuration then
    return
  end
  opts = opts or {}

  -- capabilities
  local capabilities = opts.capabilities or {}
  if type(capabilities) == "string" then
    capabilities = { capabilities }
  end
  if not capabilities[1] then
    capabilities = { "task" }
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
    outputs = { -- table of outputs per task's capabilities
      -- task = <>
      -- debug = <>
      -- ...
    },
    _callback_success = function() end, -- callback function mainly for handling dependencies
    _callback_problem = function() end, -- callback function mainly for handling dependencies
    _expand_config_variables = function () end -- function that gets assigned to a task by a loader
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

function Task:configure_outputs()
  for _, cap in pairs(self.capabilities) do
    -- create a new output
    local Output = require 'projector.config'.outputs[cap]
    local output = Output:new {
      name = self.meta.name,
      on_success = function() self._callback_success() end,
      on_problem = function() self._callback_problem(); print("problem with dependencies") end,
    }

    if not output then
      print("Output could not be created")
      return
    end

    self.outputs[cap] = output
  end
end

-- Run a task and hadle it's dependencies
function Task:run(cap)
  if not cap then
    self._callback_problem()
    return
  end
  -- If any output is already live, return
  if self:is_live() then
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

  -- run this task
  self:configure_outputs()
  self.outputs[cap]:init(self._expand_config_variables(self.configuration))
end

function Task:get_capabilities()
  return self.capabilities
end

function Task:is_live()
  for _, o in pairs(self.outputs) do
    if o and o.status ~= "inactive" and o.status ~= "" then
      return true
    end
  end
  return false
end

function Task:is_active()
  for _, o in pairs(self.outputs) do
    if o.status == "active" then
      return true
    end
  end
  return false
end

function Task:is_hidden()
  for _, o in pairs(self.outputs) do
    if o.status == "hidden" then
      return true
    end
  end
  return false
end

function Task:open_output()
  for _, o in pairs(self.outputs) do
    if o.status == "hidden" then
      o:open()
      return
    end
  end
end

function Task:close_output()
  for _, o in pairs(self.outputs) do
    if o.status == "active" then
      o:close()
      return
    end
  end
end

function Task:list_actions()
  for _, o in pairs(self.outputs) do
    if o and o.status ~= "inactive" and o.status ~= "" then
      return o:list_actions()
    end
  end
end

return Task
