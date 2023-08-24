local Handler = require("projector.handler")
local Dashboard = require("projector.dashboard")
local utils = require("projector.utils")
local default_config = require("projector.config")

---@type Handler
local handler = nil
---@type Dashboard
local dashboard = nil

-- Function for checking if setup function has been called
local warning_displayed = false
local function check_setup()
  if not handler or not dashboard then
    if not warning_displayed then
      utils.log("warn", '"projector.setup()" has not been called yet!')
      warning_displayed = true
    end
    return false
  end
  return true
end

local M = {}

---@type Config
M.config = {}

-- setup function
---@param config Config
function M.setup(config)
  ---@type Config
  local opts = vim.tbl_deep_extend("force", default_config, config)

  -- validate config
  vim.validate {
    dashboard_mappings = { opts.dashboard.mappings, "table" },
    dashboard_candies = { opts.dashboard.candies, "table" },
    dashboard_disable_candies = { opts.dashboard.disable_candies, "boolean" },
  }

  -- TODO: remove
  M.config = opts

  ---@type Handler
  handler = Handler:new()
  handler:load_sources()

  dashboard = Dashboard:new(handler, opts.dashboard)
end

function M.reload()
  if not check_setup() then
    return
  end
  handler:load_sources()
end

function M.continue()
  if not check_setup() then
    return
  end
  dashboard:open()
end

function M.next()
  if not check_setup() then
    return
  end
  handler:next_task()
end

function M.previous()
  if not check_setup() then
    return
  end
  handler:previous_task()
end

function M.toggle()
  if not check_setup() then
    return
  end
  handler:toggle_output()
end

function M.restart()
  if not check_setup() then
    return
  end
  handler:kill_task { restart = true }
end

function M.kill()
  if not check_setup() then
    return
  end
  handler:kill_task { restart = false }
end

---@return string
function M.status()
  if not check_setup() then
    return ""
  end
  return table.concat(handler:status(), " ")
end

function M.handler()
  if not check_setup() then
    return
  end
  return handler
end

return M
