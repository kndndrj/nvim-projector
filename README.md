<img src="assets/logo.svg" alt="Projector logo" title="Projector" align="right" height="200"/>

<!-- Any html tags, badges etc. go before this tag. -->

**Attention**: refactor in progress on `v3` branch. I'll tag a commit before I merge. Thanks.

<!--docgen-start-->

# Neovim Projector

Basic, yet extensible code-runner/project-configurator.

- **Run and manage tasks (shell commands) in nvim's integrated terminal!**
- **Integrates with nvim-dap!**
- **Configure vim-dadbod per-project**

![Showcase](./assets/showcase.gif)

## What exactly is it?

It's basically an easily-expandable code runner that supports all sorts of
different configuration files, like:

- VsCode's tasks.json
- VsCode's launch.json
- NPM's package.json *WIP*
- idea's workspace.xml *WIP*

It then detects "modes" for each of those tasks and determines if they can be
ran as:

- task
- debug
- database

So called "loaders" (that load configuration) and "outputs" are fully modular.
If you, for example don't wan't to use dap-ui for debugging, you can make an
extension with your own preferences!

Overview:

```
    LOADERS                                         OUTPUTS

┌──────────────┐                                ┌──────────────┐
│              │                                │              │
│ tasks.json   ├───┐                        ┌───► task         │
│              │   │                        │   │              │
└──────────────┘   │     ┌─────────────┐    │   └──────────────┘
                   │     │             │    │
┌──────────────┐   │     │             │    │   ┌──────────────┐
│              │   │     │             │    │   │              │
│ launch.json  ├───┼─────►  Projector  ─────┼──►│ debug        │
│              │   │     │             │    │   │              │
└──────────────┘   │     │             │    │   └──────────────┘
                   │     │             │    │
┌──────────────┐   │     └─────────────┘    │   ┌──────────────┐
│              │   │                        │   │              │
│ package.json ├───┤                        ├───► database     │
│              │   │                        │   │              │
└──────────────┘   │                        │   └──────────────┘
                   │                        │
                   │                        │
            ... ───┘                        └───►...
```

## Installation

Install this plugin with the plugin manager of your choice. Example with
packer.nvim:

```lua
use {
  'kndndrj/nvim-projector',
  requires = {
    -- Install the ones you want (I recommend all)
    'mfussenegger/nvim-dap',
    'rcarriga/nvim-dap-ui',
    'tpope/vim-dadbod',
    'kristijanhusak/vim-dadbod-ui',
    -- Devicons are also supported:
    'kyazdani42/nvim-web-devicons',
    -- Any extra extensions that you want:
    'kndndrj/projector-loader-vscode',
  },
}
```

TIP: for eye candy and telescope picker, use something like dressing.nvim!

## Getting started

1. Put the setup function in your `init.lua`.

   ```lua
   require 'projector'.setup()
   ```

2. Replace dap's continue with ours.

   ```lua
   -- replace
   vim.keymap.set('n', '<leader>s', '<Cmd>lua require"dap".continue()<CR>', { noremap = true, silent = true })
   -- with
   vim.keymap.set('n', '<leader>s', '<Cmd>lua require"projector".continue()<CR>', { noremap = true, silent = true })
   ```

3. You can probably also remove any dap-ui specific keybindings if you have any.

4. Then map these functions to any keys you like:

   ```lua
   require"projector".continue()
   require"projector".toggle()
   require"projector".next()
   require"projector".previous()
   require"projector".restart()
   require"projector".kill()
   ```

## Setup

The setup function takes an optional table parameter. Here are the defaults:

```lua
local config = {
  -- array of loader names with parameters
  -- for available loaders and their options see "Loaders" section in README.md
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
  -- map of outputs per mode
  -- for available outputs and their options see "Outputs" section in README.md
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
  -- function that formats the task selector output
  display_format = function(loader, scope, group, modes, name)
    return loader .. "  " .. scope .. "  " .. group .. "  " .. modes .. "  " .. name
  end,
  -- Reload configurations automatically before displaying task selector
  automatic_reload = false,
  -- map of icons
  -- NOTE: "groups" use nvim-web-devicons if available
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
```

### Configuration Object

This is a configuration for a task that projector can read.

