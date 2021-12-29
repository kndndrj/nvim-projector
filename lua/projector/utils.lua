
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

return M
