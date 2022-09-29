local Task = require 'projector.classes.task'

local M = {}

function M.load(path)
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
    for _, configurations in pairs(data.debug) do
      for _, configuration in pairs(configurations) do

        local task_opts = { capabilities = { "debug" }, scope = "project" }
        -- if run_command field exists, add the task capability
        if configuration.run_command then
          table.insert(task_opts.capabilities, "task")
          configuration.command = configuration.run_command
        end
        local task = Task:new(configuration, task_opts)
        table.insert(tasks, task)

      end
    end
  end

  -- task configurations
  if data.tasks then
    for type, configurations in pairs(data.tasks) do
      for _, configuration in pairs(configurations) do

        -- add type to the configuration
        configuration.type = type
        local task_opts = { capabilities = { "task" }, scope = "project" }
        local task = Task:new(configuration, task_opts)
        table.insert(tasks, task)

      end
    end
  end

  -- database configurations
  -- TODO: make this cleaner
  if data.database then
    for setting, configuration in pairs(data.database) do
      vim.g[setting] = configuration
    end
  end

  return tasks
end

return M