A task can have all of these fields or just a few filled out. What can the task
do is determined automatically.

```lua
{
  -- common:
  name = "Task", -- task's name
  scope = "global", -- usually project or global
  group = "go", --  language group (use vim filetype names for best icon experience)
  presentation = { "menuhidden" }, -- various presentation options (only "menuhidden" supported for now)
  dependencies = { "project.go.Run", "global.go.Generate" }, -- list of task id's to run before this one
  after = "global.sh.After Task", -- task id to run after this one is finished
  env = { a = "b" }, -- map of environment variables
  cwd =  "$HOME", -- current working directory
  args = { "--arg1", "--arg2" }, -- list of task's arguments
  pattern = "vim regex", -- regex pattern to decide if a background task has finished (entered running state)
                         -- task with this field is considered a long running task.
                         -- If this task is specified as a dependency somewhere, it's considered as finished when this matches.
  -- task specific:
  command = "go run ${workspaceDirectory}/main.go", -- command to run in task mode
  -- debug specific:
  type = "delve", -- type of debug adapter
  request = "launch",
  program = "${workspaceDirectory}/main.go",
  port = "9876",
  -- + extra dap-specific parameters (see: https://github.com/mfussenegger/nvim-dap)
  -- database specific:
  databases = { -- list of databases
    {
      name = "My-DB",
      url = "postgres://postgres:mypassword@localhost:5432/my-db",
    },
    {
      -- ...
    },
  },
  queries = { -- list of queries per database type (see: dadbod-ui table helpers)
    postgresql = {
      List = "select * from {table} order by id asc",
      Count = "select count(*) from {table}"
    },
  }
}
```

## Loaders and Outputs

If you are interested in writing your own extension (either a loader or an
output), read [EXTENSIONS.md](./EXTENSIONS.md)

### Loaders

Loaders are simple modules that translate a config file into task objects that
projector understands.

(add to this list if you write your own)

Available loaders:

- Builtin Loader (*builtin*) Loads tasks from default configs. (useful for
  specifying tasks in init.lua)

  - module: `builtin`
  - options:
    - `path` - *string*: path to a projector.json file -
      [example](./examples/projector.json)
    - `configs` - *function*|*table*: a function that returns a list of
      [default config objects](#configuration-object) OR a list of
      [default config objects](#configuration-object).
  - variable expansion: VsCode like variables (e.g. `${file}`)

- DAP Loader (*builtin*) Loads tasks from nvim-dap's configurations.

  - module: `dap`
  - options: `nil`
  - variable expansion: VsCode like variables (e.g. `${file}`)

- tasks.json Loader (*kndndrj/projector-loader-vscode*)

  - module: `tasksjson`
  - options:
    - `path` - *string*: path to `tasks.json` - default: `./.vscode/tasks.json`
  - variable expansion: VsCode like variables (e.g. `${file}`)

- launch.json Loader (*kndndrj/projector-loader-vscode*)

  - module: `launchjson`
  - options:
    - `path` - *string*: path to `launch.json` - default:
      `./.vscode/launch.json`
  - variable expansion: VsCode like variables (e.g. `${file}`)

- Idea Loader (*kndndrj/projector-loader-idea*)

  - module: `idea`
  - options:
    - `path` - *string*: path to `workspace.xml` - default:
      `./.idea/workspace.xml`
  - variable expansion: Idea's variables (e.g. `$PROJECT_DIR$`)
  - requirements:
    - `xml2lua` (luarocks)

### Outputs

Outputs are modules that recieve a configuration object and run it's commands.
They show the output on screen.

(add to this list if you write your own)

Available outputs:

- Builtin output (*builtin*) Default task output (in the integrated terminal)

  - module: `builtin`
  - options: `nil`
  - capabilities: `task`

- DAP output (*builtin*) Default debug output with dap-ui support

  - module: `dap`
  - options: `nil`
  - capabilities: `debug`

- Dadbod output (*builtin*) Default database output with dadbod-ui support

  - module: `dadbod`
  - options: `nil`
  - capabilities: `database`

## Issues

If you encounter any issues, don't hesitate to open a github issue! A list of
already known issues can be found in [KNOWN_ISSUES.md](./KNOWN_ISSUES.md), and
what's planned for the near future can be read in [TODO.md](./TODO.md).
