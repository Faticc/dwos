local e={}
local f={0x0,0xff0000,0x00ff00,0xffff00,0x0000ff,0xff00ff,0x00B6ff,0xffffff}
local function g(a,b,c)
a.x=math.min(math.max(b,1),a.width)
a.y=math.min(math.max(c,1),a.height)
end
local function l(d,h)
local i=d.gpu
local b,c=i.setForeground,i.setBackground
if d.flip then
b,c=c,b
end
if h==";"then h=""end
local a={"_"}
for j in(h..";"):gmatch("([^;]*);")do
if j~=""then a[#a+1]=j end
a[#a+1]="_"
end
local h
for j,j in ipairs(a)do
local a=tonumber(j)
h,a=not a,a or h and 0
local h=a==7
if h then
if not d.flip then
local k,j=c(i.getForeground())
b(j or k,not not j)
b,c=c,b
end
elseif a==5 then
d.blink=true
elseif a==0 then
c(f[1])
b(f[8])
elseif a then
a=a-29
local i=b
if a>10 then
a=a-10
i=c
end
local b=f[a]
if b then
i(b)
end
end
d.flip=h
end
end
local function j(a)
local b=a.gpu
a.saved={a.x,a.y,{b.getBackground()},{b.getForeground()},a.flip,a.blink}
end
local function k(a)
local c=a.gpu
local b=a.saved or{1,1,{0x0},{0xffffff},a.flip,a.blink}
a.x,a.y=b[1],b[2]
c.setBackground(table.unpack(b[3]))
c.setForeground(table.unpack(b[4]))
a.flip,a.blink=b[5],b[6]
end
local function d(a,b)
b=tonumber(b)or 0
local c=b==0 and a.x or 1
local f=b==1 and a.x or(a.width-c+1)
a.gpu.fill(c+a.dx,a.y+a.dy,f,1," ")
end
local b={
m=function(c,a)if not a:find("[^%d;]")then l(c,a)return true end end,
s=function(a,c)if c==""then j(a)return true end end,
u=function(a,c)if c==""then k(a)return true end end,
h=function(a,c)if c=="?7"then a.nowrap=false return true end end,
l=function(a,c)if c=="?7"then a.nowrap=true return true end end,
K=function(c,a)if a:match("^[012]?$")then d(c,a)return true end end,
J=function(a,c)
if not c:match("^[012]?$")then return end
d(a,c)
local d=tonumber(c)or 0
local c=d==0 and(a.y+1)or 1
local f=d==1 and(a.y-1)or a.height
a.gpu.fill(1+a.dx,c+a.dy,a.width,f," ")
return true
end,
n=function(a,c)
if c~="6"then return end
io.stdin.bufferRead=string.format("%s%s[%d;%dR",io.stdin.bufferRead,string.char(0x1b),a.y,a.x)
return true
end,
}
local function a(d,h,f)
if not h:match("^%d*$")then return end
local c=tonumber(h)or 1
local h,i=0,0
if f=="A"then i=-c elseif f=="B"then i=c elseif f=="C"then h=c else h=-c end
g(d,d.x+h,d.y+i)
return true
end
b.A,b.B,b.C,b.D=a,a,a,a
local function a(c,d)
if d==""then g(c,1,1)return true end
local f,h=d:match("^(%d*);(%d*)$")
if not f then return end
g(c,tonumber(h)or 1,tonumber(f)or 1)
return true
end
b.H,b.f=a,a
function e.consume(a,f,d)
local c=f:sub(d+1,d+1)
if c==""then
return nil
elseif c=="7"then
j(a)return 2
elseif c=="8"then
k(a)return 2
elseif c=="D"then
a.y=a.y+1 return 2
elseif c=="E"then
a.y=a.y+1 a.x=1 return 2
elseif c=="M"then
a.y=a.y-1 return 2
elseif c=="["then
local g,c=f:match("^([%d;%?]*)(.?)",d+2)
if c==""then
return nil
end
local d=b[c]
if d and d(a,g,c)then
return 2+#g+1
end
end
return 1,"\27"
end
function e.parse(a)
local b=a.output_buffer
if b:sub(1,1)~="\27"then
return""
end
local c,d=e.consume(a,b,1)
if not c then return nil end
a.output_buffer=b:sub(c+1)
return d or""
end
return e
