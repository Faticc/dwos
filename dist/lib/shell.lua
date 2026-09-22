local b=require("filesystem")
local h=require("unicode")
local d=require("process")
local a={}
local e=setmetatable({},{__mode="v"})
function a.getShell()
local f=os.getenv("SHELL")or"/bin/sh"
local c,g=a.resolve(f,"lua")
if not c then
return nil,"cannot resolve shell `"..f.."': "..g
end
if e[c]then
return e[c]
end
local f,g=loadfile(c,nil,setmetatable({},{__index=_G}))
if f then
e[c]=f
end
return f,g
end
function a.prime()
local c=d.info().data
for e,e in ipairs({"aliases","vars"})do
if not rawget(c,e)then
local f=c[e]
c[e]={}
if f then
for g,i in pairs(f)do
c[e][g]=i
end
end
end
end
end
function a.getAlias(c)
return d.info().data.aliases[c]
end
function a.setAlias(c,e)
checkArg(1,c,"string")
checkArg(2,e,"string","nil")
d.info().data.aliases[c]=e
end
function a.getWorkingDirectory()
return os.getenv("PWD")or"/"
end
function a.setWorkingDirectory(c)
checkArg(1,c,"string")
c=b.canonical(c):gsub("^$","/"):gsub("(.)/$","%1")
if b.isDirectory(c)then
os.setenv("PWD",c)
return true
end
return nil,"not a directory"
end
function a.resolve(e,g)
checkArg(1,e,"string")
local c=e
if c:find("/")~=1 then
c=b.concat(a.getWorkingDirectory(),c)
end
local f=b.name(e)
c=b[f and"path"or"canonical"](c)
local i=b.concat(c,f or"")
if not g then
return i
elseif f then
checkArg(2,g,"string")
local i=e:find("/")and c or os.getenv("PATH")
for e in string.gmatch(i,"[^:]+")do
local c=b.concat(a.resolve(e),f)
if not b.exists(c)then
c=c.."."..g
end
if b.exists(c)and not b.isDirectory(c)then
return c
end
end
end
return nil,"file not found"
end
function a.parse(...)
local f=table.pack(...)
local c,e={},{}
local g=false
for i=1,f.n do
local b=f[i]
if not g and type(b)=="string"then
if b=="--"then
g=true
elseif b:sub(1,2)=="--"then
local f,g=b:match("%-%-(.-)=(.*)")
if not f then
f,g=b:sub(3),true
end
e[f]=g
elseif b:sub(1,1)=="-"and b~="-"then
for f=2,h.len(b)do
e[h.sub(b,f,f)]=true
end
else
c[#c+1]=b
end
else
c[#c+1]=b
end
end
return c,e
end
function a.aliases()
return pairs(d.info().data.aliases)
end
function a.execute(c,e,...)
local b,f=a.getShell()
if not b then
return false,f
end
local f=d.load(b,nil,nil,c)
local b=table.pack(d.internal.continue(f,e,c,...))
if b.n==0 then return true end
return table.unpack(b,1,b.n)
end
function a.getPath()
return os.getenv("PATH")
end
function a.setPath(b)
os.setenv("PATH",b)
end
return a
