local M = {}


M.outputs = {}


function M.start(command, term_options, name)
  if name == nil or name == '' then
    name = 'Task'
  end
  vim.api.nvim_command('bo 15new')
  vim.fn.termopen(command, term_options)

  local bufnr = vim.fn.bufnr()
  M.outputs[bufnr] = {}
  local output = M.outputs[bufnr]
  output.name = name
  output.winid = vim.fn.win_getid()

  -- set title and remove the values from output table on events
  vim.api.nvim_command('autocmd! BufDelete,BufUnload <buffer> lua require"projector.output".outputs[' .. bufnr ..'] = nil')
  vim.api.nvim_command('autocmd! WinClosed <buffer> lua require"projector.output".outputs[' .. bufnr ..'].winid = nil')
  vim.api.nvim_command('file ' .. name .. ' ' .. bufnr)
end


function M.open(bufnr)
  if not M.outputs[bufnr] then
    print('Output not active')
    return
  end
  local output = M.outputs[bufnr]
  if output.winid ~= nil then
    print('Already open')
    return
  end
  vim.api.nvim_command('15split')
  output.winid = vim.fn.win_getid()
  vim.api.nvim_command('b ' .. bufnr)
end


function M.close(bufnr)
  if not M.outputs[bufnr] then
    print('Output not active')
    return
  end
  local output = M.outputs[bufnr]
  if output.winid == nil then
    print('Already closed')
    return
  end
  vim.api.nvim_win_close(output.winid, true)
  output.winid = nil
end


function M.list_hidden_outputs()
  local list = {}
  for bufnr, output in pairs(M.outputs) do
    if output.winid == nil then
      output.bufnr = bufnr
      table.insert(list, output)
    end
  end
  return list
end


function M.list_active_outputs()
  local list = {}
  for bufnr, output in pairs(M.outputs) do
    if output.winid ~= nil then
      output.bufnr = bufnr
      table.insert(list, output)
    end
  end
  return list
end

return M
