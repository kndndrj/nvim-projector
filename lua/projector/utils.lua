local M = {}

function M.contains(list, value)
  if type(list) == 'table' then
    for _, v in pairs(list) do
      if v == value then return true end
    end
  else
    if list == value then return true end
  end
  return false
end

function M.expand_table(obj)
  local ret = {}
  for _, i in pairs(obj) do
    table.insert(ret, i)
  end
  return ret
end

function M.deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
    end
    setmetatable(copy, M.deepcopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

function M.concat_tables(table1, table2)
  for i = 1, #table2 do
    table1[#table1 + 1] = table2[i]
  end
  return table1
end

function M.alphanumsort(array)
  local function padnum(d) return ("%03d%s"):format(#d, d) end

  table.sort(array, function(a, b)
    return tostring(a):gsub("%d+", padnum) < tostring(b):gsub("%d+", padnum)
  end)
  return array
end

function M.generate_table_id(obj)
  local values = vim.tbl_values(obj)

  local words = {}
  for _, value in pairs(values) do
    -- if table, expand
    if type(value) == "table" then
      value = M.generate_table_id(value)
    else
      value = tostring(value)
    end

    table.insert(words, value)
  end

  words = M.alphanumsort(words)
  return table.concat(words)
end

return M
