local Handler = require("projector.handler")
local Dashboard = require("projector.dashboard")
local utils = require("projector.utils")
local default_config = require("projector.config").default

---@toc projector.ref.contents

---@mod projector.ref Projector Reference
---@brief [[
---Code runner/project manager for neovim.
---@brief ]]

local projector = {}
local m = {
  ---@type Handler
  handler = nil,
  ---@type Dashboard
  dashboard = nil,
}

-- Function for checking if setup function has been called
local warning_displayed = false
local function check_setup()
  if not m.handler or not m.dashboard then
    if not warning_displayed then
      utils.log("warn", '"projector.setup()" has not been called yet!')
      warning_displayed = true
    end
    return false
  end
  return true
end

---Setup function with optional config parameter.
---@param cfg? Config
function projector.setup(cfg)
  cfg = cfg or {}
  ---@type Config
  local opts = vim.tbl_deep_extend("force", default_config, cfg)

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

  m.handler = Handler:new(opts.loaders, opts.outputs, opts.core)
  m.dashboard = Dashboard:new(m.handler, opts.dashboard)
end

---Reload configurations.
function projector.reload()
  if not check_setup() then
    return
  end
  m.handler:reload_configs()
end

---Entrypoint function which triggers task selection, action picker or overrides,
---depending on the context.
function projector.continue()
  if not check_setup() then
    return
  end

  -- evaluate any task overrides
  if m.handler:evaluate_live_task_action_overrides() then
    return
  end

  -- reload if necessary
  m.handler:soft_reload()

  -- open dashboard
  m.dashboard:open()
end

---Cycle next output UI.
function projector.next()
  if not check_setup() then
    return
  end
  m.handler:next_task()
end

---Cycle previous output UI.
function projector.previous()
  if not check_setup() then
    return
  end
  m.handler:previous_task()
end

---Toggle UI.
function projector.toggle()
  if not check_setup() then
    return
  end
  m.handler:toggle_output()
end

---Restart current task.
function projector.restart()
  if not check_setup() then
    return
  end
  m.handler:kill_task { restart = true }
end

---Kill current task.
function projector.kill()
  if not check_setup() then
    return
  end
  m.handler:kill_task { restart = false }
end

---Status formatted as a string.
---For statusline use.
---@return string
function projector.status()
  if not check_setup() then
    return ""
  end
  local task = m.handler:current()
  if task:is_visible() then
    return task:metadata().name
  end
  return ""
end

return projector
