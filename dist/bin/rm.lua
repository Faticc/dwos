local c=require("filesystem")
local f=require("shell")
local n,a=f.parse(...)
if#n==0 or a.help then
print([==[Usage: rm [options] <filename1> [<filename2> [...]]

  -f          ignore nonexistent files and arguments, never prompt
  -r          remove directories and their contents recursively
  -v          explain what is being done
      --help  display this help and exit

For complete documentation and more options, run: man rm]==])
return 1
end
local o=a.r or a.R or a.recursive
local d=a.f or a.force
local s=(a.v or a.verbose)and not d
local p=a.d or a.dir
local h=d and 0 or(a.I and 3)or(a.i and 1)or 0
local function g(...)
if not d then io.stderr:write(...)end
end
local function e(...)
if not d then io.stdout:write(...)end
end
local function b(a)return f.resolve(a.rel)end
local function i(a)return c.isLink(b(a))end
local function j(a)return i(a)or c.exists(b(a))end
local function f(a)return not i(a)and c.isDirectory(b(a))end
local function t(a)return not j(a)or c.get(b(a)).isReadOnly()end
local function q(a)return j(a)and f(a)and c.list(b(a))()==nil end
local function r(k,l)
local a={origin=k,rel=l:gsub("/+$","")}
if f(a)then
a.rel=a.rel.."/"
end
return a
end
local function k()
if d then
return true
end
local a=io.read()
return a=="y"or a=="yes"
end
local l
local function u(a)
if a==nil or not f(a)or q(a)then
return true
end
local m=true
if o and h==1 then
e(string.format("rm: descend into directory `%s'? ",a.rel))
if not k()then
return false
end
for v in c.list(b(a))do
m=l(r(a.origin,a.rel..v))and m
end
end
return m
end
l=function(a)
if not u(a)then
return false
end
if not j(a)then
g(string.format("rm: cannot remove `%s': No such file or directory\n",a.rel))
return false
elseif f(a)and not o and not(q(a)and p)then
if not p then
g(string.format("rm: cannot remove `%s': Is a directory\n",a.rel))
else
g(string.format("rm: cannot remove `%s': Directory not empty\n",a.rel))
end
return false
end
local c=true
if h==1 then
if f(a)then
e(string.format("rm: remove directory `%s'? ",a.rel))
elseif i(a)then
e(string.format("rm: remove symbolic link `%s'? ",a.rel))
else
e(string.format("rm: remove regular file `%s'? ",a.rel))
end
c=k()
end
if c then
if t(a)then
g(string.format("rm: cannot remove `%s': Is read only\n",a.rel))
return false
end
os.remove(b(a))
if s then
e("removed '"..a.rel.."'\n")
end
end
return c
end
local a={}
for b,b in ipairs(n)do
a[#a+1]=r(b,b)
end
if h==3 and#a>3 then
e(string.format("rm: remove %i arguments? ",#a))
if not k()then
return
end
end
local b=true
for c,c in ipairs(a)do
b=l(c)and b
end
return d or b
