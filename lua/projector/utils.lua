
local M = {}

function M.contains(list, value)
  if type(list) == "table" then
    for _, v in pairs(list) do
      if v == value then return true end
    end
  else
    if list == value then return true end
  end
  return false
end

return M
