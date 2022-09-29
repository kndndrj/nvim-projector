local Task = require 'projector.task'
local Configuration = require 'projector.contract.configuration'
local Loader = require 'projector.contract.loader'

function Task:expand_variables(configuration)
  local function expand_config_variables(option)
    if type(option) == 'function' then
      option = option()
    end
    if type(option) == 'table' then
      return vim.tbl_map(expand_config_variables, option)
    end
    if type(option) ~= 'string' then
      return option
    end
    local variables = {
      file = vim.fn.expand('%'),
      fileBasename = vim.fn.expand('%:t'),
      fileBasenameNoExtension = vim.fn.fnamemodify(vim.fn.expand('%:t'), ':r'),
      fileDirname = vim.fn.expand('%:p:h'),
      fileExtname = vim.fn.expand('%:e'),
      relativeFile = vim.fn.expand('%'),
      relativeFileDirname = vim.fn.fnamemodify(vim.fn.expand('%:h'), ':r'),
      workspaceFolder = vim.fn.getcwd(),
      workspaceFolderBasename = vim.fn.fnamemodify(vim.fn.getcwd(), ':t'),
    }
    local ret = option
    for key, val in pairs(variables) do
      ret = ret:gsub('${' .. key .. '}', val)
    end
    return ret
  end

  return vim.tbl_map(expand_config_variables, configuration)
end

local LegacyLoader = Loader:new("legacy")

function LegacyLoader:load(path)
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
    for _, configs in pairs(data.debug) do
      for _, config in pairs(configs) do

        local task_opts = { capabilities = { "debug" }, scope = "project" }
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
    for type, configs in pairs(data.tasks) do
      for _, config in pairs(configs) do

        -- add type to the configuration
        config.type = type
        local task_opts = { capabilities = { "task" }, scope = "project" }
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

return LegacyLoader
