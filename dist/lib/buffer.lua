local c=require("computer")
local f=require("unicode")
local a={}
local g={__index=a,__metatable="file"}
function a.new(b,d)
local e={
closed=false,
tty=false,
mode={},
stream=d,
bufferRead="",
bufferWrite="",
bufferSize=math.max(512,math.min(8*1024,c.freeMemory()/8)),
bufferMode="full",
readTimeout=math.huge,
}
b=b or"r"
for h=1,f.len(b)do
e.mode[f.sub(b,h,h)]=true
end
d.close=setmetatable({close=d.close,parent=e},{__call=a.close})
return setmetatable(e,g)
end
function a:close()
if getmetatable(self)==g.__metatable then
return self.stream:close()
end
local b=self.parent
if b.mode.w or b.mode.a then
b:flush()
end
b.closed=true
return self.close(b.stream)
end
function a:flush()
if#self.bufferWrite>0 then
local b=self.bufferWrite
self.bufferWrite=""
local d,e=self.stream:write(b)
if not d then
return nil,e or"bad file descriptor"
end
end
return self
end
function a:lines(...)
local d=table.pack(...)
return function()
local b=table.pack(self:read(table.unpack(d,1,d.n)))
if not b[1]and b[2]then
error(b[2])
end
return table.unpack(b,1,b.n)
end
end
local function f(b)
if c.uptime()>b.timeout then
error("timeout")
end
local d,e=b.stream:read(math.max(1,b.bufferSize))
if d then
b.bufferRead=b.bufferRead..d
return b
end
return d,e
end
function a:readLine(h,b)
self.timeout=b or(c.uptime()+self.readTimeout)
local g=1
while true do
local c=self.bufferRead
local b=c:find("[\r\n]",g)
local d=b and c:sub(b,b)
local e=d=="\r"
if b and(not e or b<#c)then
if e and c:sub(b+1,b+1)=="\n"then
d="\r\n"
end
local i=c:sub(1,b-1)..(h and""or d)
self.bufferRead=c:sub(b+#d)
return i
end
g=#self.bufferRead-(e and 1 or 0)
local b,c=f(self)
if not b then
if c then
return b,c
end
b=#self.bufferRead>0 and self.bufferRead or nil
self.bufferRead=""
return b
end
end
end
function a:read(...)
if not self.mode.r then
return nil,"read mode was not enabled for this stream"
end
if self.mode.w or self.mode.a then
self:flush()
end
if select("#",...)==0 then
return self:readLine(true)
end
return self:formatted_read(f,...)
end
function a:setvbuf(b,c)
b=b or self.bufferMode
c=c or self.bufferSize
assert(b=="no"or b=="full"or b=="line",
"bad argument #1 (no, full or line expected, got "..tostring(b)..")")
assert(b=="no"or type(c)=="number",
"bad argument #2 (number expected, got "..type(c)..")")
self.bufferMode=b
self.bufferSize=c
return self.bufferMode,self.bufferSize
end
function a:write(...)
if self.closed then
return nil,"bad file descriptor"
end
if not self.mode.w and not self.mode.a then
return nil,"write mode was not enabled for this stream"
end
local b=table.pack(...)
for c=1,b.n do
if type(b[c])=="number"then
b[c]=tostring(b[c])
end
checkArg(c,b[c],"string")
end
local f=self.bufferMode=="no"
for e=1,b.n do
local c,d
if f then
c,d=self.stream:write(b[e])
else
c,d=a.buffered_write(self,b[e])
end
if not c then
return nil,d
end
end
return self
end
require("package").delay(a,"/lib/core/full_buffer.lua")
return a
