---@class Popup
---@field private left { winid: integer, bufnr:integer, title: string }
---@field private right { winid: integer, bufnr:integer, title: string }
---@field private bottom { winid: integer, bufnr:integer, title: string }
---@field private width integer
---@field private height integer
---@field private on_close fun()
local Popup = {}

---@alias popup_config { width: integer, height: integer }

---@param left_title? string
---@param right_title? string
---@param bottom_title? string
---@param opts? popup_config
---@return Popup
function Popup:new(left_title, right_title, bottom_title, opts)
  opts = opts or {}

  local o = {
    left = {
      title = left_title or "",
    },
    right = {
      title = right_title or "",
    },
    bottom = {
      title = bottom_title or "",
    },
    width = opts.width or 100,
    height = opts.height or 20,
    on_close = function() end,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@param on_close? fun()
---@return integer left_bufnr
---@return integer right_bufnr
---@return integer bottom_bufnr
function Popup:open(on_close)
  self.on_close = on_close or function() end

  -- zero coordinates (top left corner)
  local ui_spec = vim.api.nvim_list_uis()[1]
  local x = math.floor((ui_spec.width / 2) - (self.width / 2) - 1)
  local y = math.floor(((ui_spec.height - self.height) / 2) - 1)

  -- create buffers
  self.left.bufnr = vim.api.nvim_create_buf(false, true)
  self.right.bufnr = vim.api.nvim_create_buf(false, true)
  self.bottom.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.left.bufnr, "bufhidden", "delete")
  vim.api.nvim_buf_set_option(self.right.bufnr, "bufhidden", "delete")
  vim.api.nvim_buf_set_option(self.bottom.bufnr, "bufhidden", "delete")

  -- open windows
  local window_opts = {
    relative = "editor",
    border = "rounded",
    style = "minimal",
    title_pos = "center",
  }

  self.left.winid = vim.api.nvim_open_win(
    self.left.bufnr,
    true,
    vim.tbl_extend("force", window_opts, {
      width = math.floor((self.width / 2) - 1),
      height = math.floor(self.height / 2),
      row = y,
      col = x,
      border = { "╭", "─", "┬", "│", "", "", "╰", "│" },
      title = " " .. self.left.title .. " ",
    })
  )
  self.right.winid = vim.api.nvim_open_win(
    self.right.bufnr,
    true,
    vim.tbl_extend("force", window_opts, {
      width = math.floor(self.width / 2),
      height = math.floor(self.height / 2),
      row = y,
      col = math.floor(x + (self.width / 2)),
      border = { "┬", "─", "╮", "│", "╯", "", "", "│" },
      title = " " .. self.right.title .. " ",
    })
  )
  self.bottom.winid = vim.api.nvim_open_win(
    self.bottom.bufnr,
    false,
    vim.tbl_extend("force", window_opts, {
      width = self.width,
      height = math.floor(self.height / 2),
      row = math.floor(y + (self.height / 2) + 1),
      col = x,
      border = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
      title = " " .. self.bottom.title .. " ",
    })
  )

  -- disable line wrap
  vim.api.nvim_win_set_option(self.left.winid, "wrap", false)
  vim.api.nvim_win_set_option(self.right.winid, "wrap", false)
  vim.api.nvim_win_set_option(self.bottom.winid, "wrap", false)

  -- register autocmd to automatically close the window on leave
  local function autocmd_cb()
    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= self.left.bufnr and current_buf ~= self.right.bufnr and current_buf ~= self.bottom.bufnr then
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

  for _, ui in ipairs { self.left, self.right, self.bottom } do
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
    for _, ui in ipairs { self.left, self.right, self.bottom } do
      vim.keymap.set("n", key, function()
        self:close()
      end, { silent = true, buffer = ui.bufnr })
    end
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

  return self.left.bufnr, self.right.bufnr, self.bottom.bufnr
end

function Popup:close()
  self.on_close()

  for _, ui in ipairs { self.left, self.right, self.bottom } do
    pcall(vim.api.nvim_win_close, ui.winid, true)
    pcall(vim.api.nvim_buf_delete, ui.bufnr, {})
  end
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

---@return "left"|"right"|"bottom"|""
function Popup:get_focus()
  local current_buf = vim.api.nvim_get_current_buf()
  if current_buf == self.left.bufnr then
    return "left"
  elseif current_buf == self.right.bufnr then
    return "right"
  elseif current_buf == self.bottom.bufnr then
    return "bottom"
  end
  return ""
end

return Popup
