local Output = {}

function Output:new(opts)
  opts = opts or {}

  local on_success = function () end
  if opts.on_success and type(opts.on_success) == "function" then
    on_success = opts.on_success
  end

  local on_problem = function () end
  if opts.on_problem and type(opts.on_problem) == "function" then
    on_problem = opts.on_problem
  end

  local o = {
    meta = { -- this table holds output's metadata - fields provided here are set in all outputs
      name = opts.name or "[empty output name]",
    },
    status = "inactive", -- status of the output (hidden or active)

    _callback_success = on_success, -- callback function - DO NOT OVERWRITE
    _callback_problem = on_problem, -- callback function - DO NOT OVERWRITE
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- function that should run after the task is done
-- for background tasks, this should trigger when the task is fully running
-- DO NOT OVERWRITE
---@param ok boolean
function Output:done(ok)
  if ok then
    self._callback_success()
  else
    self._callback_problem()
  end
end

-- Function that initializes the output (runs the command)
function Output:init(configuration)
  error("not_implemented")
end

-- function that opens the output (shows it on screen)
function Output:open()
  error("not_implemented")
end

-- function that closes the output (hides it from screen)
function Output:close()
  error("not_implemented")
end

-- Function that shows available actions of the running output
function Output:list_actions()
  error("not_implemented")
end

return Output
