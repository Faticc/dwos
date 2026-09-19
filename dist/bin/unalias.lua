local shell=require("shell")
local args=shell.parse(...)
if#args<1 then
io.write("Usage: unalias <name>...\n")
return 2
end
local e=0
for _,arg in ipairs(args)do
if not shell.getAlias(arg)then
io.stderr:write(string.format("unalias: %s: not found\n",arg))
e=1
else
shell.setAlias(arg,nil)
end
end
return e
