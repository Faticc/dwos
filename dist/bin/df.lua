local d=require("filesystem")
local e=require("shell")
local j=require("text")
local b,f=e.parse(...)
local function g(a)
if not f.h or type(a)=="string"then
return tostring(a)
end
local h={"","K","M","G"}
local c=1
local i=f.si and 1000 or 1024
while a>i and c<#h do
c=c+1
a=a/i
end
return math.floor(a*10)/10 ..h[c]
end
local a={}
if#b==0 then
for c,f in d.mounts()do
if not a[c]or a[c]:len()>f:len()then
a[c]=f
end
end
else
for c=1,#b do
local f,h=d.get(e.resolve(b[c]))
if not f then
io.stderr:write(b[c],": no such file or directory\n")
else
a[f]=h
end
end
end
local c={{"Filesystem","Used","Available","Use%","Mounted on"}}
for d,f in pairs(a)do
local h=d.getLabel()or d.address
local b,e=d.spaceUsed(),d.spaceTotal()
local d,a
if e==math.huge then
b=b or"N/A"
d="unlimited"
a="0%"
else
d=e-b
a=b/e
if a~=a then
d="N/A"
a="N/A"
else
a=math.ceil(a*100).."%"
end
end
c[#c+1]={h,g(b),g(d),tostring(a),f}
end
local a={}
for b,d in ipairs(c)do
for b,e in ipairs(d)do
a[b]=math.max(a[b]or 1,e:len())
end
end
for b,b in ipairs(c)do
for c,d in ipairs(b)do
io.write(j.padRight(d,a[c]+(c==#b and 0 or 2)))
end
print()
end
