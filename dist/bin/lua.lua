local a=require("shell")
local c=a.parse(...)
if#c==0 then
c={"/lib/core/lua_shell.lua"}
end
local d=c[1]
local e,a
local b
local f=io.open(d)
if f then
b=f:read("*a")
f:close()
end
if b then
b=b:gsub("^#![^\n]+","")
e,a=load(b,"="..d)
else
a=string.format("could not open %s for reading",d)
end
if not e then
io.stderr:write(tostring(a).."\n")
os.exit(false)
end
local b
b,a=pcall(e,table.unpack(c,2))
if not b then
io.stderr:write(type(a)=="table"and a.reason or tostring(a),"\n")
os.exit(false)
end
