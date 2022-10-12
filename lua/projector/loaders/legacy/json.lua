local Task = require("projector.task")
local Loader = require("projector.contract.loader")
local common = require("projector.loaders.common")
local utils = require("projector.utils")

local asked = false
-- Convert old file to new format
---@param tasks Task[]
---@param path string
local function write_new_json(tasks, path)
  if asked then
    return
  end
  asked = true
  -- get new configs
  local configs = {}
  for _, t in ipairs(tasks) do
    t.configuration.group = t.meta.group
    table.insert(configs, t.configuration)
  end

  -- Create backup
  local backup_path = path .. ".legacy-json-backup"

  -- if backup already exists, return
  if vim.loop.fs_stat(backup_path) then
    return
  end

  local answer = vim.fn.input('Detected legacy "projector.json". Update it to new format (will crate backup)? [y/n]: ')
  if answer ~= "y" and answer ~= "Y" then
    return
  end

  -- previous file is a backup
  local ok, err = os.rename(path, backup_path)
  if not ok then
    utils.log("error", "Could not create " .. backup_path .. "\nReason: " .. err, "Legacy JSON Loader")
  end

  -- Transform configs to json
  local json
  ok, json = pcall(vim.fn.json_encode, configs)
  if not ok then
    utils.log("error", "Could not parse lua configs into a file.", "Legacy JSON Loader")
  end

  -- format with jq
  if vim.fn.executable("jq") == 1 then
    local f = assert(io.popen("echo '" .. json .. "' | jq", "r"))
    json = assert(f:read("*a"))
    f:close()
  else
    utils.log(
      "warn",
      '"jq" is not executable - the new file won\'t be formatted\nIf you wish to format the files when converting, install "jq"',
      "Legacy JSON Loader"
    )
  end

  -- create a new file and write to it
  local file = assert(io.open(path, "w+"))
  if not file then
    utils.log("error", "Could not create a new file: " .. path, "Legacy JSON Loader")
    return
  end

  file:write(json)
  file:close()

  utils.log(
    "info",
    "Successfully converted the config!\nBackup was created at:\n\t" .. backup_path,
    "Legacy JSON Loader"
  )
end

---@type Loader
local LegacyJsonLoader = Loader:new("legacy.json")

---@param opt string Path to legacy projector.json
---@return Task[]|nil
function LegacyJsonLoader:load(opt)
  local path = opt or (vim.fn.getcwd() .. "/.vim/projector.json")
  if type(path) ~= "string" then
    utils.log("error", 'Got: "' .. type(path) .. '", want "string".', "Legacy JSON Loader")
    return
  end

  if not vim.loop.fs_stat(path) then
    return
  end

  local lines = {}
  for line in io.lines(path) do
    if not vim.startswith(vim.trim(line), "//") then
      table.insert(lines, line)
    end
  end

  local contents = table.concat(lines, "\n")
  local ok, data = pcall(vim.fn.json_decode, contents)
  if not ok then
    utils.log("error", 'Could not parse json file: "' .. path .. '".', "Legacy JSON Loader")
    return
  end

  -- map with Task objects
  local tasks = {}

  for type, range in pairs(data) do
    if type == "debug" or type == "tasks" then
      for group, configs in pairs(range) do
        for _, config in pairs(configs) do
          -- translate dependencies
          if config.depends then
            local deps = {}
            for _, dep in ipairs(config.depends) do
              local d = string.gsub(dep, ".tasks.", ".", 1)
              d = string.gsub(d, ".debug.", ".", 1)
              table.insert(deps, d)
            end
            config.dependencies = deps
            config.depends = nil
          end
          -- translate run_command
          if config.run_command then
            config.command = config.run_command
            config.run_command = nil
          end
          local task = Task:new(config, { scope = "project", group = group })
          table.insert(tasks, task)
        end
      end
    elseif type == "database" then
      local config = range
      config.name = "Database settings"
      config.databases = config.dbs
      config.queries = config.db_ui_table_helpers
      config.dbs = nil
      config.db_ui_table_helpers = nil
      local task = Task:new(config, { scope = "project", group = "sql" })
      table.insert(tasks, task)
    end
  end

  write_new_json(tasks, path)

  return tasks
end

---@param configuration Configuration
---@return Configuration
function LegacyJsonLoader:expand_variables(configuration)
  return vim.tbl_map(common.expand_config_variables, configuration)
end

return LegacyJsonLoader
