local g=require("shell")
local c=require("filesystem")
local h=require("text")
local e=[==[Usage: find [path] [--type=[dfs]] [--[i]name=EXPR]
  --path  if not specified, path is assumed to be current working directory
  --type  returns results of a given type, d:directory, f:file, and s:symlinks
  --name  specify the file name pattern. Use quote to include *. iname is
          case insensitive
  --help  display this help and exit]==]
local b,a=g.parse(...)
if a.help then
print(e)
return
end
if#b>1 then
io.stderr:write(e.."\n")
return 1
end
local i=b[1]or"."
local d={d=true,f=true,s=true}
local b=""
local f=true
if a.iname and a.name then
io.stderr:write("find cannot define both iname and name\n")
return 1
end
if a.type then
if not d[a.type]then
io.stderr:write(string.format("find: Unknown argument to type: %s\n",a.type))
io.stderr:write(e.."\n")
return 1
end
d={[a.type]=true}
end
if a.iname or a.name then
f=a.iname==nil
b=a.iname or a.name
if type(b)~="string"then
io.stderr:write("find: missing argument to `name'\n")
return 1
end
if not f then
b=b:lower()
end
b="^"..h.escapeMagic(b):gsub("%%%*",".*").."$"
end
local function h(a)
if not c.exists(a)then
return false
end
if b~=""then
local e=a:gsub(".*/","")
if e==""then
return false
end
if not f then
e=e:lower()
end
if not e:find(b)then
return false
end
end
if c.isDirectory(a)then
return d.d
elseif c.isLink(a)then
return d.s
end
return d.f
end
local function b(d)
local a=g.resolve(d)
local e=d:gsub("/+$","")
if h(a)then
print(e)
end
if c.isDirectory(a)then
for d in c.list(a)do
b(e.."/"..d)
end
end
end
b(i)
