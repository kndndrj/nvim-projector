---@class Configuration
---@field command string
local Configuration = {}

function Configuration:new(opts)
  local o = opts or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

return Configuration
