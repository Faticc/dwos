local comp=require("component")
local text=require("text")
local dcache,pcache={},{}
local adapters
local adapter_api={}
function adapter_api.toArgsPack(input,pack)
local split=text.split(input,{"%s"},true)
local num=#split
if num<pack[1]then return nil,"insufficient args"end
local result={n=num}
for index=1,num do
local typename=pack[index+1]
local token=split[index]
if typename=="boolean"then
if token~="true"and token~="false"then return nil,"bad boolean value"end
token=token=="true"
elseif typename=="number"then
token=tonumber(token)
if not token then return nil,"bad number value"end
end
result[index]=token
end
return result
end
function adapter_api.createWriter(callback,...)
local types=table.pack(...)
return function(input)
local args,why=adapter_api.toArgsPack(input,types)
if not args then return why end
return callback(table.unpack(args,1,args.n))
end
end
function adapter_api.create_toggle(read,write,switch)
return{
read=read and function()return tostring(read())end,
write=write and function(value)
value=text.trim(tostring(value))
local on=value=="1"or value=="true"
local off=value=="0"or value=="false"
if not on and not off then
return nil,"bad value"
end
if switch then
(off and switch or write)()
else
write(on)
end
end,
}
end
function adapter_api.make_link(list,addr,prefix,bOmitZero)
prefix=prefix or""
local zero=bOmitZero and""or"0"
local id=0
local name
repeat
name=string.format("%s%s",prefix,id==0 and zero or tostring(id))
id=id+1
until not list[name]
list[name]={link=addr}
end
local function adapter(ctype)
if dcache[ctype]==nil then
if not adapters then
local loader=loadfile("/lib/core/devfs_adapters.lua","bt",_G)
adapters=loader and loader(adapter_api)or{}
end
local a=adapters[ctype]
if not a then
local loader=loadfile("/lib/core/devfs/adapters/"..ctype..".lua","bt",_G)
a=loader and loader(adapter_api)
end
dcache[ctype]=a or false
end
return dcache[ctype]
end
local function first(ctype)
return function()return comp.list(ctype)()end
end
return{
components={
list=function()
local dirs,types,labels,ads={},{},{},{}
dirs["by-type"]={list=function()return types end}
dirs["by-label"]={list=function()return labels end}
dirs["by-address"]={list=function()return ads end}
local hw={}
for addr,ctype in comp.list()do
table.insert(hw,select(comp.isPrimary(addr)and 1 or 2,1,{ctype,addr}))
end
for _,pair in ipairs(hw)do
local ctype,addr=pair[1],pair[2]
local make=adapter(ctype)
if make then
local proxy=pcache[addr]or comp.proxy(addr)
pcache[addr]=proxy
ads[addr]={
list=function()
local node=make(proxy)
node.address={proxy.address}
node.slot={proxy.slot}
node.type={proxy.type}
node.device={device=proxy}
return node
end,
}
local type_dir=types[ctype]or{list={}}
adapter_api.make_link(type_dir.list,"../../by-address/"..addr)
types[ctype]=type_dir
local label=require("devfs").getDeviceLabel(proxy)
if label then
adapter_api.make_link(labels,"../by-address/"..addr,label,true)
end
end
end
return dirs
end,
},
eeprom={link="components/by-type/eeprom/0/contents",isAvailable=first("eeprom")},
["eeprom-data"]={link="components/by-type/eeprom/0/data",isAvailable=first("eeprom")},
null={
open=function()
return{read=function()end,write=function()end}
end,
},
random={
open=function(mode)
if mode and not mode:match("r")then
return nil,"read only"
end
return{
read=function(_,n)
local chars={}
for i=1,n do chars[i]=string.char(math.random(0,255))end
return table.concat(chars)
end,
}
end,
},
zero={
open=function()
return{
read=function(_,n)return("\0"):rep(n)end,
write=function()end,
}
end,
},
}
