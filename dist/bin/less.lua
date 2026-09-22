local b=require("shell")
local e=require("unicode")
local c=require("keyboard")
local a=c.keys
local f=require("term")
local c=require("text")
local l,k=b.parse(...)
if#l>1 then
local b=(os.getenv("_")or"less"):match("([^/]+)%.lua$")or"less"
io.write("Usage: ",b," <filename>\n")
io.write("- or no args reads stdin\n")
return 1
end
local b=table.concat({"cat",...}," ")
if not io.output().tty then
return os.execute(b)
end
local o=io.popen(b)
local d,i=f.getViewport()
local function m(g)
g=c.detab(g,8)
local b,c={},1
while true do
local h=g:sub(c,c+d*3)
if#h<d or e.wlen(h)<=d then
b[#b+1]=h
break
end
b[#b+1]=e.wtrunc(h,d+1)
c=c+#b[#b]
if c>#g then break end
end
return b
end
local b,j={},false
local function n(c)
while not j and#b<c do
local c=o:read()
if not c then
j=true
o:close()
break
end
for d,d in ipairs(m(c))do b[#b+1]=d end
end
end
if k.noback then
local c=0
local function d(g)
f.clearLine()
for h=1,g do
n(c+1)
local g=b[c+1]
if not g then return false end
c=c+1
print(g)
b[c]=nil
end
return true
end
if not d(i-1)then return end
while true do
f.clearLine()
io.write(":")
local g,c,c,c=f.pull()
if g=="interrupted"then break end
if g=="key_down"then
if c==a.q then
f.clearLine()
break
elseif c==a.space or c==a.pageDown then
if not d(i-1)then break end
elseif c==a.enter or c==a.numpadenter or c==a.down then
if not d(1)then break end
elseif c==a["end"]then
while d(i-1)do end
break
end
end
end
f.clearLine()
return
end
local d=require("gfx")
local c=require("tty")
local s=require("event")
local t,u=0xD0D0D0,0x000000
local k,p,v,w=0x1B2A3A,0x7A8A98,0xE1E1E1,0x66CCFF
local x,y,B=0x2D4A66,0xFFFFFF,0xFFAA00
local g=c.gpu()
f.clear()
f.setCursorBlink(false)
local c=d.surface(g)
local m,i=c.w,c.h
local g=i-1
local z=l[1]and require("filesystem").name(l[1])or"stdin"
local d,h=1,nil
local function A()
n(math.huge)
return math.max(1,#b-g+1)
end
local function q()
n(d+g-1)
for l=0,g-1 do
local r=b[d+l]
c:fill(1,l+1,m,1," ",t,u)
if r and r~=""then c:set(1,l+1,r,t,u)end
end
if h and h>=d and h<d+g then
c:fill(1,h-d+1,m,1," ",y,x)
if b[h]~=""then c:set(1,h-d+1,b[h],y,x)end
end
local r=math.min(d+g-1,#b)
local u=j and#b or("~"..#b)
c:fill(1,i,m,1," ",p,k)
c:set(2,i,z,v,k)
local t=2+e.wlen(z)+2
local l=string.format("%d-%d/%s",d,r,u)
if j and r>=#b then l=l.."  конец"end
c:set(t,i,l,w,k)
local r="q выход   / поиск   n дальше"
local u=m-e.wlen(r)-1
if u>t+e.wlen(l)+2 then c:set(u,i,r,p,k)end
c:present()
end
local function t(r)
local l=""
while true do
c:fill(1,i,m,1," ",p,k)
c:set(2,i,r,B,k)
local p=2+e.wlen(r)
local r=m-p-1
if r>0 then
local m=l
while e.wlen(m)>r do m=e.sub(m,2)end
if m~=""then c:set(p,i,m,v,k)end
c:set(p+e.wlen(m),i,"_",k,w)
end
c:present()
local m,i,i,k=s.pull()
if m=="interrupted"then return nil end
if m=="key_down"then
if k==a.enter or k==a.numpadenter then return l
elseif k==a.back then l=e.sub(l,1,-2)
elseif k==1 then return nil
elseif i and i>=32 then l=l..e.char(i)end
elseif m=="clipboard"then
l=l..(i or""):gsub("\n.*","")
end
end
end
local i
local function k(l)
if not i or i==""then return end
local m=i:lower()
local e=l
while true do
n(e)
if e>#b then
if j then return end
else
if b[e]:lower():find(m,1,true)then
h=e
d=math.max(1,math.min(e-math.floor(g/2),A()))
return
end
e=e+1
end
if j and e>#b then return end
end
end
local function e(l)
n(d+l+g-1)
local m=j and math.max(1,#b-g+1)or math.huge
d=math.max(1,math.min(d+l,m))
end
local function l()
c:close()
f.setCursorBlink(true)
f.clear()
if not j then pcall(o.close,o)end
end
local function f()
q()
while true do
local c,b,j,b,m=s.pull()
if c=="interrupted"then break end
if c=="key_down"then
if b==a.q then break
elseif b==a.down or b==a.enter or b==a.numpadenter then e(1)
elseif b==a.up then e(-1)
elseif b==a.space or b==a.pageDown then e(g-1)
elseif b==a.pageUp then e(-(g-1))
elseif b==a.home then d=1
elseif b==a["end"]then d=A()
elseif j==47 then
i=t("/")
h=nil
if i then k(d+1)end
elseif b==a.n then
k((h or d)+1)
end
q()
elseif c=="scroll"then
e((m or 0)>0 and-3 or 3)
q()
end
end
end
local a,b=xpcall(f,debug.traceback)
l()
if not a then error(b,0)end
