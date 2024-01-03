-- this file provides a mocked Task with the same fields as the real one.
-- It's main use case is to provide a working task in case no tasks are configured
local utils = require("projector.utils")

---@class MockedTask
local MockedTask = {}

---@return Task
function MockedTask:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- updates task's config
---@param configuration TaskConfiguration
function MockedTask:update_config(configuration)
  local _ = configuration
end

-- Run a task and hadle it's dependencies
---@param opts? { mode: task_mode, callback: fun(success: boolean), restart: boolean }
function MockedTask:run(opts)
  local _ = opts
  utils.log("warn", "Trying to run a mocked task")
end

---@return task_meta
function MockedTask:metadata()
  return {
    id = "mocked.task.id",
    name = "mocked task",
  }
end

---@return TaskConfiguration
function MockedTask:config()
  return {}
end

-- sets dependencies and after tasks
---@param deps Task[]
---@param after? Task
function MockedTask:set_accompanying_tasks(deps, after)
  local _, _ = deps, after
end

---@return task_mode[] all
---@return task_mode? latest
function MockedTask:modes()
  return { "mock" }, nil
end

---@return boolean
function MockedTask:is_live()
  return false
end

---@return boolean
function MockedTask:is_visible()
  return false
end

function MockedTask:show() end

function MockedTask:hide() end

function MockedTask:kill() end

---@return task_action[]
function MockedTask:actions()
  return {}
end

return MockedTask
