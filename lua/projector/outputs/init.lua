---@diagnostic disable:undefined-field

local TaskOutput = require("projector.outputs.task")
local DadbodOutput = require("projector.outputs.dadbod")
local DapOutput = require("projector.outputs.dap")

local M = {}

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

---@param configuration TaskConfiguration
---@return boolean
function M.TaskOutputBuilder:validate(configuration)
  if configuration and configuration.command then
    return true
  end
  return false
end

--
-- Builder for the DadbodOutput
--
---@class DadbodOutputBuilder: OutputBuilder
---@field private name string
M.DadbodOutputBuilder = {}

-- new builder
---@return DadbodOutputBuilder
function M.DadbodOutputBuilder:new()
  local o = {
    name = "Dadbod",
  }
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

---@param configuration TaskConfiguration
---@return boolean
function M.DadbodOutputBuilder:validate(configuration)
  if configuration and configuration.name == self.name and configuration.evaluate == self:mode_name() then
    return true
  end
  return false
end

---@param configurations TaskConfiguration[]
---@return TaskConfiguration[]
function M.DadbodOutputBuilder:preprocess(configurations)
  -- get databases and queries from all configs
  local databases = {} -- only supports list
  local queries = {} -- table of dadbod-ui structured table helpers

  ---@param cfgs TaskConfiguration[]
  local function parse(cfgs)
    for _, c in ipairs(cfgs) do
      if vim.tbl_islist(c.databases) then
        vim.list_extend(databases, c.databases)
      end

      if type(c.queries) == "table" then
        queries = vim.tbl_deep_extend("keep", queries, c.queries)
      end

      if vim.tbl_islist(c.children) then
        parse(c.children)
      end
    end
  end

  parse(configurations)

  -- register in global dadbod variables
  vim.g["dbs"] = databases
  vim.g["db_ui_table_helpers"] = queries

  -- return a single manufactured task capable of running in DadbodOutput
  return {
    {
      name = self.name,
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

---@param configuration TaskConfiguration
---@return boolean
function M.DapOutputBuilder:validate(configuration)
  if configuration and configuration.type and configuration.request then
    return true
  end
  return false
end

return M
