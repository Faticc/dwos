local a=require("shell").parse(...)
if#a~=1 then
io.write("Usage: useradd <name>\n")
return 1
end
local b,c=require("computer").addUser(a[1])
if not b then
io.stderr:write(c.."\n")
return 1
end
