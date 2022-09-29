local Task = require 'projector.task'
local Configuration = require 'projector.contract.configuration'
local Loader = require 'projector.contract.loader'
local common = require 'projector.loaders.legacy.common'

local Config = Configuration:new()

function Config:expand_variables()
  return vim.tbl_map(common.expand_config_variables, self)
end

local LegacyRcLoader = Loader:new("legacy-rc")

function LegacyRcLoader:load()
  local data = require 'projector'.configurations

  -- map with Task objects
  local tasks = {}

  for scope, task_or_debug in pairs(data) do

    -- debug configurations
    if task_or_debug.debug then
      for _, configs in pairs(task_or_debug.debug) do
        for _, config in pairs(configs) do

          local task_opts = { capabilities = { "debug" }, scope = scope }
          -- if run_command field exists, add the task capability
          if config.run_command then
            table.insert(task_opts.capabilities, "task")
            config.command = config.run_command
          end
          local configuration = Config:new(config)
          local task = Task:new(configuration, task_opts)
          table.insert(tasks, task)

        end
      end
    end

    -- task configurations
    if task_or_debug.tasks then
      for type, configs in pairs(task_or_debug.tasks) do
        for _, config in pairs(configs) do

          -- add type to the configuration
          config.type = type
          local task_opts = { capabilities = { "task" }, scope = scope }
          local configuration = Config:new(config)
          local task = Task:new(configuration, task_opts)
          table.insert(tasks, task)

        end
      end
    end

  end

  return tasks
end

return LegacyRcLoader
