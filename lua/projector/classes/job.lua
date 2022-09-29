local Output = require 'projector.classes.output'
local utils = require 'projector.utils'
local config = require 'projector_new'.config

local Job = {}

function Job:new(task)
  if not task then
    return
  end

  local o = {
    id = utils.generate_table_id(task.configuration),
    name = task.meta.name or "[empty name]",
    task = task,
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

function Job:configure_outputs()
  for _, cap in pairs(self.task.capabilities) do
    if not self.outputs[cap] then

      -- create a new output
      local output = Output:new(self.task.configuration, {
        name = self.task.meta.name,
        env = self.task.configuration.env,
        clear_env = false,
        cwd = self.task.configuration.cwd,
      })

      if not output then
        print("Output could not be created")
        return
      end

      -- register output's implementation
      local implementation = config.outputs[cap]

      output:set_function_init(implementation.init)
      output:set_function_open(implementation.open)
      output:set_function_close(implementation.close)

      self.outputs[cap] = output

    end
  end
end

-- Send a task to the desired output
function Job:run(cap)
  if not cap then
    return
  end
  -- If any output is active, return
  if self:is_active() then
    return
  end

  self:configure_outputs()

  self.outputs[cap]:init()
end

function Job:is_active()
  for _, o in pairs(self.outputs) do
    if o and o.status ~= "inactive" and o.status ~= "" then
      return true
    end
  end
  return false
end

function Job:is_hidden()
  for _, o in pairs(self.outputs) do
    if o.status == "hidden" then
      return true
    end
  end
  return false
end

function Job:open_output()
  for _, o in pairs(self.outputs) do
    if o.status == "hidden" then
      o:open()
      return
    end
  end
end

function Job:close_output()
  for _, o in pairs(self.outputs) do
    if o.status == "active" then
      o:close()
      return
    end
  end
end

return Job
