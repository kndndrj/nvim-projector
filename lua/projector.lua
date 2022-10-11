local dap = require'dap'
local output = require'projector.output'
local utils = require'projector.utils'

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
  if type(option) == 'table' then
    return vim.tbl_map(expand_config_variables, option)
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
  if configuration.on_exit then
    term_options.on_exit = configuration.on_exit
  end

  -- send task to the terminal
  output.start(command, term_options, configuration.name)
end

local function handle_dependencies(configuration)
  local status_map = {}
  local dependencies_configs = {}

  -- find the dependencies and fill the status map
  for _, dependency in pairs(configuration.depends) do
    local dep = string.gmatch(dependency, '[^.]+')
    local dep_scope = dep()
    local dep_type = dep()
    local dep_group = dep()
    local dep_name = dep()
    if dep_type ~= 'tasks' then
      error('only tasks can be specified as dependencies', 2)
      return
    end
    for _, dependency_config in pairs(M.configurations[dep_scope][dep_type][dep_group]) do
      if dependency_config.name == dep_name then
        dependency_config = utils.deepcopy(dependency_config)
        dependency_config.projector = {
          scope = dep_scope,
          type = dep_type,
          group = dep_group,
        }
        status_map[dep_scope..dep_type..dep_group..dep_name] = false
        table.insert(dependencies_configs, dependency_config)
      end
    end
  end

  -- copy the master config
  local master_config = utils.deepcopy(configuration)
  master_config.depends = nil
  local index = 0

  -- recursevley run the dependencies
  for _, dep_config in pairs(dependencies_configs) do
    index = index + 1
    -- first dependency calls the master task and waits for other dependencies
    if index == 1 then
      -- need to return a function, since the config gets expanded later
      dep_config.on_exit = function()
        return function ()
          status_map[dep_config.projector.scope..dep_config.projector.type..dep_config.projector.group..dep_config.name] = true
          local check_finished = function ()
            for _, d in pairs(status_map) do
              if d == false then
                return false
              end
            end
            return true
          end
          vim.wait(10000, check_finished)
          M.run_task_or_debug(master_config)
        end
      end
    else
      dep_config.on_exit = function()
        return function ()
          status_map[dep_config.projector.scope..dep_config.projector.type..dep_config.projector.group..dep_config.name] = true
        end
      end
    end

    if dep_config.depends ~= '' and dep_config.depends ~= nil then
      local ok = pcall(handle_dependencies, dep_config)
      if not ok then
        print('Could not find one or more dependencies for "' .. dep_config.name .. '"')
        return
      end
    else
      run_task(dep_config)
    end
  end
end

function M.run_task_or_debug(configuration)
  -- handle dependencies
  if configuration.depends ~= '' and configuration.depends ~= nil then
    local ok = pcall(handle_dependencies, configuration)
    if not ok then
      print('Could not find one or more dependencies for "' .. configuration.name .. '"')
    end
    return
  end
  if configuration.projector.type == 'debug' then
    dap.run(configuration)
  elseif configuration.projector.type == 'tasks' then
    run_task(configuration)
  else
    print('Invalid task type')
  end
end

local deprecation_msg_called = false

function M.continue(telescope_filter)
  if not deprecation_msg_called then
    vim.notify('Deprecation notice! nvim-projector has undergone a total rewrite. Switch to "refactor" branch to avoid compatibility issues. Reffer to the projects README for more info!', vim.log.levels.WARN, {title= 'nvim-projector'})
  end
  deprecation_msg_called = true


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
    -- open the only hidden element
    output.open(hidden_outputs[1].bufnr)
    return
  elseif #hidden_outputs == 0 and #active_outputs == 1 then
    -- close the only active element
    output.close(active_outputs[1].bufnr)
    return
  elseif #hidden_outputs > 0 then
    require'telescope'.extensions.projector.active_tasks()
    return
  end

  print('No hidden tasks running')
end


-- Show hidden tasks
-- Meant for statusbar use
function M.status()
  local hidden_outputs = output.list_hidden_outputs()
  local active_outputs = output.list_active_outputs()
  local ho = ''
  if #hidden_outputs > 0 then
    for _, task in pairs(hidden_outputs) do
      if ho == '' then
        ho = 'Hidden: "' .. task.name .. '"'
      else
        ho = ho .. ', "' .. task.name .. '"'
      end
    end
  end
  local ao = ''
  if #active_outputs > 0 then
    for _, task in pairs(active_outputs) do
      if ao == '' then
        ao = 'Active: "' .. task.name .. '"'
      else
        ao = ao .. ', "' .. task.name .. '"'
      end
    end
  end
  if ao ~= '' or ho ~= '' then
    return ao .. ' ' .. ho
  end
  return ''
end


return M
