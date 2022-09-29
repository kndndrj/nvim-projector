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

  local o = {
    meta = {
      name = configuration.name or "[empty name]",
      scope = opts.scope or "[empty scope]", -- source of task (global or project)
      type = configuration.type or "[empty type]", -- probably language (go, python, lua...)
    },
    functions = {
      expand_config_variables = function() return error("not_implemented") end, -- function that expands variables in configuration
    },
    capabilities = capabilities, -- what can the task do (debug, task)
    configuration = configuration, --configuration of the task (command, args, env, cwd...)
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Function setters
-- args:
--    func: function with signature function(self)
function Task:set_function_expand_config_variables(func)
  if type(func) ~= "function" then
    print("Invalid option type: " .. type(func))
    return
  end
  self.functions.expand_config_variables = func
end

-- Functions for expanding config variables
function Task:expand_config_variables()
  local ok, err = pcall(self.functions.expand_config_variables, self)
  if not ok then
    local msg = err
    if err == "not_implemented" then
      msg = "Task expand_config_variables function is not implemented!"
    end
    print(msg)
  end
end

return Task
