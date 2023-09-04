local utils = require("projector.utils")

-- Id of the task
---@alias task_id string

-- Table of configuration parameters
---@class task_configuration
---@field id string
---@field name string
---@field dependencies task_id[]
---@field after task_id
---@field evaluate task_mode -- evaluate the specified output immediately if any mode matches the specified one
---@field children task_configuration[] -- group multiple configurations together

-- Table of actions
---@alias task_action { label: string, action: fun( ), override?: boolean, nested?: task_action[] }

-- What modes can the task run in
---@alias task_mode string

-- Metadata of a task
---@alias task_meta { id: string, name: string }

---@class Task
---@field private children Task[]
---@field private meta task_meta
---@field private configuration task_configuration Configuration of the task (command, args, env, cwd...)
---@field private modes_list task_mode[] What can the task do (debug, task)
---@field private last_mode task_mode Mode that was selected previously
---@field private dependency_mode task_mode mode to run the dependencies in
---@field private dependencies { task: Task, status: "done"|"error"|"" }[] List of dependent tasks
---@field private after? Task a task to run after this one is finished
---@field private output_builders table<task_mode, OutputBuilder> task builders per mode
---@field private output Output currently active output
---@field private expand_config_variables fun(configuration: task_configuration):task_configuration Function that gets assigned to a task by a loader
---@field private on_run fun(as_dependency: boolean):boolean hook to trigger before running the task. as_dependency is true if the task is ran as a dependency. returns true if the task can show it's output
---@field private on_show fun() hook to trigger before showing task's output on screen
local Task = {}

---@param configuration task_configuration
---@param children? Task[] list of child tasks
---@param output_builders OutputBuilder[] map of available output builders
---@param opts? { dependency_mode: task_mode, on_run: fun(as_dependency: boolean):(boolean), on_show: fun(), expand_config: fun(config: task_configuration):task_configuration }
---@return Task?
function Task:new(configuration, children, output_builders, opts)
  if not configuration then
    return
  end
  if not output_builders or #output_builders < 1 then
    return
  end
  opts = opts or {}

  -- make output builder lookup
  local builders = {}
  for _, builder in ipairs(output_builders) do
    builders[builder:mode_name()] = builder
  end

  local o = {
    children = children or {},
    meta = {},
    configuration = configuration,
    modes_list = {},
    last_mode = nil,
    dependency_mode = opts.dependency_mode,
    dependencies = {},
    after = nil,
    output_builders = builders,
    output = nil,
    expand_config_variables = opts.expand_config or function(c)
      return c
    end,
    on_run = opts.on_run or function(_)
      return true
    end,
    on_show = opts.on_show or function() end,
  }
  setmetatable(o, self)
  self.__index = self

  -- configure metadata and other config related stuff
  if not o:update(configuration, children) then
    return
  end

  return o
end

-- updates task's config and parameters
---@param configuration task_configuration
---@param children? Task[]
---@return boolean ok
function Task:update(configuration, children)
  if not configuration then
    return false
  end
  -- update children
  self.children = children or {}

  -- check available modes
  self.modes_list = {}
  for _, builder in pairs(self.output_builders) do
    if builder:validate(self.configuration) then
      table.insert(self.modes_list, builder:mode_name())
    end
  end
  if #self.modes_list < 1 and #self.children < 1 then
    return false
  end

  -- update metadata
  self.meta = {
    id = configuration.id or configuration.name or tostring(math.random()),
    name = configuration.name or "<unnamed task>",
  }

  -- evaluate the possibly specified output
  local eval_mode = configuration.evaluate
  if utils.contains(self.modes_list, eval_mode) then
    if eval_mode ~= self.last_mode or not self.output then
      self.output = self.output_builders[eval_mode]:build()
      self.output:init(self.expand_config_variables(self.configuration), function(_) end)
    end
    self.last_mode = eval_mode
  end

  return true
end

