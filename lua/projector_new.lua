local utils = require 'projector.utils'
local M = {}

-- load config
M.config = require 'projector.config'

-- table of jobs
-- key: job.id
-- value: job
M.tasks = {}

local function load_jobs()
  local config = M.config

  local tasks = {}

  -- Load all tasks from different loaders
  for _, loader in pairs(config.loaders) do
    local l = loader.module
    local t = l:load(loader.path)
    tasks = vim.tbl_extend("keep", tasks, t)
  end

  -- add to global array
  for _, t in pairs(tasks) do
    M.tasks[t.meta.id] = t
  end

end

-- setup function
-- args:
--   config: config-like table (projector.cofig)
function M.setup(config)
  load_jobs()
end

function M.refresh_jobs()
  load_jobs()
end

function M.live_tasks()
  local active = {}
  for _, t in pairs(M.tasks) do
    if t:is_live() then
      table.insert(active, t)
    end
  end
  return active
end

function M.hidden_tasks()
  local hidden = {}
  for _, t in pairs(M.tasks) do
    if t:is_live() then
      table.insert(hidden, t)
    end
  end
  return hidden
end

local function select_and_run_task()
  if vim.tbl_isempty(M.tasks) then
    print("no tasks configured")
    return
  end
  vim.ui.select(
    utils.expand_table(M.tasks),
    {
      prompt = 'select a job:',
      format_item = function(item)
        return item.meta.name
      end,
    },
    function(choice)
      if choice then
        choice:run("task")
      end
    end
  )
end

function M.continue()
  local running_tasks = M.live_tasks()

  if vim.tbl_isempty(running_tasks) then
    select_and_run_task()
    return
  end

  -- get actions from all active tasks
  local actions = {}
  for _, t in pairs(running_tasks) do
    local t_actions = t:list_actions()
    if t_actions then
      actions = vim.tbl_extend("keep", actions, t_actions)
    end
  end

  if vim.tbl_isempty(actions) then
    select_and_run_task()
    return
  end

  -- if any overrides specified, run them and return
  local has_overrides = false
  for _, a in pairs(actions) do
    if a.override then
      a.action()
      has_overrides = true
    end
  end
  if has_overrides then
    return
  end

  -- add a task selector action
  table.insert(actions, 1, {
    label = "Run a task",
    action = select_and_run_task,
  })

  -- select an action
  vim.ui.select(
    actions,
    {
      prompt = 'select an action:',
      format_item = function(item)
        return item.label
      end,
    },
    function(choice)
      if choice then
        choice.action()
      end
    end
  )

end

return M
