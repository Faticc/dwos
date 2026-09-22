local c=require("computer")
local e=require("filesystem")
local f=require("shell")
local b={}
function b.locate(d)
for a,a in ipairs(c.getProgramLocations())do
if a[1]==d then
return a[2]
end
end
end
function b.reportNotFound(a,d)
checkArg(1,a,"string")
if e.isDirectory(f.resolve(a))then
io.stderr:write(a..": is a directory\n")
return 126
end
local c=b.locate(a)
if c then
io.stderr:write("The program '"..a.."' is currently not installed.  To install it:\n"..
"1. Craft the '"..c.."' floppy disk and insert it into this computer.\n"..
"2. Run `install "..c.."`")
elseif type(d)=="string"then
io.stderr:write(a..": "..d.."\n")
end
return 127
end
return b
