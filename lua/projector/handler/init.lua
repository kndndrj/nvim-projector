local Task = require("projector.task")
local Lookup = require("projector.handler.lookup")

-- Information that's displayed in the picker
---@alias display { loader: string, scope: string, group: string, name: string, modes: string|string[] }

---@class Handler
---@field private dashboard Dashboard
---@field private lookup Lookup task lookup
---@field private loaders Loader[]
---@field private output_builders OutputBuilder[] provided output builders
local Handler = {}

---@param dashboard Dashboard
---@return Handler
function Handler:new(dashboard)
  if not dashboard then
    error("no Dashboard provided to Handler")
  end

  local o = {
    dashboard = dashboard,
    tasks = {},
    lookup = Lookup:new(),
    output_builders = { require("projector.outputs").BuiltinOutputBuilder },
    loaders = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

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
        selected[id] = { config = cfg, output_builders = { builder }, loader = records[id].loader }
      end
    end
  end

  return selected
end

-- Load tasks from all loaders
function Handler:load_sources()
  ---@type Config
  local config = require("projector").config

  ---@alias _records table<string, { config: task_configuration, loader: Loader, output_builders: OutputBuilder[] }>

  ---@type _records
  local records = {}

  -- Load all tasks from different loaders
  for _, loader_config in pairs(config.loaders) do
    local ok, l = pcall(require, "projector.loaders." .. loader_config.module)
    if ok then
      ---@type Loader
      local loader = l:new { user_opts = loader_config.options }

      local configs = loader:load()
      if configs then
        for _, cfg in ipairs(configs) do
          records[math.random()] = { config = cfg, loader = loader }
        end

        table.insert(self.loaders, loader)
      end
    end
  end

  -- filter records using outputs
  records = self:preprocess(records)

  -- create tasks from records
  ---@type Task[]
  local tasks = {}
  for _, rec in pairs(records) do
    local task
    task = Task:new(rec.config, rec.output_builders, {
      dependency_mode = "task", -- TODO: get "task" from config
      expand_config = function(c)
        if rec.loader and type(rec.loader.expand_variables) == "function" then
          return rec.loader:expand_variables(c)
        else
          return c
        end
      end,
      activator = function()
        -- close all other task outputs
        for _, t in pairs(self.lookup:get_all { visible = true }) do
          t:hide()
        end
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

---@param filter? { live: boolean, visible: boolean }
---@return Task[] tasks
function Handler:get_tasks(filter)
  return self.lookup:get_all(filter)
end

---@return Task tasks
function Handler:selected_task()
  return self.lookup:get_selected()
end

-- entrypoint to task selection
function Handler:continue()
  -- evaluate any task overrides
  if self:evaluate_live_task_action_overrides() then
    return
  end

  -- show dashboard
  self.dashboard:open(self.lookup:get_all(), self.loaders)
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
    task:hide()
  else
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
