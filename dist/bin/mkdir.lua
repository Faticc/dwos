local fs=require("filesystem")
local shell=require("shell")
local args,options=shell.parse(...)
if#args==0 then
io.write("Usage: mkdir [-p] <dirname1> [<dirname2> [...]]\n")
return 1
end
local ec=0
for i=1,#args do
local path=shell.resolve(args[i])
local result,reason
if options.p and fs.isDirectory(path)then
result=true
else
result,reason=fs.makeDirectory(path)
end
if not result then
if not reason then
reason=fs.exists(path)and"file or folder with that name already exists"or"unknown reason"
end
io.stderr:write("mkdir: cannot create directory '"..tostring(args[i]).."': "..reason.."\n")
ec=1
end
end
return ec
