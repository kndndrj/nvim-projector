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

  local o = {
    meta = {
      id = utils.generate_table_id(configuration),
      name = configuration.name or "[empty name]",
      scope = opts.scope or "[empty scope]", -- source of task (global or project)
      type = configuration.type or "[empty type]", -- probably language (go, python, lua...)
    },
    capabilities = capabilities, -- what can the task do (debug, task)
    configuration = configuration, --configuration of the task (command, args, env, cwd...)
    outputs = { -- table of outputs per task's capabilities
      -- task = <>
      -- debug = <>
      -- ...
    },
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Task:configure_outputs()
  for _, cap in pairs(self.capabilities) do
    if not self.outputs[cap] then

      -- create a new output
      local Output = require 'projector.config'.outputs[cap]
      local output = Output:new { name = self.meta.name, }

      if not output then
        print("Output could not be created")
        return
      end

      self.outputs[cap] = output

    end
  end
end

-- Send a task to the desired output
function Task:run(cap)
  if not cap then
    return
  end
  -- If any output is live, return
  if self:is_live() then
    return
  end

  self:configure_outputs()

  self.outputs[cap]:init(self.configuration:expand_variables())
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
