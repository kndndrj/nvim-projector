local M = {}

function M.init(self)
  local name = self.meta.name or 'Builtin'
  local term_options = {
    clear_env = true,
    env = self.env,
    cwd = self.cwd,
  }

  -- open the terminal in a new buffer
  vim.api.nvim_command('bo 15new')
  vim.fn.termopen(self.command, term_options)

  local bufnr = vim.fn.bufnr()
  self.meta.bufnr = bufnr
  local winid = vim.fn.win_getid()
  self.meta.winid = winid

  self.status = "active"

  -- Rename the buffer
  vim.api.nvim_command('file ' .. name .. ' ' .. bufnr)

  -- Autocommands
  -- Deactivate the output if we delete the buffer
  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufUnload' },
    { buffer = bufnr,
      callback = function()
        self.meta.bufnr = nil
        self.status = "inactive"
      end })
  -- If we close the window, the output is hidden
  vim.api.nvim_create_autocmd({ 'WinClosed' },
    { buffer = bufnr,
      callback = function()
        self.meta.winid = nil
        self.status = "hidden"
      end })
end

function M.open(self)
  if self.status == "inactive" or self.status == "" then
    print('Output not active')
    return
  elseif self.status == "active" then
    print('Already open')
    return
  end

  -- Open a new window and open the buffer in it
  vim.api.nvim_command('15split')
  self.meta.winid = vim.fn.win_getid()
  vim.api.nvim_command('b ' .. self.meta.bufnr)

  self.status = "active"
end

function M.close(self)
  if self.status == "inactive" or self.status == "" then
    print('Output not active')
    return
  elseif self.status == "hidden" then
    print('Already closed')
    return
  end

  vim.api.nvim_win_close(self.meta.winid, true)
  self.meta.winid = nil

  self.status = "hidden"
end

return M
