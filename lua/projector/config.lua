---@class config
---@field loaders { module: string, opt: any}[]
---@field outputs { task: string, debug: string, database: string }
---@field display_format fun(loader:string, scope:string, group:string, modes:string, name:string): string Function for fromating select menu
---@field icons { enable: boolean, scopes: { [string]: string }, groups: { [string]: string }, loaders: { [string]: string } , modes: { [string]: string } }


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
  display_format = function(loader, scope, group, modes, name)
    return loader .. "  " .. scope .. "  " .. group .. "  " .. modes .. "  " .. name
  end,
  icons = {
    enable = true,
    scopes = {
      global = "",
      project = "",
    },
    groups = {},
    loaders = {},
    modes = {
      task = "",
      debug = "",
      database = ""
    },
  },
}

return config
