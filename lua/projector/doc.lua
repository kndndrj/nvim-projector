---@mod projector.ref.task Task Type
---@brief [[
---Overview of task configuration object used in projector.
---@brief ]]

---ID of the task.
---@alias task_id string

---Table of actions.
---Label is displayed in the menu,
---action is an action which is triggered on call,
---override triggers this action automatically instead of displaying the menu and
---nested is a list of optional nested actions.
---@alias task_action { label: string, action: fun(), override?: boolean, nested?: task_action[] }

-- What modes can the task run in.
---@alias task_mode string

---Metadata of a task.
---@alias task_meta { id: string, name: string }

---Task configuration is a table of any key value pairs.
---Fields listed here have a special meaning in projector-core,
---but the main functionality of the task is defined by the outputs
---(see |OutputBuilder| and |Output|).
---@class TaskConfiguration
---@field id string id of the task (doesn't need to be defined, but it's useful for specifying dependencies)
---@field name string display name of the task
---@field dependencies task_id[] task ids to run before running this one
---@field after task_id task id to run after finishing this task
---@field evaluate task_mode evaluate the specified output immediately if any mode matches the specified one
---@field children TaskConfiguration[] group multiple configurations together

local M = {}
return M
