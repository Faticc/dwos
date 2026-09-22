local b=require("buffer")
local e=require("unicode")
function b:getTimeout()
return self.readTimeout
end
function b:setTimeout(a)
self.readTimeout=tonumber(a)
end
function b:seek(a,c)
a=tostring(a or"cur")
assert(a=="set"or a=="cur"or a=="end",
"bad argument #1 (set, cur or end expected, got "..a..")")
c=c or 0
checkArg(2,c,"number")
assert(math.floor(c)==c,"bad argument #2 (not an integer)")
if self.mode.w or self.mode.a then
self:flush()
elseif a=="cur"then
c=c-#self.bufferRead
end
local d,f=self.stream:seek(a,c)
if d then
self.bufferRead=""
return d
end
return nil,f
end
function b:buffered_write(a)
local c,d
if self.bufferMode=="full"then
if self.bufferSize-#self.bufferWrite<#a then
c,d=self:flush()
if not c then
return nil,d
end
end
if#a>self.bufferSize then
return self.stream:write(a)
end
self.bufferWrite=self.bufferWrite..a
return self
end
local f=a:find("\n[^\n]*$")
if f or#a>self.bufferSize then
c,d=self:flush()
if not c then
return nil,d
end
end
if f then
c,d=self.stream:write(a:sub(1,f))
if not c then
return nil,d
end
a=a:sub(f+1)
end
if#a>self.bufferSize then
return self.stream:write(a)
end
self.bufferWrite=self.bufferWrite..a
return self
end
local function d(a)
if a.mode.b then return rawlen,string.sub end
return e.len,e.sub
end
function b:readNumber(h)
local g,c=d(self)
local a=""
local f
local function i()
if g(self.bufferRead)==0 then
local g,j=h(self)
if not g then
return g,j
end
end
return c(self.bufferRead,1,1)
end
local function g()
local h=c(self.bufferRead,1,1)
self.bufferRead=c(self.bufferRead,2)
return h
end
while true do
local c=i()
if not c then
break
end
if c:match("%s")then
if f then
break
end
g()
else
f=true
if not tonumber(a..c.."0")then
break
end
a=a..g()
end
end
return tonumber(a)
end
function b:readBytesOrChars(i,a)
a=math.max(a,0)
local f,j=d(self)
local d,c={},0
while c<a do
local g=a-c
if#self.bufferRead==0 then
local a,h=i(self)
if not a then
if h then
return a,h
end
return c>0 and table.concat(d)or nil
end
end
local a=self.bufferRead
if f(a)>g then
a=j(self.bufferRead,1,g)
if f(a)~=g then
a=self.bufferRead
end
end
d[#d+1]=a
c=c+f(a)
self.bufferRead=string.sub(self.bufferRead,#a+1)
end
return table.concat(d)
end
function b:readAll(d)
repeat
local a,c=d(self)
if not a and c then
return a,c
end
until not a
local a=self.bufferRead
self.bufferRead=""
return a
end
function b:formatted_read(c,...)
self.timeout=require("computer").uptime()+self.readTimeout
local function h(d,a)
if type(a)=="number"then
return self:readBytesOrChars(c,a)
end
if type(a)~="string"then
error("bad argument #"..d.." (invalid option)")
end
local f=e.sub(a,1,1)=="*"and 2 or 1
a=e.sub(a,f,f)
if a=="n"then
return self:readNumber(c)
elseif a=="l"then
return self:readLine(true,self.timeout)
elseif a=="L"then
return self:readLine(false,self.timeout)
elseif a=="a"then
return self:readAll(c)
end
error("bad argument #"..d.." (invalid format)")
end
local d={}
local a=table.pack(...)
for c=1,a.n do
local f,g=h(c,a[c])
if f then
d[c]=f
elseif g then
return nil,g
end
end
return table.unpack(d,1,a.n)
end
function b:size()
local b=self.mode.b and rawlen or e.len
local a=b(self.bufferRead)
if self.stream.size then
a=a+self.stream:size()
end
return a
end
