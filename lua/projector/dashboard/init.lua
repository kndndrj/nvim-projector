local utils = require("projector.utils")
local Popup = require("projector.dashboard.popup")
local convert = require("projector.dashboard.convert")

local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")

---@class Candy
---@field icon string
---@field icon_highlight string
---@field text_highlight string

---@class Node
---@field id string
---@field name string
---@field type "task_visible"|"task_inactive"|"task_hidden"|"task_group"|"action"|"loader"|"mode"|"group"|""
---@field comment? string
-- action functions:
---@field action_1? fun(close: fun()) action to perform - single parameter is a function which closes the popup
---@field action_2? fun(close: fun()) action to perform - single parameter is a function which closes the popup
---@field action_3? fun(close: fun()) action to perform - single parameter is a function which closes the popup
-- other:
---@field is_empty? boolean
---@field preview? fun(max_lines: integer):string[]

---@class Dashboard
---@field private left_tree? table NuiTree
---@field private right_tree? table NuiTree
---@field private popup Popup
---@field private handler Handler
---@field private mappings table<string, mapping>
---@field private candies table<string, Candy>
local Dashboard = {}

---@param handler Handler
---@param opts? dashboard_config
---@return Dashboard
function Dashboard:new(handler, opts)
  opts = opts or {}

  if not handler then
    error("no handler passed to Dashboard")
  end

  local candies = {}
  if not opts.disable_candies then
    candies = opts.candies or {}
  end

  local o = {
    handler = handler,
    popup = Popup:new("Tasks:", "Active:", "Preview", opts.popup),
    mappings = opts.mappings or {},
    candies = candies,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@private
---@param bufnr integer buffer to set the nodes to
---@return table tree
function Dashboard:create_tree(bufnr)
  local tree = NuiTree {
    bufnr = bufnr,
    prepare_node = function(node)
      local line = NuiLine()

      -- indent
      line:append(string.rep("  ", node:get_depth() - 1))

      -- icon
      ---@type Candy
      local candy = self.candies[node.type] or {}
      if not node.type or node.type == "" then
        candy = self.candies["none"] or {}
      end
      if candy.icon and candy.icon ~= "" then
        line:append(candy.icon .. "  ", candy.icon_highlight)
      else
        line:append("   ")
      end

      -- name
      line:append(node.name, candy.text_highlight)

      -- special icon if node can expand
      if node:has_children() and not node:is_expanded() then
        candy = self.candies["can_expand"] or {}
        if not candy.icon or candy.icon == "" then
          candy.icon = "o"
        end
        line:append(" " .. candy.icon, candy.icon_highlight)
      end

      -- comment
      if node.comment then
        candy = self.candies["comment"] or {}
        line:append("  " .. node.comment, candy.text_highlight)
      end

      return line
    end,
    get_node_id = function(node)
      if node.id then
        return node.id
      end
      return tostring(math.random())
    end,
  }
  return tree
end

---@private
---@param tree table NuiTree
---@param bufnr integer
function Dashboard:map_keys(tree, bufnr)
  local close = function()
    self.popup:close()
  end

  -- action_1
  local m = self.mappings.action_1 or { key = "<CR>", mode = "n" }
  vim.keymap.set(m.mode, m.key, function()
    local node = tree:get_node()
    if not node then
      return
    end
    if type(node.action_1) == "function" then
      node.action_1(close)
      return
    end

    if node:has_children() then
      if node:expand() then
        tree:render()
      end
    end
  end, { silent = true, buffer = bufnr })

  -- action_2
  m = self.mappings.action_2 or { key = "r", mode = "n" }
  vim.keymap.set(m.mode, m.key, function()
    local node = tree:get_node()
    if not node then
      return
    end
    if type(node.action_2) == "function" then
      node.action_2(close)
    end
  end, { silent = true, buffer = bufnr })

  -- action_3
  m = self.mappings.action_3 or { key = "d", mode = "n" }
  vim.keymap.set(m.mode, m.key, function()
    local node = tree:get_node()
    if not node then
      return
    end
    if type(node.action_3) == "function" then
      node.action_3(close)
    end
  end, { silent = true, buffer = bufnr })

  -- toggle fold
  m = self.mappings.toggle_fold or { key = "o", mode = "n" }
  vim.keymap.set(m.mode, m.key, function()
    local node = tree:get_node()
    if not node then
      return
    end
    local toggled
    if node:is_expanded() then
      toggled = node:collapse()
    else
      toggled = node:expand()
    end

    if toggled then
      tree:render()
    end
  end, { silent = true, buffer = bufnr })
end

---@private
---@param tree table NuiTree
---@param bufnr integer
---@param preview_bufnr integer
function Dashboard:configure_autocmds(tree, bufnr, preview_bufnr)
  local previous_row = 0

  local function move_cursor()
    local node = tree:get_node()
    if not node or not node.is_empty then
      return
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    if row > previous_row then
      -- moving down
      row = row + 1
    elseif row < previous_row then
      -- moving up
      row = row - 1
    end

    if row < 1 or row > vim.fn.line("$") then
      row = 1
    end

    vim.api.nvim_win_set_cursor(0, { row, col })

    move_cursor()

    previous_row = vim.api.nvim_win_get_cursor(0)[1]
  end

  -- Cursor skips empty nodes
  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    buffer = bufnr,
    callback = function()
      pcall(move_cursor)
    end,
  })

  -- update preview on move
  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    buffer = bufnr,
    callback = function()
      self:update_preview(preview_bufnr)
    end,
  })
