local g=require("shell")
local a=require("filesystem")
local h,b=g.parse(...)
if#h==0 then
h[1]="."
end
if b.help then
print([[
Usage: du [OPTION]... [FILE]...
Summarize disk usage of each FILE, recursively for directories.

  -h, --human-readable  print sizes in human readable format (e.g., 1K 234M 2G)
  -s, --summarize       display only a total for each argument
      --help     display this help and exit
      --version  output version information and exit]])
return true
end
if b.version then
print("du (DwOS bin) 1.0\nWritten by payonel, patterned after GNU coreutils du")
return true
end
local function c(d,e)
local f=b[d]or b[e]
b[d],b[e]=nil,nil
return f
end
local d=c("h","human-readable")
local i=c("s","summarize")
if next(b)then
for c in pairs(b)do
io.stderr:write(string.format("du: invalid option -- '%s'\n",c))
end
io.stderr:write("Try 'du --help' for more information.\n")
return 1
end
local function e(b)
if not d then
return tostring(b)
end
local d={"","K","M","G"}
local c=1
while b>1024 and c<#d do
c=c+1
b=b/1024
end
return math.floor(b*10)/10 ..d[c]
end
local function d(b,c)
io.write(string.format("%-12s%s\n",e(b),c))
end
local function j(b)
local c,e=0,0
local f=g.resolve(b)
if a.isDirectory(f)then
local k=b:sub(-1)=="/"and b or b.."/"
for l in a.list(f)do
local m,n=j(k..l)
c=c+m
e=e+n
end
if e==0 and not i then
d(c,b)
end
elseif not a.isLink(f)then
c=a.size(f)
end
return c,e
end
for b,b in ipairs(h)do
local c=g.resolve(b)
if not a.exists(c)then
io.stderr:write(string.format("du: cannot access '%s': no such file or directory\n",b))
return 1
end
if a.isDirectory(c)then
local e=j(b)
if i then
d(e,b)
end
elseif a.isLink(c)then
d(0,b)
else
d(a.size(c),b)
end
end
return true
