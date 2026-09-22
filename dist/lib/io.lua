local a={}
function a.close(b)
return(b or a.output()):close()
end
function a.flush()
return a.output():flush()
end
function a.lines(b,...)
if not b then
return a.input():lines()
end
local c,d=a.open(b)
if not c then
error(d,2)
end
local d=table.pack(...)
return function()
local b=table.pack(c:read(table.unpack(d,1,d.n)))
if not b[1]then
if b[2]then
error(b[2],2)
end
c:close()
return nil
end
return table.unpack(b,1,b.n)
end
end
function a.open(c,b)
local d=require("shell").resolve(c)
local c,e=require("filesystem").open(d,b)
if c then
return require("buffer").new(b,c)
end
return nil,e
end
function a.stream(c,b,e)
checkArg(1,c,"number")
checkArg(2,b,"table","string","nil")
assert(c>=0,"fd must be >= 0. 0 is input, 1 is stdout, 2 is stderr")
local d=require("process").info().data.io
if b then
if type(b)=="string"then
b=assert(a.open(b,e))
end
d[c]=b
end
return d[c]
end
function a.input(b)return a.stream(0,b,"r")end
function a.output(b)return a.stream(1,b,"w")end
function a.error(b)return a.stream(2,b,"w")end
function a.popen(b,c,d)
return require("pipe").popen(b,c,d)
end
function a.read(...)
return a.input():read(...)
end
function a.tmpfile()
local b=os.tmpname()
if b then
return a.open(b,"a")
end
end
function a.type(b)
if type(b)=="table"and getmetatable(b)=="file"then
return b.stream.handle and"file"or"closed file"
end
return nil
end
function a.write(...)
return a.output():write(...)
end
local e={
__index=function(d,b)
local c=d.fd[b]
if b~="close"and type(c)~="function"then return c end
return function(d,...)
if b=="close"or d._closed then d._closed=true return end
return c(d.fd,...)
end
end,
__newindex=function(b,c,d)
b.fd[c]=d
end,
}
function a.dup(b)
return setmetatable({fd=b,_closed=false},e)
end
return a
