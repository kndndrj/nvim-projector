local telescope = require 'telescope'
local actions = require 'telescope.actions'
local actionstate = require 'telescope.actions.state'
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local sorters = require 'telescope.sorters'
local themes = require 'telescope.themes'
local entry_display = require 'telescope.pickers.entry_display'
local projector = require 'projector'
local config_utils = require 'projector.config_utils'
local output = require 'projector.output'
local dap = require 'dap'


----------------------------------------
-- PICKER: -----------------------------
-- Select task to run ------------------
----------------------------------------
local icon_map = {
  debug = '',
  tasks = ' ',
  project = ' ',
  global = '',
}

local function select_config(opts, filters, sort)
  opts = themes.get_dropdown(opts)

  pickers.new(opts, {
    prompt_title = 'Tasks',
    finder = finders.new_table {
      results = vim.tbl_values(config_utils.list_configurations(filters, sort)),
      entry_maker = function(entry)
        local ordinal = entry.projector.scope ..
                        entry.projector.type ..
                        entry.projector.group ..
                        entry.name
        local displayer = entry_display.create {
          separator = '  ',
          items = {
            { width = 1 },
            { width = 1 },
            { width = 8 },
            { width = 20 },
            { width = 38 },
            { remaining = true },
          },
        }
        local make_display = function(tbl)
          local v = tbl.value
          return displayer {
            icon_map[v.projector.scope],
            { icon_map[v.projector.type], 'TelescopeResultsConstant' },
            string.upper(v.projector.group),
            v.name,
            { v.command or '', 'TelescopeResultsComment' },
          }
        end
        return {
          value = entry,
          display = make_display,
          ordinal = ordinal,
        }
      end,
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = actionstate.get_selected_entry(prompt_bufnr)
        if selection then
          projector.run_task_or_debug(selection.value)
        end
      end)
      return true
    end,
  }):find()
end


----------------------------------------
-- PICKER: -----------------------------
-- Show choices in the active debug ----
-- session -----------------------------
----------------------------------------
local choices = {
  {
    label = 'Run a task',
    action = function ()
      select_config({}, {project = true, global = true, tasks = true})
    end
  },
  {
    label = 'Close session',
    comment = 'debug adapter might keep running',
    action = dap.close
  },
  {
    label = 'Pause a thread',
    action = dap.pause
  },
  {
    label = 'Restart session',
    action = dap.restart,
  },
  {
    label = 'Disconnect',
    comment = 'terminate = true',
    action = function()
      dap.disconnect({ terminateDebuggee = true })
    end
  },
  {
    label = 'Disconnect',
    comment = 'terminate = false',
    action = function()
      dap.disconnect({ terminateDebuggee = false })
    end,
  },
}

local function active_debug_sessions(opts)
  opts = themes.get_dropdown(opts)

  pickers.new(opts, {
    prompt_title = 'Debug Actions',
    finder = finders.new_table {
      results = choices,
      entry_maker = function(entry)
        local ordinal = entry.label .. (entry.comment or '')
        local displayer = entry_display.create {
          separator = ' ',
          items = {
            { width = 20 },
            { width = 48 },
            { remaining = true },
          },
        }
        local make_display = function(tbl)
          local v = tbl.value
          return displayer {
            v.label,
            { v.comment or '', 'TelescopeResultsComment' },
          }
        end
        return {
          value = entry,
          display = make_display,
          ordinal = ordinal,
        }
      end,
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = actionstate.get_selected_entry(prompt_bufnr)
        if selection then
          selection.value.action()
        end
      end)
      return true
    end,
  }):find()
end


----------------------------------------
-- PICKER: -----------------------------
-- Show current running tasks ----------
----------------------------------------
local function background_tasks_sessions(opts)
  opts = themes.get_dropdown(opts)

  pickers.new(opts, {
    prompt_title = 'Background Tasks',
    finder = finders.new_table {
      results = vim.tbl_values(output.list_hidden_outputs()),
      entry_maker = function(entry)
        local ordinal = entry.name .. entry.bufnr
        local displayer = entry_display.create {
          separator = ' ',
          items = {
            { width = 20 },
            { width = 48 },
            { remaining = true },
          },
        }
        local make_display = function(tbl)
          local v = tbl.value
          return displayer {
            v.name,
            { v.bufnr, 'TelescopeResultsComment' },
          }
        end
        return {
          value = entry,
          display = make_display,
          ordinal = ordinal,
        }
      end,
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = actionstate.get_selected_entry(prompt_bufnr)
        if selection then
          output.open(selection.value.bufnr)
        end
      end)
      return true
    end,
  }):find()
end


----------------------------------------
-- Register extensions -----------------
----------------------------------------
return telescope.register_extension({
  exports = {
    all = function(opts)
      select_config(opts, {}, {key = "scope", order = false})
    end,
    project = function(opts)
      select_config(opts, {project = true, debug = true, tasks = true}, {key = "scope", order = false})
    end,
    global = function(opts)
      select_config(opts, {global = true, debug = true, tasks = true}, {key = "scope", order = false})
    end,
    debug = function(opts)
      select_config(opts, {project = true, global = true, debug = true}, {key = "scope", order = false})
    end,
    tasks = function(opts)
      select_config(opts, {project = true, global = true, tasks = true}, {key = "scope", order = false})
    end,
    filetype = function(opts)
      select_config(opts, {project = true, global = true, debug = true, tasks = true, group = {vim.api.nvim_buf_get_option(0, 'filetype')}}, {key = "scope", order = false})
    end,

    active_debug = function(opts)
      active_debug_sessions(opts)
    end,

    active_tasks = function(opts)
      background_tasks_sessions(opts)
    end,
  },
})
