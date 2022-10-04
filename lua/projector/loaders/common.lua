local M = {}

function M.expand_config_variables(option)
  if type(option) == 'function' then
    option = option()
  end
  if type(option) == 'table' then
    return vim.tbl_map(M.expand_config_variables, option)
  end
  if type(option) ~= 'string' then
    return option
  end
  local variables = {
    file = vim.fn.expand('%'),
    fileBasename = vim.fn.expand('%:t'),
    fileBasenameNoExtension = vim.fn.fnamemodify(vim.fn.expand('%:t'), ':r'),
    fileDirname = vim.fn.expand('%:p:h'),
    fileExtname = vim.fn.expand('%:e'),
    relativeFile = vim.fn.expand('%'),
    relativeFileDirname = vim.fn.fnamemodify(vim.fn.expand('%:h'), ':r'),
    workspaceFolder = vim.fn.getcwd(),
    workspaceFolderBasename = vim.fn.fnamemodify(vim.fn.getcwd(), ':t'),
  }
  local ret = option
  for key, val in pairs(variables) do
    ret = ret:gsub('${' .. key .. '}', val)
  end
  return ret
end

return M
