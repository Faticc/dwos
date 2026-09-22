local a=require("component")
local c=require("shell")
local b=c.parse(...)
if#b==0 then
io.write("Usage: primary <type> [<address>]\n")
io.write("Note that the address may be abbreviated.\n")
return 1
end
local c=b[1]
if#b>1 then
local d=b[2]
if not a.get(d)then
io.stderr:write("no component with this address\n")
return 1
end
a.setPrimary(c,d)
os.sleep(0.1)
end
if a.isAvailable(c)then
io.write(a.getPrimary(c).address,"\n")
else
io.stderr:write("no primary component for this type\n")
return 1
end
