local b=require("computer")
local d=require("shell")
local c=require("text")
local a,a=d.parse(...)
local d=b.getDeviceInfo()
local b={}
if not next(a,nil)then
a.t,a.d,a.p=true,true,true
end
for e,e in ipairs({{"t","Class"},{"d","Description"},{"p","Product"},{"v","Vendor"},
{"c","Capacity"},{"w","Width"},{"s","Clock"}})do
if a[e[1]]then b[#b+1]=e[2]end
end
local a={}
for e,f in pairs(d)do
for e,g in ipairs(b)do
a[e]=math.max(a[e]or 1,(f[g:lower()]or""):len())
end
end
io.write(c.padRight("Address",10))
for e,f in ipairs(b)do
io.write(c.padRight(f,a[e]+2))
end
io.write("\n")
for e,f in pairs(d)do
io.write(c.padRight(e:sub(1,5).."...",10))
for d,e in ipairs(b)do
io.write(c.padRight(f[e:lower()]or"",a[d]+2))
end
io.write("\n")
end
