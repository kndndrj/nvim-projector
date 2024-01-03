---@mod projector.ref.outputs Outputs
---@brief [[
---An output represents a single running instance of a task.
---
---To create a new output one has to implement the Output iterface that
---can run an arbitrary task configuration object and then implement
---the OutputBuilder interface, which builds those outputs on demand.
---
---To use the outputs, pass the OutputBuilder with config to setup function.
---@brief ]]

---Status of the output.
---@alias output_status
---| '"inactive"'
---| '"hidden"'
---| '"visible"'

---Output interface.
---@class Output
---@field status fun(self: Output):output_status function to return the output's status
---@field init fun(self: Output, configuration: TaskConfiguration, callback: fun(success: boolean)) function to initialize the output (runs, but doesn't show anythin on screen)
---@field kill fun(self: Output) function to kill the output execution
---@field show fun(self: Output) function to show the ouput on screen
---@field hide fun(self: Output) function to hide the output off the screen
---@field actions? fun(self: Output):task_action[] function to list any available actions of the output
---@field preview? fun(self: Output, max_lines: integer):string[]? function to return a preview of output (to show in the dashboard) - max_lines indicates how many lines to show

---Output Builder interface.
---@class OutputBuilder
---@field mode_name fun(self: OutputBuilder):task_mode function to return the name of the output mode (used as a display mode name)
---@field build fun(self: OutputBuilder):Output function to build the actual output
---@field validate fun(self: OutputBuilder, configuration: TaskConfiguration):boolean true if output can run the configuration, false otherwise
---@field preprocess? fun(self: OutputBuilder, configurations: TaskConfiguration[]):TaskConfiguration[]? manufacture new configurations based on the ones passed in (don't return duplicates)

local M = {}
return M
