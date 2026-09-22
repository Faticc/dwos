local d=require("event")
local a=require("filesystem")
local c=require("shell")
local b=require("computer").tmpAddress()
local e={}
local function h(f,f,g)
if g~="filesystem"or b==f then return end
local g=a.proxy(f)
if not g then return end
local b=f:sub(1,3)
while a.exists(a.concat("/mnt",b))and b:len()<f:len()do
b=f:sub(1,b:len()+1)
end
b=a.concat("/mnt",b)
a.mount(g,b)
if not a.exists("/etc/filesystem.cfg")or a.isAutorunEnabled()then
local f=c.resolve(a.concat(b,"autorun"),"lua")or
c.resolve(a.concat(b,".autorun"),"lua")
if f then
local b={f,_ENV,g}
if e then
e[#e+1]=b
else
xpcall(c.execute,d.onError,table.unpack(b))
end
end
end
end
local function f(b,b,g)
if g=="filesystem"then
if a.get(c.getWorkingDirectory()).address==b then
c.setWorkingDirectory("/")
end
a.umount(b)
end
end
d.listen("init",function()
for a,a in ipairs(e)do
xpcall(c.execute,d.onError,table.unpack(a))
end
e=nil
return false
end)
d.listen("component_added",h)
d.listen("component_removed",f)
