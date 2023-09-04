-- This package provides functions to convert various
-- structures to NuiTree nodes

local utils = require("projector.utils")
local NuiTree = require("nui.tree")
local editor = require("projector.dashboard.editor")

local M = {}

-- retrieve nodes from active tasks (hidden and visible)
---@param tasks Task[] list of all tasks
---@return Node[]
function M.active_task_nodes(tasks)
  local visible_nodes = {}
  local hidden_nodes = {}

  ---@param actions task_action[]
  ---@param parent_id string
  ---@param previewer? fun(max_lines: integer)
  ---@return Node[]
  local function parse_actions(actions, parent_id, previewer)
    actions = actions or {}
    local action_nodes = {}
    for _, action in ipairs(actions) do
      local id = parent_id .. action.label

      local node_action
      if type(action.action) == "function" then
        node_action = function(close)
          close()
          action.action()
        end
      end

      -- create action node
      local node = NuiTree.Node({
        id = id,
        name = action.label,
        type = "action",
        action_1 = node_action,
        preview = previewer,
      }, parse_actions(action.nested, id, previewer))

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
      local _, current_mode = task:modes()

      local previewer = function(max_lines)
        return task:preview(max_lines)
      end

      local node = NuiTree.Node({
        id = meta.id,
        name = meta.name,
        type = type,
        comment = current_mode,
        -- show
        action_1 = function(close)
          close()
          task:show()
        end,
        -- restart
        action_2 = function(close)
          close()
          task:run { restart = true }
        end,
        -- kill
        action_3 = function(_)
          task:kill()
        end,
        preview = previewer,
      }, parse_actions(task:actions(), meta.id, previewer))

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
---@param tasks Task[] list of all tasks
---@return Node[]
function M.inactive_task_nodes(tasks)
  ---@param tsks Task[]
  ---@return Node[]
  local function parse(tsks)
    if not tsks then
      return {}
    end

    local task_only_nodes = {} -- nodes that are only tasks
    local group_nodes = {} -- nodes that have children
    for _, task in ipairs(tsks) do
      if not task:is_live() then
        local meta = task:metadata()
        local modes, _ = task:modes()
        table.sort(modes)
        local type = "task_inactive"

        -- child tasks
        local child_nodes = parse(task:get_children())
        local has_children = false
        if #child_nodes > 0 then
          has_children = true
          type = "task_group"
        end

        local previewer = function(max_lines)
          return task:preview(max_lines)
        end

        local action
        if #child_nodes < 1 and #modes == 1 then
          -- no children, single mode
          action = function(close)
            close()
            task:run { mode = modes[1] }
          end
        else
          -- multiple modes, and/or child nodes
          for _, mode in ipairs(modes) do
            table.insert(
              child_nodes,
              1,
              NuiTree.Node {
                id = meta.id .. mode,
                name = mode,
                type = "mode",
                action_1 = function(close)
                  close()
                  task:run { mode = mode }
                end,
                preview = previewer,
              }
            )
          end
        end

        local node = NuiTree.Node({
          id = meta.id,
          name = meta.name,
          comment = table.concat(modes, "|"),
          type = type,
          action_1 = action,
          preview = previewer,
        }, child_nodes)

        if #child_nodes > 0 or action ~= nil then
          if has_children then
            table.insert(group_nodes, node)
          else
            table.insert(task_only_nodes, node)
          end
        end
      end
    end

    if #group_nodes < 1 then
      return task_only_nodes
    end

    if #task_only_nodes < 1 then
      return group_nodes
    end

    return utils.merge_lists(task_only_nodes, M.separator_nodes(1), group_nodes)
  end

  return parse(tasks)
end

-- retrieve loader nodes
---@param loaders Loader[] list of loaders
---@param reload_handle fun() function that reloads the sources when called
---@return Node[]
function M.loader_nodes(loaders, reload_handle)
  local nodes = {}

  for _, loader in ipairs(loaders) do
    local node_action
    local comment
    local previewer
    if type(loader.file) == "function" and vim.loop.fs_stat(loader:file()) then
      node_action = function(close)
        close()
        editor.open(loader:file(), {
          title = "Edit source of " .. loader:name(),
          callback = reload_handle,
        })
      end

      comment = "edit"

      previewer = function(max_lines)
        local file = io.open(loader:file())
        if not file then
          return
        end
        local lines = {}
        local i = 1
        for line in file:lines() do
          if i > max_lines then
            break
          end
          table.insert(lines, line)
          i = i + 1
        end
        io.close(file)
        print(#lines)
        return lines
      end
    end

    table.insert(
      nodes,
      NuiTree.Node {
        id = loader:name(),
        name = loader:name(),
        type = "loader",
        action_1 = node_action,
        comment = comment,
        preview = previewer,
      }
    )
  end

  if #nodes < 1 then
    return {}
  end

  local master_node = NuiTree.Node({
    id = "__loaders_master_node__",
    name = "loaders",
    type = "group",
    action_2 = function(_)
      reload_handle()
    end,
  }, nodes)

  return { master_node }
end

-- retrieve loader nodes
---@return Node[]
function M.help_no_task_nodes()
  return {
    NuiTree.Node {
      id = tostring(math.random()),
      name = "No tasks available!",
      type = "",
    },
    NuiTree.Node {
      id = tostring(math.random()),
      name = "Press here for help",
      comment = ":h projector",
      type = "",
      action_1 = function(close)
        close()
        vim.cmd(":h projector")
      end,
    },
  }
end

-- retrieve loader nodes
---@return Node[]
function M.help_no_loader_nodes()
  return {
    NuiTree.Node {
      id = tostring(math.random()),
      name = "No loaders configured!",
      type = "",
    },
    NuiTree.Node {
      id = tostring(math.random()),
      name = "Press here for help",
      comment = ":h projector-loaders",
      type = "",
      action_1 = function(close)
        close()
        vim.cmd(":h projector-loaders")
      end,
    },
  }
end

-- get blank separator nodes
---@param count? integer default is 1
---@return Node[]
function M.separator_nodes(count)
  if not count or count < 1 then
    count = 1
  end

  local nodes = {}
  for i = 1, count do
    local node = NuiTree.Node {
      id = "__separator_node_" .. i .. tostring(math.random()),
      name = "",
      type = "",
      is_empty = true,
    }
    table.insert(nodes, node)
  end

  return nodes
end

return M
