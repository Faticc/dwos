local a=require("event")
local function e(...)
local b=table.pack(...)
if b.n==0 then
return nil
end
return function(...)
local c=...
if type(c)~="string"then
return false
end
for d=1,b.n do
if b[d]~=nil and c:match(b[d])then
return true
end
end
return false
end
end
function a.pullMultiple(...)
local c,b
if type(...)=="number"then
c=...
b=table.pack(select(2,...))
for d=1,b.n do
checkArg(d+1,b[d],"string","nil")
end
else
b=table.pack(...)
for d=1,b.n do
checkArg(d,b[d],"string","nil")
end
end
return a.pullFiltered(c,e(table.unpack(b,1,b.n)))
end
function a.cancel(b)
checkArg(1,b,"number")
if a.handlers[b]then
a.handlers[b]=nil
return true
end
return false
end
function a.ignore(b,c)
checkArg(1,b,"string")
checkArg(2,c,"function")
for e,d in pairs(a.handlers)do
if d.key==b and d.callback==c then
a.handlers[e]=nil
return true
end
end
return false
end
function a.onError(c)
local b=io.open("/tmp/event.log","a")
if b then
pcall(b.write,b,tostring(c),"\n")
b:close()
end
end
function a.timer(b,c,d)
checkArg(1,b,"number")
checkArg(2,c,"function")
checkArg(3,d,"number","nil")
return a.register(false,c,b,d)
end
