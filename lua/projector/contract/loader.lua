---@class Loader
---@field user_opts any User options that can be used by extension authors
local Loader = {}

---@param opts? { user_opts: any }
function Loader:new(opts)
  opts = opts or {}
  local o = {
    user_opts = opts.user_opts or {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return Task[]|nil
function Loader:load()
  error("not_implemented")
end

---@param configuration task_configuration
---@return task_configuration
---@diagnostic disable-next-line: unused-local
function Loader:expand_variables(configuration)
  error("not_implemented")
end

return Loader
