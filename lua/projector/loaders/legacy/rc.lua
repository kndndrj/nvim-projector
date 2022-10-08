local Task = require 'projector.task'
local Loader = require 'projector.contract.loader'
local common = require 'projector.loaders.common'

---@type Loader
local LegacyRcLoader = Loader:new("legacy.rc")

---@return Task[]|nil
function LegacyRcLoader:load()
  local data = require 'projector'.configurations

  -- map with Task objects
  local tasks = {}

  for scope, range in pairs(data) do

    for _, groups in pairs(range) do

      for group, configs in pairs(groups) do
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
          local task = Task:new(config, { scope = scope, group = group })
          table.insert(tasks, task)

        end
      end
    end

  end

  return tasks
end

---@param configuration Configuration
---@return Configuration
function LegacyRcLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return LegacyRcLoader
