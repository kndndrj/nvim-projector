local BuiltinLoader = require("projector.loaders.builtin")
local DapLoader = require("projector.loaders.dap")

---@class Loader
---@field name fun(self: Loader):string function to return the output's name
---@field load fun(self: Loader):task_configuration[]? function that provides task configurations from the source
---@field expand? fun(self: Loader, config: task_configuration):task_configuration function that expands config's variables
---@field file? fun(self: Loader):string function that provides the source file name

local M = {
  BuiltinLoader = BuiltinLoader,
  DapLoader = DapLoader,
}

return M
