local Task = require("projector.task")
local Lookup = require("projector.handler.lookup")

-- Information that's displayed in the picker
---@alias display { loader: string, scope: string, group: string, name: string, modes: string|string[] }

---@class Handler
---@field private dashboard Dashboard
---@field private lookup Lookup task lookup
---@field private loaders Loader[]
---@field private output_builders OutputBuilder[]
---@field private show boolean can outputs be shown or not
---@field private depencency_mode? task_mode mode to be used for tasks running as dependenies
---@field private automatic_reload boolean reload the loaders on each call
---@field private first_load_done boolean were configs loaded for the first time?
local Handler = {}

---@alias handler_config { depencency_mode: task_mode, automatic_reload: boolean }

---@param dashboard Dashboard
---@param loaders Loader[]
---@param output_builders OutputBuilder[]
---@param opts? handler_config
---@return Handler
function Handler:new(dashboard, loaders, output_builders, opts)
  opts = opts or {}

  if not dashboard then
    error("no Dashboard provided to Handler")
  end

  local o = {
    dashboard = dashboard,
    tasks = {},
    lookup = Lookup:new(),
    output_builders = output_builders or {},
    loaders = loaders or {},
    show = true,
    dependency_mode = opts.depencency_mode,
    automatic_reload = opts.automatic_reload or false,
    first_load_done = false,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- internediate type used for loading configs from sources
---@alias _records table<string, { config: task_configuration, loader: Loader, output_builders: OutputBuilder[] }>

---@param records _records
---@return configuraiton_picks
local function to_picks(records)
  ---@type configuraiton_picks
  local picks = {}

  for id, rec in pairs(records) do
    picks[id] = rec.config
  end

  return picks
end

-- get preprocessed records from output builders
---@private
---@param records _records
---@return _records
function Handler:preprocess(records)
  local selection = to_picks(records)

  ---@type _records
  local selected = {}

  for _, builder in ipairs(self.output_builders) do
    local picked = builder:preprocess(selection)

    for id, cfg in pairs(picked) do
      if selected[id] and selected[id].output_builders then
        table.insert(selected[id].output_builders, builder)
      else
        local rec = records[id] or {}
        selected[id] = { config = cfg, output_builders = { builder }, loader = rec.loader }
      end
    end
  end

  return selected
end

-- Load tasks from all loaders
-- and adds them to internal lookup
function Handler:reload_configs()
  ---@type _records
  local records = {}

  -- Load all tasks from different loaders
  for _, loader in pairs(self.loaders) do
    local configs = loader:load()
    if configs then
      for _, cfg in ipairs(configs) do
        records[math.random()] = { config = cfg, loader = loader }
      end
    end
  end

  -- filter records using outputs
  records = self:preprocess(records)

  local hide_all = function()
    for _, t in pairs(self.lookup:get_all { visible = true }) do
      t:hide()
    end
  end

  -- create tasks from records
  ---@type Task[]
  local tasks = {}
  for _, rec in pairs(records) do
    local task
    task = Task:new(rec.config, rec.output_builders, {
      dependency_mode = self.depencency_mode,
      expand_config = function(c)
        if rec.loader and type(rec.loader.expand) == "function" then
          return rec.loader:expand(c)
        end
        return c
      end,
      on_run = function(as_dependency)
        if not as_dependency then
          self.show = true
        end
        if self.show then
          hide_all()
        end
        -- set this task as active
        self.lookup:set_selected(task:metadata().id)
        return self.show
      end,
      on_show = function()
        self.show = true
        hide_all()
        -- set this task as active
        self.lookup:set_selected(task:metadata().id)
      end,
    })
    if task then
      table.insert(tasks, task)
    end
  end

  -- add tasks to lookup
  self.lookup:replace_tasks(tasks)
end

-- entrypoint to task selection
function Handler:continue()
  -- evaluate any task overrides
  if self:evaluate_live_task_action_overrides() then
    return
  end

  if self.automatic_reload or not self.first_load_done then
    self:reload_configs()
    self.first_load_done = true
  end

  -- show dashboard
  self.dashboard:open(self.lookup:get_all(), self.loaders, function()
    self:reload_configs()
  end)
end

-- checks all live tasks for actions and triggers overrides if there are any
---@return boolean triggered was any action triggered
function Handler:evaluate_live_task_action_overrides()
  ---@type task_action[]
  local actions = {}

  -- get actions from all live tasks
  for _, task in pairs(self.lookup:get_all { live = true }) do
    vim.list_extend(actions, task:actions())
  end

  -- run all overrides
  local overrides_detected = false
  for _, action in pairs(actions) do
    if action.override then
      if type(action.action) == "function" then
        action.action()
      end
      overrides_detected = true
    end
  end

  if overrides_detected then
    return true
  end

  return false
end

-- Jump to next task's output
function Handler:next_task()
  local task = self.lookup:select_next(true)

  -- hide all visible tasks
  for _, t in pairs(self.lookup:get_all { live = true, visible = true }) do
    t:hide()
  end

  -- and show only this one
  task:show()
end

-- Jump to previous task's output
function Handler:previous_task()
  local task = self.lookup:select_prev(true)

  -- hide all visible tasks
  for _, t in pairs(self.lookup:get_all { live = true, visible = true }) do
    t:hide()
  end

  -- and show only this one
  task:show()
end

-- Toggle the current output or jump to next one if this one died
function Handler:toggle_output()
  local task = self.lookup:get_selected(true)

  if task:is_visible() then
    self.show = false
    task:hide()
  else
    self.show = true
    task:show()
  end
end

-- Kill (and optionally run again) the selected task
---@param opts? { restart: boolean  }
function Handler:kill_task(opts)
  opts = opts or {}

  local task = self.lookup:get_selected()

  if opts.restart then
    task:run { restart = true }
  else
    task:kill()
  end
end

---@return string[]
function Handler:status()
  local ret = {}

  local current = self.lookup:get_selected(true)

  for _, task in ipairs(self.lookup:get_all { live = true }) do
    if task:metadata().id == current:metadata().id then
      table.insert(ret, "[" .. task:metadata().name .. "]")
    else
      table.insert(ret, task:metadata().name)
    end
  end
  return ret
end

return Handler
