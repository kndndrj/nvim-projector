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
---@field type "task_visible"|"task_inactive"|"task_hidden"|"task_group"|"action"|"loader"|"mode"|"group"|""
---@field comment? string
-- action functions:
---@field action_1? fun()
---@field action_2? fun()
---@field action_3? fun()
-- other:
---@field is_empty? boolean
---@field preview? fun(max_lines: integer):string[]

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
      return tostring(math.random())
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

-- Show dashboard on screen
---@param inactive_tasks Task[] list of inactive tasks to display
---@param active_tasks Task[] list of inactive tasks to display
---@param loaders Loader[] list of loaders to display
---@param reload_handle fun() function that reloads the sources when called
function Dashboard:open(inactive_tasks, active_tasks, loaders, reload_handle)
  -- open popup
  local timer_cancel
  local left_bufnr, right_bufnr, bottom_bufnr = self.popup:open(function()
    if timer_cancel then
      timer_cancel()
    end
  end)

  --
  -- left panel
  --
  -- get nodes from tasks and loaders or show help
  local inactive_task_nodes = convert.inactive_task_nodes(inactive_tasks)
  if #inactive_tasks < 1 then
    inactive_task_nodes = convert.help_no_task_nodes()
  end
  local loader_nodes = convert.loader_nodes(loaders, reload_handle)
  if #loaders < 1 then
    loader_nodes = convert.help_no_loader_nodes()
  end

  self.left_tree =
    self:create_tree(left_bufnr, utils.merge_lists(inactive_task_nodes, convert.separator_nodes(1), loader_nodes))
  self:map_keys(self.left_tree, left_bufnr)
  self:configure_autocmds(self.left_tree, left_bufnr, bottom_bufnr)

  --
  -- right panel
  --
  self.right_tree = self:create_tree(right_bufnr, convert.active_task_nodes(active_tasks))
  self:map_keys(self.right_tree, right_bufnr)
  self:configure_autocmds(self.right_tree, right_bufnr, bottom_bufnr)

  -- set focus to left
  self.popup:set_focus("left")

  -- render trees
  self.left_tree:render()
  self.right_tree:render()

  -- set up auto previewing
  timer_cancel = self:configure_autopreview(bottom_bufnr)
end

return Dashboard
