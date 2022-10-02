local utils = require 'projector.utils'

---@class Handler
---@field tasks { [string]: Task }
---@field index string id of the current task
local Handler = {}

function Handler:new()
  local o = {
    tasks = {},
    index = nil,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Load tasks from all loaders
function Handler:load_sources()
  local config = require 'projector.config'

  local tasks = {}
  -- Load all tasks from different loaders
  for _, loader in pairs(config.loaders) do
    local l = loader.module
    local ts = l:load(loader.path)
    if ts then
      for _, t in pairs(ts) do
        t:set_expand_variables(function(c) return l:expand_variables(c) end)
        table.insert(tasks, t)
      end
    end
  end

  -- add all tasks to global array
  for _, t in pairs(tasks) do
    self.tasks[t.meta.id] = t
  end

  -- configure dependencies for tasks
  -- TODO: prevent dependency cycles
  for _, t in pairs(self.tasks) do
    if t.configuration.dependencies then
      for _, d in pairs(t.configuration.dependencies) do
        table.insert(t.dependencies, {
          status = "",
          task = self.tasks[d],
        })
      end
    end
  end
end

-- Get tasks that are currently live (hidden or visible)
---@return { [string]: Task }
function Handler:live_tasks()
  local live = {}
  for _, t in pairs(self.tasks) do
    if t:is_live() then
      live[t.meta.id] = t
    end
  end
  return live
end

-- Get tasks that are currently visible
---@return { [string]: Task }
function Handler:visible_tasks()
  local visible = {}
  for _, t in pairs(self.tasks) do
    if t:is_visible() then
      visible[t.meta.id] = t
    end
  end
  return visible
end

-- Get tasks that are currently hidden
---@return Task[]
function Handler:hidden_tasks()
  local hidden = {}
  for _, t in pairs(self.tasks) do
    if t:is_hidden() then
      hidden[t.meta.id] = t
    end
  end
  return hidden
end

-- Select a task and it's capability and run it
function Handler:select_and_run()
  if vim.tbl_isempty(self.tasks) then
    print("no tasks configured")
    return
  end
  vim.ui.select(
    utils.expand_table(self.tasks),
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
          -- hide all other visible tasks and open this one
          for _, t in pairs(self:visible_tasks()) do
            t:close_output()
          end
          self.index = choice.meta.id
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
                -- hide all other visible tasks and open this one
                for _, t in pairs(self:visible_tasks()) do
                  t:close_output()
                end
                self.index = choice.meta.id
                choice:run(c)
              end
            end
          )

        end
      end
    end
  )
end

-- Start new tasks, interact with live ones.
-- Acts as an entrypoint to the program
function Handler:continue()
  local live_tasks = self:live_tasks()

  if vim.tbl_isempty(live_tasks) then
    self:select_and_run()
    return
  end

  -- get actions from all live tasks
  local actions = {}
  for _, t in pairs(live_tasks) do
    local t_actions = t:list_actions()
    if t_actions then
      actions = vim.tbl_extend("keep", actions, t_actions)
    end
  end

  if vim.tbl_isempty(actions) then
    self:select_and_run()
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
    action = function() self:select_and_run() end,
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

-- Jump to previous task
function Handler:next_output()

  local i = 0
  while i <= #vim.tbl_keys(self.tasks) do
    self.index = next(self.tasks, self.index)

    if self.index and self.tasks[self.index]:is_live() then
      break
    end
    i = i + 1
  end

  if not self.index then
    return
  end

  -- close all visible tasks
  for _, t in pairs(self:visible_tasks()) do
    t:close_output()
  end

  -- and open only this one
  self.tasks[self.index]:open_output()
end

function Handler:previous_output()

  ---@type { [string]: any }
  local reverse_ids = {}
  for id, _ in pairs(self.tasks) do
    reverse_ids[id] = true
  end

  local i = 0
  while i <= #vim.tbl_keys(self.tasks) do
    self.index = next(reverse_ids, self.index)

    if self.index and self.tasks[self.index]:is_live() then
      break
    end
    i = i + 1
  end

  if not self.index then
    return
  end

  -- close all visible tasks
  for _, t in pairs(self:visible_tasks()) do
    t:close_output()
  end

  -- and open only this one
  self.tasks[self.index]:open_output()
end

-- Toggle a live output or select which one to show
-- TODO: remove in the future (new functionality)
function Handler:toggle_output()
  local hidden = self:hidden_tasks()
  local visible = self:visible_tasks()

  if #vim.tbl_keys(hidden) == 1 and #vim.tbl_keys(visible) == 0 then
    -- open the only hidden element
    hidden[next(hidden)]:open_output()
    return
  elseif #vim.tbl_keys(hidden) == 0 and #vim.tbl_keys(visible) == 1 then
    -- close the only visible element
    visible[next(visible)]:close_output()
    return
  elseif #vim.tbl_keys(hidden) > 0 then
    -- select a hidden task to open
    vim.ui.select(
      utils.expand_table(hidden),
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

return Handler
