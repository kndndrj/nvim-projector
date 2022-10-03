local M = {}

---@param array string[]
function M.alphanumsort(array)
  local function padnum(d) return ("%03d%s"):format(#d, d) end

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

return M
