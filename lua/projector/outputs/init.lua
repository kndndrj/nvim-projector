local TaskOutput = require("projector.outputs.task")
local DadbodOutput = require("projector.outputs.dadbod")
local DapOutput = require("projector.outputs.dap")

local M = {}

---@alias output_status "inactive"|"hidden"|"visible"|""

---@class Output
---@field status fun(self: Output):output_status function to return the output's status
---@field init fun(self: Output, configuration: task_configuration, callback: fun(success: boolean)) function to initialize the output (runs, but doesn't show anythin on screen)
---@field kill fun(self: Output) function to kill the output execution
---@field show fun(self: Output) function to show the ouput on screen
---@field hide fun(self: Output) function to hide the output off the screen
---@field actions? fun(self: Output):task_action[] function to list any available actions of the output

---@class OutputBuilder
---@field mode_name fun(self: OutputBuilder):task_mode function to return the name of the output mode (used as a display mode name)
---@field build fun(self: OutputBuilder):Output function to build the actual output
---@field preprocess fun(self: OutputBuilder, selection: table<string, task_configuration>):table<string, task_configuration> pick configs that suit the output (return only picked ones)

--
-- Builder for the TaskOutput
--
---@class TaskOutputBuilder: OutputBuilder
M.TaskOutputBuilder = {}

-- new builder
---@return TaskOutputBuilder
function M.TaskOutputBuilder:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- build a new output
---@return TaskOutput
function M.TaskOutputBuilder:build()
  return TaskOutput:new()
end

---@return task_mode mode
function M.TaskOutputBuilder:mode_name()
  return "task"
end

---@param selection table<string, task_configuration>
---@return table<string, task_configuration> # picked configs
function M.TaskOutputBuilder:preprocess(selection)
  ---@type table<string, task_configuration>
  local picks = {}

  for id, config in pairs(selection) do
    if config.command then
      picks[id] = config
    end
  end

  return picks
end

--
-- Builder for the DadbodOutput
--
---@class DadbodOutputBuilder: OutputBuilder
M.DadbodOutputBuilder = {}

-- new builder
---@return DadbodOutputBuilder
function M.DadbodOutputBuilder:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- build a new output
---@return DadbodOutput
function M.DadbodOutputBuilder:build()
  return DadbodOutput:new()
end

---@return task_mode mode
function M.DadbodOutputBuilder:mode_name()
  return "dadbod"
end

---@param selection table<string, task_configuration>
---@return table<string, task_configuration> # picked configs
function M.DadbodOutputBuilder:preprocess(selection)
  -- get databases and queries from all configs
  local databases = {} -- only supports list
  local queries = {} -- table of dadbod-ui structured table helpers
  for _, config in pairs(selection) do
    if vim.tbl_islist(config.databases) then
      vim.list_extend(databases, config.databases)
    end

    if type(config.queries) == "table" then
      queries = vim.tbl_deep_extend("keep", queries, config.queries)
    end
  end

  -- register in global dadbod variables
  vim.g["dbs"] = databases
  vim.g["db_ui_table_helpers"] = queries

  -- return a single manufactured task capable of running in DadbodOutput
  ---@type table<string, task_configuration>
  return {
    ["__dadbod_output_builder_task_id__"] = {
      scope = "global",
      group = "db",
      name = "Dadbod",
      evaluate = self:mode_name(),
    },
  }
end

--
-- Builder for the DapOutput
--
---@class DapOutputBuilder: OutputBuilder
M.DapOutputBuilder = {}

-- new builder
---@return DapOutputBuilder
function M.DapOutputBuilder:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- build a new output
---@return DapOutput
function M.DapOutputBuilder:build()
  return DapOutput:new()
end

---@return task_mode mode
function M.DapOutputBuilder:mode_name()
  return "debug"
end

---@param selection table<string, task_configuration>
---@return table<string, task_configuration> # picked configs
function M.DapOutputBuilder:preprocess(selection)
  ---@type table<string, task_configuration>
  local picks = {}

  for id, config in pairs(selection) do
    if config.type and config.request then
      picks[id] = config
    end
  end

  return picks
end

return M
