local has_dadbod_ui = vim.fn.exists(":DBUI") == 2

---@class DadbodOutput: Output
---@field private state output_status
---@field private first_init boolean this init is the first one
local DadbodOutput = {}

---@return DadbodOutput
function DadbodOutput:new()
  local o = {
    state = "hidden",
    first_init = true,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return output_status
function DadbodOutput:status()
  return self.state or "hidden"
end

---@param _ task_configuration
---@param callback fun(success: boolean)
function DadbodOutput:init(_, callback)
  -- due to evaluation specification in the
  -- output builder, we don't have to do anything
  -- for the first time

  if not self.first_init then
    self:show()
  end

  self.first_init = false

  callback(true)
end

function DadbodOutput:show()
  if not has_dadbod_ui then
    return
  end

  vim.cmd(":DBUI")

  -- Autocommand for current buffer
  vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
    buffer = vim.api.nvim_get_current_buf(),
    callback = function()
      self.state = "hidden"
    end,
  })

  self.state = "visible"
end

function DadbodOutput:hide()
  if not has_dadbod_ui then
    return
  end

  vim.cmd(":DBUIClose")
  self.state = "hidden"
end

function DadbodOutput:kill()
  self:hide()
end

return DadbodOutput
