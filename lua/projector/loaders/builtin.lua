local common = require("projector.loaders.common")
local utils = require("projector.utils")

---@class BuiltinLoader: Loader
---@field private get_path fun():string function that returns a path to projector.json file
---@field private get_configs fun():task_configuration[] function that provides extra configs passed to new() method
local BuiltinLoader = {}

---@param opts? { path: string|fun():(string), configs: task_configuration[]|fun():(task_configuration[]) }
---@return BuiltinLoader
function BuiltinLoader:new(opts)
  opts = opts or {}

  local path_getter
  if type(opts.path) == "string" then
    path_getter = function()
      return opts.path
    end
  elseif type(opts.path) == "function" then
    path_getter = function()
      return opts.path() or ""
    end
  end

  local configs_getter
  if type(opts.configs) == "table" then
    configs_getter = function()
      return opts.configs
    end
  elseif type(opts.configs) == "function" then
    configs_getter = function()
      return opts.configs() or {}
    end
  end

  local o = {
    get_path = path_getter or function()
      return ""
    end,
    get_configs = configs_getter or function()
      return {}
    end,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return string
function BuiltinLoader:name()
  return "builtin"
end

---@return task_configuration[]?
function BuiltinLoader:load()
  ---@type task_configuration[]
  local cfgs = {}

  -- parse json file
  local path = self.get_path()
  if vim.loop.fs_stat(path) then
    local lines = {}
    for line in io.lines(path) do
      if not vim.startswith(vim.trim(line), "//") then
        table.insert(lines, line)
      end
    end

    local contents = table.concat(lines, "\n")
    local ok, data = pcall(vim.fn.json_decode, contents)
    if ok then
      vim.list_extend(cfgs, data)
    else
      utils.log("error", 'Could not parse json file: "' .. path .. '".', "Builtin Loader")
    end
  end

  -- parse extra configs
  vim.list_extend(cfgs, self.get_configs())

  return cfgs
end

---@param configuration task_configuration
---@return task_configuration
function BuiltinLoader:expand(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return BuiltinLoader
