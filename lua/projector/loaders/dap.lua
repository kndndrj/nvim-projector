---@class DapLoader: Loader
local DapLoader = {}

---@return DapLoader
function DapLoader:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return string
function DapLoader:name()
  return "dap"
end

---@return task_configuration[]?
function DapLoader:load()
  local has_dap, dap = pcall(require, "dap")
  if not has_dap then
    return
  end

  ---@type task_configuration[]
  local configurations = {}

  for _, configs in pairs(dap.configurations) do
    for _, config in ipairs(configs) do
      table.insert(configurations, config)
    end
  end

  return configurations
end

return DapLoader
