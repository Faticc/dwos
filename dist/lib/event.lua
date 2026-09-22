local d=require("computer")
local f=require("keyboard")
local a={}
local c={}
local g=-math.huge
a.handlers=c
function a.register(b,i,j,k,e)
local h={
key=b,
times=k or 1,
callback=i,
interval=j or math.huge,
}
h.timeout=d.uptime()+h.interval
e=e or c
local b=0
repeat
b=b+1
until not e[b]
e[b]=h
return b
end
local b=d.pullSignal
setmetatable(c,{__call=function(e,...)return b(...)end})
d.pullSignal=function(b)
checkArg(1,b,"number","nil")
b=b or math.huge
local e=d.uptime
local h=e()+b
repeat
if f.isControlDown()and f.isKeyDown(f.keys.c)and e()-g>1 then
g=e()
if f.isAltDown()then
local b=require("process").findProcess()
if b and b.parent and b.data.killable~=false then
b.data.signal("interrupted",0)
return
end
end
a.push("interrupted",g)
end
local b=h
for f,f in pairs(c)do
if f.timeout<b then b=f.timeout end
end
local f=table.pack(c(b-e()))
local i=f[1]
local j={}
for b,g in pairs(c)do
j[b]=g
end
for g,b in pairs(j)do
if b.key==nil or b.key==i or e()>=b.timeout then
b.times=b.times-1
b.timeout=b.timeout+b.interval
if b.times<=0 and c[g]==b then
c[g]=nil
end
local k,j=pcall(b.callback,table.unpack(f,1,f.n))
if not k then
pcall(a.onError,j)
elseif j==false and c[g]==b then
c[g]=nil
end
end
end
if i then
return table.unpack(f,1,f.n)
end
until e()>=h
end
local function g(e,...)
local b=table.pack(...)
if e==nil and b.n==0 then
return nil
end
return function(...)
local f=table.pack(...)
if e and not(type(f[1])=="string"and f[1]:match(e))then
return false
end
for e=1,b.n do
if b[e]~=nil and b[e]~=f[e+1]then
return false
end
end
return true
end
end
function a.listen(b,e)
checkArg(1,b,"string")
checkArg(2,e,"function")
for f,f in pairs(c)do
if f.key==b and f.callback==e then
return false
end
end
return a.register(b,e,math.huge,math.huge)
end
function a.pull(...)
local b=table.pack(...)
if type(b[1])=="string"then
return a.pullFiltered(g(...))
end
checkArg(1,b[1],"number","nil")
checkArg(2,b[2],"string","nil")
return a.pullFiltered(b[1],g(select(2,...)))
end
function a.pullFiltered(...)
local b=table.pack(...)
local e,c=math.huge
if type(b[1])=="function"then
c=b[1]
else
checkArg(1,b[1],"number","nil")
checkArg(2,b[2],"function","nil")
e=b[1]
c=b[2]
end
local b=d.uptime()+(e or math.huge)
repeat
local f=b-d.uptime()
if f<=0 then
break
end
local b=table.pack(d.pullSignal(f))
if b.n>0 then
if not(e or c)or c==nil or c(table.unpack(b,1,b.n))then
return table.unpack(b,1,b.n)
end
end
until b.n==0
end
a.push=d.pushSignal
require("package").delay(a,"/lib/core/full_event.lua")
return a
