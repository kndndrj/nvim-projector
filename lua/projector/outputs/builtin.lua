local Output = require("projector.contract.output")
local utils = require("projector.utils")

---@type Output
local BuiltinOutput = Output:new()

---@param configuration Configuration
---@diagnostic disable-next-line: unused-local
function BuiltinOutput:init(configuration)
  local name = self.meta.name or "Builtin"

  local command = configuration.command
  if configuration.args then
    command = command .. ' "' .. table.concat(configuration.args, '" "') .. '"'
  end

  local term_options = {
    clear_env = false,
    env = configuration.env,
    cwd = configuration.cwd,
    on_exit = function(_, code)
      local ok = true
      if code ~= 0 then
        ok = false
      end
      self:done(ok)
    end,
  }

  -- If pattern is specified, long running task is implied
  if configuration.pattern then
    local regex = vim.regex(configuration.pattern)
    term_options.on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if regex:match_str(line) then
          self:done(true)
        end
      end
    end
  end

  -- open the terminal in a new buffer
  vim.api.nvim_command("bo 15new")
  vim.fn.termopen(command, term_options)

  local bufnr = vim.fn.bufnr()
  self.meta.bufnr = bufnr
  local winid = vim.fn.win_getid()
  self.meta.winid = winid

  self.status = "visible"

  -- Rename and hide the buffer
  vim.api.nvim_command("file " .. name .. " " .. bufnr)
  vim.o.buflisted = false

  -- Autocommands
  -- Deactivate the output if we delete the buffer
  vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
    buffer = bufnr,
    callback = function()
      self.meta.bufnr = nil
      self.status = "inactive"
    end,
  })
  -- If we close the window, the output is hidden
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = bufnr,
    callback = function()
      self.meta.winid = nil
      self.status = "hidden"
    end,
  })
end

function BuiltinOutput:show()
  if self.status == "inactive" or self.status == "" then
    utils.log("warn", "Not live!", "Builtin Output " .. self.meta.name)
    return
  elseif self.status == "visible" then
    utils.log("info", "Already visible.", "Builtin Output " .. self.meta.name)
    return
  end

  -- Open a new window and open the buffer in it
  vim.api.nvim_command("15split")
  self.meta.winid = vim.fn.win_getid()
  vim.api.nvim_command("b " .. self.meta.bufnr)

  self.status = "visible"
end

function BuiltinOutput:hide()
  if self.status == "inactive" or self.status == "" then
    utils.log("warn", "Not live!", "Builtin Output " .. self.meta.name)
    return
  elseif self.status == "hidden" then
    utils.log("info", "Already hidden.", "Builtin Output " .. self.meta.name)
    return
  end

  vim.api.nvim_win_close(self.meta.winid, true)
  self.meta.winid = nil

  self.status = "hidden"
end

function BuiltinOutput:kill()
  if self.status == "inactive" or self.status == "" then
    utils.log("warn", "Not live!", "Builtin Output " .. self.meta.name)
    return
  end

  if self.meta.winid ~= nil then
    vim.api.nvim_win_close(self.meta.winid, true)
  end

  if self.meta.bufnr ~= nil then
    vim.api.nvim_buf_delete(self.meta.bufnr, { force = true })
  end

  self.status = "inactive"
end

---@return Action[]|nil
function BuiltinOutput:list_actions() end

return BuiltinOutput
