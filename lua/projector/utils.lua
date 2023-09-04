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

-- pretty prints a key-value table
---@param obj table<string, any>
---@return string[]
function M.format_table(obj)
  ---@type string[]
  local keys = {}

  local max_len = 0
  for k, _ in pairs(obj) do
    table.insert(keys, k)
    local len = string.len(k)
    if len > max_len then
      max_len = len
    end
  end

  table.sort(keys)

  ---@type string[]
  local out = {}
  for _, k in ipairs(keys) do
    local value = obj[k]
    if type(value) == "table" then
      value = "{ ... }"
    elseif type(value) == "function" then
      value = "fun()"
    end
    if type(value) ~= "string" then
      value = tostring(value)
    end
    local line = k .. ":  " .. string.rep(" ", max_len - string.len(k)) .. value
    table.insert(out, line)
  end

  return out
end

return M
