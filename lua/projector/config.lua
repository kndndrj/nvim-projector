local config = {
  loaders = {
    {
      module = require 'projector.loaders.legacy.json',
      path = vim.fn.getcwd() .. '/.vscode/projector.json',
    },
    {
      module = require 'projector.loaders.legacy.rc',
      path = '',
    },
  },
  outputs = {
    task = require 'projector.outputs.builtin',
    debug = require 'projector.outputs.dap',
    database = "database",
  },
}

return config
