local M = {}


M.outputs = {}


function M.open(command, term_options, name)
  if name == nil or name == '' then
    name = 'Task'
  end
  local tag = math.random(10000)
  M.outputs[tag] = {}
  local output = M.outputs[tag]
  output.name = name

  vim.api.nvim_command('bo 15new')
  output.winid = vim.fn.win_getid()

  vim.fn.termopen(command, term_options)
  output.bufnr = vim.fn.bufnr()

  -- set title and remove the values from output table on events
  vim.api.nvim_command('autocmd! BufDelete,BufUnload <buffer> lua require"projector.output".outputs[' .. tag ..'] = nil')
  vim.api.nvim_command('autocmd! WinClosed <buffer> lua require"projector.output".outputs[' .. tag ..'].winid = nil')
  vim.api.nvim_command('file ' .. name .. ' ' .. tag)
end


function M.toggle(tag)
  if not M.outputs[tag] or not M.outputs[tag].bufnr then
    print('Output not active')
    return
  end
  local output = M.outputs[tag]
  if output.winid == nil then
    vim.api.nvim_command('15split')
    output.winid = vim.fn.win_getid()
    vim.api.nvim_command('b ' .. output.bufnr)
  else
    vim.api.nvim_win_close(output.winid, true)
    output.winid = nil
  end
end

function M.list_outputs()
  local list = {}
  for tag, output in pairs(M.outputs) do
    output.tag = tag
    table.insert(list, output)
  end
  return list
end

return M
