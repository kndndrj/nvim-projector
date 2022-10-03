---@alias config { loaders: {module: string, path: string}[], outputs: {task:string, debug:string, database:string}}

---@type config
local config = {
  loaders = {
    {
      module = 'legacy.json',
      path = vim.fn.getcwd() .. '/.vim/projector.json',
    },
    {
      module = 'legacy.rc',
      path = '',
    },
    {
      module = 'dap',
      path = '',
    },
  },
  outputs = {
    task = 'builtin',
    debug = 'dap',
    database = 'dadbod',
  },
}

return config
