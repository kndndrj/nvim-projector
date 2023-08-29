---@alias mapping {key: string, mode: string}

---@class Config
---@field dashboard dashboard_config
---@field loaders Loader[]
---@field outputs OutputBuilder[]
---@field core handler_config

local M = {}

-- DOCGEN_START
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
        icon_highlight = "Title",
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

return M
