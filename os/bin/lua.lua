local shell = require("shell")
local args = shell.parse(...)

if #args == 0 then
  args = { "/lib/core/lua_shell.lua" } -- без файла - интерактивный Lua
end

local filename = args[1]
local script, reason
local buffer
local file = io.open(filename)
if file then
  buffer = file:read("*a")
  file:close()
end
if buffer then
  buffer = buffer:gsub("^#![^\n]+", "") -- shebang не нужен
  script, reason = load(buffer, "=" .. filename)
else
  reason = string.format("could not open %s for reading", filename)
end

if not script then
  io.stderr:write(tostring(reason) .. "\n")
  os.exit(false)
end

local ok
ok, reason = pcall(script, table.unpack(args, 2))
if not ok then
  io.stderr:write(type(reason) == "table" and reason.reason or tostring(reason), "\n")
  os.exit(false)
end
