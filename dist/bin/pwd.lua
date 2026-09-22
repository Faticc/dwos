local b=require("shell")
local d=require("filesystem")
local a,e=b.parse(...)
local a,c=b.getWorkingDirectory(),""
if e.P then
a,c=d.realPath(a)
end
if not a then
io.stderr:write(string.format("error retrieving current directory: %s",c))
os.exit(1)
end
io.write(a,"\n")
