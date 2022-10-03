local Handler = require 'projector.handler'

---@type Handler
local handler = nil

-- Function for checking if handler has been initialized
---@param hnd Handler
local function check_handler(hnd)
  if not hnd then
    vim.notify("projector.setup() has not been called yet!", vim.log.levels.WARN)
    return false
  end
  return true
end

local M = {}

-- for legacy reasons
-- TODO: remove in the future
M.configurations = {
  global = {
    debug = {},
    tasks = {},
  },
  project = {
    debug = {},
    tasks = {},
  }
}

---@type config
M.config = {}

-- setup function
---@param config config
function M.setup(config)

  -- combine default config with user config
  M.config = require 'projector.config'
  if config then
    -- loaders
    if config.loaders then
      M.config.loaders = config.loaders
    end
    -- outputs
    if config.outputs then
      if config.outputs.task then
        M.config.outputs.task = config.outputs.task
      end
      if config.outputs.debug then
        M.config.outputs.debug = config.outputs.debug
      end
      if config.outputs.database then
        M.config.outputs.database = config.outputs.database
      end
    end
  end

  handler = Handler:new()
  handler:load_sources()
end

function M.refresh_jobs()
  if not check_handler(handler) then return end
  handler:load_sources()
end

function M.continue()
  if not check_handler(handler) then return end
  handler:continue()
end

function M.next()
  if not check_handler(handler) then return end
  handler:next_output()
end

function M.previous()
  if not check_handler(handler) then return end
  handler:previous_output()
end

function M.toggle()
  if not check_handler(handler) then return end
  handler:toggle_output()
end

---@deprecated
function M.toggle_output()
  if not check_handler(handler) then return end
  handler:toggle_output()
  print("projector.toggle_output() is deprecated. Use projector.toggle() instead")
end

---@return string
function M.status()
  if not check_handler(handler) then return "" end
  return table.concat(handler:dashboard(), " ")
end

function M.handler()
  if not check_handler(handler) then return end
  return handler
end

return M
