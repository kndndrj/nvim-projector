local utils = require("projector.utils")
local Popup = require("projector.dashboard.popup")
local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")

---@class Candy
---@field icon string
---@field icon_highlight string
---@field text_highlight string

---@alias dashboard_config { mappings: table<string, mapping>, disable_candies: boolean, candies: table<string, Candy> }

---@class Node
---@field id string
---@field name string
---@field type "task_visible"|"task_inactive"|"task_hidden"|"action"|"loader"|"mode"|""
---@field comment? string
-- action functions:
---@field action_1? fun()
---@field action_2? fun()
---@field action_3? fun()

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
    popup = Popup:new(),
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

      -- comment
      if node.comment then
        candy = self.candies["comment"]
        line:append("  (" .. node.comment .. ")", candy.text_highlight)
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

-- retrieve nodes from active tasks (hidden and visible)
---@private
---@param tasks Task[] list of all tasks
---@return Node[]
function Dashboard:get_active_task_nodes(tasks)
  local visible_nodes = {}
  local hidden_nodes = {}

  ---@param actions task_action[]
  ---@param parent_id string
  ---@return Node[]
  local function parse_actions(actions, parent_id)
    actions = actions or {}
    local action_nodes = {}
    for _, action in ipairs(actions) do
      local id = parent_id .. action.label

      -- create action node
      local node = NuiTree.Node({
        id = id,
        name = action.label,
        type = "action",
        action_1 = function()
          action.action()
        end,
      }, parse_actions(action.nested, id))

      -- expand by default (show nested actions)
      node:expand()

      table.insert(action_nodes, node)
    end

    return action_nodes
  end

  for _, task in ipairs(tasks) do
    if task:is_live() then
      local is_visible = task:is_visible()
      local type = "task_hidden"
      local meta = task:metadata()
      if is_visible then
        type = "task_visible"
      end
      local _, current_mode = task:get_modes()

      local node = NuiTree.Node({
        id = meta.id,
        name = meta.name,
        type = type,
        comment = current_mode,
        -- show
        action_1 = function()
          task:show()
        end,
        -- restart
        action_2 = function()
          task:run { restart = true }
        end,
        -- kill
        action_3 = function()
          task:kill()
        end,
      }, parse_actions(task:actions(), meta.id))

      -- expand by default (show actions)
      node:expand()

      if is_visible then
        table.insert(visible_nodes, node)
      else
        table.insert(hidden_nodes, node)
      end
    end
  end

  -- merge visible and hidden tasks together
  vim.list_extend(visible_nodes, hidden_nodes)

  return visible_nodes
end

-- retrieve nodes from inactive tasks
---@private
---@param tasks Task[] list of all tasks
---@return Node[]
function Dashboard:get_inactive_task_nodes(tasks)
  local normal_nodes = {}

  -- nodes that are hidden in the menu (because of presentation options)
  local menuhidden_nodes = {}

  for _, task in ipairs(tasks) do
    if not task:is_live() then
      -- handle modes
      local comment
      local modes, _ = task:get_modes()
      local action
      local children = {}
      if #modes == 1 then
        action = function()
          task:run { mode = modes[1] }
        end
        comment = modes[1]
      elseif #modes > 1 then
        for _, mode in ipairs(modes) do
          table.insert(
            children,
            NuiTree.Node {
              id = task:metadata().id .. mode,
              name = mode,
              type = "mode",
              action_1 = function()
                task:run { mode = mode }
              end,
            }
          )
        end
      end

      local node = NuiTree.Node({
        id = task:metadata().id,
        name = task:metadata().name,
        comment = comment,
        type = "task_inactive",
        action_1 = action,
      }, children)

      -- put in appropriate list based on presentation
      if task:presentation().menu.show then
        table.insert(normal_nodes, node)
      else
        table.insert(menuhidden_nodes, node)
      end
    end
  end

  -- if there aren't any normal nodes, return hidden ones as normal
  if #normal_nodes < 1 then
    return menuhidden_nodes
  end

  -- if there aren't any hidden nodes, return just the normal ones
  if #menuhidden_nodes < 1 then
    return normal_nodes
  end

  -- if there are hidden and normal nodes, add hidden ones under a fold

  local hidden_fold_node = NuiTree.Node({
    id = "__menuhidden_nodes_ui__",
    name = "hidden tasks",
    type = "",
  }, menuhidden_nodes)

  return utils.merge_lists(normal_nodes, self:get_separator_nodes(1), { hidden_fold_node })
end

---@private
---@param count? integer default is 1
---@return Node[]
function Dashboard:get_separator_nodes(count)
  if not count or count < 1 then
    count = 1
  end

  local nodes = {}
  for i = 1, count do
    local node = NuiTree.Node {
      id = "__separator_node_" .. i .. tostring(math.random()),
      name = "",
      type = "",
    }
    table.insert(nodes, node)
  end

  return nodes
end

-- retrieve loader nodes
---@private
---@param loaders Loader[] list of loaders
---@return Node[]
function Dashboard:get_loader_nodes(loaders)
  local nodes = {}

  for _, loader in ipairs(loaders) do
    table.insert(
      nodes,
      NuiTree.Node {
        id = tostring(math.random()),
        name = "asdf",
        type = "loader",
        action_1 = function() end,
      }
    )
  end

  return nodes
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
      node.action_1()
      self.popup:close()
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
      node.action_2()
      self.popup:close()
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
      node.action_3()
      self.popup:close()
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

-- Show dashboard on screen
---@param tasks Task[] list of tasks to display
---@param loaders Loader[] list of loaders to display
function Dashboard:open(tasks, loaders)
  local left_bufnr, right_bufnr = self.popup:open()

  -- left panel
  self.left_tree = self:create_tree(
    left_bufnr,
    utils.merge_lists(self:get_inactive_task_nodes(tasks), self:get_separator_nodes(3), self:get_loader_nodes(loaders))
  )
  self:map_keys(self.left_tree, left_bufnr)

  -- right panel
  local active_nodes = self:get_active_task_nodes(tasks)
  self.right_tree = self:create_tree(right_bufnr, active_nodes)
  self:map_keys(self.right_tree, right_bufnr)

  -- set focus depending on the task state
  if #active_nodes > 0 then
    self.popup:set_focus("right")
  else
    self.popup:set_focus("left")
  end

  -- render trees
  self.left_tree:render()
  self.right_tree:render()
end

return Dashboard
