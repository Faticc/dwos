local c=require("process")
local b=require("unicode")
local f=require("event")
local i=getmetatable(f.handlers)
local j=b.char(0x2514)
local function a(d,e)
if d then
return(tostring(d):gsub("^thread: 0x",""))
end
for d,g in pairs(c.list)do
if g==e then
return a(d)
end
end
return"-"
end
local function g(e)
local d=getmetatable(e)
return d and d.__status
end
local function d(e)return e==0 and"-"or tostring(e)end
local k={
{"PID",a},
{"EVENTS",function(e,h)
local e={}
if i.threaded then
e=rawget(h.data,"handlers")or{}
elseif not h.parent then
e=f.handlers
end
local f=0
for h in pairs(e)do f=f+1 end
return d(f)
end},
{"THREADS",function(e,f)
local e=0
for h,h in ipairs(f.data.handles)do
if g(h)then e=e+1 end
end
return d(e)
end},
{"PARENT",function(e,e)
for f,f in pairs(c.list)do
for h,h in ipairs(f.data.handles)do
if g(h)and getmetatable(h).process==e then
return a(nil,f)
end
end
end
return a(nil,e.parent)
end},
{"HANDLES",function(a,a)return d(#a.data.handles)end},
{"CMD",function(a,a)return a.command end},
}
local d={}
for e,f in pairs(c.list)do
local a={}
for c,c in ipairs(k)do
a[c[1]]=c[2](e,f)
end
d[#d+1]=a
end
local c,f={},{}
local function g(i,e)
for h,a in ipairs(d)do
if not f[h]and a.PARENT==i then
f[h]=true
a.CMD=(" "):rep(math.max(e-1,0))..(e>0 and j or"")..a.CMD
c[#c+1]=a
g(a.PID,e+1)
end
end
end
g("-",0)
local d={"PID","EVENTS","THREADS","HANDLES","CMD"}
local e={}
for a,a in ipairs(d)do
e[a]=b.wlen(a)
for f,f in ipairs(c)do
e[a]=math.max(e[a],b.wlen(f[a]))
end
end
local function f(j)
local g={}
for h,i in ipairs(d)do
local a=j[i]
g[h]=h<#d and a..string.rep(" ",e[i]-b.wlen(a))or a
end
print(table.concat(g,"   "))
end
local a={}
for b,b in ipairs(d)do a[b]=b end
f(a)
for a,a in ipairs(c)do
f(a)
end
