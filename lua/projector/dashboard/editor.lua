local M = {}

---@param file string file to edit
---@param opts? { width: integer, height: integer, title: string, border: string|string[], callback: fun() } optional parameters
function M.open(file, opts)
  opts = opts or {}

  local ui_spec = vim.api.nvim_list_uis()[1]
  local win_width = opts.width or (ui_spec["width"] - 50)
  local win_height = opts.height or (ui_spec["height"] - 10)
  local x = math.floor((ui_spec["width"] - win_width) / 2)
  local y = math.floor((ui_spec["height"] - win_height) / 2)

  -- create new dummy buffer
  local tmp_buf = vim.api.nvim_create_buf(false, true)

  -- open window
  local winid = vim.api.nvim_open_win(tmp_buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    col = x,
    row = y,
    border = opts.border or "rounded",
    title = opts.title or "",
    title_pos = "center",
    style = "minimal",
  })

  -- open the file
  vim.cmd("e " .. file)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "delete")

  local callback = opts.callback or function() end

  -- set callbacks
  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = bufnr,
    callback = callback,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "BufWritePost" }, {
    buffer = bufnr,
    callback = function()
      -- close the window if not using "wq" already
      local cmd_hist = vim.api.nvim_exec2(":history cmd -1", { output = true })
      local last_cmd = cmd_hist.output:gsub(".*\n>%s*%d+%s*(.*)%s*", "%1")
      if not last_cmd:find("^wq") then
        pcall(vim.api.nvim_win_close, winid, true)
        pcall(vim.api.nvim_buf_delete, bufnr, {})
      end
    end,
  })

  -- set keymaps
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(winid, true)
  end, { silent = true, buffer = bufnr })
end

return M
