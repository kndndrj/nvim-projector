local utils = require("projector.utils")
local Popup = require("projector.dashboard.popup")
local convert = require("projector.dashboard.convert")

local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")

---@class Candy
---@field icon string
---@field icon_highlight string
---@field text_highlight string

---@alias dashboard_config { mappings: table<string, mapping>, disable_candies: boolean, candies: table<string, Candy>, popup: popup_config }

---@class Node
---@field id string
---@field name string
---@field type "task_visible"|"task_inactive"|"task_hidden"|"action"|"loader"|"mode"|"group"|""
---@field comment? string
-- action functions:
---@field action_1? fun()
---@field action_2? fun()
---@field action_3? fun()
-- other:
---@field is_empty boolean

---@class Dashboard
---@field private left_tree table NuiTree
---@field private right_tree table NuiTree
---@field private popup Popup
---@field private mappings table<string, mapping>
---@field private candies table<string, Candy>
local Dashboard = {}

---@param opts? dashboard_config
---@return Dashboard
function Dashboard:new(opts)
  opts = opts or {}

  local candies = {}
  if not opts.disable_candies then
    candies = opts.candies or {}
  end

  local o = {
    popup = Popup:new("Tasks:", "Active:", opts.popup),
    mappings = opts.mappings or {},
    candies = candies,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@private
---@param bufnr integer buffer to set the nodes to
---@param nodes Node[] nodes to set to the tree
---@return table tree
function Dashboard:create_tree(bufnr, nodes)
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
      return math.random()
    end,
  }

  -- set nodes to tree
  tree:set_nodes(nodes)

  return tree
end

---@private
---@param tree table NuiTree
---@param bufnr integer
function Dashboard:map_keys(tree, bufnr)
  -- action_1
  local m = self.mappings.action_1 or { key = "<CR>", mode = "n" }
  vim.keymap.set(m.mode, m.key, function()
    local node = tree:get_node()
    if not node then
      return
    end
    if type(node.action_1) == "function" then
      self.popup:close()
      node.action_1()
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
      self.popup:close()
      node.action_2()
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
      self.popup:close()
      node.action_3()
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
function Dashboard:configure_autocmds(tree, bufnr)
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
end

-- Show dashboard on screen
---@param tasks Task[] list of tasks to display
---@param loaders Loader[] list of loaders to display
---@param reload_handle fun() function that reloads the sources when called
function Dashboard:open(tasks, loaders, reload_handle)
  -- open popup
  local left_bufnr, right_bufnr = self.popup:open()

  --
  -- left panel
  --
  -- get nodes from tasks and loaders or show help
  local inactive_task_nodes = convert.inactive_task_nodes(tasks)
  if #tasks < 1 then
    inactive_task_nodes = convert.help_no_task_nodes()
  end
  local loader_nodes = convert.loader_nodes(loaders, reload_handle)
  if #loaders < 1 then
    loader_nodes = convert.help_no_loader_nodes()
  end

  -- calculate number of separators so that loaders are near the bottom of the window
  local _, height = self.popup:dimensions()
  local n_sep = height - #inactive_task_nodes - #loader_nodes - 3
  if n_sep < 1 then
    n_sep = 1
  end

  self.left_tree =
    self:create_tree(left_bufnr, utils.merge_lists(inactive_task_nodes, convert.separator_nodes(n_sep), loader_nodes))
  self:map_keys(self.left_tree, left_bufnr)
  self:configure_autocmds(self.left_tree, left_bufnr)

  --
  -- right panel
  --
  self.right_tree = self:create_tree(right_bufnr, convert.active_task_nodes(tasks))
  self:map_keys(self.right_tree, right_bufnr)
  self:configure_autocmds(self.right_tree, right_bufnr)

  -- set focus to left
  self.popup:set_focus("left")

  -- render trees
  self.left_tree:render()
  self.right_tree:render()
end

return Dashboard
