local projector = require'projector'
local utils = require'projector.utils'
local dap = require'dap'
local projector_configs = require'projector'.configurations

local M = {}


-- retrieve any existing configurations from dap
function M.load_dap_configurations()
  local dap_configurations = dap.configurations

  for group, configurations in pairs(dap_configurations) do
    if not projector.configurations.global.debug[group] then
      projector.configurations.global.debug[group] = {}
    end
    for _, configuration in pairs(configurations) do
      table.insert(projector.configurations.global.debug[group], configuration)
    end
  end
end


function M.load_project_configurations(path)
  local resolved_path = path or (vim.fn.getcwd() .. '/.vim/projector.json')

  if not vim.loop.fs_stat(resolved_path) then
    return
  end

  local lines = {}
  for line in io.lines(resolved_path) do
    if not vim.startswith(vim.trim(line), '//') then
      table.insert(lines, line)
    end
  end

  local contents = table.concat(lines, '\n')
  local valid_json, data = pcall(vim.fn.json_decode, contents)

  if not valid_json then
    vim.notify('Error parsing project json file: ' .. resolved_path, vim.log.levels.ERROR, {title= 'nvim-projector'})
    return false
  end

  -- debug configurations
  if data.debug then
    for group, configurations in pairs(data.debug) do
      if not projector_configs.project.debug[group] then
        projector_configs.project.debug[group] = {}
      end
      for _, configuration in pairs(configurations) do
        -- if run_command field exists, add the config to tasks as well
        if configuration.run_command then
          if not projector_configs.project.tasks[group] then
            projector_configs.project.tasks[group] = {}
          end
          local task = {
            name = configuration.name,
            command = configuration.run_command,
            args = configuration.args,
            env = configuration.env,
            console = configuration.console,
          }
          table.insert(projector_configs.project.tasks[group], task)
        end
        table.insert(projector_configs.project.debug[group], configuration)
      end
    end
  end

  -- task configurations
  if data.tasks then
    for group, configurations in pairs(data.tasks) do
      if not projector_configs.project.tasks[group] then
        projector_configs.project.tasks[group] = {}
      end
      for _, configuration in pairs(configurations) do
        table.insert(projector_configs.project.tasks[group], configuration)
      end
    end
  end

  -- database configurations
  if data.database then
    for setting, configuration in pairs(data.database) do
      vim.g[setting] = configuration
    end
  end
end


-- Append all configurations to a list, depending on the filters and sort by value
-- filters:
--      project <bool>
--      global <bool>
--      debug <bool>
--      tasks <bool>
--      group <string> - e.g. "go", "python", "c"
-- sort:
--      key <string> - "scope", "type", "group"
--      order <bool> - true - asc, false - desc
function M.list_configurations(filters, sort)
  if filters == nil or next(filters) == nil then
    filters = {
      project = true,
      global = true,
      debug = true,
      tasks = true,
      group = nil,
    }
  end
  local list = {}
  for scope, scopes in pairs(projector.configurations) do

    if filters[scope] then
    for task_type, types in pairs(scopes) do

      if filters[task_type] then
      for group, configs in pairs(types) do

        if filters.group == nil or utils.contains(filters.group, group) then
        for _, config in pairs(configs) do
          if not config.projector then
            config.projector = {}
          end
          config.projector.type = task_type
          config.projector.group = group
          config.projector.scope = scope
          table.insert(list, config)
        end
        end
      end
      end
    end
    end
  end

  -- sort if specified
  if sort ~= nil and next(sort) ~= nil then
    local sort_fn = function (k1, k2) return k1.projector[sort.key] < k2.projector[sort.key] end
    if not sort.order then
      sort_fn = function (k1, k2) return k1.projector[sort.key] > k2.projector[sort.key] end
    end
    table.sort(list, sort_fn)
  end

  return list
end

return M
