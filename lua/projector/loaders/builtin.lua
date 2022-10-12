local Task = require("projector.task")
local Loader = require("projector.contract.loader")
local common = require("projector.loaders.common")
local utils = require("projector.utils")

---@type Loader
local BuiltinLoader = Loader:new("builtin")

---@param opt string|function|Configuration[] Path to projector.json OR a function that returns a list of configurations OR a list of configurations
---@return Task[]|nil
function BuiltinLoader:load(opt)
  local data
  local scope

  if not opt or type(opt) == "string" then
    local path = opt or (vim.fn.getcwd() .. "/.vim/projector.json")
    if not vim.loop.fs_stat(path) then
      return
    end

    local lines = {}
    for line in io.lines(path) do
      if not vim.startswith(vim.trim(line), "//") then
        table.insert(lines, line)
      end
    end

    local contents = table.concat(lines, "\n")
    local ok
    ok, data = pcall(vim.fn.json_decode, contents)
    if not ok then
      utils.log("error", 'Could not parse json file: "' .. path .. '".', "Builtin Loader")
      return
    end
    scope = "project"
  elseif type(opt) == "function" then
    data = opt()
    scope = "global"
  elseif type(opt) == "table" then
    data = opt
    scope = "global"
  else
    utils.log("error", 'Got: "' .. type(opt) .. '", want "string"|"function"|"table".', "Builtin Loader")
    return
  end

  ---@type Task[]
  local tasks = {}

  ---@type _, Configuration
  for _, config in pairs(data) do
    local task_opts = { scope = scope, group = config.group }
    local task = Task:new(config, task_opts)
    table.insert(tasks, task)
  end

  return tasks
end

---@param configuration Configuration
---@return Configuration
function BuiltinLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return BuiltinLoader
