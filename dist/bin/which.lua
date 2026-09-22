local d=require("shell")
local b=d.parse(...)
if#b==0 then
io.write("Usage: which <program>\n")
return 255
end
for c=1,#b do
local a,e=d.resolve(b[c],"lua")
if not a then
a=d.getAlias(b[c])
if a then
a=b[c]..": aliased to "..a
end
end
if a then
print(a)
else
io.stderr:write(b[c]..": "..e.."\n")
return 1
end
end
