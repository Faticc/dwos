local raw_loadfile=...
_G._OSVERSION="DwOS 1.0"
local component,computer,unicode=component,computer,unicode
_G.runlevel="S"
local shutdown=computer.shutdown
computer.runlevel=function()return _G.runlevel end
computer.shutdown=function(reboot)
_G.runlevel=reboot and 6 or 0
if os.sleep then
computer.pushSignal("shutdown")
os.sleep(0.1)
end
shutdown(reboot)
end
local gpu
do
local screen=component.list("screen",true)()
gpu=screen and component.list("gpu",true)()
if gpu then
gpu=component.proxy(gpu)
if not gpu.getScreen()then gpu.bind(screen)end
_G.boot_screen=gpu.getScreen()
local w,h=gpu.maxResolution()
gpu.setResolution(w,h)
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1,1,w,h," ")
end
end
local gfx=raw_loadfile("/lib/gfx.lua")()
local splash
if gpu then
local ok,s=pcall(function()return raw_loadfile("/lib/core/splash.lua")(gfx).start(gpu)end)
splash=ok and s or nil
end
local uptime,pull=computer.uptime,computer.pullSignal
local last_sleep=uptime()
local line,progress=1,0
local function status(msg,frac)
progress=frac or progress
if splash then
local ok=pcall(splash.status,splash,msg,progress)
if not ok then splash=nil end
elseif gpu and msg then
local w,h=gpu.getResolution()
gpu.set(1,line,msg)
if line==h then
gpu.copy(1,2,w,h-1,0,-1)
gpu.fill(1,h,w,1," ")
else
line=line+1
end
end
if uptime()-last_sleep>1 then
local signal=table.pack(pull(0))
if signal.n>0 then computer.pushSignal(table.unpack(signal,1,signal.n))end
last_sleep=uptime()
end
end
status("Booting ".._OSVERSION.."...",0.02)
local function dofile(file)
local program,reason=raw_loadfile(file)
if not program then error(reason)end
local result=table.pack(pcall(program))
if not result[1]then error(result[2])end
return table.unpack(result,2,result.n)
end
status("Packages",0.08)
local package=dofile("/lib/package.lua")
do
_G.component,_G.computer,_G.process,_G.unicode=nil,nil,nil,nil
_G.package=package
local loaded=package.loaded
loaded.component=component
loaded.computer=computer
loaded.unicode=unicode
loaded.gfx=gfx
loaded.buffer=dofile("/lib/buffer.lua")
loaded.filesystem=dofile("/lib/filesystem.lua")
_G.io=dofile("/lib/io.lua")
end
status("File system",0.16)
require("filesystem").mount(computer.getBootAddress(),"/")
local scripts={}
for _,file in ipairs(component.invoke(computer.getBootAddress(),"list","boot"))do
if file:sub(-1)~="/"then scripts[#scripts+1]="boot/"..file end
end
table.sort(scripts)
for i=1,#scripts do
status(scripts[i],0.2+0.6*(i-1)/#scripts)
dofile(scripts[i])
end
status("Components",0.85)
for c,t in component.list()do
computer.pushSignal("component_added",c,t)
end
status("Starting",0.93)
computer.pushSignal("init")
require("event").pull(1,"init")
_G.runlevel=1
if splash then pcall(splash.finish,splash)end
