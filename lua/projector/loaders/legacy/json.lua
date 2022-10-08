local Task = require 'projector.task'
local Loader = require 'projector.contract.loader'
local common = require 'projector.loaders.common'

---@type Loader
local LegacyJsonLoader = Loader:new("legacy.json")

---@param opt string Path to legacy projector.json
---@return Task[]|nil
function LegacyJsonLoader:load(opt)
  local path = opt or (vim.fn.getcwd() .. '/.vim/projector.json')
  if type(path) ~= "string" then
    print("LegacyJsonLoader error: got " .. type(path) .. ", want string")
    return
  end

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
  local ok, data = pcall(vim.fn.json_decode, contents)
  if not ok then
    vim.notify('[Legacy JSON Loader] Error parsing json file: "' .. path .. '"', vim.log.levels.ERROR, {title= 'nvim-projector'})
    return
  end

  -- map with Task objects
  local tasks = {}

  for type, range in pairs(data) do
    if type == "debug" or type == "tasks" then

      for group, configs in pairs(range) do
        for _, config in pairs(configs) do

          -- translate dependencies
          if config.depends then
            local deps = {}
            for _, dep in ipairs(config.depends) do
              local d = string.gsub(dep, ".tasks.", ".", 1)
              d = string.gsub(d, ".debug.", ".", 1)
              table.insert(deps, d)
            end
            config.dependencies = deps
          end
          -- translate run_command
          if config.run_command then
            config.command = config.run_command
          end
          local task = Task:new(config, { scope = "project", group = group })
          table.insert(tasks, task)
        end
      end

    elseif type == "database" then
      local config = range
      config.name = "Database settings"
      config.databases = config.dbs
      config.queries = config.db_ui_table_helpers
      local task = Task:new(config, { scope = "project", group = "sql" })
      table.insert(tasks, task)
    end
  end

  return tasks
end

---@param configuration Configuration
---@return Configuration
function LegacyJsonLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return LegacyJsonLoader
