local Output = require 'projector.contract.output'
local has_dadbod_ui = vim.fn.exists(":DBUI") == 2

---@type Output
local DadbodOutput = Output:new()

---@param configuration Configuration
---@diagnostic disable-next-line: unused-local
function DadbodOutput:init(configuration)
  -- apply dadbod configuration variables
  if not configuration then
    self:done(false)
    return
  end

  for setting, config in pairs(configuration) do
    vim.g[setting] = config
  end

  if has_dadbod_ui then
    self.status = "hidden"
    self:open()
  else
    self.status = "inactive"
  end

  self:done(true)
end

function DadbodOutput:open()
  if has_dadbod_ui then
    if self.status == "inactive" or self.status == "" then
      print('Output not active')
      return
    elseif self.status == "active" then
      print('Already open')
      return
    end

    vim.cmd(":DBUI")

    local bufnr = vim.fn.bufnr()
    self.meta.bufnr = bufnr

    -- Autocommand for current buffer
    vim.api.nvim_create_autocmd({ 'BufDelete', 'BufUnload' },
      { buffer = bufnr,
        callback = function()
          print("aa")
          self.meta.bufnr = nil
          self.status = "hidden"
        end })

    self.status = "active"
  end
end

function DadbodOutput:close()
  if has_dadbod_ui then
    if self.status == "inactive" or self.status == "" then
      print('Output not active')
      return
    elseif self.status == "hidden" then
      print('Already closed')
      return
    end

    vim.api.nvim_buf_delete(self.meta.bufnr, { force = true })
    self.meta.bufnr = nil
    self.status = "hidden"
  end
end

---@return Action[]|nil
function DadbodOutput:list_actions()
end

return DadbodOutput
