local shell=require("shell")
local fs=require("filesystem")
local args,options=shell.parse(...)
if options.help then
print([[Usage: touch [OPTION]... FILE...
Update the modification times of each FILE to the current time.
A FILE argument that does not exist is created empty, unless -c is supplied.

  -c, --no-create    do not create any files
      --help         display this help and exit]])
return 0
elseif#args==0 then
io.stderr:write("touch: missing operand\n")
return 1
end
local noCreate=options.c or options["no-create"]
local errors=0
for _,arg in ipairs(args)do
local path=shell.resolve(arg)
if fs.isDirectory(path)then
io.stderr:write(string.format("`%s' ignored: directories not supported\n",arg))
else
local real,reason=fs.realPath(path)
if real then
local file
if fs.exists(real)or not noCreate then
file=io.open(real,"a")
end
if not file then
real=noCreate
reason="permission denied"
else
file:close()
end
end
if not real then
io.stderr:write(string.format("touch: cannot touch `%s': %s\n",arg,reason))
errors=1
end
end
end
return errors
