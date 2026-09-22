local e=require("shell")
local c=require("filesystem")
local f,a=e.parse(...)
if a.help then
print([[Usage: rmdir [OPTION]... DIRECTORY...
Removes the DIRECTORY(ies), if they are empty.

  -q, --ignore-fail-on-non-empty
                  ignore failures due solely to non-empty directories
  -p, --parents   remove DIRECTORY and its empty ancestors
                  e.g. 'rmdir -p a/b/c' is similar to 'rmdir a/b/c a/b a'
  -v, --verbose   output a diagnostic for every directory processed
      --help      display this help and exit]])
return 0
end
if#f==0 then
io.stderr:write("rmdir: missing operand\n")
return 1
end
local h=a.p or a.parents
local d=a.v or a.verbose
local i=a.q or a["ignore-fail-on-non-empty"]
local g=0
local function a(b)
if b then io.stderr:write(b)end
g=1
return false
end
local function j(b)
if d then
print(string.format("rmdir: removing directory, %s",b))
end
local d=e.resolve(b)
if b=="."then
return a("rmdir: failed to remove directory '.': Invalid argument\n")
elseif not c.exists(d)then
return a("rmdir: cannot remove "..b..": path does not exist\n")
elseif c.isLink(d)or not c.isDirectory(d)then
return a("rmdir: cannot remove "..b..": not a directory\n")
end
local e,k=c.list(d)
if not e then
return a(tostring(k).."\n")
end
if e()then
return a(not i and("rmdir: failed to remove "..b..": Directory not empty\n")or nil)
end
local b,e=c.remove(d)
if not b then
return a(tostring(e).."\n")
end
return true
end
for a,a in ipairs(f)do
a=a:gsub("/+","/")
local b={a}
if h and a:len()>1 and a:find("/")then
b={}
local c=a:sub(1,1)=="/"and"/"or""
for d in a:gmatch("[^/]+")do
table.insert(b,1,c..d)
c=c..d.."/"
end
end
for a,a in ipairs(b)do
if not j(a)then break end
end
end
return g
