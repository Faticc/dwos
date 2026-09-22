local b=...
local f=require("filesystem")
local g=require("text")
local d={}
local function e(c)
local a=d[c]
if not a then
a=c()
d[c]=a
end
return a
end
return{
computer=function(a)
return{
beep={write=b.createWriter(a.beep,0,"number","number")},
running=b.create_toggle(a.isRunning,a.start,a.stop),
}
end,
eeprom=function(a)
return{
contents={read=a.get,write=a.set},
data={read=a.getData,write=a.setData},
checksum={read=a.getChecksum,size=function()return 8 end},
size={e(a.getSize)},
dataSize={e(a.getDataSize)},
label={write=a.setLabel,a.getLabel()},
makeReadonly={write=a.makeReadonly},
}
end,
filesystem=function(a)
return{
label={
read=function()return a.getLabel()or""end,
write=function(c)a.setLabel(g.trim(c))end,
},
isReadOnly={a.isReadOnly()},
spaceUsed={a.spaceUsed()},
spaceTotal={a.spaceTotal()},
mounts={read=function()
local c={}
for d,e in f.mounts()do
if d.address==a.address then
c[#c+1]=e
end
end
return table.concat(c,"\n")
end},
}
end,
gpu=function(a)
local c=a.getScreen()
c=c and("../"..c)
return{
viewport={write=b.createWriter(a.setViewport,2,"number","number"),a.getViewport()},
resolution={write=b.createWriter(a.setResolution,2,"number","number"),a.getResolution()},
maxResolution={a.maxResolution()},
screen={link=c,isAvailable=a.getScreen},
depth={write=b.createWriter(a.setDepth,1,"number"),a.getDepth()},
maxDepth={a.maxDepth()},
background={write=b.createWriter(a.setBackground,1,"number","boolean"),a.getBackground()},
foreground={write=b.createWriter(a.setForeground,1,"number","boolean"),a.getForeground()},
}
end,
internet=function(a)
return{
httpEnabled={a.isHttpEnabled()},
tcpEnabled={a.isTcpEnabled()},
}
end,
modem=function(a)
return{
wakeMessage={
read=function()return a.getWakeMessage()or""end,
write=function(c)return a.setWakeMessage(c)end,
},
wireless={a.isWireless()},
}
end,
screen=function(a)
return{
aspectRatio={a.getAspectRatio()},
keyboards={read=function()
local c={}
for d,d in ipairs(a.getKeyboards())do
c[#c+1]=d
end
return table.concat(c,"\n")
end},
on=b.create_toggle(a.isOn,a.turnOn,a.turnOff),
precise=b.create_toggle(a.isPrecise,a.setPrecise),
touchModeInverted=b.create_toggle(a.isTouchModeInverted,a.setTouchModeInverted),
}
end,
}
