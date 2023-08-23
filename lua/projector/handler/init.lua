local Task = require("projector.task")
local Lookup = require("projector.handler.lookup")

-- Information that's displayed in the picker
---@alias display { loader: string, scope: string, group: string, name: string, modes: string|string[] }

---@class Handler
---@field private lookup Lookup task lookup
---@field private output_builders OutputBuilder[] provided output builders
local Handler = {}

function Handler:new()
  local o = {
    tasks = {},
    lookup = Lookup:new(),
    output_builders = { require("projector.outputs").BuiltinOutputBuilder },
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
---@param builders OutputBuilder[]
---@param records _records
---@return _records
local function preprocess(builders, records)
  local selection = to_picks(records)

  ---@type _records
  local selected = {}

  for _, builder in ipairs(builders) do
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
  ---@type config
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
      end
    end
  end

  -- filter records using outputs
  records = preprocess(self.output_builders, records)

  -- create tasks from records
  ---@type Task[]
  local tasks = {}
  for _, rec in pairs(records) do
    local task = Task:new(
      rec.config,
      rec.output_builders,
      { dependency_mode = "task", loader = rec.loader } --[[TODO: get "task" from config]]
    )
    if task then
      table.insert(tasks, task)
    end
  end

  -- add tasks to lookup
  self.lookup:replace_tasks(tasks)
end

-- Select a task and it's mode and run it
---@param override_hidden? boolean
function Handler:select_and_run(override_hidden)
  ---@type config
  local config = require("projector").config

  -- reload configs if configured
  if config.automatic_reload then
    self:load_sources()
  end

  vim.ui.select(
    self.lookup:get_all(),
    {
      prompt = "select a task:",
      ---@param item Task
      format_item = function(item)
        return item:metadata().name
      end,
    },
    ---@param choice Task
    function(choice)
      if choice then
        local modes = choice:get_modes()
        if #modes == 1 then
          -- hide all other visible tasks and show this one
          for _, t in pairs(self.lookup:get_all { live = true, visible = true }) do
            t:hide_output()
          end
          self.lookup:set_selected(choice:metadata().id)
          choice:run(modes[1])
        elseif #modes > 1 then
          vim.ui.select(
            modes,
            {
              prompt = "select mode:",
            },
            ---@param m task_mode
            function(m)
              if m then
                -- hide all other visible tasks and show this one
                for _, t in pairs(self.lookup:get_all { live = true, visible = true }) do
                  t:hide_output()
                end
                self.lookup:set_selected(choice:metadata().id)
                choice:run(m)
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
  local live_tasks = self.lookup:get_all { live = true }

  if vim.tbl_isempty(live_tasks) then
    self:select_and_run()
    return
  end

  -- get actions from all live tasks
  local actions = {}
  for _, t in pairs(live_tasks) do
    local t_actions = t:actions()
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
      if a.action then
        a.action()
      end
      has_overrides = true
    end
  end
  if has_overrides then
    return
  end

  -- add a task selector action
  table.insert(actions, 1, {
    label = "Run a task",
    action = function()
      self:select_and_run()
    end,
  })

  ---@param list task_action[]
  local function select_action(list)
    vim.ui.select(
      list,
      {
        prompt = "select an action:",
        format_item = function(item)
          return item.label
        end,
      },
      ---@param choice task_action
      function(choice)
        if choice then
          if choice.action then
            choice.action()
          elseif choice.nested then
            -- Handle nested actions recursively
            select_action(choice.nested)
          end
        end
      end
    )
  end

  -- Open action selector
  select_action(actions)
end

-- Jump to next task's output
function Handler:next_task()
  local task = self.lookup:select_next(true)

  -- hide all visible tasks
  for _, t in pairs(self.lookup:get_all { live = true, visible = true }) do
    t:hide_output()
  end

  -- and show only this one
  task:show_output()
end

-- Jump to previous task's output
function Handler:previous_task()
  local task = self.lookup:select_prev(true)

  -- hide all visible tasks
  for _, t in pairs(self.lookup:get_all { live = true, visible = true }) do
    t:hide_output()
  end

  -- and show only this one
  task:show_output()
end

-- Toggle the current output or jump to next one if this one died
function Handler:toggle_output()
  local task = self.lookup:get_selected(true)

  if task:is_visible() then
    task:hide_output()
  else
    task:show_output()
  end
end

-- Kill or restart the currently selected task
---@param opts? { restart: boolean }
function Handler:kill_current_task(opts)
  opts = opts or {}

  local task = self.lookup:get_selected()

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

  local current = self.lookup:get_selected()

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
