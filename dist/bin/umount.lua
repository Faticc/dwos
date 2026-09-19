local fs = require("filesystem")
local shell = require("shell")
local args, options = shell.parse(...)
if #args < 1 then
io.write("Usage: umount [-a] <mount>\n")
io.write(" -a  Remove any mounts by file system label or address instead of by path. Note that the address may be abbreviated.\n")
return 1
end
local target, reason
if options.a then
local proxy
proxy, reason = fs.proxy(args[1])
target = proxy and proxy.address
else
local path = shell.resolve(args[1])
local proxy, mount = fs.get(path)
if proxy then
if mount ~= path then
io.stderr:write("not a mount point\n")
return 1
end
target = mount
else
reason = mount
end
end
if not target then
io.stderr:write(tostring(reason) .. "\n")
return 1
end
if not fs.umount(target) then
io.stderr:write("nothing to unmount here\n")
return 1
end
