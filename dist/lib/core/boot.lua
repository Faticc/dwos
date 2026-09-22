local g=...
_G._OSVERSION="DwOS 1.0"
local d,b,n=component,computer,unicode
_G.runlevel="S"
local c=b.shutdown
b.runlevel=function()return _G.runlevel end
b.shutdown=function(a)
_G.runlevel=a and 6 or 0
if os.sleep then
b.pushSignal("shutdown")
os.sleep(0.1)
end
c(a)
end
local a
do
local c=d.list("screen",true)()
a=c and d.list("gpu",true)()
if a then
a=d.proxy(a)
if not a.getScreen()then a.bind(c)end
_G.boot_screen=a.getScreen()
local c,e=a.maxResolution()
a.setResolution(c,e)
a.setBackground(0x000000)
a.setForeground(0xFFFFFF)
a.fill(1,1,c,e," ")
end
end
local k=g("/lib/gfx.lua")()
local c
if a then
local e,f=pcall(function()return g("/lib/core/splash.lua")(k).start(a)end)
c=e and f or nil
end
local h,o=b.uptime,b.pullSignal
local l=h()
local f,i=1,0
local function e(j,m)
i=m or i
if c then
local m=pcall(c.status,c,j,i)
if not m then c=nil end
elseif a and j then
local m,i=a.getResolution()
a.set(1,f,j)
if f==i then
a.copy(1,2,m,i-1,0,-1)
a.fill(1,i,m,1," ")
else
f=f+1
end
end
if h()-l>1 then
local a=table.pack(o(0))
if a.n>0 then b.pushSignal(table.unpack(a,1,a.n))end
l=h()
end
end
e("Booting ".._OSVERSION.."...",0.02)
local function f(a)
local h,i=g(a)
if not h then error(i)end
local a=table.pack(pcall(h))
if not a[1]then error(a[2])end
return table.unpack(a,2,a.n)
end
e("Packages",0.08)
local g=f("/lib/package.lua")
do
_G.component,_G.computer,_G.process,_G.unicode=nil,nil,nil,nil
_G.package=g
local a=g.loaded
a.component=d
a.computer=b
a.unicode=n
a.gfx=k
a.buffer=f("/lib/buffer.lua")
a.filesystem=f("/lib/filesystem.lua")
_G.io=f("/lib/io.lua")
end
e("File system",0.16)
require("filesystem").mount(b.getBootAddress(),"/")
local a={}
for g,g in ipairs(d.invoke(b.getBootAddress(),"list","boot"))do
if g:sub(-1)~="/"then a[#a+1]="boot/"..g end
end
table.sort(a)
for g=1,#a do
e(a[g],0.2+0.6*(g-1)/#a)
f(a[g])
end
e("Components",0.85)
for a,f in d.list()do
b.pushSignal("component_added",a,f)
end
e("Starting",0.93)
b.pushSignal("init")
require("event").pull(1,"init")
_G.runlevel=1
if c then pcall(c.finish,c)end
