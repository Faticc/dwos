local c=require("component")
local a=require("shell")
local g=require("text")
local b,f=a.parse(...)
local d=tonumber(f.limit)or math.huge
local h={}
local a=1
if#b==0 then
b[1]=""
end
for e,e in ipairs(b)do
for i,b in c.list(e)do
if b:len()>a then
a=b:len()+2
end
h[i]=b
end
end
a=a+8-a%8
for e,b in pairs(h)do
io.write(g.padRight(b,a)..e.."\n")
if f.l then
local h=c.proxy(e)
local a=1
local b={}
for f,i in pairs(h)do
if type(i)=="table"or type(i)=="function"then
if f:len()>a then
a=f:len()+2
end
b[#b+1]=f
end
end
table.sort(b)
a=a+8-a%8
for f,f in ipairs(b)do
local b=c.doc(e,f)or tostring(h[f])
io.write("  "..g.padRight(f,a)..b.."\n")
end
end
d=d-1
if d<=0 then
break
end
end
