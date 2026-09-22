local n=require("component")
local l=require("unicode")
local a={}
local m={name="",children={},links={}}
local i={}
local function e(f)
local c,b={},0
for d in f:gmatch("[^\\/]+")do
if d==".."then
if b>0 then c[b]=nil b=b-1 end
elseif d~="."then
b=b+1
c[b]=d
end
end
return c
end
local function d(g,p,q)
checkArg(1,g,"string")
local k={}
local f=e(g)
local o={}
local b=m
local c=1
while c<=#f do
local h=f[c]
o[c]=b
if not b.children[h]then
local j=b.links[h]
if j then
if not q and#f==c then break end
if k[g]then
return nil,string.format("link cycle detected '%s'",g)
end
k[g]=c
local q="/"..table.concat(f,"/",c+1)
local k
if j:match("^[^/]")then
k=table.concat(f,"/",1,c-1).."/"
local r=e(j)
local s=e(k..j)
local t=(c-1+#r)-#s
c=c-t
b=o[c]
else
k=""
c=1
b=m
end
g=k..j..q
f=e(g)
h=nil
elseif p then
b.children[h]={name=h,parent=b,children={},links={}}
else
break
end
end
if h then
b=b.children[h]
c=c+1
end
end
local h,g=b,#f>=c and table.concat(f,"/",c)
local c=g
while b and not b.fs do
c=c and a.concat(b.name,c)or b.name
b=b.parent
end
return b,c,h,g
end
function a.canonical(b)
local c=table.concat(e(b),"/")
if l.sub(b,1,1)=="/"then
return"/"..c
end
return c
end
function a.concat(...)
local b=table.pack(...)
for c,f in ipairs(b)do
checkArg(c,f,"string")
end
return a.canonical(table.concat(b,"/"))
end
function a.get(b)
local c=d(b)
if c.fs then
local f=c.fs
b=""
while c and c.parent do
b=a.concat(c.name,b)
c=c.parent
end
b=a.canonical(b)
if b~="/"then b="/"..b end
return f,b
end
return nil,"no such file system"
end
function a.realPath(c)
checkArg(1,c,"string")
local b,f=d(c,false,true)
if not b then return nil,f end
local c={f or nil}
repeat
table.insert(c,1,b.name)
b=b.parent
until not b
return table.concat(c,"/")
end
function a.mount(f,c)
checkArg(1,f,"string","table")
if type(f)=="string"then
f=a.proxy(f)
end
assert(type(f)=="table","bad argument #1 (file system proxy or address expected)")
checkArg(2,c,"string")
local b
if not m.fs then
if c~="/"then return nil,"rootfs must be mounted first"end
b=c
else
local g
b,g=a.realPath(c)
if not b then return nil,g end
if a.exists(b)and not a.isDirectory(b)then
return nil,"mount point is not a directory"
end
end
if i[b]then
return nil,"another filesystem is already mounted here"
end
local c
for g,g in pairs(i)do
if g.fs.address==f.address then
c=g
break
end
end
if not c then
c=select(3,d(b,true))
f.fsnode=c
else
local g=select(3,d(a.path(b),true))
local h=a.name(b)
c=setmetatable({name=h,parent=g},{__index=c})
g.children[h]=c
end
c.fs=f
i[b]=c
return true
end
function a.path(c)
local f=e(c)
local b=table.concat(f,"/",1,#f-1).."/"
if l.sub(c,1,1)=="/"and l.sub(b,1,1)~="/"then
return"/"..b
end
return b
end
function a.name(b)
checkArg(1,b,"string")
local c=e(b)
return c[#c]
end
function a.proxy(b,c)
checkArg(1,b,"string")
if not n.list("filesystem")[b]or next(c or{})then
return a.internal.proxy(b,c)
end
return n.proxy(b)
end
function a.exists(c)
if not a.realPath(a.path(c))then
return false
end
local b,g,h,f=d(c)
if not f or h.links[f]then
return true
elseif b and b.fs then
return b.fs.exists(g)
end
return false
end
function a.isDirectory(c)
local b,f=a.realPath(c)
if not b then return nil,f end
local c,f,g,h=d(b)
if not g.fs and not h then
return true
end
if c.fs then
return not f or c.fs.isDirectory(f)
end
return false
end
function a.list(f)
local c,h,g,j=d(f,false,true)
local b={}
if c then
b=c.fs and c.fs.list(h or"")or{}
if not j then
for c,h in pairs(g.children)do
if not h.fs or i[a.concat(f,c)]then
b[#b+1]=c.."/"
end
end
for c in pairs(g.links)do
b[#b+1]=c
end
end
end
local c={}
for f,f in ipairs(b)do
c[a.canonical(f)]=f
end
return function()
local b,f=next(c)
c[b or false]=nil
return f
end
end
local c={r=true,rb=true,w=true,wb=true,a=true,ab=true}
function a.open(g,b)
checkArg(1,g,"string")
b=tostring(b or"r")
checkArg(2,b,"string")
assert(c[b],"bad argument #2 (r[b], w[b] or a[b] expected, got "..b..")")
local c,f=d(g,false,true)
if not c then
return nil,f
end
if not c.fs or not f or((b=="r"or b=="rb")and not c.fs.exists(f))then
return nil,"file not found"
end
local g,h=c.fs.open(f,b)
if not g then
return nil,h
end
return setmetatable({fs=c.fs,handle=g},{__index=function(c,b)
if not c.fs[b]then return end
if not c.handle then
return nil,"file is closed"
end
return function(c,...)
local f=c.handle
if b=="close"then
c.handle=nil
end
return c.fs[b](f,...)
end
end})
end
a.findNode=d
a.segments=e
a.fstab=i
require("package").delay(a,"/lib/core/full_filesystem.lua")
return a
