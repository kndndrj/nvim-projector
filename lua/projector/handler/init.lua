local utils = require("projector.utils")
local Task = require("projector.task")
local Lookup = require("projector.handler.lookup")

---@class Handler
---@field private lookup Lookup task lookup
---@field private loaders Loader[]
---@field private output_builders OutputBuilder[]
---@field private show boolean can outputs be shown or not
---@field private depencency_mode? task_mode mode to be used for tasks running as dependenies
---@field private automatic_reload boolean reload the loaders on each call
---@field private first_load_done boolean were configs loaded for the first time?
local Handler = {}

---@alias handler_config { depencency_mode: task_mode, automatic_reload: boolean }

---@param loaders Loader[]
---@param output_builders OutputBuilder[]
---@param opts? handler_config
---@return Handler
function Handler:new(loaders, output_builders, opts)
  opts = opts or {}

  local o = {
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

-- get preprocessed records from output builders
---@private
---@param configs task_configuration[]
function Handler:preprocess(configs)
  for _, builder in ipairs(self.output_builders) do
    if type(builder.preprocess) == "function" then
      configs = utils.merge_lists(configs, builder:preprocess(configs))
    end
  end
  return configs
end

-- create tasks from records
---@private
---@param cfgs task_configuration[]
---@return Task[]
function Handler:create_tasks(cfgs)
  if not cfgs then
    return {}
  end

  local hide_all = function()
    for _, t in pairs(self.lookup:get_all { visible = true }) do
      t:hide()
    end
  end

  ---@type Task[]
  local tasks = {}

  for _, cfg in ipairs(cfgs) do
    -- get loader for variable expansion
    local loader = cfg._loader
    cfg._loader = nil

    local children = self:create_tasks(cfg.children)

    local task
    task = Task:new(cfg, children, self.output_builders, {
      dependency_mode = self.depencency_mode,
      expand_config = function(c)
        if loader and type(loader.expand) == "function" then
          return loader:expand(c)
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

  return tasks
end

-- Load tasks from all loaders
-- and adds them to internal lookup
function Handler:reload_configs()
  ---@param cfgs? task_configuration[]
  ---@param loader Loader
  local function set_loader(cfgs, loader)
    if not cfgs then
      return
    end
    for _, cfg in ipairs(cfgs) do
      cfg._loader = loader
      set_loader(cfg.children, loader)
    end
  end

  ---@type task_configuration[]
  local configs = {}

  -- Load all tasks from different loaders
  for _, loader in pairs(self.loaders) do
    local loaded_configs = loader:load()
    set_loader(loaded_configs, loader)
    configs = utils.merge_lists(configs, loaded_configs)
  end

  -- filter records using outputs
  configs = self:preprocess(configs)

  -- add tasks to lookup
  self.lookup:replace_tasks(self:create_tasks(configs))
end

-- reload based on configs or first load
function Handler:soft_reload()
  if self.automatic_reload or not self.first_load_done then
    self:reload_configs()
    self.first_load_done = true
  end
end

---@param filter? { live: boolean, visible: boolean, suppress_children: boolean }
---@return Task[] tasks
function Handler:get_tasks(filter)
  return self.lookup:get_all(filter)
end

---@return Loader[] loaders
function Handler:get_loaders()
  return self.loaders
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

---@return Task
function Handler:current()
  return self.lookup:get_selected()
end

return Handler
