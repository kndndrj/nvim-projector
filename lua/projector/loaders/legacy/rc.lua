local Task = require("projector.task")
local Loader = require("projector.contract.loader")
local common = require("projector.loaders.common")
local utils = require("projector.utils")

local asked = false
-- Convert old file to new format
---@param tasks Task[]
local function convert_config(tasks)
  if asked then
    return
  end
  asked = true
  -- get new configs
  local configs = {}
  for _, t in ipairs(tasks) do
    t.configuration.group = t.meta.group
    table.insert(configs, t.configuration)
  end

  local new_setup = [[
  local configs = ]] .. vim.inspect(configs) .. [[


  require 'projector'.setup {
    loaders = {
      {
        module = 'builtin',
        opt = configs,
      },
    },
  }]]

  utils.log(
    "info",
    "Detected old projector configs in init.lua.\nTo update your config, stick this in your init.lua:\n\n" .. new_setup,
    "Legacy JSON Loader"
  )
end

---@type Loader
local LegacyRcLoader = Loader:new()

---@return Task[]|nil
function LegacyRcLoader:load()
  local data = require("projector").configurations

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
            config.depends = nil
          end
          -- translate run_command
          if config.run_command then
            config.command = config.run_command
            config.run_command = nil
          end
          local task = Task:new(config, { scope = scope, group = group })
          table.insert(tasks, task)
        end
      end
    end
  end

  convert_config(tasks)

  return tasks
end

---@param configuration Configuration
---@return Configuration
function LegacyRcLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return LegacyRcLoader
