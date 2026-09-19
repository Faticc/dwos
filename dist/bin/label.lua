local shell = require("shell")
local devfs = require("devfs")
local comp = require("component")
local args, options = shell.parse(...)
if #args < 1 then
  io.write("Usage: label [-a] <device> [<label>]\n")
  io.write(" -a  Device is specified via label or address instead of by path.\n")
  return 1
end
local filter, label = args[1], args[2]
local proxy, reason
if options.a then
  for addr in comp.list() do
    if addr:sub(1, filter:len()) == filter then
      proxy, reason = comp.proxy(addr)
      break
    end
    local candidate = comp.proxy(addr)
    if devfs.getDeviceLabel(candidate) == filter then
      proxy = candidate
      break
    end
  end
else
  proxy, reason = devfs.getDevice(filter)
end
if not proxy then
  io.stderr:write(tostring(reason) .. "\n")
  return 1
end
if #args < 2 then
  local current = devfs.getDeviceLabel(proxy)
  if current then
    print(current)
  else
    io.stderr:write("no label\n")
    return 1
  end
else
  devfs.setDeviceLabel(proxy, label)
end
