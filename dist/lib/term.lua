local a=require("tty")
local h=require("computer")
local e=require("process")
local l=require("event")
local i=require("core/cursor")
local j=require("keyboard").keys
local b=setmetatable({internal={}},{__index=a})
local function f(d,g,...)
local c=e.info().data
if not c.window or not d then
return g(...)
end
local k=rawget(c,"window")
c.window=d
local d=table.pack(g(...))
c.window=k
return table.unpack(d,1,d.n)
end
function b.internal.open(...)
local g,k,m,n=...
local d={fullscreen=select("#",...)==0,blink=true,output_buffer=""}
setmetatable(d,{
__index=function(o,c)
c=c=="w"and"width"or c=="h"and"height"or c
return rawget(o,c)
end,
__newindex=function(o,c,p)
c=c=="w"and"width"or c=="h"and"height"or c
return rawset(o,c,p)
end,
})
if rawget(a,"window")then
for c,c in pairs(e.list)do
if not c.parent then
c.data.window=a.window
break
end
end
a.window=nil
setmetatable(a,{
__index=function(c,c)
if c=="window"then
return e.info().data.window
end
end,
})
end
f(d,a.setViewport,m,n,g,k,1,1)
f(d,a.bind,a.gpu())
return d
end
local function m(d,g)
local c=d or{}
c.hint=g.hint or c.hint
local d=g.filter or c.filter
if d then
if type(d)=="string"then
local e=d
d=function(k)return k:match(e)end
end
function c:handle(k,n,e)
if k=="key_down"and(e==j.enter or e==j.numpadenter)then
if not d(self.data)then
h.beep(2000,0.1)
return true
end
end
return self.super.handle(self,k,n,e)
end
end
local e=g.pwchar or c.pwchar
local j=g.dobreak==false or c.dobreak==false
if e or j then
if type(e)=="string"then
local d=e
e=function(g)return g:gsub(".",d)end
end
function c:echo(d,...)
if e and type(d)=="string"and#d>0 and not d:match("^\27")then
d=e(d)
elseif j and d=="\n"then
d=""
end
return self.super.echo(self,d,...)
end
end
return i.new(c,c.nowrap and i.horizontal)
end
function b.write(c,d)
io.stdout:flush()
local e=a.window.nowrap
a.window.nowrap=d==false
io.write(c)
io.stdout:flush()
a.window.nowrap=e
end
function b.read(c,d,e,g,j)
a.window.cursor=m(c,{
dobreak=d,
pwchar=g,
filter=j,
hint=e,
})
return io.stdin:readLine(false)
end
function b.getGlobalArea()
local c,d,e,g=a.getViewport()
return e+1,g+1,c,d
end
function b.clearLine()
b.write("\27[2K\27[999D")
end
function b.setCursorBlink(c)
a.window.blink=c
end
function b.getCursorBlink()
return a.window.blink
end
function b.pull(...)
local c=table.pack(...)
local d=math.huge
if type(c[1])=="number"then
d=h.uptime()+table.remove(c,1)
c.n=c.n-1
end
local e=i.new()
while d>=h.uptime()do
e:echo()
local d=table.pack(l.pull(.5,table.unpack(c,1,c.n)))
e:echo(not d[1])
if d.n>1 then return table.unpack(d,1,d.n)end
end
end
function b.bind(c,d)
return f(d,a.bind,c)
end
b.scroll=a.stream.scroll
b.internal.run_in_window=f
return b
