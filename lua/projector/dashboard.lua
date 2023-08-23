local utils = require("projector.utils")
local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")

---@class Node
---@field id string
---@field name string
---@field type "task"|"loader"|"mode"
---@field state "special"|"active"|"normal"|"inactive"
-- action functions:
---@field action_1 fun()
---@field action_2 fun()
---@field action_3 fun()

---@class Dashboard
---@field private handler Handler
---@field private left_tree table NuiTree
---@field private right_tree table NuiTree
---@field private ui { left: { winid: integer, bufnr:integer }, right: { winid: integer, bufnr:integer } }
local Dashboard = {}

---@param handler Handler
function Dashboard:new(handler)
  local o = {
    handler = handler,
    ui = {
      left = {},
      right = {},
    },
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@private
---@return integer left_bufnr
---@return integer right_bufnr
function Dashboard:open_ui()
  local ui_spec = vim.api.nvim_list_uis()[1]
  local win_width = 70 / 2
  local win_height = 20

  local middle = math.floor(ui_spec.width / 2)
  local y = math.floor((ui_spec.height - win_height) / 2)

  -- create buffers
  self.ui.left.bufnr = vim.api.nvim_create_buf(false, true)
  self.ui.right.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.ui.left.bufnr, "bufhidden", "delete")
  vim.api.nvim_buf_set_option(self.ui.right.bufnr, "bufhidden", "delete")

  -- open windows
  local window_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = y,
    border = "rounded",
    style = "minimal",
  }

  self.ui.left.winid = vim.api.nvim_open_win(
    self.ui.left.bufnr,
    true,
    vim.tbl_extend("force", window_opts, {
      col = middle - win_width - 1,
      border = { "╭", "─", "┬", "│", "┴", "─", "╰", "│" },
      title_pos = "left",
      title = "Projector",
    })
  )
  self.ui.right.winid = vim.api.nvim_open_win(
    self.ui.right.bufnr,
    true,
    vim.tbl_extend("force", window_opts, {
      col = middle,
      border = { "┬", "─", "╮", "│", "╯", "─", "┴", "│" },
    })
  )

  -- register autocmd to automatically close the window on leave
  local function autocmd_cb()
    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= self.ui.left.bufnr and current_buf ~= self.ui.right.bufnr then
      self:close_ui()
    else
      vim.api.nvim_create_autocmd({ "BufEnter" }, {
        callback = autocmd_cb,
        once = true,
      })
    end
  end
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = autocmd_cb,
    once = true,
  })

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    buffer = self.ui.left.bufnr,
    callback = function()
      vim.api.nvim_win_set_option(self.ui.left.winid, "cursorline", true)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    buffer = self.ui.left.bufnr,
    callback = function()
      vim.api.nvim_win_set_option(self.ui.left.winid, "cursorline", false)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    buffer = self.ui.right.bufnr,
    callback = function()
      vim.api.nvim_win_set_option(self.ui.right.winid, "cursorline", true)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    buffer = self.ui.right.bufnr,
    callback = function()
      vim.api.nvim_win_set_option(self.ui.right.winid, "cursorline", false)
    end,
  })

  -- set keymaps
  vim.keymap.set("n", "q", function()
    self:close_ui()
  end, { silent = true, buffer = self.ui.left.bufnr })
  vim.keymap.set("n", "q", function()
    self:close_ui()
  end, { silent = true, buffer = self.ui.right.bufnr })

  vim.keymap.set("n", "l", function()
    pcall(vim.api.nvim_set_current_win, self.ui.right.winid)
  end, { silent = true, buffer = self.ui.left.bufnr })
  vim.keymap.set("n", "l", function()
    pcall(vim.api.nvim_set_current_win, self.ui.left.winid)
  end, { silent = true, buffer = self.ui.right.bufnr })

  vim.keymap.set("n", "h", function()
    pcall(vim.api.nvim_set_current_win, self.ui.right.winid)
  end, { silent = true, buffer = self.ui.left.bufnr })
  vim.keymap.set("n", "h", function()
    pcall(vim.api.nvim_set_current_win, self.ui.left.winid)
  end, { silent = true, buffer = self.ui.right.bufnr })

  -- set left window as current one
  vim.api.nvim_set_current_win(self.ui.left.winid)

  return self.ui.left.bufnr, self.ui.right.bufnr
end

