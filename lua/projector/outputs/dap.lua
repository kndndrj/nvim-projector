local has_dap, dap = pcall(require, "dap")
local has_dapui, dapui = pcall(require, "dapui")

---@class DapOutput: Output
---@field state output_status
---@field session table -- Dap Session
local DapOutput = {}

---@return DapOutput
function DapOutput:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

---@return output_status
function DapOutput:status()
  return self.state or "inactive"
end

---@param configuration TaskConfiguration
---@param callback fun(success: boolean)
function DapOutput:init(configuration, callback)
  if not has_dap then
    return
  end

  self.state = "hidden"

  -- run the config
  dap.run(configuration)

  -- get dap session
  self.session = dap.session()
  if not self.session then
    callback(false)
    return
  end

  self.session.on_close["projector"] = function()
    self.state = "inactive"
    callback(true)
  end
end

function DapOutput:show()
  if not has_dapui then
    return
  end
  dapui.open()
  self.state = "visible"
end

function DapOutput:hide()
  if not has_dapui then
    return
  end
  dapui.close()
  self.state = "hidden"
end

function DapOutput:kill()
  if has_dap then
    dap.terminate()
  end
  if has_dapui then
    dapui.close()
  end
end

---@return task_action[]
function DapOutput:actions()
  if not has_dap or not self.session then
    return {}
  end

  -- override action if thread stopped
  if self.session.stopped_thread_id then
    return {
      {
        label = "Continue",
        action = function()
          self.session:_step("continue")
        end,
        override = true,
      },
    }
  end

  ---@type task_action[]
  local actions = {
    {
      label = "Terminate session",
      action = dap.terminate,
    },
    {
      label = "Pause a thread",
      action = dap.pause,
    },
    {
      label = "Restart session",
      action = dap.restart,
    },
    {
      label = "Disconnect (terminate = true)",
      action = function()
        dap.disconnect { terminateDebuggee = true }
      end,
    },
    {
      label = "Disconnect (terminate = false)",
      action = function()
        dap.disconnect { terminateDebuggee = false }
      end,
    },
  }

  -- Add stopped threads nested actions
  local stopped_threads = vim.tbl_filter(function(t)
    return t.stopped
  end, self.session.threads)

  if next(stopped_threads) then
    ---@type task_action[]
    local stopped_thread_actions = {}

    for _, t in pairs(stopped_threads) do
      table.insert(stopped_thread_actions, {
        label = t.name or t.id,
        action = function()
          self.session.stopped_thread_id = t.id
          self.session:_step("continue")
        end,
      })
    end

    -- Add an action with nested actions to the list
    table.insert(actions, 1, {
      label = "Resume stopped thread",
      nested = stopped_thread_actions,
    })
  end

  return actions
end

---@param _ integer
---@return string[]?
function DapOutput:preview(_)
  return { dap.status() }
end

return DapOutput
