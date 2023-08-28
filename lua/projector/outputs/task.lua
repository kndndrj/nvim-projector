local utils = require("projector.utils")

---@class TaskOutput: Output
---@field private name string
---@field private bufnr integer
---@field private winid integer
---@field private state output_status
local TaskOutput = {}

---@return TaskOutput
function TaskOutput:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return output_status
function TaskOutput:status()
  return self.state or "inactive"
end

---@param configuration task_configuration
---@param callback fun(success: boolean)
function TaskOutput:init(configuration, callback)
  local name = configuration.name or "Builtin"

  local command = configuration.command
  if configuration.args then
    command = command .. ' "' .. table.concat(configuration.args, '" "') .. '"'
  end

  local term_options = {
    clear_env = false,
    env = configuration.env,
    cwd = configuration.cwd,
    on_exit = function(_, code)
      callback(code == 0)
    end,
  }

  -- If pattern is specified, long running task is implied
  if configuration.pattern then
    local regex = vim.regex(configuration.pattern)
    term_options.on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if regex:match_str(line) then
          callback(true)
        end
      end
    end
  end

  -- create new window and open a terminal job inside
  vim.api.nvim_command("bo 15new")
  vim.fn.termopen(command, term_options)

  local winid = vim.api.nvim_get_current_win()
  self.bufnr = vim.api.nvim_get_current_buf()

  -- Rename and hide the buffer
  vim.api.nvim_command("file " .. name .. " " .. self.bufnr)
  vim.o.buflisted = false

  -- close the window
  vim.api.nvim_win_close(winid, true)

  self.state = "hidden"

  -- Autocommands
  -- Deactivate the output if we delete the buffer
  vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
    buffer = self.bufnr,
    callback = function()
      self.bufnr = nil
      self.state = "inactive"
    end,
  })
  -- If we close the window, the output is hidden
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = self.bufnr,
    callback = function()
      self.winid = nil
      self.state = "hidden"
    end,
  })
end

function TaskOutput:show()
  if self.state == "inactive" or self.state == "" then
    utils.log("warn", "Not live!", "Builtin Output " .. self.name)
    return
  elseif self.state == "visible" then
    utils.log("info", "Already visible.", "Builtin Output " .. self.name)
    return
  end

  -- Open a new window and open the buffer in it
  vim.api.nvim_command("15split")
  self.winid = vim.fn.win_getid()
  vim.api.nvim_command("b " .. self.bufnr)

  self.state = "visible"
end

function TaskOutput:hide()
  if self.state == "inactive" or self.state == "" then
    utils.log("warn", "Not live!", "Builtin Output " .. self.name)
    return
  elseif self.state == "hidden" then
    utils.log("info", "Already hidden.", "Builtin Output " .. self.name)
    return
  end

  vim.api.nvim_win_close(self.winid, true)
  self.winid = nil

  self.state = "hidden"
end

function TaskOutput:kill()
  if self.state == "inactive" or self.state == "" then
    return
  end

  if self.winid then
    vim.api.nvim_win_close(self.winid, true)
  end

  if self.bufnr then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end

  self.state = "inactive"
end

return TaskOutput