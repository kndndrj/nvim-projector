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
  self.name = configuration.name or "Builtin"

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

  -- create new dummy window and open a terminal job inside
  vim.api.nvim_command("bo 15new")
  vim.fn.termopen(command, term_options)

  local winid = vim.api.nvim_get_current_win()
  self.bufnr = vim.api.nvim_get_current_buf()

  -- hide the buffer
  vim.api.nvim_buf_set_option(self.bufnr, "buflisted", false)

  -- close the dummy window
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
  -- switch back to our buffer when trying to open a different buffer in this window
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWinLeave", "BufReadPost", "BufNewFile" }, {
    callback = function(arg)
      -- delete autocmd if output is dead
      if not self.bufnr or self.state == "inactive" then
        return true
      end

      local wid = vim.api.nvim_get_current_win()
      if wid == self.winid and arg.buf ~= self.bufnr then
        pcall(vim.api.nvim_win_set_buf, self.winid, self.bufnr)
      end
    end,
  })
end

function TaskOutput:show()
  -- Open a new window and open the buffer in it
  if not self.bufnr then
    self.state = "inactive"
    return
  end

  vim.api.nvim_command("15split")
  self.winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(self.winid, self.bufnr)

  -- set winbar
  vim.api.nvim_win_set_option(self.winid, "winbar", self.name)

  self.state = "visible"
end

function TaskOutput:hide()
  pcall(vim.api.nvim_win_close, self.winid, true)
  self.winid = nil

  self.state = "hidden"
end

function TaskOutput:kill()
  -- close the window and delete the buffer
  pcall(vim.api.nvim_win_close, self.winid, true)
  pcall(vim.api.nvim_buf_delete, self.bufnr, { force = true })

  self.state = "inactive"
end

return TaskOutput
