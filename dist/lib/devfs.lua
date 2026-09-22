local b=require("filesystem")
local j=require("text")
local a={}
local function d(c)
local e={proxy=c}
if not c or not c.list then
e.children={}
end
return e
end
local function k(e,f)
local c={}
for g,g in ipairs(e)do
c[#c+1]=tostring(g)
end
return table.concat(c,f or" ")
end
local function i(c)
local e={}
if c then
if c.proxy and c.proxy.list then
local f=c.proxy.list
e=type(f)=="table"and f or f()
elseif c.children then
e=c.children
end
end
local f={}
for g,c in pairs(e)do
if g:len()>0 then
if not c.proxy then c=d(c)end
if not c.proxy.isAvailable or c.proxy.isAvailable()then
f[g]=c
end
end
end
return pairs(f)
end
local function f(c,e)
for g,h in i(c)do
if g==e then
return h
end
end
end
local function l(c,g,h)
if not c or c.proxy and c.proxy.list then
return nil,"cannot add child to listing proxy"
end
local e=d(h)
c.children[g]=e
return e
end
local function e(h,m)
local c=a.root
for g,g in ipairs(b.segments(h))do
local h=f(c,g)
if not h then
if not m then
return nil,"no such file or directory"
end
if not l(c,g)then
return nil,"cannot create child node"
end
h=f(c,g)
end
c=h
end
return c
end
a.root=d()
function a.create(c,h)
checkArg(1,c,"string")
checkArg(2,h,"table","nil")
local d=b.name(c)
if not d then return nil,"invalid devfs path"end
local g,m=e(b.path(c),true)
if not g then
return nil,m
end
if f(g,d)then
return nil,"file or directory exists"
end
return l(g,d,h)
end
a.proxy={}
local f
local function g(h,p)
local l,m,n={},{},{}
local o=e(h)
if o then
for d,c in i(o)do
if c.proxy and c.proxy.link then
m[d]=c.proxy.link
elseif c.proxy and c.proxy.list then
local i={name=d,parent=p}
f(i,h.."/"..d,true)
n[d]=i
else
l[d]=c
end
end
end
return l,m,n
end
f=function(c,l,m)
if getmetatable(c)then return end
c.children=nil
c.links=nil
setmetatable(c,{
__index=function(c,d)
local h=d=="links"
if not h and d~="children"then return end
local d,d,i=g(l,c)
if m then
c.children=i
c.links=d
end
return h and d or i
end,
})
end
local c=dofile("/lib/core/device_labeling.lua")
c.loadRules()
a.getDeviceLabel=c.getDeviceLabel
a.setDeviceLabel=c.setDeviceLabel
local c=false
function a.register(d)
if c then return end
c=true
local c="/lib/core/devfs/"
for h in b.list(c)do
if h:match("%.lua$")then
for i,l in pairs(dofile(c..h))do
a.create(i,l)
end
end
end
if rawget(d,"fsnode")then
f(d.fsnode,"")
end
end
function a.proxy.list(d)
local c={}
for f in pairs(g(d,false))do
c[#c+1]=f
end
return c
end
function a.proxy.isDirectory(d)
local c=e(d)
return c and c.proxy and c.proxy.list
end
function a.proxy.size(c)
checkArg(1,c,"string")
local d=e(c)
if not d or not d.proxy then
return 0
end
local c=d.proxy
if c.list then return 0 end
if c.size then return c.size()end
if c.open then return 0 end
if c.read then return c.read():len()end
if c[1]~=nil then return k(c):len()end
return 0
end
function a.proxy.lastModified()
return 0
end
function a.proxy.exists(c)
checkArg(1,c,"string")
return not not e(c)
end
function a.getDevice(g)
checkArg(1,g,"string")
local d
local f="no such device"
local c,h=b.realPath(require("shell").resolve(g))
if not c then return nil,h end
if b.exists(c)then
c=b.path(c)..(b.name(c)or"")
local h,g=c:gsub("^/dev/","")
if g>0 and h:len()>0 then
local g=e(h)
if g and g.proxy then
d=g.proxy.device
end
if not d then
f="not a device"
end
else
d,f=b.get(c)
end
end
return d,f
end
function a.proxy.open(g,d)
checkArg(1,g,"string")
checkArg(2,d,"string","nil")
d=d or"r"
local h=d:match("[ra]")
local i=d:match("[wa]")
if not h and not i then
return nil,"invalid mode"
end
local f,c=e(g)
if not f then
return nil,c
elseif not f.proxy or f.proxy.list then
return nil,"is a directory"
end
local c=f.proxy
if c.link then
return b.open("/dev/"..g,d)
end
if c[1]~=nil then
local b=c
c.read=function()return k(b)end
end
if c.open then
return c.open(d)
end
if h and not c.read then
return nil,"cannot open for read"
elseif i and not c.write then
return nil,"cannot open for write"
end
local b=h and c.read()
if i then
return j.internal.writer(c.write,d,b)
end
return j.internal.reader(b,d)
end
local function b(c,d,...)
checkArg(1,c,"table")
checkArg(2,d,"string")
checkArg(3,c[d],"function","table","nil")
local e=c[d]
if not e then
return nil,"bad file handle"
elseif type(e)=="table"then
local f=getmetatable(e)
assert(f and f.__call,string.format("FILE handle [%s] method defined, but is not callable",tostring(d)))
end
return e(c,...)
end
function a.proxy.read(c,...)return b(c,"read",...)end
function a.proxy.close(c,...)return b(c,"close",...)end
function a.proxy.write(c,...)return b(c,"write",...)end
function a.proxy.seek(c,...)return b(c,"seek",...)end
function a.proxy.remove()return nil,"cannot remove file or directory"end
function a.proxy.makeDirectory()return nil,"use create in the devfs api"end
function a.proxy.setLabel()return nil,"cannot set label on devfs"end
return a
