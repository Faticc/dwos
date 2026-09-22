local a=require("shell").parse(...)
if#a~=1 then
io.write("Usage: userdel <name>\n")
return 1
end
if not require("computer").removeUser(a[1])then
io.stderr:write("no such user\n")
return 1
end
