local a=require("shell")
local b=require("devfs")
local e=require("component")
local c,g=a.parse(...)
if#c<1 then
io.write("Usage: label [-a] <device> [<label>]\n")
io.write(" -a  Device is specified via label or address instead of by path.\n")
return 1
end
local d,i=c[1],c[2]
local a,f
if g.a then
for g in e.list()do
if g:sub(1,d:len())==d then
a,f=e.proxy(g)
break
end
local h=e.proxy(g)
if b.getDeviceLabel(h)==d then
a=h
break
end
end
else
a,f=b.getDevice(d)
end
if not a then
io.stderr:write(tostring(f).."\n")
return 1
end
if#c<2 then
local c=b.getDeviceLabel(a)
if c then
print(c)
else
io.stderr:write("no label\n")
return 1
end
else
b.setDeviceLabel(a,i)
end
