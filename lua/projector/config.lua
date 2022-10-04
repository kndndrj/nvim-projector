---@alias config { loaders: {module: string, opt: any}[], outputs: {task:string, debug:string, database:string}}

---@type config
local config = {
  loaders = {
    {
      module = 'legacy.json',
      opt = vim.fn.getcwd() .. '/.vim/projector.json',
    },
    {
      module = 'legacy.rc',
      opt = '',
    },
    {
      module = 'dap',
      opt = '',
    },
  },
  outputs = {
    task = 'builtin',
    debug = 'dap',
    database = 'dadbod',
  },
}

return config
