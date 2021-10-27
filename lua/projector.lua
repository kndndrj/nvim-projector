local dap = require'dap'
local output = require'projector.output'

local M = {}

M.configurations = {
  global = {
    debug = {},
    tasks = {},
  },
  project = {
    debug = {},
    tasks = {},
  }
}


-- shamelessly coppied from nvim-dap
local function expand_config_variables(option)
  if type(option) == 'function' then
    option = option()
  end
  if type(option) == "table" then
    return vim.tbl_map(expand_config_variables, option)
  end
  if type(option) ~= "string" then
    return option
  end
  local variables = {
    file = vim.fn.expand("%"),
    fileBasename = vim.fn.expand("%:t"),
    fileBasenameNoExtension = vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r"),
    fileDirname = vim.fn.expand("%:p:h"),
    fileExtname = vim.fn.expand("%:e"),
    relativeFile = vim.fn.expand("%"),
    relativeFileDirname = vim.fn.fnamemodify(vim.fn.expand("%:h"), ":r"),
    workspaceFolder = vim.fn.getcwd(),
    workspaceFolderBasename = vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
  }
  local ret = option
  for key, val in pairs(variables) do
    ret = ret:gsub('${' .. key .. '}', val)
  end
  return ret
end


local function run_task(configuration)
  configuration = vim.tbl_map(expand_config_variables, configuration)
  if not configuration.command then
    print('Task must specify a command')
    return
  end
  local command = configuration.command
  if configuration.args then
    command = configuration.command .. ' "' .. table.concat(configuration.args, '" "') .. '"'
  end
  local term_options = { clear_env = false }
  if configuration.env then
    term_options.env = configuration.env
  end
  if configuration.cwd then
    term_options.cwd = configuration.cwd
  end

  -- send task to the terminal
  output.start(command, term_options, configuration.name)
end


function M.run_task_or_debug(configuration)
  if configuration.projector.type == 'debug' then
    dap.run(configuration)
  elseif configuration.projector.type == 'tasks' then
    run_task(configuration)
  else
    print('Invalid task type')
  end
end


function M.continue(telescope_filter)
  if telescope_filter == nil or telescope_filter == '' then
    telescope_filter = 'debug'
  end
  local session = dap.session()
  if not session then
    require'telescope'.extensions.projector[telescope_filter]()
  elseif session.stopped_thread_id then
    session:_step('continue')
  else
    require'telescope'.extensions.projector.active_debug()
  end
end


function M.toggle_output()
  local hidden_outputs = output.list_hidden_outputs()
  local active_outputs = output.list_active_outputs()

  if #hidden_outputs == 1 and #active_outputs == 0 then
    -- open the only element
    for _, out in ipairs(hidden_outputs) do
      output.open(out.bufnr)
      return
    end
  elseif #hidden_outputs == 0 and #active_outputs == 1 then
    -- close the only element
    for _, out in ipairs(active_outputs) do
      output.close(out.bufnr)
      return
    end
  elseif #hidden_outputs > 0 then
    require'telescope'.extensions.projector.active_tasks()
    return
  end

  print('No hidden tasks running')
end


return M
