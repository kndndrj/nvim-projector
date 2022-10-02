local Task = require 'projector.task'
local Loader = require 'projector.contract.loader'
local common = require 'projector.loaders.legacy.common'

---@type Loader
local LegacyJsonLoader = Loader:new("legacy-json")

---@param path string
---@return Task[]|nil
function LegacyJsonLoader:load(path)
  path = path or (vim.fn.getcwd() .. '/.vim/projector.json')

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
  local data = vim.fn.json_decode(contents)

  -- map with Task objects
  local tasks = {}

  for type, range in pairs(data) do
    if type == "debug" or type == "tasks" then

      for lang, configs in pairs(range) do
        for _, config in pairs(configs) do
          config.dependencies = config.depends
          -- if run_command field exists, add the task capability
          if config.run_command then
            config.command = config.run_command
          end
          local task = Task:new(config, { scope = "project", lang = lang })
          table.insert(tasks, task)
        end
      end

    elseif type == "database" then
      local config = range
      config.name = "Database settings"
      local task = Task:new(config, { scope = "project", lang = "sql" })
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
