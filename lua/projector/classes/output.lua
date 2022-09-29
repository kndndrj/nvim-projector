local Output = {}

function Output:new(configuration, opts)
  if not configuration then
    return
  end
  opts = opts or {}

  --command
  local command = configuration.command .. ' "' .. table.concat(configuration.args, '" "') .. '"'

  -- name
  local name = opts.name
  if name == "" or name == nil then
    name = "[empty output name]"
  end

  -- env
  local env = opts.env
  if type(env) ~= "table" then
    env = {}
  end
  if not opts.clear_env then
    env = vim.tbl_extend("force", vim.fn.environ(), env)
  end

  -- cwd
  local cwd = opts.cwd
  if cwd == "" or cwd == nil then
    cwd = vim.fn.getcwd()
  end

  -- Initial object
  local o = {
    meta = { -- this table holds output's metadata - fields provided here are set in all outputs
      name = name,
    },
    functions = {
      init = function(--[[self]]) return error("not_implemented") end, -- function that initializes the output (runs the command)
      open = function(--[[self]]) return error("not_implemented") end, -- function that opens the output (shows it on screen)
      close = function(--[[self]]) return error("not_implemented") end, -- function that closes the output (hides it from screen)
      ask = function(--[[self]]) return {} end, -- function that returns a list of actions for the task
    },
    command = command, -- command with arguments to run
    env = env, -- output's environment
    cwd = cwd, -- output's current working directory (where to cd to)
    status = "", -- status of the output (hidden or active)
    configuration = configuration -- task configuration
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Function setters
-- args:
--    func: function with signature function(self)
function Output:set_function_init(func)
  if type(func) ~= "function" then
    print("Invalid option type: " .. type(func))
    return
  end
  self.functions.init = func
end

function Output:set_function_open(func)
  if type(func) ~= "function" then
    print("Invalid option type: " .. type(func))
    return
  end
  self.functions.open = func
end

function Output:set_function_close(func)
  if type(func) ~= "function" then
    print("Invalid option type: " .. type(func))
    return
  end
  self.functions.close = func
end

function Output:set_function_ask(func)
  if type(func) ~= "function" then
    print("Invalid option type: " .. type(func))
    return
  end
  self.functions.ask = func
end

-- Functions for initializing, opening and closing the output
function Output:init()
  local ok, err = pcall(self.functions.init, self)
  if not ok then
    local msg = err
    if err == "not_implemented" then
      msg = "Output init function is not implemented!"
    end
    print(msg)
  end
end

function Output:open()
  local ok, err = pcall(self.functions.open, self)
  if not ok then
    local msg = err
    if err == "not_implemented" then
      msg = "Output open function is not implemented!"
    end
    print(msg)
  end
end

function Output:close()
  local ok, err = pcall(self.functions.close, self)
  if not ok then
    local msg = err
    if err == "not_implemented" then
      msg = "Output close function is not implemented!"
    end
    print(msg)
  end
end

-- Function for getting output actions
function Output:action()
  local actions = self.functions.ask(self)
  if not actions then
    return
  elseif #actions == 1 then
    actions[1].action()
    return
  end

  -- select if many options
  vim.ui.select(
    actions,
    {
      prompt = 'Pick a choice:',
      format_item = function(item)
        return item.label
      end,
    },
    function(choice)
      choice.action()
    end
  )
end

return Output
