local args=require("shell").parse(...)
if#args~=1 then
io.write("Usage: useradd <name>\n")
return 1
end
local result,reason=require("computer").addUser(args[1])
if not result then
io.stderr:write(reason.."\n")
return 1
end
