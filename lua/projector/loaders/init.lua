local BuiltinLoader = require("projector.loaders.builtin")
local DapLoader = require("projector.loaders.dap")

---@mod projector.ref.loaders Loaders
---@brief [[
---Loaders load tasks (see |TaskConfiguration|) from various sources - it can
---be a json file or an encrypted yaml file.
---
---To create a new loader one has to implement the Loader iterface and pass it with
---config to setup function.
---@brief ]]

---Loader interface.
---@class Loader
---@field name fun(self: Loader):string function to return the output's name
---@field load fun(self: Loader):TaskConfiguration[] function that provides task configurations from the source
---@field expand? fun(self: Loader, config: TaskConfiguration):TaskConfiguration function that expands config's variables
---@field file? fun(self: Loader):string function that provides the source file name

local M = {
  BuiltinLoader = BuiltinLoader,
  DapLoader = DapLoader,
}

return M
