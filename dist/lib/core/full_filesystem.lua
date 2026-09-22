local a=require("filesystem")
local e=require("component")
local i=require("shell")
function a.makeDirectory(c)
if a.exists(c)then
return nil,"file or directory with that name already exists"
end
local b,d=a.findNode(c)
if b.fs and d then
local f,c=b.fs.makeDirectory(d)
if not f and not c and b.fs.isReadOnly()then
c="filesystem is readonly"
end
return f,c
end
if b.fs then
return nil,"virtual directory with that name already exists"
end
return nil,"cannot create a directory in a virtual directory"
end
function a.lastModified(d)
local b,c,f,g=a.findNode(d,false,true)
if not b or not f.fs and not g then
return 0
end
if b.fs and c then
return b.fs.lastModified(c)
end
return 0
end
function a.mounts()
local b={}
for c,d in pairs(a.fstab)do
b[#b+1]={d.fs,c}
end
return function()
local c=table.remove(b)
if c then return table.unpack(c)end
end
end
function a.link(d,b)
checkArg(1,d,"string")
checkArg(2,b,"string")
if a.exists(b)then
return nil,"file already exists"
end
local f=a.path(b)
if not a.exists(f)then
return nil,"no such directory"
end
local c,g=a.realPath(f)
if not c then
return nil,g
end
if not a.isDirectory(c)then
return nil,"not a directory"
end
local f,f,f=a.findNode(c,true)
f.links[a.name(b)]=d
return true
end
function a.umount(b)
checkArg(1,b,"string","table")
local c,d,f
if type(b)=="string"then
c=a.realPath(b)
f=b
else
d=b
end
local b={}
for g,h in pairs(a.fstab)do
if c==g or f==h.fs.address or d==h.fs then
b[#b+1]=g
end
end
for c,d in ipairs(b)do
local c=a.fstab[d]
a.fstab[d]=nil
c.fs=nil
c.parent.children[c.name]=nil
end
return#b>0
end
function a.size(g)
local b,c,d,f=a.findNode(g,false,true)
if not b or not d.fs and(not f or d.links[f])then
return 0
end
if b.fs and c then
return b.fs.size(c)
end
return 0
end
function a.isLink(b)
local c=a.name(b)
local d,f,g,h=a.findNode(a.path(b),false,true)
if not d then return nil,f end
local b=g.links[c]
if not h and b~=nil then
return true,b
end
return false
end
function a.copy(f,g)
local b=false
local d,c=a.open(f,"rb")
if d then
local f=a.open(g,"wb")
if f then
repeat
b,c=d:read(2048)
if not b then break end
b,c=f:write(b)
if not b then b,c=false,"failed to write"end
until not b
f:close()
end
d:close()
end
return b==nil,c
end
local function j(c)
checkArg(1,c,"table")
if c.isReadOnly()then
return c
end
local function b()return nil,"filesystem is readonly"end
return setmetatable({
rename=b,
open=function(f,d)
checkArg(1,f,"string")
checkArg(2,d,"string")
if d:match("[wa]")then
return b()
end
return c.open(f,d)
end,
isReadOnly=function()return true end,
write=b,
setLabel=b,
makeDirectory=b,
remove=b,
},{__index=c})
end
local function h(b)
local d,c=a.realPath(b)
if not d then
return nil,c
end
if not a.isDirectory(d)then
return nil,"must bind to a directory"
end
local b,c=a.get(d)
if d==c then
return b
end
local f=d:sub(#c+1)
local function c(g)
return function(k,...)
return g(a.concat(f,k),...)
end
end
return{
type="filesystem_bind",
address=d,
isReadOnly=b.isReadOnly,
list=c(b.list),
isDirectory=c(b.isDirectory),
size=c(b.size),
lastModified=c(b.lastModified),
exists=c(b.exists),
open=c(b.open),
remove=c(b.remove),
read=b.read,
write=b.write,
close=b.close,
getLabel=function()return""end,
setLabel=function()return nil,"cannot set the label of a bind point"end,
}
end
a.internal={}
function a.internal.proxy(c,d)
checkArg(1,c,"string")
checkArg(2,d,"table","nil")
d=d or{}
local f,b,g
if d.bind then
b,g=h(c)
else
for h in e.list("filesystem",true)do
if e.invoke(h,"getLabel")==c or h:sub(1,c:len())==c then
f=h
break
end
end
if not f then
return nil,"no such file system"
end
b,g=e.proxy(f)
end
if not b then
return b,g
end
if d.readonly then
b=j(b)
end
return b
end
function a.remove(d)
local function e()
local b,b,b,c=a.findNode(a.path(d),false,true)
if not c then
local c=a.name(d)
if b.children[c]or b.links[c]then
b.children[c]=nil
b.links[c]=nil
while b and b.parent and not b.fs and not next(b.children)and not next(b.links)do
b.parent.children[b.name]=nil
b=b.parent
end
return true
end
end
return false
end
local function f()
local b,c=a.findNode(d)
if b.fs and c then
return b.fs.remove(c)
end
return false
end
local b=e()
b=f()or b
if b then return true end
return nil,"no such file or directory"
end
function a.rename(b,c)
if a.isLink(b)then
local d,d,d=a.findNode(a.path(b))
local e=d.links[a.name(b)]
local d,f=a.link(e,c)
if d then
a.remove(b)
end
return d,f
end
local d,e=a.findNode(b)
local f,g=a.findNode(c)
if d.fs and e and f.fs and g then
if d.fs.address==f.fs.address then
return d.fs.rename(e,g)
end
local d,e=a.copy(b,c)
if d then
return a.remove(b)
end
return nil,e
end
return nil,"trying to read from or write to virtual directory"
end
local b=nil
local function d()
local c=a.get("/")
if c and not c.isReadOnly()then
local c=a.open("/etc/filesystem.cfg","w")
if c then
c:write("autorun="..tostring(b))
c:close()
end
end
end
function a.isAutorunEnabled()
if b==nil then
local c={}
local e=loadfile("/etc/filesystem.cfg",nil,c)
if e then
pcall(e)
b=not not c.autorun
else
b=true
end
d()
end
return b
end
function a.setAutorunEnabled(c)
checkArg(1,c,"boolean")
b=c
d()
end
os.remove=a.remove
os.rename=a.rename
os.execute=function(b)
if not b then
return type(i)=="table"
end
return i.execute(b)
end
function os.exit(b)
error({reason="terminated",code=b},0)
end
function os.tmpname()
local b=os.getenv("TMPDIR")or"/tmp"
if a.exists(b)then
for c=1,10 do
local c=a.concat(b,tostring(math.random(1,0x7FFFFFFF)))
if not a.exists(c)then
return c
end
end
end
end
