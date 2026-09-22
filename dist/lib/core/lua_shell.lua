local e=require("package")
local g=require("term")
local function c(...)
local a,b=pcall(require,...)
if a then
return b
end
end
local a
a=setmetatable({},{
__index=function(b,b)
_ENV[b]=_ENV[b]or c(b)
return _ENV[b]
end,
__pairs=function(b)
return function(c,f)
local c,d=next(b,f)
if not c and b==a then
b=_ENV
c,d=next(b)
end
if not c and b==_ENV then
b=e.loaded
c,d=next(b)
end
return c,d
end
end,
})
a._PROMPT=tostring(a._PROMPT or"\27[32mlua> \27[37m")
local function d(b,c)
if type(b)~="table"then return nil end
if not c or#c==0 then return b end
local e=c:match("[^.]+")
for f,h in pairs(b)do
if f==e then
return d(h,c:sub(#e+2))
end
end
local e=getmetatable(b)
if b==a then e={__index=_ENV}end
if e then
return d(e.__index,c)
end
end
local function h(c,i,j,k)
if type(c)~="table"then return end
for e,b in pairs(c)do
if type(e)=="string"and e:match("^"..k)then
local f=""
if type(b)=="function"or type(b)=="table"and getmetatable(b)and getmetatable(b).__call then
f="()"
elseif type(b)=="table"then
f="."
end
i[j..e..f]=true
end
end
local b=getmetatable(c)
if c==a then b={__index=_ENV}end
if b then
return h(b.__index,i,j,k)
end
end
local i={hint=function(b,c)
b=b or""
local j=b:sub(c)
b=b:sub(1,c-1)
local c=b:match("[a-zA-Z_][a-zA-Z0-9_.]*$")
if not c then return nil end
local e=c:match("[^.]+$")or""
local k=c:sub(1,#c-#e)
local f=d(a,k)
if not f then return nil end
local d,c={},{}
h(f,d,b:sub(1,#b-#e),e)
for b in pairs(d)do
c[#c+1]=b..j
end
return c
end}
io.write("\27[37m".._VERSION.." Copyright (C) 1994-2022 Lua.org, PUC-Rio\n")
io.write("\27[33mEnter a statement and hit enter to evaluate it.\n")
io.write("Prefix an expression with '=' to show its value.\n")
io.write("Press Ctrl+D to exit the interpreter.\n\27[37m")
while g.isAvailable()do
io.write(a._PROMPT)
local c=g.read(i)
if not c then
return
end
local b,d
if c:sub(1,1)=="="then
b,d=load("return "..c:sub(2),"=stdin","t",a)
else
b,d=load("return "..c,"=stdin","t",a)
if not b then
b,d=load(c,"=stdin","t",a)
end
end
if b then
local a=table.pack(xpcall(b,debug.traceback))
if not a[1]then
if type(a[2])=="table"and a[2].reason=="terminated"then
os.exit(a[2].code)
end
io.stderr:write(tostring(a[2]).."\n")
else
local c,e=pcall(function()
local f=require("serialization")
for b=2,a.n do
io.write(f.serialize(a[b],true),b<a.n and"\t"or"\n")
end
end)
if not c then
io.stderr:write("crashed serializing result: ",tostring(e))
end
end
else
io.stderr:write(tostring(d).."\n")
end
end
