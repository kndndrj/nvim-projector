---@class Loader
---@field name string
local Loader = {}

function Loader:new(name)
  local o = {
		name = name or "[empty loader name]",
	}
  setmetatable(o, self)
  self.__index = self
  return o
end

---@param path string
---@return Task[]|nil
---@diagnostic disable-next-line: unused-local
function Loader:load(path)
	error("not_implemented")
end

---@param configuration Configuration
---@return Configuration
---@diagnostic disable-next-line: unused-local
function Loader:expand_variables(configuration)
	error("not_implemented")
end

return Loader
