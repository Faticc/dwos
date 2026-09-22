local g=require("filesystem")
local b=require("shell")
local h=require("sh")
local d=loadfile(b.resolve("touch","lua"))
local i=loadfile(b.resolve("mkdir","lua"))
if not d then
io.stderr:write("missing tools for mktmp\n")
return false,"missing tools for mktmp"
end
local e,a=b.parse(...)
local function b(...)
local c
for f,f in ipairs({...})do
c=a[f]or c
a[f]=nil
end
return c
end
local f=b("d")
local c=b("v","verbose")
local j=b("q","quiet")
if b("help")or#e>1 or next(a)then
print([[Usage: mktmp [OPTION] [PATH]
Create a new file with a random name in $TMPDIR or PATH argument if given
  -d              create a directory instead of a file
  -v, --verbose   print result to stdout, even if no tty
  -q, --quiet     do not print results to stdout, even if tty (verbose overrides)
      --help      print this help message]])
if next(a)then
io.stderr:write("invalid option: "..(next(a)).."\n")
return 1
end
return
end
if not c and not j and io.stdout.tty then
c=true
end
local a=e[1]or os.getenv("TMPDIR").."/"
if not g.exists(a)then
io.stderr:write(string.format("cannot create tmp file or directory at %s, it does not exist\n",a))
return 1
end
local a=os.tmpname()
local b,e=(f and i or d)(a)
if h.internal.command_passed(b)then
if c then
print(a)
end
return a
end
return b,e
