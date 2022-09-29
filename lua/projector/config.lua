local config = {
  loaders = {
    {
      module = require 'projector.loaders.legacy',
      path = vim.fn.getcwd() .. '/.vscode/projector.json',
    }
  },
  outputs = {
    task = require 'projector.outputs.builtin',
    debug = require 'projector.outputs.dap',
    database = "database",
  },
}

return config
