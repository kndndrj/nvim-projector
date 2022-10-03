local utils = require 'projector.utils'

---@class Handler
---@field tasks { [string]: Task }
---@field id_current string id of the current task
---@field id_lookup_reverse { [string]: integer } reverse lookup of task ids in order
---@field id_lookup string[] reverse lookup of task ids in order
local Handler = {}

function Handler:new()
  local o = {
    tasks = {},
    id_current = nil,
    id_lookup = {},
    id_lookup_reverse = {},
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

  -- add all tasks to tasks table
  -- and create a task id lookup table
  local ids = {}
  for _, t in pairs(tasks) do
    self.tasks[t.meta.id] = t
    table.insert(ids, t.meta.id)
  end
  -- sort the lookup table alphanumerically
  ---@type string[]
  self.id_lookup = utils.alphanumsort(ids)
  for i, v in ipairs(self.id_lookup) do
    self.id_lookup_reverse[v] = i
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
---@return { [string]: Task }
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
    self.id_lookup,
    {
      prompt = 'select a job:',
      format_item = function(item)
        return self.tasks[item].meta.name
      end,
    },
    ---@param choice string
    function(choice)
      if choice then
        local caps = self.tasks[choice]:get_capabilities()
        if #caps == 1 then
          -- hide all other visible tasks and open this one
          for _, t in pairs(self:visible_tasks()) do
            t:close_output()
          end
          self.id_current = choice
          self.tasks[choice]:run(caps[1])
        elseif #caps > 1 then

          vim.ui.select(
            caps,
            {
              prompt = 'select mode:',
              format_item = function(item)
                return item
              end,
            },
            ---@param c Capability
            function(c)
              if c then
                -- hide all other visible tasks and open this one
                for _, t in pairs(self:visible_tasks()) do
                  t:close_output()
                end
                self.id_current = choice
                self.tasks[choice]:run(c)
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

-- Jump to next task's output
function Handler:next_output()

  local i = self.id_lookup_reverse[self.id_current] or 0
  local id = nil

  for _ = 1, #self.id_lookup do

    if i >= #self.id_lookup then
      i = 0
    end

    id = self.id_lookup[i + 1]

    if self.tasks[id]:is_live() then
      self.id_current = id
      break
    end

    i = i + 1
  end

  if not self.id_current then
    return
  end

  -- close all visible tasks
  for _, t in pairs(self:visible_tasks()) do
    t:close_output()
  end

  -- and open only this one
  self.tasks[self.id_current]:open_output()
end

-- Jump to previous task's output
-- TODO: not working as expected
function Handler:previous_output()

  local i = self.id_lookup_reverse[self.id_current] or #self.id_lookup + 1
  local id = nil

  for _ = 1, #self.id_lookup do

    if i <= 1 then
      i = #self.id_lookup + 1
    end

    id = self.id_lookup[i - 1]

    if self.tasks[id]:is_live() then
      self.id_current = id
      break
    end

    i = i - 1
  end

  if not self.id_current then
    return
  end

  -- close all visible tasks
  for _, t in pairs(self:visible_tasks()) do
    t:close_output()
  end

  -- and open only this one
  self.tasks[self.id_current]:open_output()
end

-- Toggle the current output or jump to next one if this one died
function Handler:toggle_output()
  local visible = self:visible_tasks()
  local hidden = self:hidden_tasks()

  -- if any outputs are visible, close them
  if #vim.tbl_keys(visible) > 0 then
    for _, t in pairs(visible) do
      t:close_output()
    end
    return
  end

  -- If there are any hidden outputs, show the current one,
  -- if the current one isn't live, select the next one
  if #vim.tbl_keys(hidden) > 0 and self.id_current ~= nil then
    if self.tasks[self.id_current]:is_live() then
      self.tasks[self.id_current]:open_output()
      return
    end
    self:next_output()
    return
  end

  print('No hidden tasks running')
end

---@return string[]
function Handler:dashboard()
  local ret = {}
  for _, id in ipairs(self.id_lookup) do
    local task = self.tasks[id]
    if task:is_live() then
      if id == self.id_current then
        table.insert(ret, "[" .. task.meta.name .. "]")
      else
        table.insert(ret, task.meta.name)
      end
    end
  end
  return ret
end

return Handler
