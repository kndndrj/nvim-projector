---@alias extension_config { module: string, options: any}

---@class config
---@field loaders extension_config[]
---@field outputs { task: extension_config, debug: extension_config, database: extension_config }
---@field display_format fun(loader:string, scope:string, group:string, modes:string, name:string): string Function for fromating select menu
---@field icons { enable: boolean, scopes: { [string]: string }, groups: { [string]: string }, loaders: { [string]: string } , modes: { [string]: string } }
---@field automatic_reload boolean Reload configurations automatically before displaying task selector

---@type config
local config = {
  loaders = {
    {
      module = "builtin",
      options = {
        path = vim.fn.getcwd() .. "/.vim/projector.json",
        configs = nil,
      },
    },
    {
      module = "dap",
      options = nil,
    },
  },
  outputs = {
    task = {
      module = "builtin",
      options = nil,
    },
    debug = {
      module = "dap",
      options = nil,
    },
    database = {
      module = "dadbod",
      options = nil,
    },
  },
  display_format = function(loader, scope, group, modes, name)
    return loader .. "  " .. scope .. "  " .. group .. "  " .. modes .. "  " .. name
  end,
  automatic_reload = false,
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
      database = "",
    },
  },
}

return config
