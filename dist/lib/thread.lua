local pipe=require("pipe")
local event=require("event")
local process=require("process")
local computer=require("computer")
local thread={}
local init_thread
local function waitForDeath(threads,timeout,all)
checkArg(1,threads,"table")
checkArg(2,timeout,"number","nil")
checkArg(3,all,"boolean")
timeout=timeout or math.huge
local mortician={}
local timed_out=true
local deadline=computer.uptime()+timeout
while deadline>computer.uptime()do
local dieing={}
local living=false
for _,t in ipairs(threads)do
local result=getmetatable(t).attached.data.result
local proc_ok=type(result)~="table"or result[1]
if t:status()~="running"or not proc_ok then
dieing[#dieing+1]=t
mortician[t]=true
else
living=true
end
end
if all and not living or not all and#dieing>0 then
timed_out=false
break
end
event.pull(deadline-computer.uptime())
end
for t in pairs(mortician)do
t:kill()
end
if timed_out then
return nil,"thread join timed out"
end
return true
end
function thread.waitForAny(threads,timeout)
return waitForDeath(threads,timeout,false)
end
function thread.waitForAll(threads,timeout)
return waitForDeath(threads,timeout,true)
end
local box_thread={}
function box_thread:resume()
local mt=getmetatable(self)
if mt.__status~="suspended"then
return nil,"cannot resume "..mt.__status.." thread"
end
mt.__status="running"
if coroutine.status(self.pco.root)=="suspended"and not mt.reg then
mt.register(0)
end
return true
end
function box_thread:suspend()
local mt=getmetatable(self)
if mt.__status~="running"then
return nil,"cannot suspend "..mt.__status.." thread"
end
mt.__status="suspended"
local pco_status=coroutine.status(self.pco.root)
if pco_status=="running"or pco_status=="normal"then
mt.coma()
end
return true
end
function box_thread:status()
return getmetatable(self).__status
end
function box_thread:join(timeout)
return waitForDeath({self},timeout,true)
end
function box_thread:kill()
getmetatable(self).close()
end
function box_thread:detach()
return self:attach(init_thread)
end
function box_thread:attach(parent)
local proc=process.info(parent)
local mt=assert(getmetatable(self),"thread panic: no metadata")
if not proc then return nil,"thread failed to attach, process not found"end
if mt.attached==proc then return self end
local waiting_handler
if mt.attached then
waiting_handler=mt.unregister()
process.removeHandle(self,mt.attached)
end
self.close=self.join
mt.attached=proc
process.addHandle(self,proc)
if waiting_handler then
mt.register(waiting_handler.timeout-computer.uptime())
end
return self
end
function thread.current()
local proc=process.findProcess()
local thread_root
while proc do
if thread_root then
for _,handle in ipairs(proc.data.handles)do
if handle.pco and handle.pco.root==thread_root then
return handle
end
end
else
thread_root=proc.data.coroutine_handler.root
end
proc=proc.parent
end
end
function thread.create(fp,...)
checkArg(1,fp,"function")
local mt={__status="suspended",__index=box_thread}
local t=setmetatable({},mt)
t.pco=pipe.createCoroutineStack(function(...)
mt.__status="running"
local fp_co=t.pco.create(fp)
local args=table.pack(...)
while true do
local result=table.pack(t.pco.resume(fp_co,table.unpack(args,1,args.n)))
if t.pco.status(fp_co)=="dead"then
if not result[1]then
local exit_code
local msg=result[2]
local reason="crashed"
if type(msg)=="table"then
if type(msg.reason)=="string"then
reason=msg.reason
end
exit_code=tonumber(msg.code)
elseif type(msg)=="string"then
reason=msg
end
if not exit_code then
pcall(event.onError,string.format("[thread] %s",reason))
exit_code=1
end
os.exit(exit_code)
end
break
end
args=table.pack(event.pull(table.unpack(result,2,result.n)))
end
end,nil,"thread")
function mt.private_resume(...)
mt.unregister()
if t:status()=="dead"then return end
local result=table.pack(t.pco.resume(t.pco.root,...))
if t.pco.status(t.pco.root)=="dead"then
mt.close()
end
return table.unpack(result,1,result.n)
end
mt.process=process.list[t.pco.root]
mt.process.data.handlers={}
function mt.register(timeout)
mt.id=event.register(
nil,
mt.private_resume,
timeout,
1,
mt.attached.data.handlers)
mt.reg=mt.attached.data.handlers[mt.id]
end
function mt.unregister()
local id,reg=mt.id,mt.reg
mt.id,mt.reg=nil,nil
if id and mt.attached.data.handlers[id]==reg then
mt.attached.data.handlers[id]=nil
return reg
end
end
function mt.coma()
mt.unregister()
while mt.__status=="suspended"do
t.pco.yield_past(t.pco.root,0)
end
end
function mt.process.data.pull(_,timeout)
mt.register(timeout)
local event_data=table.pack(t.pco.yield_past(t.pco.root,timeout))
mt.coma()
return table.unpack(event_data,1,event_data.n)
end
function mt.close()
local old_status=t:status()
mt.__status="dead"
process.removeHandle(t,mt.attached)
if old_status~="dead"then
event.push("thread_exit")
end
end
t:attach()
mt.private_resume(...)
return t
end
do
local handlers=event.handlers
local handlers_mt=getmetatable(handlers)
if not handlers_mt.threaded then
local root_data
for t,p in pairs(process.list)do
if not p.parent then
init_thread=t
root_data=p.data
break
end
end
assert(init_thread,"thread library panic: no init thread")
handlers_mt.threaded=true
root_data.handlers={}
root_data.pull=handlers_mt.__call
while true do
local key,value=next(handlers)
if not key then break end
root_data.handlers[key]=value
handlers[key]=nil
end
handlers_mt.__index=function(_,key)
return process.info().data.handlers[key]
end
handlers_mt.__newindex=function(_,key,value)
process.info().data.handlers[key]=value
end
handlers_mt.__pairs=function(_,...)
return pairs(process.info().data.handlers,...)
end
handlers_mt.__call=function(tbl,...)
return process.info().data.pull(tbl,...)
end
end
end
return thread