end

-- updates preview window with the currently selected node's preview
---@private
---@param bufnr integer preview buffer
function Dashboard:update_preview(bufnr)
  ---@param max_lines integer
  ---@return string[]?
  local function get_preview(max_lines)
    local focus = self.popup:get_focus()
    local tree
    if focus == "left" then
      tree = self.left_tree
    elseif focus == "right" then
      tree = self.right_tree
    end
    if not tree then
      return
    end
    local node = tree:get_node()
    if not node or type(node.preview) ~= "function" then
      return
    end

    return node.preview(max_lines)
  end

  -- get max lines of the preview window
  local _, height = self.popup:dimensions()
  local max_lines = math.floor(height / 2)

  local preview = get_preview(max_lines) or {}

  -- display first n records of the preview
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { unpack(preview, 1, max_lines) })
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
end

---@private
---@param bufnr integer
---@return fun() # timer cancel function
function Dashboard:configure_autopreview(bufnr)
  local update = function()
    self:update_preview(bufnr)
  end

  -- first time call manually
  update()

  -- setup timer for recurring calls
  local timer = vim.fn.timer_start(300, update, { ["repeat"] = -1 })
  return function()
    vim.fn.timer_stop(timer)
  end
end

---@private
---@return fun() # timer cancel function
function Dashboard:configure_autorefresh()
  local refresh = function()
    self:refresh()
  end

  -- setup timer for recurring calls
  local timer = vim.fn.timer_start(500, refresh, { ["repeat"] = -1 })
  return function()
    vim.fn.timer_stop(timer)
  end
end

-- applies the expansion on new nodes
---@param tree table tree to apply the expansion map to
---@param expansion table<string, boolean> expansion map
local function set_expansion(tree, expansion)
  for id, t in pairs(expansion) do
    if t then
      local node = tree:get_node(id)
      if node then
        node:expand()
      end
    end
  end
end

-- gets an expansion config to restore the expansion on new nodes
---@param tree table
---@return table<string, boolean>
local function get_expansion(tree)
  ---@type table<string, boolean>
  local nodes = {}

  local function process(node)
    if node:is_expanded() then
      nodes[node:get_id()] = true
    end

    if node:has_children() then
      for _, n in ipairs(tree:get_nodes(node:get_id())) do
        process(n)
      end
    end
  end

  for _, node in ipairs(tree:get_nodes()) do
    process(node)
  end

  return nodes
end

-- Show dashboard on screen
function Dashboard:refresh()
  -- get nodes from tasks and loaders or show help
  local inactive_task_nodes =
    convert.inactive_task_nodes(self.handler:get_tasks { live = false, suppress_children = true })
  if #inactive_task_nodes < 1 then
    inactive_task_nodes = convert.help_no_task_nodes()
  end
  local loader_nodes = convert.loader_nodes(self.handler:get_loaders(), function()
    self.handler:reload_configs()
  end)
  if #loader_nodes < 1 then
    loader_nodes = convert.help_no_loader_nodes()
  end

  if self.left_tree then
    local expansion = get_expansion(self.left_tree)
    local nodes = utils.merge_lists(inactive_task_nodes, convert.separator_nodes(1), loader_nodes)
    self.left_tree:set_nodes(nodes)
    set_expansion(self.left_tree, expansion)
    self.left_tree:render()
  end

  local active_task_nodes = convert.active_task_nodes(self.handler:get_tasks { live = true })
  if #active_task_nodes < 1 then
    active_task_nodes = convert.separator_nodes(1)
  end

  if self.right_tree then
    local expansion = get_expansion(self.right_tree)
    self.right_tree:set_nodes(active_task_nodes)
    set_expansion(self.right_tree, expansion)
    self.right_tree:render()
  end
end
-- Show dashboard on screen
function Dashboard:open()
  -- open popup
  local cancel_autopreview
  local cancel_autorefresh
  local left_bufnr, right_bufnr, bottom_bufnr = self.popup:open(function()
    if cancel_autopreview then
      cancel_autopreview()
    end
    if cancel_autorefresh then
      cancel_autorefresh()
    end
  end)

  -- create trees if they don't exist
  self.left_tree = self.left_tree or self:create_tree(left_bufnr)
  self.left_tree.bufnr = left_bufnr
  self.right_tree = self.right_tree or self:create_tree(right_bufnr)
  self.right_tree.bufnr = right_bufnr

  -- map keys and configure autocommands
  self:map_keys(self.left_tree, left_bufnr)
  self:configure_autocmds(self.left_tree, left_bufnr, bottom_bufnr)
  self:map_keys(self.right_tree, right_bufnr)
  self:configure_autocmds(self.right_tree, right_bufnr, bottom_bufnr)

  -- set focus to left tree
  self.popup:set_focus("left")

  -- refresh trees (populate their layouts)
  self:refresh()

  -- set up auto previewing
  cancel_autopreview = self:configure_autopreview(bottom_bufnr)
  cancel_autorefresh = self:configure_autorefresh()
end

return Dashboard
