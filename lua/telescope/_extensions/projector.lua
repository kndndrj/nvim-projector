local telescope = require('telescope')
local actions = require('telescope.actions')
local actionstate = require('telescope.actions.state')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local themes = require('telescope.themes')
local projector = require'projector'
local config_utils = require'projector.config_utils'
local dap = require'dap'


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

local function select_config(opts, filters)
  opts = themes.get_dropdown(opts)

  pickers.new(opts, {
    prompt_title = 'Tasks',
    finder = finders.new_table {
      results = vim.tbl_values(config_utils.list_configurations(filters)),
      entry_maker = function(entry)
        local display = icon_map[entry.projector.scope] .. ' ' ..
                        icon_map[entry.projector.type] .. ' ' ..
                        string.upper(entry.projector.group) .. '\t'..
                        entry.name
        return {
          value = entry,
          display = display,
          ordinal = display,
        }
      end,
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      local source_session = function()
        actions.close(prompt_bufnr)
        local entry = actionstate.get_selected_entry(prompt_bufnr)
        if entry then
          projector.run_task_or_debug(entry.value)
        end
      end

      actions.select_default:replace(source_session)
      return true
    end,
  }):find()
end


----------------------------------------
-- PICKER: -----------------------------
-- Show choices in the active session --
----------------------------------------
local choices = {
  {
    label = "Run another task",
    action = function ()
      select_config({}, {project = true, global = true, tasks = true})
    end
  },
  {
    label = "Close session (Debug adapter might keep running)",
    action = dap.close
  },
  {
    label = "Pause a thread",
    action = dap.pause
  },
  {
    label = "Restart session",
    action = dap.restart,
  },
  {
    label = "Disconnect (terminate = true)",
    action = function()
      dap.disconnect({ terminateDebuggee = true })
    end
  },
  {
    label = "Disconnect (terminate = false)",
    action = function()
      dap.disconnect({ terminateDebuggee = false })
    end,
  },
}

local function active_session(opts)
  opts = themes.get_dropdown(opts)

  pickers.new(opts, {
    prompt_title = 'Debug Actions',
    finder = finders.new_table {
      results = vim.tbl_values(choices),
      entry_maker = function(entry)
        local display = entry.label
        return {
          value = entry.action,
          display = display,
          ordinal = display,
        }
      end,
    },
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr)
      local source_session = function()
        actions.close(prompt_bufnr)
        local entry = actionstate.get_selected_entry(prompt_bufnr)
        if entry then
          entry.value()
        end
      end

      actions.select_default:replace(source_session)
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
      select_config(opts, {})
    end,
    project = function(opts)
      select_config(opts, {project = true, debug = true, tasks = true})
    end,
    global = function(opts)
      select_config(opts, {global = true, debug = true, tasks = true})
    end,
    debug = function(opts)
      select_config(opts, {project = true, global = true, debug = true})
    end,
    tasks = function(opts)
      select_config(opts, {project = true, global = true, tasks = true})
    end,
    filetype = function(opts)
      select_config(opts, {project = true, global = true, debug = true, tasks = true, group = {vim.api.nvim_buf_get_option(0, 'filetype')}})
    end,

    active_session = function(opts)
      active_session(opts)
    end,
  },
})
