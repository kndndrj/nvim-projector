local Task = require("projector.task")
local Loader = require("projector.contract.loader")
local common = require("projector.loaders.common")
local utils = require("projector.utils")

---@type Loader
local BuiltinLoader = Loader:new()

---@return Task[]|nil
function BuiltinLoader:load()
  ---@type { path: string, configs: task_configuration[]|fun():task_configuration[] }
  local opts = self.user_opts or {
    path = vim.fn.getcwd() .. "/.vim/projector.json",
    configs = nil,
  }

  ---@type task_configuration[]
  local cfgs = {}

  -- parse json file
  if opts.path then
    local path = opts.path
    if vim.loop.fs_stat(path) then
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

      vim.list_extend(cfgs, data)
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

    vim.list_extend(cfgs, data)
  end

  return cfgs
end

---@param configuration task_configuration
---@return task_configuration
function BuiltinLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return BuiltinLoader
