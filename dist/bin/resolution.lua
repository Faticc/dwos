local c=require("shell")
local b=require("tty")
local a=c.parse(...)
local c=b.gpu()
if#a==0 then
local d,e=c.getViewport()
io.write(d," ",e,"\n")
return
end
if#a~=2 then
print("Usage: resolution [<width> <height>]")
return
end
local d,e=tonumber(a[1]),tonumber(a[2])
if not d or not e then
io.stderr:write("invalid width or height\n")
return 1
end
local f,a=c.setResolution(d,e)
if not f then
if a then
io.stderr:write(a.."\n")
end
return 1
end
b.clear()
