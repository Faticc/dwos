do
local a,b=computer.getBootAddress(),component.invoke
local function d(e)
local f=assert(b(a,"open",e))
local g,c={},0
repeat
local h=b(a,"read",f,math.maxinteger or math.huge)
c=c+1
g[c]=h
until not h
b(a,"close",f)
return load(table.concat(g),"="..e,"bt",_G)
end
d("/lib/core/boot.lua")(d)
end
while true do
local b,a=xpcall(require("shell").getShell(),function(c)
return tostring(c).."\n"..debug.traceback()
end)
if not b then
io.stderr:write((a~=nil and tostring(a)or"unknown error").."\n")
io.write("Press any key to continue.\n")
os.sleep(0.5)
require("event").pull("key")
end
end
