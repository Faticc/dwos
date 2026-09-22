local a=require("process")
local k=require("shell")
local h=require("buffer")
local j=require("sh").internal.command_result_as_code
local d={}
local c=assert(a.info(),"process metadata failed to load").data.coroutine_handler
function d.createCoroutineStack(b,e,f)
checkArg(1,b,"thread","function")
if type(b)=="function"then
b=assert(a.load(b,e,nil,f or"pipe"),"failed to load proc data for given function")
end
local f=assert(a.list[b],"coroutine must be a process thread else the parent process is corrupted")
local e=setmetatable({root=b},{__index=c})
f.data.coroutine_handler=e
function e.yield(...)
return c.yield(nil,...)
end
function e.yield_past(b,...)
return c.yield(b,...)
end
function e.resume(f,...)
checkArg(1,f,"thread")
local g=table.pack(...)
while true do
local b=table.pack(c.resume(f,table.unpack(g,1,g.n)))
local i=b[2]==true and e.root or b[2]
if not b[1]or c.status(f)=="dead"then
return table.unpack(b,1,b.n)
elseif i and i~=f then
g=table.pack(c.yield(table.unpack(b,2,b.n)))
else
return true,table.unpack(b,3,b.n)
end
end
end
return e
end
local l={
continue=function(c,e)
local b=table.pack(coroutine.resume(c.next))
while true do
if coroutine.status(c.next)=="dead"then
c:close()
b[1]=nil
end
if not b[1]then
if e then
os.exit(j(b[2]))
end
return c
end
if c.read_mode then
return c
end
b=table.pack(coroutine.yield_past(true,table.unpack(b,2,b.n)))
b=table.pack(coroutine.resume(c.next,table.unpack(b,1,b.n)))
end
end,
close=function(b)
b.closed=true
if coroutine.status(b.next)=="suspended"then
b:continue()
end
end,
seek=function()
return nil,"bad file descriptor"
end,
write=function(b,c)
if b.closed then
if coroutine.status(b.next)~="dead"then
io.stderr:write("attempt to use a closed stream\n")
os.exit(1)
end
else
b.buffer=b.buffer..c
return b:continue(true)
end
os.exit(0)
end,
read=function(b,c)
if b.closed then
return nil
end
if b.buffer==""then
b.read_mode=true
coroutine.yield_past(b.next)
b.read_mode=false
end
local e=string.sub(b.buffer,1,c)
b.buffer=string.sub(b.buffer,c+1)
return e
end,
}
function d.buildPipeChain(f)
local i={}
local c
for g=1,#f do
local b=f[g]
d.createCoroutineStack(b)
i[g]=b
local j=a.info(b).data.io
local e
if g<#f then
local f=setmetatable({buffer=""},{__index=l})
a.addHandle(f,a.info(b))
e=h.new("rw",f)
e:setvbuf("no",1024)
j[1]=e
end
if c then
c.stream.next=b
j[0]=c
end
c=e
end
return i
end
local g={
read=function(b,e,...)
if b.io_stream.closed then return nil end
b.ready=false
local c=table.pack(coroutine.resume(b.pco.root,e,...))
if coroutine.status(b.pco.root)=="dead"then
return nil
elseif not c[1]then
return table.unpack(c,1,c.n)
end
if not b.ready then
return b:read(coroutine.yield())
end
return c[2]
end,
write=function(b,...)
return b:read(...)
end,
close=function(b)
b.io_stream:close()
end,
}
function d.popen(e,b,i)
b=b or"r"
if b~="r"and b~="w"then
return nil,"bad argument #2: invalid mode "..tostring(b).." must be r or w"
end
local f=b=="r"
local c={}
local l=a.load(function()return k.execute(e,i)end,nil,nil,e)
local e=setmetatable({},{__index=g})
local k=a.load(function()
local i=f and 0 or""
local m=f and"read"or"write"
local g=e.io_stream
while not g.closed do
local j=table.pack(g[m](g,i))
e.ready=true
i=coroutine.yield_past(c[1],table.unpack(j,1,j.n))
end
end,nil,nil,"pipe_handler")
c[f and 1 or 2]=l
c[f and 2 or 1]=k
d.buildPipeChain(c)
local f=a.info(c[1]).data
local a=f.coroutine_handler
e.io_stream=f.io[1].stream
e.pco=a
a.resume(a.root)
local a=h.new(b,e)
a:setvbuf("no",1024)
return a
end
return d
