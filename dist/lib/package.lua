local a={}
a.config="/\n;\n?\n!\n-\n"
a.path="/lib/?.lua;/usr/lib/?.lua;/home/lib/?.lua;./?.lua;/lib/?/init.lua;/usr/lib/?/init.lua;/home/lib/?/init.lua;./?/init.lua"
local e,i,d={},{},{}
local f={
_G=_G,bit32=bit32,coroutine=coroutine,math=math,os=os,
package=a,string=string,table=table,
}
a.loaded,a.preload,a.searchers=f,i,d
function a.searchpath(c,j,b,g)
checkArg(1,c,"string")
checkArg(2,j,"string")
b,g="%"..(b or"."),g or"/"
c=c:gsub(b,g)
local g=require("filesystem")
local h={}
for b in j:gmatch("[^;]+")do
b=b:gsub("?",c)
if b:sub(1,1)~="/"and os.getenv then
b=g.concat(os.getenv("PWD")or"/",b)
end
if g.exists(b)and not g.isDirectory(b)then
return b
end
h[#h+1]="no file '"..b.."'"
end
return nil,table.concat(h,"\n\t")
end
d[1]=function(b)
return i[b]or"no field package.preload['"..b.."']"
end
d[2]=function(b)
local c,g=a.searchpath(b,a.path)
if not c then return g end
local g,h=loadfile(c)
if not g then
error(string.format("error loading module '%s' from file '%s':\n\t%s",b,c,h))
end
return g,b
end
function require(b)
checkArg(1,b,"string")
local c=f[b]
if c~=nil then return c end
if e[b]then
error("already loading: "..b.."\n"..debug.traceback(),2)
end
if type(d)~="table"then error("'package.searchers' must be a table")end
local c,h
local g=""
for i,i in pairs(d)do
c,h=i(b)
if type(c)=="function"then break end
if c~=nil then g=g.."\n\t"..tostring(c)end
c=nil
end
if not c then error(string.format("module '%s' not found:%s",b,g))end
e[b]=true
local g,d=pcall(c,h or b)
e[b]=false
assert(g,string.format("module '%s' load failed:\n%s",b,d))
f[b]=d
return d
end
function a.delay(c,d)
local b={}
function b.__index(e,f)
b.__index=nil
dofile(d)
return e[f]
end
if c.internal then setmetatable(c.internal,b)end
setmetatable(c,b)
end
return a
