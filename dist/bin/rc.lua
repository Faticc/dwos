local rc = require("rc")
local fs = require("filesystem")
local function loadConfig()
  local env = {}
  local result, reason = loadfile("/etc/rc.cfg", "t", env)
  if result then
    result, reason = xpcall(result, debug.traceback)
    if result then
      return env
    end
  end
  return nil, reason
end
local function saveConfig(conf)
  local file, reason = io.open("/etc/rc.cfg", "w")
  if not file then
    return nil, reason
  end
  local ser = require("serialization")
  for key, value in pairs(conf) do
    file:write(tostring(key) .. " = " .. ser.serialize(value) .. "\n")
  end
  file:close()
  return true
end
local function load(name, args)
  if rc.loaded[name] then
    return rc.loaded[name]
  end
  local fileName = fs.concat("/etc/rc.d/", name .. ".lua")
  local env = setmetatable({ args = args }, { __index = _G })
  local result, reason = loadfile(fileName, "t", env)
  if not result then
    return nil, string.format("%s failed to load: %s", fileName, reason)
  end
  result, reason = xpcall(result, debug.traceback)
  if not result then
    return nil, string.format("%s failed to start: %s", fileName, reason)
  end
  rc.loaded[name] = env
  return env
end
function rc.unload(name)
  rc.loaded[name] = nil
end
local function rawRunCommand(conf, name, cmd, args, ...)
  local result, what = load(name, args)
  if not result then
    return nil, what
  end
  if not cmd then
    io.output():write("Commands for service " .. name .. "\n")
    for command, val in pairs(result) do
      if type(val) == "function" then
        io.output():write(tostring(command) .. " ")
      end
    end
    return true
  elseif type(result[cmd]) == "function" then
    local ok, why = xpcall(result[cmd], debug.traceback, ...)
    if ok then return true end
    return nil, why
  elseif cmd == "restart" and type(result.stop) == "function" and type(result.start) == "function" then
    local ok, why = xpcall(result.stop, debug.traceback, ...)
    if ok then
      ok, why = xpcall(result.start, debug.traceback, ...)
      if ok then return true end
    end
    return nil, why
  elseif cmd == "enable" then
    conf.enabled = conf.enabled or {}
    for _, other in ipairs(conf.enabled) do
      if name == other then
        return nil, "Service already enabled"
      end
    end
    conf.enabled[#conf.enabled + 1] = name
    return saveConfig(conf)
  elseif cmd == "disable" then
    conf.enabled = conf.enabled or {}
    for n = #conf.enabled, 1, -1 do
      if conf.enabled[n] == name then
        table.remove(conf.enabled, n)
      end
    end
    return saveConfig(conf)
  end
  return nil, "Command '" .. cmd .. "' not found in daemon '" .. name .. "'"
end
local function runCommand(name, cmd, ...)
  local conf, reason = loadConfig()
  if not conf then
    return nil, reason
  end
  return rawRunCommand(conf, name, cmd, conf[name], ...)
end
local function allRunCommand(cmd, ...)
  local conf, reason = loadConfig()
  if not conf then
    return nil, reason
  end
  local results = {}
  for _, name in ipairs(conf.enabled or {}) do
    results[name] = table.pack(rawRunCommand(conf, name, cmd, conf[name], ...))
  end
  return results
end
local stream = io.stderr
local write = stream.write
if select("#", ...) == 0 then
  if _G.runlevel == "S" then
    write = function(_, msg)
      require("event").onError(msg)
    end
  end
  local results, reason = allRunCommand("start")
  if not results then
    write(stream, "rc failed to start:" .. tostring(reason), "\n")
    return
  end
  for _, result in pairs(results) do
    local ok, why = table.unpack(result)
    if not ok then
      write(stream, why, "\n")
    end
  end
else
  local result, reason = runCommand(...)
  if not result then
    write(stream, reason, "\n")
    return 1
  end
end
