if vim.g.loaded_projector == 1 then
  return
end
vim.g.loaded_projector = 1

-- Create user command for projector
vim.api.nvim_create_user_command("Projector", function(opts)
  local cmd = opts.args or ""
  if cmd == "" then
    -- default is continue
    require("projector").continue()
    return
  end

  local lookup = require("projector")

  local fn = lookup[cmd]
  if fn then
    fn(cmd)
    return
  end

  error("unsupported subcommand: " .. cmd)
end, {
  nargs = "?",
  complete = function(_, _, _)
    return { "reload", "continue", "next", "previous", "toggle", "restart", "kill" }
  end,
})
