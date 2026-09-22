local i=require("buffer")
local d=require("component")
local a={}
function a.request(f,b,g,h)
checkArg(1,f,"string")
checkArg(2,b,"string","table","nil")
checkArg(3,g,"table","nil")
checkArg(4,h,"string","nil")
if not d.isAvailable("internet")then
error("no primary internet card found",2)
end
local j=d.internet
local c
if type(b)=="string"then
c=b
elseif type(b)=="table"then
local e={}
for k,l in pairs(b)do
e[#e+1]=tostring(k).."="..tostring(l)
end
c=table.concat(e,"&")
end
local b,e=j.request(f,c,g,h)
if not b then
error(e,2)
end
return setmetatable({
["()"]="function():string -- Tries to read data from the socket stream and return the read byte array.",
close=setmetatable({},{
__call=b.close,
__tostring=function()return"function() -- closes the connection"end,
}),
},{
__call=function()
while true do
local c,e=b.read()
if not c then
b.close()
if e then
error(e,2)
end
return nil
elseif#c>0 then
return c
end
os.sleep(0)
end
end,
__index=b,
})
end
local b={}
function b:close()
if self.socket then
self.socket.close()
self.socket=nil
end
end
function b:seek()
return nil,"bad file descriptor"
end
function b:read(c)
if not self.socket then
return nil,"connection is closed"
end
return self.socket.read(c)
end
function b:write(c)
if not self.socket then
return nil,"connection is closed"
end
while#c>0 do
local e,f=self.socket.write(c)
if not e then
return nil,f
end
c=string.sub(c,e+1)
end
return true
end
function a.socket(c,e)
checkArg(1,c,"string")
checkArg(2,e,"number","nil")
if e then
c=c..":"..e
end
local e=d.internet
local d,f=e.connect(c)
if not d then
return nil,f
end
return setmetatable({inet=e,socket=d},{__index=b,__metatable="socketstream"})
end
function a.open(c,d)
local b,e=a.socket(c,d)
if not b then
return nil,e
end
return i.new("rwb",b)
end
return a
