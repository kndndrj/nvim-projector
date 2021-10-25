local M = {}

local dap = require'dap'


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

M.configurations.global.debug.go = {
  {
    type = 'go',
    name = 'Debug Current File',
    request = 'launch',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
  {
    type = 'go',
    name = 'Debug Test',
    request = 'launch',
    mode = 'test',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
}

M.configurations.global.tasks.shell = {
  {
    type = 'shell',
    name = 'CAT',
    command = 'cat',
    args = {
      '${workspaceFolder}/.vscode/launch.json',
      '|',
      'grep',
      'e',
    },
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
  {
    type = 'shell',
    name = 'read',
    command = 'read',
    args = {
      'i;',
      'echo',
      '$i',
    },
  },
  {
    type = 'shell',
    name = 'ls',
    command = 'ls',
    args = {
      '-al',
    },
    cwd = '/home/andrej/',
  },
}


M.configurations.project.debug.go = {
  {
    type = 'go',
    name = 'Debug Current File project',
    request = 'launch',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
  {
    type = 'go',
    name = 'Debug Test project',
    request = 'launch',
    mode = 'test',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
}

M.configurations.project.tasks.shell = {
  {
    type = 'shell',
    name = 'CAT project',
    command = 'echo',
    args = {
      '$TEST_ENV',
      '$TEST_ENV2',
    },
    env = {
      TEST_ENV = "test",
      TEST_ENV2 = "test2",
    }
  },
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
    file = vim.fn.expand("%");
    fileBasename = vim.fn.expand("%:t");
    fileBasenameNoExtension = vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r");
    fileDirname = vim.fn.expand("%:p:h");
    fileExtname = vim.fn.expand("%:e");
    relativeFile = vim.fn.expand("%");
    relativeFileDirname = vim.fn.fnamemodify(vim.fn.expand("%:h"), ":r");
    workspaceFolder = vim.fn.getcwd();
    workspaceFolderBasename = vim.fn.fnamemodify(vim.fn.getcwd(), ":t");
  }
  local ret = option
  for key, val in pairs(variables) do
    ret = ret:gsub('${' .. key .. '}', val)
  end
  return ret
end


function M.run_task(configuration)
  configuration = vim.tbl_map(expand_config_variables, configuration)
  if not configuration.command then
    print('Task must specify a command')
    return
  end
  local command = configuration.command
  if configuration.args then
    command = configuration.command .. ' ' .. table.concat(configuration.args, ' ')
  end
  local term_options = { clear_env = true }
  if configuration.env then
    term_options.env = configuration.env
  end
  if configuration.cwd then
    term_options.cwd = configuration.cwd
  end

  -- send task to the terminal
  vim.api.nvim_command("bot 15new")
  local bufnr = vim.fn.bufnr()

  vim.fn.termopen(command, term_options)
  vim.api.nvim_command("autocmd! WinClosed <buffer> " .. bufnr .. "bd!")

end


function M.run_task_or_debug(configuration)
  if configuration.projector.type == 'debug' then
    dap.run(configuration)
  elseif configuration.projector.type == 'tasks' then
    M.run_task(configuration)
  else
    print('Invalid task type')
  end
end


function M.dap_continue()
  local session = dap.session()
  if not session then
    require'telescope'.extensions.projector.debug()
  elseif session.stopped_thread_id then
    session:_step('continue')
  else
    require'telescope'.extensions.projector.active_session()
  end
end


return M
