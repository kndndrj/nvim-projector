local MockedTask = require("projector.handler.task_mock")

-- Lookup is a "dumb" storage for sources and connections
-- and their relations
---@class Lookup
---@field private tasks table<task_id, Task> map of tasks
---@field private order task_id[] order of tasks (task ids)
---@field private order_lookup table<task_id, integer> lookup for task's position in the order list
---@field private selected task_id selected task's id
local Lookup = {}

---@return Lookup
function Lookup:new()
  local o = {
    tasks = {},
    order = {},
    order_lookup = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Replaces tasks with new ones
---@param tasks Task[]
function Lookup:replace_tasks(tasks)
  if not tasks or #tasks < 1 then
    return
  end

  -- keep live tasks
  local keep = {}
  for id, task in pairs(self.tasks) do
    if task:is_live() then
      keep[id] = task
    end
  end

  self.tasks = keep

  -- add new tasks
  self:add_tasks(tasks)
end

-- Adds new tasks
---@param tasks Task[]
function Lookup:add_tasks(tasks)
  if not tasks then
    return
  end

  -- add tasks to lookup
  for _, task in ipairs(tasks) do
    local id = task:metadata().id

    -- if the task with id already exists, just update it's config
    local existing = self.tasks[id]
    if existing then
      existing:update_config(task:config())
    else
      self.tasks[id] = task
    end
  end

  -- update order
  self.order = {}
  for id in pairs(self.tasks) do
    table.insert(self.order, id)
  end

  table.sort(self.order)

  -- update order_lookup
  self.order_lookup = {}
  for i, id in ipairs(self.order) do
    self.order_lookup[id] = i
  end

  self:configure_dependencies()
end

-- configure dependencies and post tasks for tasks
---@private
function Lookup:configure_dependencies()
  for _, task in pairs(self.tasks) do
    local deps = {}
    if task:config().dependencies then
      for _, id in ipairs(task:config().dependencies) do
        local dep = self.tasks[id]
        if dep then
          table.insert(deps, dep)
        end
      end
    end

    local after
    if task:config().after then
      after = self.tasks[task:config().after]
    end

    task:set_accompanying_tasks(deps, after)
  end
end

---@param filter? { live: boolean, visible: boolean }
---@return Task[] tasks
function Lookup:get_all(filter)
  local tasks = {}
  filter = filter or {}

  for _, id in ipairs(self.order) do
    local task = self.tasks[id]

    if filter.live == true and not task:is_live() then
      goto continue
    elseif filter.live == false and task:is_live() then
      goto continue
    elseif filter.visible == true and not task:is_visible() then
      goto continue
    elseif filter.visible == false and task:is_visible() then
      goto continue
    end

    table.insert(tasks, self.tasks[id])

    ::continue::
  end

  return tasks
end

---@param id task_id
---@return Task? task
function Lookup:get(id)
  return self.tasks[id]
end

---@param live? boolean select the first live task if the selected one is not running
---@return Task
function Lookup:get_selected(live)
  local task = self.tasks[self.selected] or self:select_next()

  if live and not task:is_live() then
    task = self:select_next(true)
  end

  -- set the task as selected
  self:set_selected(task:metadata().id)

  return task
end

---@param id task_id
function Lookup:set_selected(id)
  if self.tasks[id] then
    self.selected = id
  end
end

---@param live? boolean should the next task be live
---@return Task
function Lookup:select_next(live)
  local index = self.order_lookup[self.selected] or 0

  local selected
  for _ = 1, #self.order do
    if index >= #self.order then
      index = 0
    end

    local id = self.order[index + 1]
    if not live then
      selected = id
      break
    end

    if self.tasks[id]:is_live() then
      selected = id
      break
    end

    index = index + 1
  end

  self.selected = selected or self.selected

  return self.tasks[self.selected] or MockedTask:new()
end

---@param live? boolean should the previous task be live
---@return Task
function Lookup:select_prev(live)
  local index = self.order_lookup[self.selected] or #self.order + 1

  local selected
  for _ = 1, #self.order do
    if index <= 1 then
      index = #self.order + 1
    end

    local id = self.order[index - 1]
    if not live then
      selected = id
      break
    end

    if self.tasks[id]:is_live() then
      selected = id
      break
    end

    index = index - 1
  end

  self.selected = selected or self.selected

  -- and show only this one
  return self.tasks[self.selected] or MockedTask:new()
end

return Lookup