---@private
function Dashboard:close_ui()
  pcall(vim.api.nvim_win_close, self.ui.left.winid, true)
  pcall(vim.api.nvim_win_close, self.ui.right.winid, true)
  pcall(vim.api.nvim_buf_delete, self.ui.left.bufnr, {})
  pcall(vim.api.nvim_buf_delete, self.ui.right.bufnr, {})
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

      line:append(string.rep("  ", node:get_depth() - 1))

      line:append(node.name)

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
---@return Node[]
function Dashboard:get_active_task_nodes()
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
        type = "",
        state = "normal",
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

  for _, task in ipairs(self.handler:get_tasks { live = true }) do
    local is_visible = task:is_visible()
    local state = "active"
    local meta = task:metadata()
    local action_1
    if is_visible then
      state = "special"
    end
    if not is_visible then
      action_1 = function()
        self.handler:show_task(meta.id)
      end
    end

    local node = NuiTree.Node({
      id = meta.id,
      name = meta.name,
      type = "task",
      state = state,
      action_1 = action_1,
      action_2 = function()
        self.handler:kill_task { id = task:metadata().id, restart = true }
      end,
      action_3 = function()
        self.handler:kill_task { id = task:metadata().id, restart = false }
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

  -- merge visible and hidden tasks together
  vim.list_extend(visible_nodes, hidden_nodes)

  return visible_nodes
end

-- retrieve nodes from inactive tasks
---@private
---@return Node[]
function Dashboard:get_inactive_task_nodes()
  local nodes = {}

  local inactive_tasks = self.handler:get_tasks { live = false }
  for _, task in ipairs(inactive_tasks) do
    local modes = task:get_modes()
    local action
    local children = {}
    if #modes == 1 then
      action = function()
        task:run(modes[1])
      end
    elseif #modes > 1 then
      for _, mode in ipairs(modes) do
        table.insert(
          children,
          NuiTree.Node {
            id = task:metadata().id .. mode,
            name = mode,
            type = "mode",
            state = "normal",
            action_1 = function()
              task:run(mode)
            end,
          }
        )
      end
    end

    table.insert(
      nodes,
      NuiTree.Node({
        id = task:metadata().id,
        name = task:metadata().name,
        type = "task",
        state = "normal",
        action_1 = action,
      }, children)
    )
  end

  return nodes
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
      type = "separator",
      state = "normal",
    }
    table.insert(nodes, node)
  end

  return nodes
end

-- retrieve loader nodes
---@private
---@return Node[]
function Dashboard:get_loader_nodes()
  local nodes = {}

  local loaders = self.handler:get_loaders()
  for _, loader in ipairs(loaders) do
    table.insert(
      nodes,
      NuiTree.Node {
        id = tostring(math.random()),
        name = "asdf",
        type = "loader",
        state = "normal",
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
  vim.keymap.set("n", "<CR>", function()
    local node = tree:get_node()
    if not node then
      return
    end
    if type(node.action_1) == "function" then
      node.action_1()
      self:close_ui()
      return
    end

    if node:has_children() then
      node:expand()
      tree:render()
    end
  end, { silent = true, buffer = bufnr })
  -- action_2
  vim.keymap.set("n", "r", function()
    local node = tree:get_node()
    if not node then
      return
    end
    if type(node.action_2) == "function" then
      node.action_2()
      self:close_ui()
    end
  end, { silent = true, buffer = bufnr })
  -- action_3
  vim.keymap.set("n", "d", function()
    local node = tree:get_node()
    if not node then
      return
    end
    if type(node.action_3) == "function" then
      node.action_3()
      self:close_ui()
    end
  end, { silent = true, buffer = bufnr })
end

-- Show dashboard on screen
function Dashboard:open()
  -- evaluate any task overrides
  if self.handler:evaluate_live_task_action_overrides() then
    return
  end

  local left_bufnr, right_bufnr = self:open_ui()

  self.left_tree = self:create_tree(
    left_bufnr,
    utils.merge_lists(self:get_inactive_task_nodes(), self:get_separator_nodes(3), self:get_loader_nodes())
  )
  self.right_tree = self:create_tree(right_bufnr, self:get_active_task_nodes())

  self:map_keys(self.left_tree, left_bufnr)
  self:map_keys(self.right_tree, right_bufnr)

  self.left_tree:render()
  self.right_tree:render()
end

return Dashboard
