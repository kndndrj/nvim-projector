local Task = require 'projector.task'
local Configuration = require 'projector.contract.configuration'
local Loader = require 'projector.contract.loader'
local common = require 'projector.loaders.legacy.common'

local LegacyJsonLoader = Loader:new("legacy-json")

function LegacyJsonLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

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

  -- debug configurations
  if data.debug then
    for lang, configs in pairs(data.debug) do
      for _, config in pairs(configs) do

        config.dependencies = config.depends
        local task_opts = { capabilities = { "debug" }, scope = "project", lang = lang }
        -- if run_command field exists, add the task capability
        if config.run_command then
          table.insert(task_opts.capabilities, "task")
          config.command = config.run_command
        end
        local configuration = Configuration:new(config)
        local task = Task:new(configuration, task_opts)
        table.insert(tasks, task)

      end
    end
  end

  -- task configurations
  if data.tasks then
    for lang, configs in pairs(data.tasks) do
      for _, config in pairs(configs) do

        -- add type to the configuration
        config.dependencies = config.depends
        local task_opts = { capabilities = { "task" }, scope = "project", lang = lang }
        local configuration = Configuration:new(config)
        local task = Task:new(configuration, task_opts)
        table.insert(tasks, task)

      end
    end
  end

  -- database configurations
  -- TODO: make this cleaner
  if data.database then
    for setting, config in pairs(data.database) do
      vim.g[setting] = config
    end
  end

  return tasks
end

return LegacyJsonLoader
