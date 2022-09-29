local Output = require'projector.contract.output'
local has_dap, dap = pcall(require, 'dap')
local has_dapui, dapui = pcall(require, 'dapui')

local DapOutput = Output:new()

function DapOutput:init()
  if has_dap then
    dap.run(self.configuration)
    self.status = "active"
  end
end

function DapOutput:open()
  if has_dapui then
    dapui.open()
    self.status = "active"
  end
end

function DapOutput:close()
  if has_dapui then
    dapui.close()
    self.status = "hidden"
  end
end

function DapOutput:list_actions()
  if not has_dap then
    return
  end

  local session = dap.session()
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
    {
      label = "Do nothing",
      action = function() end,
    },
  }

  -- Add stopped threads action
  local stopped_threads = vim.tbl_filter(function(t) return t.stopped end, session.threads)

  if next(stopped_threads) then
    for t in pairs(stopped_threads) do
      local name = t.name or t.id

      table.insert(choices, 1, {
        label = "Resume thread " .. name,
        action = function()
          if t then
            session.stopped_thread_id = t.id
            session:_step('continue')
          end
        end
      })

    end
  end

  return choices
end

return DapOutput