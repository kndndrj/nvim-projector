local Output = {}

function Output:new(opts)
  opts = opts or {}

  local o = {
    meta = { -- this table holds output's metadata - fields provided here are set in all outputs
      name = opts.name or "[empty output name]",
    },
    status = "inactive", -- status of the output (hidden or active)
  }
  setmetatable(o, self)
  self.__index = self
  return o
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
