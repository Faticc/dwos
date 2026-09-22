local d=require("component")
local g=require("text")
local c,h={},{}
local e
local a={}
function a.toArgsPack(b,i)
local j=g.split(b,{"%s"},true)
local b=#j
if b<i[1]then return nil,"insufficient args"end
local k={n=b}
for f=1,b do
local l=i[f+1]
local b=j[f]
if l=="boolean"then
if b~="true"and b~="false"then return nil,"bad boolean value"end
b=b=="true"
elseif l=="number"then
b=tonumber(b)
if not b then return nil,"bad number value"end
end
k[f]=b
end
return k
end
function a.createWriter(f,...)
local i=table.pack(...)
return function(j)
local b,k=a.toArgsPack(j,i)
if not b then return k end
return f(table.unpack(b,1,b.n))
end
end
function a.create_toggle(b,f,i)
return{
read=b and function()return tostring(b())end,
write=f and function(b)
b=g.trim(tostring(b))
local g=b=="1"or b=="true"
local j=b=="0"or b=="false"
if not g and not j then
return nil,"bad value"
end
if i then
(j and i or f)()
else
f(g)
end
end,
}
end
function a.make_link(i,j,f,b)
f=f or""
local k=b and""or"0"
local b=0
local g
repeat
g=string.format("%s%s",f,b==0 and k or tostring(b))
b=b+1
until not i[g]
i[g]={link=j}
end
local function m(b)
if c[b]==nil then
if not e then
local f=loadfile("/lib/core/devfs_adapters.lua","bt",_G)
e=f and f(a)or{}
end
local f=e[b]
if not f then
local e=loadfile("/lib/core/devfs/adapters/"..b..".lua","bt",_G)
f=e and e(a)
end
c[b]=f or false
end
return c[b]
end
local function i(b)
return function()return d.list(b)()end
end
return{
components={
list=function()
local e,f,j,k={},{},{},{}
e["by-type"]={list=function()return f end}
e["by-label"]={list=function()return j end}
e["by-address"]={list=function()return k end}
local b={}
for c,g in d.list()do
table.insert(b,select(d.isPrimary(c)and 1 or 2,1,{g,c}))
end
for c,l in ipairs(b)do
local g,c=l[1],l[2]
local l=m(g)
if l then
local b=h[c]or d.proxy(c)
h[c]=b
k[c]={
list=function()
local d=l(b)
d.address={b.address}
d.slot={b.slot}
d.type={b.type}
d.device={device=b}
return d
end,
}
local d=f[g]or{list={}}
a.make_link(d.list,"../../by-address/"..c)
f[g]=d
local d=require("devfs").getDeviceLabel(b)
if d then
a.make_link(j,"../by-address/"..c,d,true)
end
end
end
return e
end,
},
eeprom={link="components/by-type/eeprom/0/contents",isAvailable=i("eeprom")},
["eeprom-data"]={link="components/by-type/eeprom/0/data",isAvailable=i("eeprom")},
null={
open=function()
return{read=function()end,write=function()end}
end,
},
random={
open=function(a)
if a and not a:match("r")then
return nil,"read only"
end
return{
read=function(a,b)
local a={}
for c=1,b do a[c]=string.char(math.random(0,255))end
return table.concat(a)
end,
}
end,
},
zero={
open=function()
return{
read=function(a,a)return("\0"):rep(a)end,
write=function()end,
}
end,
},
}
