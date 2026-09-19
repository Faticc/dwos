local computer = require("computer")
local fs = require("filesystem")
local READ = math.maxinteger or math.huge
function loadfile(filename, ...)
  if filename:sub(1, 1) ~= "/" then
    filename = (os.getenv("PWD") or "/") .. "/" .. filename
  end
  local handle, open_reason = fs.open(filename)
  if not handle then
    return nil, open_reason
  end
  local buffer, n = {}, 0
  while true do
    local data, reason = handle:read(READ)
    if not data then
      handle:close()
      if reason then
        return nil, reason
      end
      break
    end
    n = n + 1
    buffer[n] = data
  end
  return load(table.concat(buffer), "=" .. filename, ...)
end
function dofile(filename)
  local program, reason = loadfile(filename)
  if not program then
    return error(reason .. ":" .. filename, 0)
  end
  return program()
end
function print(...)
  local args = table.pack(...)
  local out = {}
  for i = 1, args.n do
    out[i] = assert(tostring(args[i]), "'tostring' must return a string to 'print'")
  end
  local stdout = io.stdout
  stdout:write(table.concat(out, "\t", 1, args.n), "\n")
  stdout:flush()
end
local process = require("process")
local _coroutine = coroutine
_G.coroutine = setmetatable({
  resume = function(co, ...)
    local proc = process.info(co)
    return (proc and proc.data.coroutine_handler.resume or _coroutine.resume)(co, ...)
  end,
}, {
  __index = function(_, key)
    local proc = process.info(_coroutine.running())
    return (proc and proc.data.coroutine_handler or _coroutine)[key]
  end,
})
package.loaded.coroutine = _G.coroutine
local kernel_load = _G.load
_G.load = function(source, label, mode, env)
  local prev_load = env and env.load or _G.load
  local e = env and setmetatable({
    load = function(_source, _label, _mode, _env)
      return prev_load(_source, _label, _mode, _env or env)
    end,
  }, {
    __index = env,
    __pairs = function(...) return pairs(env, ...) end,
    __newindex = function(_, key, value) env[key] = value end,
  })
  return kernel_load(source, label, mode, e or process.info().env)
end
local kernel_create = _coroutine.create
_coroutine.create = function(f, standAlone)
  local co = kernel_create(f)
  if not standAlone then
    table.insert(process.findProcess().instances, co)
  end
  return co
end
_coroutine.wrap = function(f)
  local thread = coroutine.create(f)
  return function(...)
    return select(2, coroutine.resume(thread, ...))
  end
end
process.list[_coroutine.running()] = {
  path = "/init.lua",
  command = "init",
  env = _ENV,
  data = {
    vars = {},
    handles = {},
    io = {},
    coroutine_handler = _coroutine,
    signal = error,
  },
  instances = setmetatable({}, { __mode = "v" }),
}
local fs_open = fs.open
fs.open = function(...)
  local result = table.pack(fs_open(...))
  if result[1] then
    process.addHandle(result[1])
  end
  return table.unpack(result, 1, result.n)
end
local event = require("event")
local info = process.info
function os.getenv(varname)
  local env = info().data.vars
  if not varname then
    return env
  elseif varname == "#" then
    return #env
  end
  return env[varname]
end
function os.setenv(varname, value)
  checkArg(1, varname, "string", "number")
  if value ~= nil then
    value = tostring(value)
  end
  info().data.vars[varname] = value
  return value
end
function os.sleep(timeout)
  checkArg(1, timeout, "number", "nil")
  local deadline = computer.uptime() + (timeout or 0)
  repeat
    event.pull(deadline - computer.uptime())
  until computer.uptime() >= deadline
end
os.setenv("PATH", "/bin:/usr/bin:/home/bin:.")
os.setenv("TMP", "/tmp")
os.setenv("TMPDIR", "/tmp")
if computer.tmpAddress() then
  fs.mount(computer.tmpAddress(), "/tmp")
end
require("package").delay(os, "/lib/core/full_filesystem.lua")
local buffer = require("buffer")
local tty_stream = require("tty").stream
local core_stdin = buffer.new("r", tty_stream)
local core_stdout = buffer.new("w", tty_stream)
local core_stderr = buffer.new("w", setmetatable({
  write = function(_, str)
    return tty_stream:write("\27[31m" .. str .. "\27[37m")
  end,
}, { __index = tty_stream }))
core_stdout:setvbuf("no")
core_stderr:setvbuf("no")
core_stdin.tty, core_stdout.tty, core_stderr.tty = true, true, true
core_stdin.close = tty_stream.close
core_stdout.close = tty_stream.close
core_stderr.close = tty_stream.close
local io_mt = getmetatable(io) or {}
io_mt.__index = function(_, k)
  return k == "stdin" and io.input() or
         k == "stdout" and io.output() or
         k == "stderr" and io.error() or
         nil
end
setmetatable(io, io_mt)
io.input(core_stdin)
io.output(core_stdout)
io.error(core_stderr)
