local h=...
local o=require("unicode")
local function p(a)
if not a then return"?"end
if a>=1048576 then return string.format("%.1f МБ",a/1048576)end
return string.format("%d КБ",math.floor(a/1024+0.5))
end
local function D(d,e)
local b,c={},nil
for a,a in ipairs(d)do
if a.on and not a.header and a.disk and a.disk~=a.at then
b[a.disk]=(b[a.disk]or 0)+(a.size or 0)
end
end
for d,a in ipairs(e)do
if b[d]and a.free and b[d]>a.free then
c=c or string.format("на \"%s\" не влезает: нужно %s, свободно %s",
a.name,p(b[d]),p(a.free))
end
end
return b,c
end
local function E(a)
if a.header or a.lock then return end
a.on=not a.on
end
local function F(a,b,c)
if a.header or a.lock or not a.on or#b==0 then return end
a.disk=((a.disk or 1)-1+c)%#b+1
end
local u={
sources="What do you want to install?",
targets="Where do you want to install to?",
}
local y={
sources="Что установить?",
targets="Куда установить?",
}
local function z(b)
local a=b.dev
local c=(b.prop or{}).label or a.getLabel()
if c then
return string.format("%s (%s...)",c,a.address:sub(1,8))
end
return a.address
end
local function k(a)
table.sort(a,function(a,b)return a.path<b.path end)
end
local function m(b,a)
if b=="sources"then
if a.label then
io.stderr:write("Nothing to install labeled: "..a.label.."\n")
elseif a.from then
io.stderr:write("Nothing to install from: "..a.from.."\n")
else
io.stderr:write("Nothing to install\n")
end
else
if a.to then
io.stderr:write("No such target to install to: "..a.to.."\n")
else
io.stderr:write("No writable disks found, aborting\n")
end
end
os.exit(1)
end
local a={graphic=false}
function a.select(d,b,c)
if#b==0 then m(d,c)end
k(b)
local c=#b
if c<2 then return b[1]end
io.write(u[d],"\n")
for e=1,c do
local d=b[e]
io.write(string.format("%d) %s at %s [r%s]\n",
e,z(d),d.path,d.dev.isReadOnly()and"o"or"w"))
end
io.write("Please enter a number between 1 and "..c.."\n")
io.write("Enter 'q' to cancel the installation: ")
for d=1,5 do
local e=io.read()or"q"
if e=="q"then os.exit()end
local d=tonumber(e)
if d and d>0 and d<=c then
return b[d]
end
io.write("Invalid input, please try again: ")
os.sleep(0)
end
print("\ntoo many bad inputs, aborting")
os.exit(1)
end
function a.note(b)
io.write(b,"\n")
end
function a.ask(b)
io.write(b," [Y/n] ")
return((io.read()or"n").."y"):match("^%s*[Yy]")~=nil
end
function a.progress()end
function a.step(b,c)
io.write(b," -> ",c,"\n")
end
function a.finish(b)
io.write(b,"\n")
end
function a.pause()end
function a.close()end
function a.checklist(e,c,d,b)
b=b or{}
while true do
io.write("\n",e,"\n")
for e,b in ipairs(d)do
io.write(string.format("  диск %d: %s, свободно %s\n",e,b.name,p(b.free)))
end
for e,b in ipairs(c)do
if b.header then
io.write("  ",b.text,"\n")
else
local f=b.lock and"[*]"or b.on and"[x]"or"[ ]"
local g=b.on and b.disk and(" -> диск "..b.disk)or""
io.write(string.format("%3d) %s %s  %s%s\n",e,f,b.text,b.sub or"",g))
end
end
local b,b=D(c,d)
if b then io.write("!! ",b,"\n")end
io.write("номер - отметить, 'номер диск' - куда, 'все диск' - всё туда,\n")
io.write("пустая строка - ставить, q - отмена: ")
local f=io.read()
if not f or f=="q"then return nil end
local e,g=f:match("^%s*(%S*)%s*(%S*)%s*$")
if e==""then
if not b then return true end
elseif e=="все"or e=="all"then
local f=tonumber(g)
if f and d[f]then
for b,b in ipairs(c)do
if b.on and not b.lock and not b.header then b.disk=f end
end
end
else
local b,f=c[tonumber(e)or 0],tonumber(g)
if b and f and d[f]then
if not b.lock and not b.header then b.on=true b.disk=f end
elseif b then
E(b)
end
end
end
end
if not h then return a end
local s=require("gfx")
local v=require("term")
local A=require("tty")
local B=require("event")
local I=require("computer")
local b=require("keyboard").keys
local i,l,d,w=0x1B2A3A,0xE1E1E1,0x8C8C8C,0x66CCFF
local G,J,K=0x2D4A66,0x33B5E5,0x000000
local j={graphic=true}
local a,f,c
local function q(e,g)
local h=A.gpu()
local n,r=h.getResolution()
e=math.min(e or 62,n-2)
g=math.min(g or 16,r-2)
if a and f==e and c==g then return end
if a then a:close()a=nil end
f,c=e,g
v.clear()
v.setCursorBlink(false)
a=s.surface(h,{
x=math.floor((n-f)/2)+1,
y=math.floor((r-c)/2)+1,
w=f,h=c,
})
end
local function r(e,g)
if o.wlen(e)>g then e=o.wtrunc(e,g+1)end
return e
end
local function h(n,g,s,e)
e=e or i
a:fill(2,n,f-2,1," ",l,e)
if g and g~=""then a:set(3,n,r(g,f-4),s or l,e)end
end
local function s(t,g)
local e=("─"):rep(f-2)
a:fill(1,1,f,c," ",l,i)
a:set(1,1,"┌"..e.."┐",d,i)
a:set(1,c,"└"..e.."┘",d,i)
for n=2,c-1 do
a:set(1,n,"│",d,i)
a:set(f,n,"│",d,i)
end
a:set(1,3,"├"..e.."┤",d,i)
a:set(3,1," "..r(t,f-6).." ",w,i)
if g then a:set(3,c," "..r(g,f-6).." ",d,i)end
end
local function t()
a:fill(2,4,f-2,c-4," ",l,i)
end
local function x()
while true do
local e,g,g,n=B.pull()
if e=="interrupted"then return nil,nil end
if e=="key_down"then return g,n end
end
end
function j.select(n,g,e)
if#g==0 then
j.close()
m(n,e)
end
k(g)
if#g<2 then return g[1]end
q()
local m=c-5
local e,k=1,1
while true do
if e<k then k=e end
if e>k+m-1 then k=e-m+1 end
s(y[n],"↑↓ выбор · Enter — ok · Q — отмена")
h(2,u[n],d)
t()
for n=0,m-1 do
local u=g[k+n]
if not u then break end
local y=k+n==e
local k=y and G or i
local B=u.dev.isReadOnly()and"ro"or"rw"
h(4+n,(y and"▸ "or"  ")..z(u),y and l or d,k)
local y=u.path.." ["..B.."]"
local u=f-3-o.wlen(y)
if u>4 then a:set(u,4+n,y,d,k)end
end
if#g>m then
h(c-1,string.format("%d из %d",e,#g),d)
end
a:present()
local m,k=x()
if not k then return nil end
if k==b.up then
e=e>1 and e-1 or#g
elseif k==b.down then
e=e<#g and e+1 or 1
elseif k==b.home then
e=1
elseif k==b["end"]then
e=#g
elseif k==b.enter or k==b.numpadenter then
return g[e]
elseif k==b.q or m==113 or k==1 then
return nil
end
end
end
local L,M=0xFF6655,0x77DD77
function j.checklist(H,k,n,B)
B=B or{}
local e=A.gpu()
local g,m=e.getResolution()
q(math.min(g-2,110),math.min(m-2,#k+9))
local u=c-7
local y=#n>0 and 26 or 0
local function C(e)return k[e]and not k[e].header end
local g=1
while k[g]and not C(g)do g=g+1 end
local m,z=1,nil
local function A(N)
local e=g
repeat e=e+N until e<1 or e>#k or C(e)
if C(e)then g=e end
end
while true do
if g<m then m=g end
if g>1 and k[g-1].header and g-1<m then m=g-1 end
if g>m+u-1 then m=g-u+1 end
s(H,"пробел — отметить · ←→ — диск · Tab — этот диск всем · Enter — ставить · Q — отмена")
h(2,B.prompt or"Отметь, что поставить, и выбери, на какой диск",d)
t()
for C=0,u-1 do
local e=k[m+C]
if not e then break end
local B=4+C
if e.header then
h(B,e.text,w)
else
local H=m+C==g
local m=H and G or i
local i=e.lock and"[•]"or e.on and"[x]"or"[ ]"
h(B,(H and"▸ "or"  ")..i.." "..e.text,e.on and l or d,m)
local C=f-3-y
if e.sub then
local i=r(e.sub,24)
a:set(C-o.wlen(i)-1,B,i,d,m)
end
if y>0 and e.on and n[e.disk]then
local G=e.at and e.disk~=e.at
local H=n[e.disk].name
local i=(e.lock and"  "or"◂ ")..r(H,y-4)
i=i..(" "):rep(y-2-o.wlen(i))..(e.lock and""or"▸")
a:set(C+1,B,i,(e.at==nil or G)and w or d,m)
end
end
end
local i,m=D(k,n)
local e={}
for r,y in ipairs(n)do
if i[r]then e[#e+1]=string.format("%s: %s из %s",y.name,p(i[r]),p(y.free))end
end
local i=#e>0 and("запишется — "..table.concat(e," · "))or"ничего нового не качается"
h(c-2,z or m or i,(z or m)and L or M)
z=nil
a:present()
local p,e=x()
if not e then return nil end
local i=k[g]
if e==b.up then A(-1)
elseif e==b.down then A(1)
elseif e==b.pageUp then for g=1,u do A(-1)end
elseif e==b.pageDown then for g=1,u do A(1)end
elseif e==b.space then E(i)
elseif e==b.left then F(i,n,-1)
elseif e==b.right then F(i,n,1)
elseif e==b.tab then
if i and i.on and i.disk then
for g,g in ipairs(k)do
if g.on and not g.lock and not g.header then g.disk=i.disk end
end
end
elseif e==b.enter or e==b.numpadenter then
if m then z=m else return true end
elseif e==b.q or p==113 or e==1 then
return nil
end
end
end
local i
function j.note(e)
i=e
end
local function m(e,p)
local g={}
for n in(e.."\n"):gmatch("(.-)\n")do
local e=""
for k in n:gmatch("%S+")do
local n=e==""and k or(e.." "..k)
if o.wlen(n)>p and e~=""then
g[#g+1]=e
e=k
else
e=n
end
end
g[#g+1]=e
end
return g
end
function j.ask(g)
q()
s("Подтверждение","Enter/Y — да · N — нет")
h(2,i or"",d)
t()
local e=m(g,f-6)
local g=math.max(4,math.floor((c-3-#e)/2)+3)
for k,n in ipairs(e)do
if g+k-1<c then h(g+k-1,n)end
end
h(c-2,"[ Да ]   [ Нет ]",w)
a:present()
while true do
local g,e=x()
if not e then return false end
if e==b.enter or e==b.numpadenter or e==b.y or g==121 then
return true
elseif e==b.n or g==110 or e==b.q or e==1 then
return false
end
end
end
local e,b,g
local function k()
local n=f-6
local o=e>0 and math.min(1,b/e)or 0
local p=math.floor(n*o+0.5)
a:fill(3,c-3,n,1," ",l,K)
if p>0 then a:fill(3,c-3,p,1," ",l,J)end
local n=string.format("%d%%  %d/%d",math.floor(o*100+0.5),b,e)
h(c-2,n,d)
end
function j.progress(n)
q()
e,b,g=n or 0,0,0
s("Установка","Ctrl+C — прервать")
h(2,i or"",d)
t()
h(5,"Копирование файлов…",l)
k()
a:present()
end
function j.step(l)
b=b+1
local i=I.uptime()
if i-g<0.2 and b<e then return end
g=i
h(7,l,d)
k()
a:present()
end
function j.finish(d)
q()
s("Готово","Enter — дальше")
t()
local b=m(d,f-6)
local d=math.max(4,math.floor((c-3-#b)/2)+3)
for e,f in ipairs(b)do
if d+e-1<c then h(d+e-1,f)end
end
a:present()
end
function j.pause()
x()
end
function j.close()
if not a then return end
a:close()
a=nil
v.setCursorBlink(true)
v.clear()
end
return j
