local Task = require 'projector.task'
local Loader = require 'projector.contract.loader'
local common = require 'projector.loaders.common'

---@type Loader
local BuiltinLoader = Loader:new("builtin")

---@param opt string|function|Configuration[] Path to projector.json OR a function that returns a list of configurations OR a list of configurations
---@return Task[]|nil
function BuiltinLoader:load(opt)
  local data

  if not opt or type(opt) == "string" then
    local path = opt or (vim.fn.getcwd() .. '/.vim/projector.json')
    if not vim.loop.fs_stat(path) then
      return
    end

    local lines = {}
    for line in io.lines(path) do
      if not vim.startswith(vim.trim(line), '//') then
        table.insert(lines, line)
      end
    end

    local contents = table.concat(lines, '\n')
    data = vim.fn.json_decode(contents)

  elseif type(opt) == "function" then
    data = opt()
  elseif type(opt) == "table" then
    data = opt
  end

  ---@type Task[]
  local tasks = {}

  ---@type _, Configuration
  for _, config in pairs(data) do
    local scope = config.scope or "global"
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
