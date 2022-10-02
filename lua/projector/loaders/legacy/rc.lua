local Task = require 'projector.task'
local Configuration = require 'projector.contract.configuration'
local Loader = require 'projector.contract.loader'
local common = require 'projector.loaders.legacy.common'

local LegacyRcLoader = Loader:new("legacy-rc")

function LegacyRcLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

function LegacyRcLoader:load()
  local data = require 'projector'.configurations

  -- map with Task objects
  local tasks = {}

  for scope, range in pairs(data) do

    for _, langs in pairs(range) do

      for lang, configs in pairs(langs) do
        for _, config in pairs(configs) do

          config.dependencies = config.depends
          -- if run_command field exists, add the task capability
          if config.run_command then
            config.command = config.run_command
          end
          local configuration = Configuration:new(config)
          local task = Task:new(configuration, { scope = scope, lang = lang })
          table.insert(tasks, task)

        end
      end
    end

  end

  return tasks
end

return LegacyRcLoader
