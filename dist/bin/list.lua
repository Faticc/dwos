local a=require("filesystem")
local d=require("shell")
local b,c=d.parse(...)
if c.help then
io.write([[Usage: list [path]
  path:
    optional argument (defaults to ./)
  Displays a list of files in the given path with no added formatting
  Intended for low memory systems
]])
return 0
end
local e=b[1]or"."
local b,c=a.realPath(d.resolve(e))
if b and not a.exists(b)then
c="no such file or directory"
end
if c then
io.stderr:write(string.format("cannot access '%s': %s",e,tostring(c)))
return 1
end
for c in a.list(b)do
io.write(c,"\n")
end
