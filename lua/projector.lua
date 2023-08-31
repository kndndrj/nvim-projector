local Handler = require("projector.handler")
local Dashboard = require("projector.dashboard")
local utils = require("projector.utils")
local default_config = require("projector.config").default

local M = {}
local m = {}

---@type Handler
m.handler = nil

-- Function for checking if setup function has been called
local warning_displayed = false
local function check_setup()
  if not m.handler then
    if not warning_displayed then
      utils.log("warn", '"projector.setup()" has not been called yet!')
      warning_displayed = true
    end
    return false
  end
  return true
end

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
    dashboard_popup_width = { opts.dashboard.popup.width, "number" },
    dashboard_popup_height = { opts.dashboard.popup.height, "number" },

    loaders = { opts.loaders, "table" },
    outputs = { opts.outputs, "table" },
  }

  local dashboard = Dashboard:new(opts.dashboard)
  m.handler = Handler:new(dashboard, opts.loaders, opts.outputs, opts.core)
end

function M.reload()
  if not check_setup() then
    return
  end
  m.handler:reload_configs()
end

function M.continue()
  if not check_setup() then
    return
  end
  m.handler:continue()
end

function M.next()
  if not check_setup() then
    return
  end
  m.handler:next_task()
end

function M.previous()
  if not check_setup() then
    return
  end
  m.handler:previous_task()
end

function M.toggle()
  if not check_setup() then
    return
  end
  m.handler:toggle_output()
end

function M.restart()
  if not check_setup() then
    return
  end
  m.handler:kill_task { restart = true }
end

function M.kill()
  if not check_setup() then
    return
  end
  m.handler:kill_task { restart = false }
end

---@return string
function M.status()
  if not check_setup() then
    return ""
  end
  local task = m.handler:current()
  if task:is_visible() then
    return task:metadata().name
  end
  return ""
end

-- experimental and subject to change!
M.api = m

return M
