do
local addr, invoke = computer.getBootAddress(), component.invoke
local function rawload(file)
local handle = assert(invoke(addr, "open", file))
local parts, n = {}, 0
repeat
local data = invoke(addr, "read", handle, math.maxinteger or math.huge)
n = n + 1
parts[n] = data
until not data
invoke(addr, "close", handle)
return load(table.concat(parts), "=" .. file, "bt", _G)
end
rawload("/lib/core/boot.lua")(rawload)
end
while true do
local result, reason = xpcall(require("shell").getShell(), function(msg)
return tostring(msg) .. "\n" .. debug.traceback()
end)
if not result then
io.stderr:write((reason ~= nil and tostring(reason) or "unknown error") .. "\n")
io.write("Press any key to continue.\n")
os.sleep(0.5)
require("event").pull("key")
end
end
