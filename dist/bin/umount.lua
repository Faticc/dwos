local b=require("filesystem")
local f=require("shell")
local c,e=f.parse(...)
if#c<1 then
io.write("Usage: umount [-a] <mount>\n")
io.write(" -a  Remove any mounts by file system label or address instead of by path. Note that the address may be abbreviated.\n")
return 1
end
local a,d
if e.a then
local e
e,d=b.proxy(c[1])
a=e and e.address
else
local e=f.resolve(c[1])
local f,c=b.get(e)
if f then
if c~=e then
io.stderr:write("not a mount point\n")
return 1
end
a=c
else
d=c
end
end
if not a then
io.stderr:write(tostring(d).."\n")
return 1
end
if not b.umount(a)then
io.stderr:write("nothing to unmount here\n")
return 1
end