-- Run a task and hadle it's dependencies
---@param opts? { mode: task_mode, callback: fun(success: boolean), restart: boolean, as_dependency: boolean }
function Task:run(opts)
  opts = opts or {}

  -- hook
  local can_show = self.on_run(opts.as_dependency or false)

  -- options
  local mode = opts.mode or self.last_mode or self.modes_list[1]
  self.last_mode = mode
  local callback = opts.callback or function(_) end
  local restart = opts.restart or false

  -- If any output is already live, return
  if self:is_live() and not restart then
    if can_show then
      self:show()
    end
    callback(true)
    return
  end

  -- check if task has the capability to run the selected mode
  if not utils.contains(self.modes_list, mode) then
    callback(false)
    return
  end

  local revert_dep_statuses = function()
    for _, dep in pairs(self.dependencies) do
      dep.status = ""
    end
  end

  -- run the first not completed dependency
  for _, dep in ipairs(self.dependencies) do
    if dep.status ~= "done" and dep.status ~= "error" then
      local cb = function(ok)
        if ok then
          dep.status = "done"
          self:run { mode = opts.mode, callback = opts.callback, restart = opts.restart, as_dependency = true }
          return
        end

        dep.status = "error"
        utils.log("error", 'Problem with dependency: "' .. dep.task:metadata().id .. '".', "Task " .. self.meta.name)
        -- trigger callback, stop further dependency execution and revert task's dependency statuses
        callback(false)
        revert_dep_statuses()
      end

      -- Run the dependency (restart it if already running)
      dep.task:run { mode = self.dependency_mode, callback = cb, restart = true, as_dependency = true }
      return
    end
  end
  -- revert dependency statuses if all dependencies are successfully finished
  revert_dep_statuses()

  -- handle post task with on_success output callback
  local cb = function(ok)
    if ok then
      if self.after then
        self.after:run { mode = self.dependency_mode, restart = true, as_dependency = true }
      end
    end
    callback(ok)
  end

  -- build the output and run the task
  if mode ~= self.last_mode or not self.output then
    self.output = self.output_builders[mode]:build()
  end
  self.output:init(self.expand_config_variables(self.configuration), cb)

  -- show the output
  if can_show then
    self:show()
  end
end

---@return task_meta
function Task:metadata()
  return self.meta
end

---@return task_configuration
function Task:config()
  return self.configuration
end

---@return Task[]
function Task:get_children()
  return self.children
end

-- sets dependencies and after tasks
---@param deps Task[]
---@param after? Task
function Task:set_accompanying_tasks(deps, after)
  self.dependencies = {}
  for _, dep in ipairs(deps) do
    table.insert(self.dependencies, { status = "", task = dep })
  end

  self.after = after
end

---@return task_mode[] all # all modes
---@return task_mode? latest # last mode that this task was ran in
function Task:modes()
  return self.modes_list, self.last_mode
end

---@return boolean
function Task:is_live()
  local o = self.output
  if o and o:status() ~= "inactive" and o:status() ~= "" then
    return true
  end
  return false
end

---@return boolean
function Task:is_visible()
  local o = self.output
  if o and o:status() == "visible" then
    return true
  end
  return false
end

function Task:show()
  self.on_show()

  local o = self.output
  if o and o:status() == "hidden" then
    o:show()
  end
end

function Task:hide()
  local o = self.output
  if o and o:status() == "visible" then
    o:hide()
  end
end

function Task:kill()
  local o = self.output
  if o and (o:status() == "visible" or o:status() == "hidden") then
    o:kill()
  end
end

---@return task_action[]
function Task:actions()
  local o = self.output
  if o and type(o.actions) == "function" and o:status() ~= "inactive" and o:status() ~= "" then
    return o:actions() or {}
  end
  return {}
end

---@param max_lines integer
---@return string[]
function Task:preview(max_lines)
  local o = self.output
  if o and o:status() ~= "inactive" and o:status() ~= "" then
    if type(o.preview) == "function" then
      return o:preview(max_lines) or {}
    end
    return {}
  end

  -- return formatted config by default
  return utils.format_table(self.configuration)
end

return Task
