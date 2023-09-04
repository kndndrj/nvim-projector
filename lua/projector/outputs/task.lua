---@class TaskOutput: Output
---@field private name string
---@field private bufnr integer
---@field private winid integer
---@field private state output_status
---@field private job_id integer
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
  self.job_id = vim.fn.termopen(command, term_options)

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
  -- kill the task
  if self.job_id then
    vim.fn.jobstop(self.job_id)
  end

  -- close the window and delete the buffer
  pcall(vim.api.nvim_win_close, self.winid, true)
  pcall(vim.api.nvim_buf_delete, self.bufnr, { force = true })

  self.state = "inactive"
end

---@param max_lines integer
---@return string[]?
function TaskOutput:preview(max_lines)
  if self.state ~= "visible" and self.state ~= "hidden" then
    return
  end
  if not self.bufnr then
    return
  end

  -- get last max_lines * 3 lines (should be enough for most cases)
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, -30, -1, false)

  -- get last non blank line
  local to = 0
  for i = #lines, 1, -1 do
    if lines[i] ~= "" then
      to = i
      break
    end
  end

  local from = to - max_lines
  if from < 0 then
    from = 0
  end

  -- return range of lines
  return { unpack(lines, from + 1, to + 1) }
end

return TaskOutput
