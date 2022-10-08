local utils = require 'projector.utils'

-- Information that's displayed in the picker
---@alias Display { loader: string, scope: string, group: string, name: string, modes: string|string[] }

---@class Handler
---@field tasks { [string]: Task }
---@field id_current string id of the current task
---@field id_lookup_reverse { [string]: integer } reverse lookup of task ids in order
---@field id_lookup string[] reverse lookup of task ids in order
---@field displays { [string]: Display } Table that stores task info that's displayed in the select menus
local Handler = {}

function Handler:new()
  local o = {
    tasks = {},
    id_current = nil,
    id_lookup = {},
    id_lookup_reverse = {},
    displays = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Load tasks from all loaders
function Handler:load_sources()
  ---@type config
  local config = require 'projector'.config

  local tasks = {}
  -- Load all tasks from different loaders
  for _, loader in pairs(config.loaders) do
    ---@type boolean, Loader
    local ok, l = pcall(require, 'projector.loaders.' .. loader.module)
    if ok then
      local ts = l:load(loader.opt)
      if ts then
        for _, t in pairs(ts) do
          t:set_expand_variables(function(c) return l:expand_variables(c) end)
          table.insert(tasks, t)
          -- Insert icons/names into lookup table
          self.displays[t.meta.id] = utils.map_icons {
            loader = l.name,
            scope = t.meta.scope,
            group = t.meta.group,
            name = t.meta.name,
            modes = t.modes,
          }
        end
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

  -- configure dependencies and post tasks for tasks
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
    if t.configuration.after then
      t.after = self.tasks[t.configuration.after]
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

-- Select a task and it's mode and run it
function Handler:select_and_run()
  if vim.tbl_isempty(self.tasks) then
    print("no tasks configured")
    return
  end

  -- find the longest word for each category
  local loader_max_len = utils.longest(self.displays, "loader")
  local scope_max_len = utils.longest(self.displays, "scope")
  local group_max_len = utils.longest(self.displays, "group")
  local modes_max_len = utils.longest(self.displays, "modes")
  local name_max_len = utils.longest(self.displays, "name")

  vim.ui.select(
    self.id_lookup,
    {
      prompt = 'select a task:',
      format_item = function(item)
        ---@type config
        local config = require 'projector'.config
        ---@type Display
        local display = self.displays[item]

        local loader = display.loader .. string.rep(" ", loader_max_len - vim.fn.strchars(display.loader))
        local scope = display.scope .. string.rep(" ", scope_max_len - vim.fn.strchars(display.scope))
        local group = display.group .. string.rep(" ", group_max_len - vim.fn.strchars(display.group))
        local modes = display.modes .. string.rep(" ", modes_max_len - vim.fn.strchars(display.modes))
        local name = display.name .. string.rep(" ", name_max_len - vim.fn.strchars(display.name))

        return config.display_format(loader, scope, group, modes, name)

      end,
    },
    ---@param choice string
    function(choice)
      if choice then
        local modes = self.tasks[choice]:get_modes()
        if #modes == 1 then
          -- hide all other visible tasks and show this one
          for _, t in pairs(self:visible_tasks()) do
            t:hide_output()
          end
          self.id_current = choice
          self.tasks[choice]:run(modes[1])
        elseif #modes > 1 then

          vim.ui.select(
            modes,
            {
              prompt = 'select mode:',
            },
            ---@param m Mode
            function(m)
              if m then
                -- hide all other visible tasks and show this one
                for _, t in pairs(self:visible_tasks()) do
                  t:hide_output()
                end
                self.id_current = choice
                self.tasks[choice]:run(m)
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
function Handler:next_task()

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

  -- hide all visible tasks
  for _, t in pairs(self:visible_tasks()) do
    t:hide_output()
  end

  -- and show only this one
  self.tasks[self.id_current]:show_output()
end

-- Jump to previous task's output
function Handler:previous_task()

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

  -- hide all visible tasks
  for _, t in pairs(self:visible_tasks()) do
    t:hide_output()
  end

  -- and show only this one
  self.tasks[self.id_current]:show_output()
end

-- Toggle the current output or jump to next one if this one died
function Handler:toggle_output()
  local visible = self:visible_tasks()
  local hidden = self:hidden_tasks()

  -- if any outputs are visible, hide them
  if #vim.tbl_keys(visible) > 0 then
    for _, t in pairs(visible) do
      t:hide_output()
    end
    return
  end

  -- If there are any hidden outputs, show the current one,
  -- if the current one isn't live, select the next one
  if #vim.tbl_keys(hidden) > 0 and self.id_current ~= nil then
    if self.tasks[self.id_current]:is_live() then
      self.tasks[self.id_current]:show_output()
      return
    end
    self:next_task()
    return
  end

  print('No hidden tasks running')
end

-- Kill or restart the currently selected task
---@param opts? { restart: boolean }
function Handler:kill_current_task(opts)
  opts = opts or {}
  local task = self.tasks[self.id_current]
  if not task then
    return
  end
  -- kill
  task:kill_output()

  -- restart if specified
  if opts.restart then
    task:run()
  end
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
