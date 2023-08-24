---@alias mapping {key: string, mode: string}

---@class Config
---@field dashboard dashboard_config
---@field loaders extension_config[]
---@field outputs { task: extension_config, debug: extension_config, database: extension_config }
--
---@field display_format fun(loader:string, scope:string, group:string, modes:string, name:string): string Function for fromating select menu
---@field icons { enable: boolean, scopes: table<string, string>, groups: table<string, string>, loaders: table<string, string> , modes: table<string, string> }
---@field automatic_reload boolean Reload configurations automatically before displaying task selector

---@type Config
local config = {
  -- dashboard (popup) settings
  dashboard = {
    -- key mappings
    mappings = {
      action_1 = {
        key = "<CR>",
        mode = "n",
      },
      action_2 = {
        key = "r",
        mode = "n",
      },
      action_3 = {
        key = "d",
        mode = "n",
      },
      toggle_fold = {
        key = "o",
        mode = "n",
      },
    },
    -- eye candy settings:
    disable_candies = false,
    candies = {
      --"task_visible"|"task_inactive"|"task_hidden"|"action"|"loader"|"mode"|""
      -- these represent node types
      task_visible = {
        icon = "",
        icon_highlight = "String",
        text_highlight = "String",
      },
      task_inactive = {
        icon = "󰏫",
        icon_highlight = "Directory",
        text_highlight = "Directory",
      },
      task_hidden = {
        icon = "󰆴",
        icon_highlight = "SpellBad",
        text_highlight = "SpellBad",
      },
      action = {
        icon = "󰋖",
        icon_highlight = "Title",
        text_highlight = "Title",
      },
      loader = {
        icon = "󰃖",
        icon_highlight = "MoreMsg",
        text_highlight = "MoreMsg",
      },
      mode = {
        icon = "󰋖",
        icon_highlight = "Title",
        text_highlight = "Title",
      },

      -- these are special
      comment = {
        icon = "󰃖",
        icon_highlight = "",
        text_highlight = "MoreMsg",
      },
      none = {
        icon = "",
        icon_highlight = "",
        text_highlight = "MoreMsg",
      },
    },
  },
  loaders = {
    -- {
    --   module = "builtin",
    --   options = {
    --     path = vim.fn.getcwd() .. "/.vim/projector.json",
    --     configs = nil,
    --   },
    -- },
    -- {
    --   module = "dap",
    --   options = nil,
    -- },
  },
  outputs = {
    task = {
      module = require("projector.loaders.builtin"),
      options = nil,
    },
    -- debug = {
    --   module = "dap",
    --   options = nil,
    -- },
    -- database = {
    --   module = "dadbod",
    --   options = nil,
    -- },
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
      debug = "󰃤",
      database = "",
    },
  },
}

return config
