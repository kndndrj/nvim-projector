local Task = require 'projector.task'
local Loader = require 'projector.contract.loader'

---@type Loader
local DapLoader = Loader:new("dap")

---@return Task[]|nil
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
      local task = Task:new(config, task_opts)
      table.insert(tasks, task)
    end
  end

  return tasks
end

-- just to avoid "not_implemented" error
-- dap handles variables itself
---@param configuration Configuration
---@return Configuration
function DapLoader:expand_variables(configuration)
  return configuration
end

return DapLoader
