local Output = require 'projector.contract.output'
local has_dap, dap = pcall(require, 'dap')
local has_dapui, dapui = pcall(require, 'dapui')
---@cast dap -Loader

---@type Output
local DapOutput = Output:new()

---@param configuration Configuration
---@diagnostic disable-next-line: unused-local
function DapOutput:init(configuration)
  if has_dap then
    self.status = "visible"

    -- set status to inactive and close outputs on exit
    dap.listeners.before.event_terminated["projector"] = function()
      self.status = "inactive"
      self:done(true)
    end
    dap.listeners.before.event_exited["projector"] = function()
      self.status = "inactive"
    end

    dap.run(configuration)
  end
end

function DapOutput:open()
  if has_dapui then
    dapui.open()
    self.status = "visible"
  end
end

function DapOutput:close()
  if has_dapui then
    dapui.close()
    self.status = "hidden"
  end
end

function DapOutput:kill()
  if has_dap then
    dap.terminate()
  end
  if has_dapui then
    dapui.close()
  end
  self.status = "inactive"
end

---@return Action[]|nil
function DapOutput:list_actions()
  if not has_dap then
    return
  end

  local session = dap.session()
  if not session then
    return
  end

  if session.stopped_thread_id then
    return {
      {
        label = "Continue",
        action = function() session:_step('continue') end,
        override = true,
      },
    }
  end

  local choices = {
    {
      label = "Terminate session",
      action = dap.terminate
    },
    {
      label = "Pause a thread",
      action = dap.pause
    },
    {
      label = "Restart session",
      action = dap.restart,
    },
    {
      label = "Disconnect (terminate = true)",
      action = function()
        dap.disconnect({ terminateDebuggee = true })
      end
    },
    {
      label = "Disconnect (terminate = false)",
      action = function()
        dap.disconnect({ terminateDebuggee = false })
      end,
    },
  }

  -- Add stopped threads action
  local stopped_threads = vim.tbl_filter(function(t) return t.stopped end, session.threads)

  if next(stopped_threads) then
    -- empty line before threads for prettier ui. TODO?
      table.insert(choices, #choices+1, {
        label = "",
        action = function() end,
      })

    for _, t in pairs(stopped_threads) do
      local name = t.name or t.id

      table.insert(choices, #choices+1, {
        label = "Resume thread " .. name,
        action = function()
          session.stopped_thread_id = t.id
          session:_step('continue')
        end
      })

    end
  end

  return choices
end

return DapOutput
