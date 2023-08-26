---@alias mapping {key: string, mode: string}

---@class Config
---@field dashboard dashboard_config
---@field loaders Loader[]
---@field outputs OutputBuilder[]
---@field core handler_config

local M = {}

local task_output_builder = require("projector.outputs").TaskOutputBuilder:new()

---@type Config
M.default = {
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
    popup = {
      width = 100,
      height = 20,
    },
  },
}

return M
