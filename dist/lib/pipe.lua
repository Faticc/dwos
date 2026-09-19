local process=require("process")
local shell=require("shell")
local buffer=require("buffer")
local command_result_as_code=require("sh").internal.command_result_as_code
local pipe={}
local _root_co=assert(process.info(),"process metadata failed to load").data.coroutine_handler
function pipe.createCoroutineStack(root,env,name)
checkArg(1,root,"thread","function")
if type(root)=="function"then
root=assert(process.load(root,env,nil,name or"pipe"),"failed to load proc data for given function")
end
local proc=assert(process.list[root],"coroutine must be a process thread else the parent process is corrupted")
local pco=setmetatable({root=root},{__index=_root_co})
proc.data.coroutine_handler=pco
function pco.yield(...)
return _root_co.yield(nil,...)
end
function pco.yield_past(co,...)
return _root_co.yield(co,...)
end
function pco.resume(co,...)
checkArg(1,co,"thread")
local args=table.pack(...)
while true do
local result=table.pack(_root_co.resume(co,table.unpack(args,1,args.n)))
local target=result[2]==true and pco.root or result[2]
if not result[1]or _root_co.status(co)=="dead"then
return table.unpack(result,1,result.n)
elseif target and target~=co then
args=table.pack(_root_co.yield(table.unpack(result,2,result.n)))
else
return true,table.unpack(result,3,result.n)
end
end
end
return pco
end
local pipe_stream={
continue=function(self,exit)
local result=table.pack(coroutine.resume(self.next))
while true do
if coroutine.status(self.next)=="dead"then
self:close()
result[1]=nil
end
if not result[1]then
if exit then
os.exit(command_result_as_code(result[2]))
end
return self
end
if self.read_mode then
return self
end
result=table.pack(coroutine.yield_past(true,table.unpack(result,2,result.n)))
result=table.pack(coroutine.resume(self.next,table.unpack(result,1,result.n)))
end
end,
close=function(self)
self.closed=true
if coroutine.status(self.next)=="suspended"then
self:continue()
end
end,
seek=function()
return nil,"bad file descriptor"
end,
write=function(self,value)
if self.closed then
if coroutine.status(self.next)~="dead"then
io.stderr:write("attempt to use a closed stream\n")
os.exit(1)
end
else
self.buffer=self.buffer..value
return self:continue(true)
end
os.exit(0)
end,
read=function(self,n)
if self.closed then
return nil
end
if self.buffer==""then
self.read_mode=true
coroutine.yield_past(self.next)
self.read_mode=false
end
local result=string.sub(self.buffer,1,n)
self.buffer=string.sub(self.buffer,n+1)
return result
end,
}
function pipe.buildPipeChain(progs)
local chain={}
local prev_piped_stream
for i=1,#progs do
local thread=progs[i]
pipe.createCoroutineStack(thread)
chain[i]=thread
local pio=process.info(thread).data.io
local piped_stream
if i<#progs then
local handle=setmetatable({buffer=""},{__index=pipe_stream})
process.addHandle(handle,process.info(thread))
piped_stream=buffer.new("rw",handle)
piped_stream:setvbuf("no",1024)
pio[1]=piped_stream
end
if prev_piped_stream then
prev_piped_stream.stream.next=thread
pio[0]=prev_piped_stream
end
prev_piped_stream=piped_stream
end
return chain
end
local chain_stream={
read=function(self,value,...)
if self.io_stream.closed then return nil end
self.ready=false
local ret=table.pack(coroutine.resume(self.pco.root,value,...))
if coroutine.status(self.pco.root)=="dead"then
return nil
elseif not ret[1]then
return table.unpack(ret,1,ret.n)
end
if not self.ready then
return self:read(coroutine.yield())
end
return ret[2]
end,
write=function(self,...)
return self:read(...)
end,
close=function(self)
self.io_stream:close()
end,
}
function pipe.popen(prog,mode,env)
mode=mode or"r"
if mode~="r"and mode~="w"then
return nil,"bad argument #2: invalid mode "..tostring(mode).." must be r or w"
end
local r=mode=="r"
local chain={}
local cmd_proc=process.load(function()return shell.execute(prog,env)end,nil,nil,prog)
local stream=setmetatable({},{__index=chain_stream})
local pipe_proc=process.load(function()
local n=r and 0 or""
local key=r and"read"or"write"
local ios=stream.io_stream
while not ios.closed do
local ret=table.pack(ios[key](ios,n))
stream.ready=true
n=coroutine.yield_past(chain[1],table.unpack(ret,1,ret.n))
end
end,nil,nil,"pipe_handler")
chain[r and 1 or 2]=cmd_proc
chain[r and 2 or 1]=pipe_proc
pipe.buildPipeChain(chain)
local cmd_data=process.info(chain[1]).data
local cmd_stack=cmd_data.coroutine_handler
stream.io_stream=cmd_data.io[1].stream
stream.pco=cmd_stack
cmd_stack.resume(cmd_stack.root)
local buffered_stream=buffer.new(mode,stream)
buffered_stream:setvbuf("no",1024)
return buffered_stream
end
return pipe
