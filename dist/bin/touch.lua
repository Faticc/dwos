local d=require("shell")
local b=require("filesystem")
local e,a=d.parse(...)
if a.help then
print([[Usage: touch [OPTION]... FILE...
Update the modification times of each FILE to the current time.
A FILE argument that does not exist is created empty, unless -c is supplied.

  -c, --no-create    do not create any files
      --help         display this help and exit]])
return 0
elseif#e==0 then
io.stderr:write("touch: missing operand\n")
return 1
end
local f=a.c or a["no-create"]
local g=0
for a,c in ipairs(e)do
local e=d.resolve(c)
if b.isDirectory(e)then
io.stderr:write(string.format("`%s' ignored: directories not supported\n",c))
else
local a,h=b.realPath(e)
if a then
local d
if b.exists(a)or not f then
d=io.open(a,"a")
end
if not d then
a=f
h="permission denied"
else
d:close()
end
end
if not a then
io.stderr:write(string.format("touch: cannot touch `%s': %s\n",c,h))
g=1
end
end
end
return g
