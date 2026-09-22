local a=require("shell")
local c=a.parse(...)
if#c<1 then
io.write("Usage: unalias <name>...\n")
return 2
end
local d=0
for b,b in ipairs(c)do
if not a.getAlias(b)then
io.stderr:write(string.format("unalias: %s: not found\n",b))
d=1
else
a.setAlias(b,nil)
end
end
return d
