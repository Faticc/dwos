local c=require("filesystem")
local b=require("shell")
local a,h=b.parse(...)
if#a==0 then
io.write("Usage: mkdir [-p] <dirname1> [<dirname2> [...]]\n")
return 1
end
local f=0
for g=1,#a do
local d=b.resolve(a[g])
local e,b
if h.p and c.isDirectory(d)then
e=true
else
e,b=c.makeDirectory(d)
end
if not e then
if not b then
b=c.exists(d)and"file or folder with that name already exists"or"unknown reason"
end
io.stderr:write("mkdir: cannot create directory '"..tostring(a[g]).."': "..b.."\n")
f=1
end
end
return f
