local Handler = require'projector.handler'

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
-- args:
--   config: config-like table (projector.cofig)
function M.setup(config)
  handler:load_sources()
end

function M.refresh_jobs()
  handler:load_sources()
end

function M.continue()
  handler:continue()
end

function M.toggle_output()
  handler:toggle_output()
end

function M.status()
  return "not implemented yet"
end

function M.handler()
  return handler
end

return M
