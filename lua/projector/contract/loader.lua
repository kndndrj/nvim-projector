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

function Loader:load(path)
	error("not_implemented")
end

function Loader:expand_variables()
	error("not_implemented")
end

return Loader
