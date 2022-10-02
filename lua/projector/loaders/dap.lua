local Task = require 'projector.task'
local Configuration = require 'projector.contract.configuration'
local Loader = require 'projector.contract.loader'

local DapLoader = Loader:new("dap")

-- just to avoid "not_implemented" error
-- dap handles variables itself
function DapLoader:expand_variables(configuration)
  return configuration
end

function DapLoader:load()
  local has_dap, dap = pcall(require, "dap")
  if not has_dap then
    return
  end

  local data = dap.configurations

  -- map with Task objects
  local tasks = {}

  for lang, configs in pairs(data) do
    for _, config in pairs(configs) do
      local task_opts = { scope = "global", lang = lang }
      local configuration = Configuration:new(config)
      local task = Task:new(configuration, task_opts)
      table.insert(tasks, task)
    end
  end

  return tasks
end

return DapLoader