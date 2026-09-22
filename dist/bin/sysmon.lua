local y=require("component")
local c=require("computer")
local A=require("event")
local z=require("filesystem")
local e=require("gfx")
local B=require("keyboard").keys
local f=require("term")
local a=require("tty")
local C=require("unicode")
if not f.isAvailable()then return end
local b,l=0x000000,0x181818
local r,s=0x66CCFF,0x88DD66
local D,n,E=0xD0D0D0,0x888888,0xFFCC66
local d=a.gpu()
local g,h=d.getResolution()
f.clear()
f.setCursorBlink(false)
local a=e.new(d,g,h,{rgb=true,keepResolution=true,background=b})
local d,i=a.w,a.h
local j=math.min(10,math.max(3,math.floor((i-14)/2)))
local k=3
local o=k+j+1
local p=o+j+2
local t,u={},{}
local g=d
local function v(e,h)
e[#e+1]=h
while#e>g do table.remove(e,1)end
end
local function g(e)
if e>=1048576 then return string.format("%.1fM",e/1048576)end
if e>=1024 then return string.format("%.0fK",e/1024)end
return tostring(math.floor(e))
end
local function F(h)
local e=math.floor(h)
return string.format("%d:%02d:%02d",math.floor(e/3600),math.floor(e/60)%60,e%60)
end
local function w(q,x,m,G)
local e,h=(q-1)*2+1,x*2
a:rect(1,e,d,h,b)
for q=e,e+h-1,4 do a:rect(1,q,d,1,l)end
local l=#m
local x=math.max(1,l-d+1)
for q=x,l do
local x=math.max(0,math.min(1,m[q]))
local m=math.floor(x*h+0.5)
if m>0 then a:rect(d-(l-q),e+h-m,1,m,G)end
end
end
local function x()
local h,e={},{}
for l,l in pairs(y.list())do e[l]=(e[l]or 0)+1 end
local l={}
for m in pairs(e)do l[#l+1]=m end
table.sort(l)
local q={}
for m,m in ipairs(l)do
q[#q+1]=e[m]>1 and(m.." x"..e[m])or m
end
h[#h+1]={"Железо",table.concat(q,", ")}
local l={}
for e,q in z.mounts()do
if not l[e.address]and e.spaceTotal then
l[e.address]=true
local y,l=pcall(e.spaceTotal)
local z,m=pcall(e.spaceUsed)
if y and z and m then
local y=e.getLabel()or e.address:sub(1,8)
local e=(l and l<math.huge)and(g(m).." / "..g(l))
or(g(m).." занято")
h[#h+1]={y,e.."  "..q}
end
end
end
return h
end
local q,y=x(),c.uptime()
local function z()
local h,e=c.totalMemory(),c.freeMemory()
local l=h-e
local m,e=c.energy(),c.maxEnergy()
v(t,l/h)
v(u,e>0 and m/e or 0)
w(k,j,t,r)
w(o,j,u,s)
a:rect(1,1,d,(k-1)*2,b)
a:rect(1,(p-2)*2+1,d,(i-p+2)*2,b)
a:flush(true)
a:text(2,1,"DwOS · монитор",E,b)
local j="аптайм "..F(c.uptime())
a:text(d-C.wlen(j)-1,1,j,n,b)
a:text(2,k-1,string.format("Память  %s из %s  (%d%%)",
g(l),g(h),math.floor(l/h*100+0.5)),r,b)
a:text(2,o-1,string.format("Энергия  %d из %d  (%d%%)",
math.floor(m),math.floor(e),
e>0 and math.floor(m/e*100+0.5)or 0),s,b)
for g,e in ipairs(q)do
local d=p+g-1
if d<=i-1 then
a:text(2,d,e[1],D,b)
a:text(16,d,e[2],n,b)
end
end
a:text(2,i,"q — выход",n,b)
a:present()
end
local function e()
z()
while true do
local b,d,d,d=A.pull(0.5)
if b=="interrupted"then break end
if b=="key_down"and(d==B.q or d==1)then break end
if c.uptime()-y>5 then
q,y=x(),c.uptime()
end
z()
end
end
local b,c=xpcall(e,debug.traceback)
a:close()
f.setCursorBlink(true)
f.clear()
if not b then error(c,0)end
