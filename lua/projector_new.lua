local utils = require'projector.utils'
local M = {}

-- load config
M.config = require 'projector.config'

-- table of jobs
-- key: job.id
-- value: job
M.jobs = {}

local function load_jobs()
  local Job = require 'projector.classes.job'
  local config = M.config

  local tasks = {}

  -- Load all tasks from different loaders
  for _, loader in pairs(config.loaders) do
    local t = loader.module.load(loader.path)
    tasks = vim.tbl_extend("keep", tasks, t)
  end

  -- Assign tasks to jobs
  for _, task in pairs(tasks) do
    local j = Job:new(task)
    if j then
      M.jobs[j.id] = j
    end
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

function M.active_jobs()
  local active = {}
  for _, j in pairs(M.jobs) do
    if j:is_active() then
      table.insert(active, j)
    end
  end
  return active
end

function M.hidden_jobs()
  local hidden = {}
  for _, j in pairs(M.jobs) do
    if j:is_active() then
      table.insert(hidden, j)
    end
  end
  return hidden
end

function M.continue()
  vim.ui.select(
    utils.expand_table(M.jobs),
    {
      prompt = 'select a job:',
      format_item = function(item)
        return item.name
      end,
    },
    function(choice)
      choice:run("task")
    end
  )
end

return M
