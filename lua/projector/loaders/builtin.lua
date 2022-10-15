local Task = require("projector.task")
local Loader = require("projector.contract.loader")
local common = require("projector.loaders.common")
local utils = require("projector.utils")

---@type Loader
local BuiltinLoader = Loader:new()

---@return Task[]|nil
function BuiltinLoader:load()
  ---@type { path: string, configs: Configuration[]|fun():Configuration[] }
  local opts = self.user_opts or {
    path = vim.fn.getcwd() .. "/.vim/projector.json",
    configs = nil
  }

  ---@type Task[]
  local tasks = {}

  -- parse json file
  if opts.path then
    local path = opts.path
    if not vim.loop.fs_stat(path) then
      -- TODO?: file not found error
      return
    end

    local lines = {}
    for line in io.lines(path) do
      if not vim.startswith(vim.trim(line), "//") then
        table.insert(lines, line)
      end
    end

    local contents = table.concat(lines, "\n")
    local ok, data = pcall(vim.fn.json_decode, contents)
    if not ok then
      utils.log("error", 'Could not parse json file: "' .. path .. '".', "Builtin Loader")
      return
    end

    ---@type _, Configuration
    for _, config in pairs(data) do
      local task_opts = { scope = "project", group = config.group }
      local task = Task:new(config, task_opts)
      table.insert(tasks, task)
    end
  end

  -- parse configs
  if opts.configs then
    local data
    if type(opts.configs) == "function" then
      data = opts.configs()
    elseif type(opts.configs) == "table" then
      data = opts.configs
    end

    ---@type _, Configuration
    for _, config in pairs(data) do
      local task_opts = { scope = "global", group = config.group }
      local task = Task:new(config, task_opts)
      table.insert(tasks, task)
    end
  end

  return tasks
end

---@param configuration Configuration
---@return Configuration
function BuiltinLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return BuiltinLoader
