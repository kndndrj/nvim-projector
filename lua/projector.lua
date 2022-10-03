local Handler = require'projector.handler'

---@type Handler
local handler = Handler:new()

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

-- setup function
---@param config table config-like table (projector.cofig)
function M.setup(config)
  handler:load_sources()
end

function M.refresh_jobs()
  handler:load_sources()
end

function M.continue()
  handler:continue()
end

function M.next()
  handler:next_output()
end

function M.previous()
  handler:previous_output()
end

function M.toggle()
  handler:toggle_output()
end

---@deprecated
function M.toggle_output()
  handler:toggle_output()
  print("projector.toggle_output() is deprecated. Use projector.toggle() instead")
end

---@return string
function M.status()
  return table.concat(handler:dashboard(), " ")
end

function M.handler()
  return handler
end

return M
