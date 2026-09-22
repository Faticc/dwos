local a=require("filesystem")
local m=require("shell")
local e={}
local function f(b,c,...)
if c then
io.stderr:write(b.cmd..string.format(": "..c,...).."\n")
b.exit_code=1
return 1
end
end
local function s(b,h,i)
if b==""then
return f(h,"cannot create regular file '' No such file or directory")
end
local g=m.resolve(b)
local c,d=b:reverse():match("^(%.*)(.?)")
d=d:match("^/?$")
local j=c and c:len()or 0
c=d and({true,true})[j]
if(not i or a.exists(g))and d and not a.isDirectory(g)then
f(h,"'%s' is not a directory",b)
os.exit(1)
end
return c,g
end
local function w(d,g)
local c,b=a.open(d,"rb")
local h=true
if c then
b=a.open(g,"rb")
if b then
repeat
local i,j=c:read(2048),b:read(2048)
if i~=j then
h=false
break
end
until not i or not j
b:close()
end
c:close()
end
assert(c and b,"could not open files for reading: "..d ..", "..g)
return h
end
local b=require("computer").uptime
local d=b()
local function g(i,h,c)
if i then
io.write(h..(c and(" -> "..c)or"").."\n")
end
if e.onFile then e.onFile(h,c)end
if b()-d>=0.5 then
os.sleep(0)
d=b()
end
end
local function x(b)
io.write(b.." [Y/n] ")
local b=io.read()
if not b then
os.exit(1)
end
return b==""or b:sub(1,1):lower()=="y"
end
local function t(b,h,i)
local c,d=a.realPath(b)
if not c and not i then
f(h,"cannot read '%s': '%s'",b,d)
return false
end
local h,i=a.isLink(b)
return true,c,d,h,i,a.exists(b),a.get(b),c and a.isDirectory(c)
end
function e.recurse(b,d,c,u,p)
b=b:gsub("/+","/")
d=d:gsub("/+","/")
local h=m.resolve(b)
local k=m.resolve(d)
local n=c.cmd=="mv"
local i=c.v and(not n or p)
if c.skip[h]then
g(i,string.format("skipping %s",b))
return true
end
local function q(j,l)
if j and n and p then
if a.get(h).isReadOnly()or not a.remove(h)then
f(c,"cannot remove '%s': filesystem is readonly",b)
j=false
end
end
return j,l
end
local j,o,l,y,z,A,B,C=t(h,c,c.P)
if not j then return nil end
local D,l,j,E,j,j,v,r=t(k,c)
if not D then os.exit(1)end
if v.isReadOnly()then
f(c,"cannot create target '%s': filesystem is readonly",d)
return
end
local t=o==l
local D=B==v
local v=u[o]
if n and v then
return false,string.format("cannot move '%s', it is a mount point",b)
end
if y and c.P and not(j and t and not E)then
if j and c.n then
return true
end
a.remove(k)
if j then
g(i,string.format("removed '%s'",d))
end
g(i,b,d)
return q(a.link(z,k))
elseif C then
if not c.r then
g(true,string.format("omitting directory '%s'",b))
c.exit_code=1
return true
end
if j and not r then
return nil,"cannot overwrite non-directory '"..d.."' with directory '"..b.."'"
end
if c.x and not p and v then
return true
end
if D and(l.."/"):find(o.."/",1,true)then
return nil,"cannot write a directory, '"..b.."', into itself, '"..d.."'"
end
if n then
if a.list(l)()then
return nil,"cannot move '"..b.."' to '"..d.."': Directory not empty"
end
g(i,b,d)
end
if not j then
g(i,b,d)
a.makeDirectory(k)
end
for n in a.list(h)do
local p,v=e.recurse(b.."/"..n,d.."/"..n,c,u,false)
if not p then
return false,v
end
end
return q(true)
elseif A then
if j then
if t then
return nil,"'"..b.."' and '"..d.."' are the same file"
end
if c.n then
return true
end
if c.u and not r and w(o,l)then
return true
end
if c.i and not x("overwrite '"..d.."'?")then
return true
end
if r then
return nil,"cannot overwrite directory '"..d.."' with non-directory"
end
a.remove(l)
end
g(i,b,d)
return q(a.copy(h,k))
end
return nil,"'"..b.."': No such file or directory"
end
function e.batch(g,b)
b.exit_code=0
b.i=b.i and not b.f
b.P=b.P or b.r
local c=b.skip or{}
b.skip={}
for d,d in ipairs(c)do
b.skip[m.resolve(d)]=true
end
local h={}
for c,d in a.mounts()do
h[d]=c
end
local i=table.remove(g)
local c,c=s(i,b)
if not c then
return 1
end
local j=a.isDirectory(c)
for d,d in ipairs(g)do
local g
g,c=s(d,b,true)
if c then
local c=i
if g and b.cmd=="mv"then
f(b,"invalid move path '%s'",d)
else
if not g and j then
local g=a.name(d)
if g then
c=c.."/"..g
end
end
local a,g=e.recurse(d,c,b,h,true)
if not a then
f(b,g)
end
end
end
end
return b.exit_code
end
return e
