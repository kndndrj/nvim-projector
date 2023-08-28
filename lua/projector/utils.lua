local M = {}

---@param list any[] list like table
---@param val any value in the table
function M.contains(list, val)
  for _, f in ipairs(list) do
    if f == val then
      return true
    end
  end
  return false
end

-- merges multiple list like tables
---@param ... any[] list like tables
---@return any[] # merged list
function M.merge_lists(...)
  local args = { ... }
  local ret = {}

  for _, v in ipairs(args) do
    vim.list_extend(ret, v)
  end

  return ret
end

---@param level "info"|"warn"|"error"
---@param message string
---@param subtitle? string
function M.log(level, message, subtitle)
  -- log level
  local l = vim.log.levels.OFF
  if level == "info" then
    l = vim.log.levels.INFO
  elseif level == "warn" then
    l = vim.log.levels.WARN
  elseif level == "error" then
    l = vim.log.levels.ERROR
  end

  -- subtitle
  if subtitle then
    subtitle = "[" .. subtitle .. "]:"
  else
    subtitle = ""
  end
  vim.notify(subtitle .. " " .. message, l, { title = "nvim-projector" })
end

return M
