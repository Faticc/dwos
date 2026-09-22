local a=require("rc")
local e=require("filesystem")
local function g()
local c={}
local b,d=loadfile("/etc/rc.cfg","t",c)
if b then
b,d=xpcall(b,debug.traceback)
if b then
return c
end
end
return nil,d
end
local function h(c)
local b,d=io.open("/etc/rc.cfg","w")
if not b then
return nil,d
end
local d=require("serialization")
for f,i in pairs(c)do
b:write(tostring(f).." = "..d.serialize(i).."\n")
end
b:close()
return true
end
local function i(b,c)
if a.loaded[b]then
return a.loaded[b]
end
local d=e.concat("/etc/rc.d/",b..".lua")
local e=setmetatable({args=c},{__index=_G})
local c,f=loadfile(d,"t",e)
if not c then
return nil,string.format("%s failed to load: %s",d,f)
end
c,f=xpcall(c,debug.traceback)
if not c then
return nil,string.format("%s failed to start: %s",d,f)
end
a.loaded[b]=e
return e
end
function a.unload(b)
a.loaded[b]=nil
end
local function f(a,d,c,e,...)
local b,j=i(d,e)
if not b then
return nil,j
end
if not c then
io.output():write("Commands for service "..d.."\n")
for e,i in pairs(b)do
if type(i)=="function"then
io.output():write(tostring(e).." ")
end
end
return true
elseif type(b[c])=="function"then
local e,i=xpcall(b[c],debug.traceback,...)
if e then return true end
return nil,i
elseif c=="restart"and type(b.stop)=="function"and type(b.start)=="function"then
local e,i=xpcall(b.stop,debug.traceback,...)
if e then
e,i=xpcall(b.start,debug.traceback,...)
if e then return true end
end
return nil,i
elseif c=="enable"then
a.enabled=a.enabled or{}
for b,b in ipairs(a.enabled)do
if d==b then
return nil,"Service already enabled"
end
end
a.enabled[#a.enabled+1]=d
return h(a)
elseif c=="disable"then
a.enabled=a.enabled or{}
for b=#a.enabled,1,-1 do
if a.enabled[b]==d then
table.remove(a.enabled,b)
end
end
return h(a)
end
return nil,"Command '"..c.."' not found in daemon '"..d.."'"
end
local function d(b,c,...)
local a,e=g()
if not a then
return nil,e
end
return f(a,b,c,a[b],...)
end
local function e(h,...)
local a,b=g()
if not a then
return nil,b
end
local c={}
for b,b in ipairs(a.enabled or{})do
c[b]=table.pack(f(a,b,h,a[b],...))
end
return c
end
local a=io.stderr
local b=a.write
if select("#",...)==0 then
if _G.runlevel=="S"then
b=function(c,c)
require("event").onError(c)
end
end
local c,f=e("start")
if not c then
b(a,"rc failed to start:"..tostring(f),"\n")
return
end
for e,e in pairs(c)do
local c,f=table.unpack(e)
if not c then
b(a,f,"\n")
end
end
else
local c,e=d(...)
if not c then
b(a,e,"\n")
return 1
end
end
