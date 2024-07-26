---@class TaskOutput: Output
---@field private name? string
---@field private bufnr? integer
---@field private winid? integer
---@field private job_id? integer
---@field private died? boolean did task already die?
---@field private killed_manually? boolean was task killed by using the :kill method?
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
  if self.died then
    return "inactive"
  end

  local alive = (self.job_id ~= nil and vim.fn.jobwait({ self.job_id }, 0)[1] == -1)

  if not alive then
    self.died = true
    return "inactive"
  elseif self.winid and vim.api.nvim_win_is_valid(self.winid) then
    return "visible"
  elseif self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    return "hidden"
  end

  return "inactive"
end

---@param configuration TaskConfiguration
---@param callback fun(success: boolean)
function TaskOutput:init(configuration, callback)
  self.name = configuration.name or "Builtin"

  local command = configuration.command
  if configuration.args then
    local args = {}
    -- escape arg characters
    for _, arg in ipairs(configuration.args) do
      local a = arg:gsub('"', [[\"]])
      table.insert(args, a)
    end
    command = command .. ' "' .. table.concat(args, '" "') .. '"'
  end

  local term_options = {
    clear_env = false,
    env = configuration.env,
    cwd = configuration.cwd,
    on_exit = function(_, code)
      if self.killed_manually then
        -- close the window and delete the buffer (only if killed usink key combination)
        self:close()
      end

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

  -- Autocommands
  -- If we close the window, the output is hidden
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = self.bufnr,
    callback = function()
      self.winid = nil
    end,
  })
  -- switch back to our buffer when trying to open a different buffer in this window
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWinLeave", "BufReadPost", "BufNewFile" }, {
    callback = function(arg)
      -- delete autocmd if output is dead
      if (not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr)) or self:status() == "inactive" then
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
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end

  vim.api.nvim_command("15split")
  self.winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(self.winid, self.bufnr)

  -- set winbar
  vim.api.nvim_win_set_option(self.winid, "winbar", self.name)
end

function TaskOutput:hide()
  pcall(vim.api.nvim_win_close, self.winid, true)
end

---@param winid integer
local function kill_terminal(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  -- switch to provided window and kill it
  vim.api.nvim_set_current_win(winid)

  -- enter insert mode and send ctrl+c and escape (insert-mode, kill-process, normal-mode)
  local escaped = vim.api.nvim_replace_termcodes("i<C-c>", true, false, true)
  vim.api.nvim_feedkeys(escaped, "m", false)
end

function TaskOutput:kill()
  local status = self:status()
  if status == "inactive" then
    return
  end

  -- show window on screen if it's not there
  if status == "hidden" then
    self:show()
  end

  self.killed_manually = true
  -- kill the process
  kill_terminal(self.winid)
end

function TaskOutput:close()
  pcall(vim.api.nvim_win_close, self.winid, true)
  pcall(vim.api.nvim_buf_delete, self.bufnr, { force = true })
end

---@param max_lines integer
---@return string[]?
function TaskOutput:preview(max_lines)
  local status = self:status()
  if status ~= "visible" and status ~= "hidden" then
    return
  end
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
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
