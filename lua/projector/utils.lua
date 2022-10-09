local M = {}

---@param array string[]
function M.alphanumsort(array)
  local function padnum(d)
    return ("%03d%s"):format(#d, d)
  end

  table.sort(array, function(a, b)
    return tostring(a):gsub("%d+", padnum) < tostring(b):gsub("%d+", padnum)
  end)
  return array
end

---@param obj table targeted table
---@param fields { exact?: string[], prefixes?: string[] } exact field names or prefixes
function M.is_in_table(obj, fields)
  for _, f in pairs(fields) do
    if obj[f] == nil then
      return false
    end
  end
  return true
end

---@param obj table
---@param selector string
function M.longest(obj, selector)
  local len = 0
  for _, item in pairs(obj) do
    local item_len = vim.fn.strchars(item[selector])
    if item_len > len then
      len = item_len
    end
  end
  return len
end

---@param display Display
---@return Display
function M.map_icons(display)
  ---@type config
  local config = require("projector").config

  if not config.icons.enable then
    if type(display.modes) == "table" then
      ---@diagnostic disable-next-line
      display.modes = table.concat(display.modes, "|")
    end
    return display
  end

  local group = config.icons.groups[display.group]
  if not group then
    local has_devicons, devicons = pcall(require, "nvim-web-devicons")
    if has_devicons then
      local icon, hl = devicons.get_icon_by_filetype(display.group)
      if hl ~= "DevIconDefault" then
        group = icon
      end
    end
  end

  local modes = {}
  for _, mode in ipairs(display.modes) do
    mode = config.icons.modes[mode] or mode
    table.insert(modes, mode)
  end

  return {
    loader = config.icons.loaders[display.loader] or display.loader,
    scope = config.icons.scopes[display.scope] or display.scope,
    group = group or display.group,
    name = display.name,
    modes = table.concat(modes, " |"),
  }
end

return M
