local a=require("component")
local j=require("computer")
local g=require("event")
local c={}
local b={}
setmetatable(a,{
__index=function(d,d)
return a.getPrimary(d)
end,
__pairs=function(h)
local d=false
return function(e,e)
if d then
return next(b,e)
end
local f,i=next(h,e)
if not f then
d=true
return next(b)
end
return f,i
end
end,
})
function a.get(d,e)
checkArg(1,d,"string")
checkArg(2,e,"string","nil")
for f in a.list(e,true)do
if f:sub(1,d:len())==d then
return f
end
end
return nil,"no such component"
end
function a.isAvailable(d)
checkArg(1,d,"string")
if not b[d]and not c[d]then
a.setPrimary(d,a.list(d,true)())
end
return b[d]~=nil
end
function a.isPrimary(e)
local d=a.type(e)
if d and a.isAvailable(d)then
return b[d].address==e
end
return false
end
function a.getPrimary(d)
checkArg(1,d,"string")
assert(a.isAvailable(d),"no primary '"..d.."' available")
return b[d]
end
function a.setPrimary(d,e)
checkArg(1,d,"string")
checkArg(2,e,"string","nil")
if e~=nil then
e=a.get(e,d)
assert(e,"no such component")
end
local h=b[d]
if h and e==h.address then
return
end
local f=c[d]
if f and e==f.address then
return
end
if f then
g.cancel(f.timer)
end
b[d]=nil
c[d]=nil
local i=e and a.proxy(e)or nil
if h then
j.pushSignal("component_unavailable",d)
end
if i then
if h or f then
c[d]={
address=e,
proxy=i,
timer=g.timer(0.1,function()
c[d]=nil
b[d]=i
j.pushSignal("component_available",d)
end),
}
else
b[d]=i
j.pushSignal("component_available",d)
end
end
end
local function i(d,f,d)
local e=b[d]or(c[d]and c[d].proxy)
if e then
if d=="screen"then
if#e.getKeyboards()==0 then
local h=a.invoke(f,"getKeyboards")[1]
if h then
a.setPrimary("keyboard",h)
e=nil
end
end
elseif d=="keyboard"and f~=e.address then
local h=b.screen or(c.screen and c.screen.proxy)
if h then
e=f~=h.getKeyboards()[1]
end
end
end
if not e then
a.setPrimary(d,f)
end
end
local function f(d,e,d)
if b[d]and b[d].address==e or
c[d]and c[d].address==e then
local e=a.list(d,true)()
a.setPrimary(d,e)
if d=="screen"and e then
local e=b.screen or(c.screen and c.screen.proxy)
if e then
local d=e.getKeyboards()[1]
local e=b.keyboard or c.keyboard
if d and(not e or e.address~=d)then
a.setPrimary("keyboard",d)
end
end
end
end
end
g.listen("component_added",i)
g.listen("component_removed",f)
if _G.boot_screen then
a.setPrimary("screen",_G.boot_screen)
end
_G.boot_screen=nil
