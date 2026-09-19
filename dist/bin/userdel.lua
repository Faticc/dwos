local args=require("shell").parse(...)
if#args~=1 then
io.write("Usage: userdel <name>\n")
return 1
end
if not require("computer").removeUser(args[1])then
io.stderr:write("no such user\n")
return 1
end
