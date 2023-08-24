---@class Popup
---@field private left { winid: integer, bufnr:integer }
---@field private right { winid: integer, bufnr:integer }
---@field private width integer
---@field private height integer
local Popup = {}

---@alias popup_config { width: integer, height: integer }

---@param opts? popup_config
---@return Popup
function Popup:new(opts)
  opts = opts or {}

  local o = {
    left = {},
    right = {},
    width = opts.width or 100,
    height = opts.height or 20,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return integer left_bufnr
---@return integer right_bufnr
function Popup:open()
  local ui_spec = vim.api.nvim_list_uis()[1]
  local width = self.width / 2
  local height = self.height

  local middle = math.floor(ui_spec.width / 2)
  local y = math.floor((ui_spec.height - height) / 2)

  -- create buffers
  self.left.bufnr = vim.api.nvim_create_buf(false, true)
  self.right.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.left.bufnr, "bufhidden", "delete")
  vim.api.nvim_buf_set_option(self.right.bufnr, "bufhidden", "delete")

  -- open windows
  local window_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = y,
    border = "rounded",
    style = "minimal",
  }

  self.left.winid = vim.api.nvim_open_win(
    self.left.bufnr,
    true,
    vim.tbl_extend("force", window_opts, {
      col = middle - width - 1,
      border = { "╭", "─", "┬", "│", "┴", "─", "╰", "│" },
      title_pos = "left",
      title = "Projector",
    })
  )
  self.right.winid = vim.api.nvim_open_win(
    self.right.bufnr,
    true,
    vim.tbl_extend("force", window_opts, {
      col = middle,
      border = { "┬", "─", "╮", "│", "╯", "─", "┴", "│" },
    })
  )

  -- disable line wrap
  vim.api.nvim_win_set_option(self.left.winid, "wrap", false)
  vim.api.nvim_win_set_option(self.right.winid, "wrap", false)

  -- register autocmd to automatically close the window on leave
  local function autocmd_cb()
    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= self.left.bufnr and current_buf ~= self.right.bufnr then
      self:close()
    else
      vim.api.nvim_create_autocmd({ "BufEnter" }, {
        callback = autocmd_cb,
        once = true,
      })
    end
  end
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = autocmd_cb,
    once = true,
  })

  for _, ui in ipairs { self.left, self.right } do
    -- set cursorline on enter and disable on leave
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      buffer = ui.bufnr,
      callback = function()
        vim.api.nvim_win_set_option(ui.winid, "cursorline", true)
      end,
    })
    vim.api.nvim_create_autocmd({ "BufLeave" }, {
      buffer = ui.bufnr,
      callback = function()
        vim.api.nvim_win_set_option(ui.winid, "cursorline", false)
      end,
    })

    -- close the popup if one of the windows is closed
    vim.api.nvim_create_autocmd({ "WinClosed" }, {
      buffer = ui.bufnr,
      callback = function()
        self:close()
      end,
    })
  end

  -- set keymaps
  -- close
  for _, key in ipairs { "q", "<ESC>" } do
    vim.keymap.set("n", key, function()
      self:close()
    end, { silent = true, buffer = self.left.bufnr })
    vim.keymap.set("n", key, function()
      self:close()
    end, { silent = true, buffer = self.right.bufnr })
  end

  -- switch windows
  vim.keymap.set("n", "l", function()
    pcall(vim.api.nvim_set_current_win, self.right.winid)
  end, { silent = true, buffer = self.left.bufnr })
  vim.keymap.set("n", "l", function()
    pcall(vim.api.nvim_set_current_win, self.left.winid)
  end, { silent = true, buffer = self.right.bufnr })

  vim.keymap.set("n", "h", function()
    pcall(vim.api.nvim_set_current_win, self.right.winid)
  end, { silent = true, buffer = self.left.bufnr })
  vim.keymap.set("n", "h", function()
    pcall(vim.api.nvim_set_current_win, self.left.winid)
  end, { silent = true, buffer = self.right.bufnr })

  -- set left window as current one by default
  vim.api.nvim_set_current_win(self.left.winid)

  return self.left.bufnr, self.right.bufnr
end

function Popup:close()
  pcall(vim.api.nvim_win_close, self.left.winid, true)
  pcall(vim.api.nvim_win_close, self.right.winid, true)
  pcall(vim.api.nvim_buf_delete, self.left.bufnr, {})
  pcall(vim.api.nvim_buf_delete, self.right.bufnr, {})
end

---@return integer width
---@return integer height
function Popup:dimensions()
  return self.width, self.height
end

---@param where "left"|"right"
function Popup:set_focus(where)
  if where == "left" then
    vim.api.nvim_set_current_win(self.left.winid)
  elseif where == "right" then
    vim.api.nvim_set_current_win(self.right.winid)
  end
end

return Popup
