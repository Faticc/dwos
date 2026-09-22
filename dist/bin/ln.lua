local a=require("filesystem")
local c=require("shell")
local d=c.parse(...)
if#d==0 then
io.write("Usage: ln <target> [<name>]\n")
return 1
end
local f=d[1]
local e=c.resolve(f)
if not a.exists(e)and not a.isLink(e)then
io.stderr:write("ln: failed to access '"..f.."': No such file or directory\n")
return 1
end
local b
if#d>1 then
b=c.resolve(d[2])
else
b=a.concat(c.getWorkingDirectory(),a.name(e))
end
if a.isDirectory(b)then
b=a.concat(b,a.name(e))
end
local c,d=a.link(f,b)
if not c then
io.stderr:write(d.."\n")
return 1
end
