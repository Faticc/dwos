local o=require("pipe")
local d=require("event")
local c=require("process")
local e=require("computer")
local f={}
local i
local function g(j,a,b)
checkArg(1,j,"table")
checkArg(2,a,"number","nil")
checkArg(3,b,"boolean")
a=a or math.huge
local k={}
local l=true
local m=e.uptime()+a
while m>e.uptime()do
local h={}
local n=false
for a,a in ipairs(j)do
local j=getmetatable(a).attached.data.result
local p=type(j)~="table"or j[1]
if a:status()~="running"or not p then
h[#h+1]=a
k[a]=true
else
n=true
end
end
if b and not n or not b and#h>0 then
l=false
break
end
d.pull(m-e.uptime())
end
for a in pairs(k)do
a:kill()
end
if l then
return nil,"thread join timed out"
end
return true
end
function f.waitForAny(a,b)
return g(a,b,false)
end
function f.waitForAll(a,b)
return g(a,b,true)
end
local b={}
function b:resume()
local a=getmetatable(self)
if a.__status~="suspended"then
return nil,"cannot resume "..a.__status.." thread"
end
a.__status="running"
if coroutine.status(self.pco.root)=="suspended"and not a.reg then
a.register(0)
end
return true
end
function b:suspend()
local a=getmetatable(self)
if a.__status~="running"then
return nil,"cannot suspend "..a.__status.." thread"
end
a.__status="suspended"
local h=coroutine.status(self.pco.root)
if h=="running"or h=="normal"then
a.coma()
end
return true
end
function b:status()
return getmetatable(self).__status
end
function b:join(a)
return g({self},a,true)
end
function b:kill()
getmetatable(self).close()
end
function b:detach()
return self:attach(i)
end
function b:attach(a)
local g=c.info(a)
local a=assert(getmetatable(self),"thread panic: no metadata")
if not g then return nil,"thread failed to attach, process not found"end
if a.attached==g then return self end
local h
if a.attached then
h=a.unregister()
c.removeHandle(self,a.attached)
end
self.close=self.join
a.attached=g
c.addHandle(self,g)
if h then
a.register(h.timeout-e.uptime())
end
return self
end
function f.current()
local a=c.findProcess()
local e
while a do
if e then
for g,g in ipairs(a.data.handles)do
if g.pco and g.pco.root==e then
return g
end
end
else
e=a.data.coroutine_handler.root
end
a=a.parent
end
end
function f.create(e,...)
checkArg(1,e,"function")
local a={__status="suspended",__index=b}
local b=setmetatable({},a)
b.pco=o.createCoroutineStack(function(...)
a.__status="running"
local h=b.pco.create(e)
local j=table.pack(...)
while true do
local g=table.pack(b.pco.resume(h,table.unpack(j,1,j.n)))
if b.pco.status(h)=="dead"then
if not g[1]then
local h
local e=g[2]
local k="crashed"
if type(e)=="table"then
if type(e.reason)=="string"then
k=e.reason
end
h=tonumber(e.code)
elseif type(e)=="string"then
k=e
end
if not h then
pcall(d.onError,string.format("[thread] %s",k))
h=1
end
os.exit(h)
end
break
end
j=table.pack(d.pull(table.unpack(g,2,g.n)))
end
end,nil,"thread")
function a.private_resume(...)
a.unregister()
if b:status()=="dead"then return end
local e=table.pack(b.pco.resume(b.pco.root,...))
if b.pco.status(b.pco.root)=="dead"then
a.close()
end
return table.unpack(e,1,e.n)
end
a.process=c.list[b.pco.root]
a.process.data.handlers={}
function a.register(e)
a.id=d.register(
nil,
a.private_resume,
e,
1,
a.attached.data.handlers)
a.reg=a.attached.data.handlers[a.id]
end
function a.unregister()
local e,g=a.id,a.reg
a.id,a.reg=nil,nil
if e and a.attached.data.handlers[e]==g then
a.attached.data.handlers[e]=nil
return g
end
end
function a.coma()
a.unregister()
while a.__status=="suspended"do
b.pco.yield_past(b.pco.root,0)
end
end
function a.process.data.pull(e,e)
a.register(e)
local g=table.pack(b.pco.yield_past(b.pco.root,e))
a.coma()
return table.unpack(g,1,g.n)
end
function a.close()
local e=b:status()
a.__status="dead"
c.removeHandle(b,a.attached)
if e~="dead"then
d.push("thread_exit")
end
end
b:attach()
a.private_resume(...)
return b
end
do
local e=d.handlers
local a=getmetatable(e)
if not a.threaded then
local b
for g,d in pairs(c.list)do
if not d.parent then
i=g
b=d.data
break
end
end
assert(i,"thread library panic: no init thread")
a.threaded=true
b.handlers={}
b.pull=a.__call
while true do
local d,g=next(e)
if not d then break end
b.handlers[d]=g
e[d]=nil
end
a.__index=function(b,b)
return c.info().data.handlers[b]
end
a.__newindex=function(b,b,d)
c.info().data.handlers[b]=d
end
a.__pairs=function(b,...)
return pairs(c.info().data.handlers,...)
end
a.__call=function(a,...)
return c.info().data.pull(a,...)
end
end
end
return f
