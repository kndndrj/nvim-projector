local utils = require 'projector.utils'
local M = {}

-- load config
M.config = require 'projector.config'

-- table of jobs
-- key: job.id
-- value: job
M.tasks = {}

-- for legacy reason
-- TODO: remove in the future
M.configurations = {
  global = {
    debug = {},
    tasks = {},
  },
  project = {
    debug = {},
    tasks = {},
  }
}

local function load_jobs()
  local config = M.config

  local tasks = {}

  -- Load all tasks from different loaders
  for _, loader in pairs(config.loaders) do
    local l = loader.module
    local ts = l:load(loader.path)
    if ts then
      for _, t in pairs(ts) do
        table.insert(tasks, t)
      end
    end
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
  local live = {}
  for _, t in pairs(M.tasks) do
    if t:is_live() then
      table.insert(live, t)
    end
  end
  return live
end

function M.active_tasks()
  local active = {}
  for _, t in pairs(M.tasks) do
    if t:is_active() then
      table.insert(active, t)
    end
  end
  return active
end

function M.hidden_tasks()
  local hidden = {}
  for _, t in pairs(M.tasks) do
    if t:is_hidden() then
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
        local caps = choice:get_capabilities()
        if #caps == 1 then
          choice:run(caps[1])
        elseif #caps > 1 then

          vim.ui.select(
            caps,
            {
              prompt = 'select mode:',
              format_item = function(item)
                return item
              end,
            },
            function(c)
              if c then
                choice:run(c)
              end
            end
          )

        end
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

function M.toggle_output()
  local hidden_tasks = M.hidden_tasks()
  local active_tasks = M.active_tasks()

  if #hidden_tasks == 1 and #active_tasks == 0 then
    -- open the only hidden element
    hidden_tasks[1]:open_output()
    return
  elseif #hidden_tasks == 0 and #active_tasks == 1 then
    -- close the only active element
    active_tasks[1]:close_output()
    return
  elseif #hidden_tasks > 0 then
    -- select a hidden task to open
    vim.ui.select(
      hidden_tasks,
      {
        prompt = 'select a hidden task to open:',
        format_item = function(item)
          return item.meta.name
        end,
      },
      function(choice)
        if choice then
          choice:open_output()
        end
      end
    )
    return
  end

  print('No hidden tasks running')
end

function M.status()
  return "not implemented yet"
end

return M
