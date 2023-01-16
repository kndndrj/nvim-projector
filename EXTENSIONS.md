<!-- Any html tags, badges etc. go before this tag. -->

<!--docgen-start-->

# Projector's Extensions

Projector is designed in a way that writing extensions should be extremly easy.
You can write extensions for loaders and/or outputs. If you decide to write any
extensions, please document them in README.md

## Custom Loader

If you find that projector doesn't support the task file (whatever you may call
tasks.json and stuff like that), write the loader as an extension for the
projector. To do that, first create the same directory structure that projector
uses:

```sh
mkdir -p lua/projector/loaders/<unique-name-of-your-loader>.lua
```

NOTE: To see the loader contract, look into
[this file](./lua/projector/contract/loader.lua).

In that file, you need to implement a few methods that the loader "interface"
requires. Here is a commented example:

```lua
-- Get Task object and a Loader interface
local Task = require 'projector.task'
local Loader = require 'projector.contract.loader'

-- Create a new loader
---@type Loader
local MyLoader = Loader:new()

-- Implement a "load" method
-- Use anything you like as user_opts, but make sure to specify them in the documentation.
-- I suggest, you use a table with parameters (see below).
-- Access those options with self.user_opts (these are the options specifed by the end user in setup())

-- return type should always be a list of Task objects or nil if nothing is loaded
---@return Task[]|nil
function MyLoader:load()
  -- access opts with:
  ---@type { path: string }
  local opts = self.user_opts

  local path = opts.path or (vim.fn.getcwd() .. '/.myformat.xml')

  local data = load_xml_file_into_lua_table()

  -- List to return
  ---@type Task[]
  local tasks = {}

  -- Fill the list
  for _, config in pairs(data) do
    -- Every task needs these 2 metadata fields...
    local task_opts = {
      scope = "project", --or "global" -  usualy "project" means local to project (e.g. from project config file)
                                       -- and "global" means that it's available from anywhere (just pick one if you aren't sure)
      group = config.language, -- try to use vim's filetype names here. For example: sh, python, go...
    }
    -- ... and a config object. Translate the names from your format to projector's. Example:
    local c = {
      command = config.cmd,
      args = config.arguments,
      -- let's say that other names are identical...
    }
    -- Create a task...
    local task = Task:new(c, task_opts)
    -- ... and insert it to the list
    table.insert(tasks, task)
  end

  -- Finally, return the list
  return tasks
end

-- Implement a "load" method
-- It takes a single "configuration" argument and returns the same back.
-- The purpose of this method is to expand fields like:
--   command = "${workspaceFolder}/run.sh"    to   command = "/home/user/project/run.sh"
---@param configuration Configuration
---@return Configuration
function MyLoader:expand_variables(configuration)
  -- Our file doesn't support variable substitution, so we just return the same object back.
  return configuration
end

-- Return the loader from the file
return MyLoader
```

After that, your loader can be registered to projector via it's `setup()`
function:

```lua
require 'projector'.setup {
  loaders = {
    {
      module = '<unique-name-of-your-loader>', -- name of your file in lua require syntax
      options = { -- argument to your "load" method
        path = vim.fn.getcwd() .. '/.misc/tasks.xml',
      },
    },
  },
  -- ...
}
```

**In short**:

1. Create a new loader.
2. Implement these methods:
   ```lua
   function Loader:load() end
   function Loader:expand_variables(configuration) end
   ```

## Custom Output

If you find that projector is lacking some functionality for tasks, you can
create your own output (runner). First create a new file:

```sh
mkdir -p lua/projector/outputs/<unique-name-of-your-output>.lua
```

NOTE: To see the output contract, look into
[this file](./lua/projector/contract/output.lua).

In that file, you need to implement a few methods that the output "interface"
requires. Here is a commented example:

```lua
-- Get the Output interface
local Output = require 'projector.contract.output'

-- Create a new output
---@type Output
local MyOutput = Output:new()

-- You can use specific options, but make sure to specify them in the documentation.
-- I suggest, you use a table with parameters, like:
-- { height: string } window height
-- Access those options with self.user_opts (these are the options specifed by the end user in setup())

-- Init method gets task's configuration and runs it
-- For available fields, see the configuration object specification in README.md
---@param configuration Configuration
---@diagnostic disable-next-line: unused-local
function MyOutput:init(configuration)
  self.user_opts.height = tostring(self.user_opts.height) or "15"

  local term_options = {
    env = configuration.env,
    on_exit = function(_, code)
      local ok = true
      if code ~= 0 then ok = false end
      -- You MUST trigger this method once the task finishes!!
      -- on success: ok = true, on failure: ok = false
      self:done(ok)
    end,
  }

  -- Start the output
  vim.api.nvim_command('bo ' .. self.user_opts.height .. 'new')
  vim.fn.termopen(configuration.command, term_options)

  -- You can use "meta" field to store any private info you need
  self.meta.bufnr = vim.fn.bufnr()
  self.meta.winid = vim.fn.win_getid()

  -- Set status to visible if the output is shown on the screen
  self.status = "visible"
end

function MyOutput:show()
  -- show the output on screen if it isn't visible
  -- For example: open a new window and open the buffer in it
  vim.api.nvim_command(self.user_opts.height .. 'split')
  self.meta.winid = vim.fn.win_getid()
  vim.api.nvim_command('b ' .. self.meta.bufnr)

  self.status = "visible"
end

function MyOutput:hide()
  -- Hide the output from the screen
  -- For example: close the window, but keep the buffer
  vim.api.nvim_win_close(self.meta.winid, true)
  self.meta.winid = nil

  self.status = "hidden"
end

function MyOutput:kill()
  -- Stop the task from executing
  -- For example: delete the window and buffer
  vim.api.nvim_win_close(self.meta.winid, true)
  vim.api.nvim_buf_delete(self.meta.bufnr, { force = true })

  self.status = "inactive"
end

-- This method returns a list of actions that can be performed when the task is live
---@return Action[]|nil
function MyOutput:list_actions()
  return {
    {
      label = "Say Something", -- Display name
      action = function() vim.cmd('echo "Something"')  end -- command to run - must be an anonymous function
      nested = { -- list of nested actions (to be displayed as a submenu)... if action is specified, this has no effect
        {
          label = "Say Nothing",
          action = function() vim.cmd('echo "Nothing"')  end
        },
        -- ...
      },
      override = false, -- optional parameter to run the task without the output even appearing
                        -- use this only on certain conditions, otherwise the task selector won't ever appear
                        -- Can only apply to action field!
    },
  }
end

-- Return the output from the file
return MyOutput
```

After that, your output can be registered to projector via it's `setup()`
function:

```lua
require 'projector'.setup {
  outputs = {
    task = {
      module = '<unique-name-of-your-loader>', -- name of your file in lua require syntax
      options = {}, -- what's supplied to self.user_opts
    },
    -- or debug = ...
    -- or database = ...
  },
  -- ...
}
```

**In short**:

1. Implement these methods:
   ```lua
   function Output:init(configuration) end
   function Output:show() end
   function Output:hide() end
   function Output:kill() end
   function Output:list_actions() end
   ```
2. Call `self:done(true|false)` once the command finishes.
3. Set `self.status` according to the task. supported values are: `"visible"`,
   `"hidden"`, `"inactive"`
4. You only need to care about simple configuration options. For example
   dependencies and post tasks are handled by projector. It's only important
   that you trigger `self:done()` when needed!
