local d=require("computer")
local e=require("filesystem")
local i=math.maxinteger or math.huge
function loadfile(a,...)
if a:sub(1,1)~="/"then
a=(os.getenv("PWD")or"/").."/"..a
end
local b,c=e.open(a)
if not b then
return nil,c
end
local f,c={},0
while true do
local g,h=b:read(i)
if not g then
b:close()
if h then
return nil,h
end
break
end
c=c+1
f[c]=g
end
return load(table.concat(f),"="..a,...)
end
function dofile(a)
local b,c=loadfile(a)
if not b then
return error(c..":"..a,0)
end
return b()
end
function print(...)
local a=table.pack(...)
local b={}
for c=1,a.n do
b[c]=assert(tostring(a[c]),"'tostring' must return a string to 'print'")
end
local c=io.stdout
c:write(table.concat(b,"\t",1,a.n),"\n")
c:flush()
end
local b=require("process")
local a=coroutine
_G.coroutine=setmetatable({
resume=function(c,...)
local f=b.info(c)
return(f and f.data.coroutine_handler.resume or a.resume)(c,...)
end,
},{
__index=function(c,f)
local c=b.info(a.running())
return(c and c.data.coroutine_handler or a)[f]
end,
})
package.loaded.coroutine=_G.coroutine
local f=_G.load
_G.load=function(g,h,i,c)
local j=c and c.load or _G.load
local k=c and setmetatable({
load=function(l,m,n,o)
return j(l,m,n,o or c)
end,
},{
__index=c,
__pairs=function(...)return pairs(c,...)end,
__newindex=function(j,j,l)c[j]=l end,
})
return f(g,h,i,k or b.info().env)
end
local f=a.create
a.create=function(g,h)
local c=f(g)
if not h then
table.insert(b.findProcess().instances,c)
end
return c
end
a.wrap=function(c)
local f=coroutine.create(c)
return function(...)
return select(2,coroutine.resume(f,...))
end
end
b.list[a.running()]={
path="/init.lua",
command="init",
env=_ENV,
data={
vars={},
handles={},
io={},
coroutine_handler=a,
signal=error,
},
instances=setmetatable({},{__mode="v"}),
}
local c=e.open
e.open=function(...)
local a=table.pack(c(...))
if a[1]then
b.addHandle(a[1])
end
return table.unpack(a,1,a.n)
end
local f=require("event")
local c=b.info
function os.getenv(a)
local b=c().data.vars
if not a then
return b
elseif a=="#"then
return#b
end
return b[a]
end
function os.setenv(b,a)
checkArg(1,b,"string","number")
if a~=nil then
a=tostring(a)
end
c().data.vars[b]=a
return a
end
function os.sleep(a)
checkArg(1,a,"number","nil")
local b=d.uptime()+(a or 0)
repeat
f.pull(b-d.uptime())
until d.uptime()>=b
end
os.setenv("PATH","/bin:/usr/bin:/home/bin:.")
os.setenv("TMP","/tmp")
os.setenv("TMPDIR","/tmp")
if d.tmpAddress()then
e.mount(d.tmpAddress(),"/tmp")
end
require("package").delay(os,"/lib/core/full_filesystem.lua")
local d=require("buffer")
local a=require("tty").stream
local e=d.new("r",a)
local b=d.new("w",a)
local c=d.new("w",setmetatable({
write=function(d,d)
return a:write("\27[31m"..d.."\27[37m")
end,
},{__index=a}))
b:setvbuf("no")
c:setvbuf("no")
e.tty,b.tty,c.tty=true,true,true
e.close=a.close
b.close=a.close
c.close=a.close
local d=getmetatable(io)or{}
d.__index=function(a,a)
return a=="stdin"and io.input()or
a=="stdout"and io.output()or
a=="stderr"and io.error()or
nil
end
setmetatable(io,d)
io.input(e)
io.output(b)
io.error(c)
