local utils = require("projector.utils")
local BuiltinOutput = require("projector.outputs.builtin")

local M = {}

---@alias output_status "inactive"|"hidden"|"visible"|""

---@class Output
---@field status fun(self: Output):output_status function to return the output's status
---@field init fun(self: Output, configuration: task_configuration, callback: fun(success: boolean)) function to initialize the output
---@field kill fun(self: Output) function to kill the output execution
---@field show fun(self: Output) function to show the ouput on screen
---@field hide fun(self: Output) function to hide the output off the screen
---@field actions? fun(self: Output):task_action[ ] function to list any available actions of the output

---@alias configuraiton_picks table<string, task_configuration> map of task_id: task_configuration for picking tasks that suit the outputs

---@class OutputBuilder
---@field mode_name fun(self: OutputBuilder):task_mode function to return the name of the output mode (used as a display mode name)
---@field build fun(self: OutputBuilder):Output function to build the actual output
---@field preprocess fun(self: OutputBuilder, selection: configuraiton_picks):configuraiton_picks pick configs that suit the output (return only picked ones)

--
-- Builder for the BuiltinOutput
--
---@class BuiltinOutputBuilder: OutputBuilder
M.BuiltinOutputBuilder = {}

-- new builder
---@return BuiltinOutputBuilder
function M.BuiltinOutputBuilder:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- build a new output
---@return BuiltinOutput
function M.BuiltinOutputBuilder:build()
  return BuiltinOutput:new()
end

---@return task_mode mode
function M.BuiltinOutputBuilder:mode_name()
  return "task"
end

---@param selection configuraiton_picks
---@return configuraiton_picks # picked configs
function M.BuiltinOutputBuilder:preprocess(selection)
  ---@type configuraiton_picks
  local picks = {}

  for id, config in pairs(selection) do
    if utils.has_fields(config, { "command" }) then
      picks[id] = config
    end
  end

  return picks
end

return M
