local config = {
  loaders = {
    {
      module = require 'projector.loaders.legacy',
      path = "/home/andrej/Repos/nvim-projector/examples/projector.json",
    }
  },
  outputs = {
    task = require 'projector.outputs.builtin',
    debug = require 'projector.outputs.dap',
    database = "database",
  },
}

return config
