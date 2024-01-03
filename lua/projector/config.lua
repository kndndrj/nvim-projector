local config = {}

---@mod projector.ref.config Projector Configuration

---Configuration object
---@class Config
---@field dashboard dashboard_config
---@field core core_config
---@field loaders Loader[]
---@field outputs OutputBuilder[]

---Keymap input.
---@alias mapping { key: string, mode: string }

---Core options.
---@alias core_config { depencency_mode: task_mode, automatic_reload: boolean }

---Dashboard related options.
---@alias dashboard_config { mappings: table<string, mapping>, disable_candies: boolean, candies: table<string, Candy>, popup: popup_config }

-- DOCGEN_START
local task_output_builder = require("projector.outputs").TaskOutputBuilder:new()

---Default config.
---To see defaults, run :lua= require"projector.config".default
---@type Config
config.default = {
  core = {
    depencency_mode = task_output_builder:mode_name(),
    automatic_reload = false,
  },

  loaders = {
    require("projector.loaders").BuiltinLoader:new {
      path = function()
        return vim.fn.getcwd() .. "/.vim/projector.json"
      end,
    },
    require("projector.loaders").DapLoader:new(),
  },

  outputs = {
    task_output_builder,
    require("projector.outputs").DadbodOutputBuilder:new(),
    require("projector.outputs").DapOutputBuilder:new(),
  },

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
      -- these represent node types
      task_visible = {
        icon = "",
        icon_highlight = "Character",
        text_highlight = "Character",
      },
      task_hidden = {
        icon = "",
        icon_highlight = "Character",
        text_highlight = "",
      },
      task_inactive = {
        icon = "",
        icon_highlight = "MoreMsg",
        text_highlight = "",
      },
      task_group = {
        icon = "󱓼",
        icon_highlight = "MoreMsg",
        text_highlight = "",
      },
      action = {
        icon = "󰣪",
        icon_highlight = "Character",
        text_highlight = "",
      },
      loader = {
        icon = "󰃖",
        icon_highlight = "Title",
        text_highlight = "",
      },
      mode = {
        icon = "",
        icon_highlight = "Title",
        text_highlight = "",
      },
      group = {
        icon = "",
        icon_highlight = "",
        text_highlight = "",
      },

      -- these are special
      comment = {
        icon = "",
        icon_highlight = "NonText",
        text_highlight = "NonText",
      },
      none = {
        icon = "",
        icon_highlight = "",
        text_highlight = "",
      },
      can_expand = {
        icon = "o",
        icon_highlight = "String",
        text_highlight = "String",
      },
    },
    popup = {
      width = 100,
      height = 20,
    },
  },
}
-- DOCGEN_END

return config
