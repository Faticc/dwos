local a={}
a.list=setmetatable({},{__mode="k"})
function a.findProcess(b)
b=b or coroutine.running()
for d,c in pairs(a.list)do
if d==b then
return c
end
for d,d in pairs(c.instances)do
if d==b then
return c
end
end
end
end
function a.load(b,d,e,i)
checkArg(1,b,"string","function")
checkArg(2,d,"table","nil")
checkArg(3,e,"function","nil")
checkArg(4,i,"string","nil")
assert(type(b)=="string"or d==nil,"process cannot load function environments")
local f=a.findProcess()
d=d or f.env
local g
if type(b)=="string"then
g=function(...)
local j,h=require("filesystem"),require("shell")
local c,k=h.resolve(b,"lua")
if not c then
return require("tools/programLocations").reportNotFound(b,k)
end
os.setenv("_",c)
local h=j.open(c)
if h then
local j=(h:read(1024)or""):match("^#!([^\n]+)")
h:close()
if j then
b=j:gsub("%s","")
return g(c,...)
end
end
return assert(loadfile(c,"bt",d))(...)
end
else
g=b
end
local h
h=coroutine.create(function(...)
local c={
xpcall(function(...)
e=e or function(...)return...end
return g(e(...))
end,
function(e)
if type(e)=="table"and e.reason=="terminated"then
return e.code or 0
end
return{e,debug.traceback()}
end,...)
}
if not c[1]and type(c[2])=="table"then
xpcall(function()
local e=c[2][2]:gsub("^([^\n]*\n)[^\n]*\n[^\n]*\n","%1")
io.stderr:write(string.format("%s:\n%s",c[2][1]or"",e))
end,
function(e)
io.stderr:write("process library exception handler crashed: ",tostring(e))
end)
c[2]=128
end
a.internal.close(h,c)
return select(2,table.unpack(c))
end,true)
local c={
path=b,
command=i or tostring(b),
env=d,
data={handles={},io={}},
parent=f,
instances=setmetatable({},{__mode="v"}),
}
for b,d in pairs(f.data.io)do
c.data.io[b]=io.dup(d)
end
setmetatable(c.data,{__index=f.data})
a.list[h]=c
return h
end
function a.info(c)
checkArg(1,c,"thread","number","nil")
local b
if type(c)=="thread"then
b=a.findProcess(c)
else
local d=c or 1
b=a.findProcess()
while d>1 and b do
b=b.parent
d=d-1
end
end
if b then
return{path=b.path,env=b.env,command=b.command,data=b.data}
end
end
function a.killable(c)
local b=a.findProcess()
if not b then return false end
if c~=nil then
b.data.killable=c and true or false
end
return b.parent~=nil and b.data.killable~=false
end
a.internal={}
function a.internal.close(b,d)
checkArg(1,b,"thread")
local c=a.info(b).data
c.result=d
while c.handles[1]do
local d=table.remove(c.handles)
if d.close then
pcall(d.close,d)
end
end
a.list[b]=nil
end
function a.internal.continue(c,...)
local b={}
local d=table.pack(...)
while coroutine.status(c)~="dead"do
b=table.pack(coroutine.resume(c,table.unpack(d,1,d.n)))
if coroutine.status(c)~="dead"then
d=table.pack(coroutine.yield(table.unpack(b,2,b.n)))
elseif not b[1]then
io.stderr:write(b[2])
end
end
return table.unpack(b,2,b.n)
end
function a.removeHandle(c,d)
local b=(d or a.info()).data.handles
for d,e in ipairs(b)do
if e==c then
return table.remove(b,d)
end
end
end
function a.addHandle(b,d)
local c=b.close
local e=(d or a.info()).data.handles
e[#e+1]=b
function b:close(...)
if c then
self.close=c
c=nil
a.removeHandle(self,d)
return self:close(...)
end
end
return b
end
function a.running(c)
local b=a.info(c)
if b then
return b.path,b.env,b.command
end
end
return a
