local q=require("unicode")
local b=require("event")
local k=require("component")
local t=require("computer")
local a={}
a.window={
fullscreen=true,
blink=true,
dx=0,
dy=0,
x=1,
y=1,
output_buffer="",
}
a.stream={}
local c={}
local function m(d,e)
c[e or d.getScreen()or false]=nil
end
b.listen("screen_resized",m)
function a.getViewport()
local b=a.window
local d=a.screen()
if b.fullscreen and d and not c[d]then
c[d]=true
b.width,b.height=b.gpu.getViewport()
end
return b.width,b.height,b.dx,b.dy,b.x,b.y
end
function a.setViewport(g,h,c,d,e,f)
checkArg(1,g,"number")
checkArg(2,h,"number")
local b=a.window
c,d,e,f=c or 0,d or 0,e or 1,f or 1
b.width,b.height,b.dx,b.dy,b.x,b.y=g,h,c,d,e,f
end
function a.gpu()
return a.window.gpu
end
function a.clear()
a.stream.scroll(math.huge)
a.setCursor(1,1)
end
function a.isAvailable()
local b=a.gpu()
return not not(b and b.getScreen())
end
function a.stream.read()
local c=require("core/cursor")
local b=c.new(a.window.cursor)
a.window.cursor=b
local d,e,f=xpcall(c.read,debug.traceback,b)
if not d or not e then
pcall(b.update,b)
end
return select(2,assert(d,e,f))
end
local h="[\27\t\r\n\a\b\v\15]"
function a.stream:write(b)
local u=a.gpu()
if not u then
return
end
local c=a.window
local f=c.cursor or{}
f.sy=f.sy or 0
f.tails=f.tails or{}
local g=require("vt100")
local v
local d=t.uptime
local e=d()
local i=c.output_buffer..b
local b,r=1,#i
while true do
if d()-e>3 then
os.sleep(0)
e=d()
end
local n=""
if i:byte(b)==27 then
local d,e=g.consume(c,i,b)
if not d then
break
end
b=b+d
n=e or""
end
f.sy=f.sy+self.scroll()
if b>r and n==""then
break
end
local d,j=c.x,c.y
local w=c.width
local g=i:find(h,b)
local h=g and i:sub(g,g)
local l=g and g-1 or r
local o=b+w*4-1
local x=l>o
local e=n..i:sub(b,x and o or l)
local o=l-b+1
if e~=""then
local s=""
local p=w-d+1
local w=not e:find("[\128-\255]")
local l=w and#e or q.wlen(e)
if x or p<l then
if w then
e=e:sub(1,math.max(p,0))
l=#e
else
e=q.wtrunc(e,p+1)
l=q.wlen(e)
end
s=l<p and" "or""
f.tails[j+c.dy-f.sy]=s
if not c.nowrap then
o=#e-#n
if o<0 then o=0 end
h="\n"
g=nil
end
end
u.set(d+c.dx,j+c.dy,e..s)
d=d+l
end
b=b+o
if g then b=g+1 end
if h=="\t"then
d=((d-1)-((d-1)%8))+9
elseif h=="\r"then
d=1
elseif h=="\n"then
d=1
j=j+1
elseif h=="\b"then
d=d-1
elseif h=="\v"then
j=j+1
elseif h=="\a"and not v then
t.beep()
v=true
elseif h=="\27"then
b=b-1
end
c.x,c.y=d,j
end
c.output_buffer=b<=r and i:sub(b)or""
return f.sy
end
function a.getCursor()
local b=a.window
return b.x,b.y
end
function a.setCursor(b,c)
checkArg(1,b,"number")
checkArg(2,c,"number")
local d=a.window
d.x,d.y=b,c
end
local c={}
function a.bind(b)
checkArg(1,b,"table")
if not c[b]then
c[b]=true
local c,d=b.setResolution,b.setViewport
b.setResolution=function(...)
m(b)
return c(...)
end
b.setViewport=function(...)
m(b)
return d(...)
end
end
local c=a.window
if c.gpu~=b then
c.gpu=b
c.keyboard=nil
a.getViewport()
end
m(b)
end
function a.keyboard()
local c=a.window
if c.keyboard then
return c.keyboard
end
local b=k.isAvailable("keyboard")and k.keyboard
b=b and b.address or"no_system_keyboard"
local d=a.screen()
if not d then
return b
end
if k.isAvailable("screen")and k.screen.address==d then
c.keyboard=b
else
c.keyboard=k.invoke(d,"getKeyboards")[1]or b
end
return c.keyboard
end
function a.screen()
local b=a.gpu()
if not b then
return nil
end
return b.getScreen()
end
function a.stream.scroll(b)
local e=a.gpu()
if not e then
return 0
end
local g,c,h,i,k,d=a.getViewport()
if not b then
if d<1 then
b=d-1
elseif d>c then
b=d-c
else
return 0
end
end
b=math.max(math.min(b,c),-c)
local j=math.abs(b)
local f=c-j
local l=i+1+(b<0 and 0 or f)
if f>0 then
e.copy(h+1,i+1+math.max(0,b),g,f,0,-b)
end
e.fill(h+1,l,g,j," ")
a.setCursor(k,math.max(1,math.min(d,c)))
return b
end
local function b()return nil,"tty: invalid operation"end
a.stream.close=b
a.stream.seek=b
a.stream.handle="tty"
return a
