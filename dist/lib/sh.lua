local h=require("process")
local j=require("shell")
local e=require("text")
local a={}
a.internal={}
function a.internal.isWordOf(b,c)
if not b or#b~=1 or b[1].qr then return false end
local d=b[1].txt
for b=1,#c do
if c[b]==d then return true end
end
return false
end
local f=a.internal.isWordOf
local k={";","&&","||","|"}
a.internal.ec={parseCommand=127,last=0}
function a.getLastExitCode()
return a.internal.ec.last
end
function a.internal.command_result_as_code(c,d)
local b
if c==false then
b=1
elseif c==nil or c==true then
b=0
elseif type(c)~="number"then
b=2
else
b=c
end
if d and b~=0 then io.stderr:write(d,"\n")end
return b
end
function a.internal.resolveActions(d,b)
b=b or{}
local i={}
local g=true
local c,l=e.internal.tokenize(d)
if not c then
return nil,l
end
local d=1
while d<=#c do
local e=c[d]
d=d+1
if f(e,k)then
g=true
b={}
elseif g then
g=false
if#e==1 and not e[1].qr then
local f=e[1].txt
if f=="!"then
g=true
elseif not b[f]then
b[f]=j.getAlias(f)
local g=b[f]
if g and f~=g then
local f,j=a.internal.resolveActions(g,b)
if not f then
return f,j
end
local b={}
for g=1,#f do b[#b+1]=f[g]end
for f=d,#c do b[#b+1]=c[f]end
c,d=b,1
e=table.remove(c,1)
end
end
end
end
i[#i+1]=e
end
return i
end
function a.internal.isIdentifier(b)
if type(b)~="string"then
return false
end
return b:match("^[%a_][%w_]*$")==b
end
function a.expand(b)
return(b:gsub("%$([_%w%?]+)",function(b)
if b=="?"then
return tostring(a.getLastExitCode())
end
return os.getenv(b)or""
end):gsub("%${(.*)}",function(b)
if a.internal.isIdentifier(b)then
return os.getenv(b)or""
end
io.stderr:write("${"..b.."}: bad substitution\n")
os.exit(1)
end))
end
function a.internal.createThreads(b,i,j)
local c={}
for f=1,#b do
local g,e,d=table.unpack(b[f])
local b=type(g)=="string"and i or nil
local i,k=h.load(g or"/dev/null",b,function(...)
if d then
a.internal.openCommandRedirects(d)
end
local d,b={},0
for l=1,#e do b=b+1 d[b]=e[l]end
local e=j[f]
if e then for j=1,e.n or#e do b=b+1 d[b]=e[j]end end
local e=table.pack(...)
for j=1,e.n do b=b+1 d[b]=e[j]end
io.write("")
return table.unpack(d,1,b)
end,tostring(g))
if not i then
for b,b in ipairs(c)do
h.internal.close(b)
end
return nil,k
end
c[f]=i
end
if#c>1 then
require("pipe").buildPipeChain(c)
end
return c
end
function a.internal.executePipes(b,i,j)
local c={}
for d,g in ipairs(b)do
local b={}
local d
for e,k in ipairs(g)do
local e=""
for f,f in ipairs(k)do
d=d or f.qr or f.txt:find("[%$%*%?<>]")
e=e..f.txt
end
b[#b+1]=e
end
local e
if d then
b,e=a.internal.evaluate(g)
if not b then
return false,e
end
end
c[#c+1]=table.pack(table.remove(b,1),b,e)
end
local b,d=a.internal.createThreads(c,j,{[#c]=i})
if not b then return false,d end
return h.internal.continue(b[1])
end
function a.execute(d,c,...)
checkArg(2,c,"string")
if c:find("^%s*#")then return true,0 end
local b,e=a.internal.resolveActions(c)
if type(b)~="table"then
return b,e
elseif#b==0 then
return true
end
local e=table.pack(...)
if not c:find("[;%$&|!<>]")then
a.internal.ec.last=a.internal.command_result_as_code(a.internal.executePipes({b},e,d))
return a.internal.ec.last==0
end
return a.internal.execute_complex(b,e,d)
end
function a.hintHandler(b,c)
return a.internal.hintHandlerImpl(b,c)
end
require("package").delay(a,"/lib/core/full_sh.lua")
return a
