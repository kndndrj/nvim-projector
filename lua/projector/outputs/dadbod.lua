local has_dadbod_ui = vim.fn.exists(":DBUI") == 2

---@class DadbodOutput: Output
---@field private state output_status
local DadbodOutput = {}

---@return DadbodOutput
function DadbodOutput:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return output_status
function DadbodOutput:status()
  return self.state or "visible"
end

---@param _ TaskConfiguration
---@param callback fun(success: boolean)
function DadbodOutput:init(_, callback)
  -- due to evaluation specification in the
  -- output builder, we don't have to do anything
  self.state = "hidden"
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

  if vim.fn.exists(":DBUIClose") == 2 then
    vim.cmd(":DBUIClose")
    self.state = "hidden"
  end
end

function DadbodOutput:kill()
  self:hide()
end

return DadbodOutput
