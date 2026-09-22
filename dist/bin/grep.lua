local b=require("filesystem")
local f=require("shell")
local i=require("tty")
local C=require("computer")
local a,c=f.parse(...)
local function l(g,d)
local e=g or io.stdout
if d then
e:write(d,"\n")
end
e:write([[Usage: grep [OPTION]... PATTERN [FILE]...
Example: grep -i "hello world" menu.lua main.lua
for more information, run: man grep
]])
end
local d={a[1]}
local e={select(2,table.unpack(a))}
local m=0xb000b0
local D=0x00FF00
local E=0xFF0000
local n=0x00FFFF
local function a(...)
local g
for h,h in ipairs({...})do
g=c[h]or g
c[h]=nil
end
return g
end
local k=a("F","fixed-strings")
k=not a("e","--lua-regexp")and k
local h=a("file")
local B=a("w","word-regexp")
local F=a("x","line-regexp")
local A=a("i","ignore-case")
local G=a("label")or"(standard input)"
local g=a("s","no-messages")and{write=function()end}or io.stderr
local H=not not a("v","invert-match")
if a("V","version","help")then
l()
return 0
end
local o=tonumber(a("max-count"))or math.huge
local w=a("n","line-number")
local p=a("r","recursive")
if h then
local j=f.resolve(h)
if not b.exists(j)then
g:write("grep: ",h,": file not found")
return 2
end
table.insert(e,1,d[1])
d={}
for h in io.lines(j)do
d[#d+1]=h
end
end
if#d==0 then
l(g)
return 2
end
if#e==0 then
e=p and{"."}or{"-"}
end
if not c.h and p then
c.H=true
end
if#e<2 then
c.h=true
end
local j=a("l","files-with-matches")
local q=a("L","files-without-match")and not j
local h=a("H","with-filename")
h=not a("h","no-filename")or h
local r=a("o","only-matching")
local x=a("q","quiet","silent")
local s=a("c","count")
local t=a("color","colour")and io.output().tty and i.isAvailable()
local u=i.gpu()
local i=function(...)return...end
local v=t and u.setForeground or i
local I=t and u.getForeground or i
local t=a("t","trim")
local y=t and function(a)return a:gsub("^%s+","")end or i
local z=t and function(a)return a:gsub("%s+$","")end or i
if next(c)then
if not x then
l(g,"unexpected option: "..next(c))
return 2
end
return 0
end
local function t(a)
if a:sub(1,1)=="/"then
return b.canonical(a)
end
if a:sub(1,2)=="./"then
a=a:sub(3,-1)
end
return b.canonical(b.concat(f.getWorkingDirectory(),a))
end
if A then
for a=1,#d do
d[a]=d[a]:gsub("(%%?)(.)",function(c,a)
if c~=""or not a:match("%a")then
return c..a
end
return string.format("[%s%s]",a:lower(),a:upper())
end)
end
end
local function i(l,a)
for u in b.list(f.resolve(l))do
local c=l:gsub("/+$","").."/"..u
if b.isDirectory(f.resolve(c))then
i(c,a)
else
a[#a+1]=c
end
end
end
if p then
local a={}
for c,c in ipairs(e)do
if b.isDirectory(c)then
i(c,a)
else
a[#a+1]=c
end
end
e=a
end
local function J()
local c,f,a
return function()
if not f then
local i=table.remove(e,1)
if not i then
return
end
a={line_num=0,hits=0}
if i=="-"then
f=i
a.label=G
c=io.input()
else
a.label=i
local e=t(i)
if not b.exists(e)then
g:write("grep: ",e,": file not found\n")
return false,2
end
local b
c,b=io.open(e,"r")
if not c then
g:write("grep: ",string.format("failed to read from %s: %s",a.label,b),"\n")
return false,2
end
f=a.label
end
end
a.line=nil
if not a.close and c then
a.line_num=a.line_num+1
a.line=c:read("*l")
end
if not a.line then
f=nil
if c then
c:close()
end
return false,a
end
return a,f
end
end
local function a(c,b)
local e=b and I()
if b then v(b)end
io.write(c)
if b then v(e)end
end
local l=(j or q or s)and function(b)
if q and b.hits==0 or j and b.hits~=0 then
a(b.label,m)
a("\n")
elseif s then
if h then
a(b.label,m)
a(":",n)
end
a(b.hits)
a("\n")
end
end
local p=nil
local A=1
local function G(b,s)
local t=true
local e,g=1,#b.line
local u,v=h,w
local i=1
while e<=g and not b.close do
local c,f=b.line:find(s,e,k)
local I=B and not(c and not(b.line:sub(c-1,c-1)..b.line:sub(f+1,f+1)):find("[%a_]"))
local K=F and not(c==1 and f==g)
local B=not((r or e==1)and not c)
if(i==1 and I)or K then
B,c,f=false
end
if H==B then break end
if o==0 then os.exit(1)end
A=0
b.hits,i=b.hits+i,0
if j or q then
b.close=true
end
if l or x then return end
if u then
a(b.label,m)
a(":",n)
u=nil
end
if v then
a(b.line_num,D)
a(":",n)
v=nil
end
local i=r and""or b.line:sub(e,(c or 0)-1)
local j=c and b.line:sub(c,f)or""
if c==1 then j=y(j)elseif e==1 then i=y(i)end
if f==g then j=z(j)elseif not c then i=z(i)end
a(i)
a(j,E)
t=false
e=(f or g)+1
if r or e>g then
a("\n")
t=true
u,v=h,w
elseif s:find("^^")and not k then
s="^$"
end
end
if not t then a("\n")end
if o~=math.huge and o>=b.hits then
b.close=true
end
end
local b=C.uptime
local c=b()
for e,a in J()do
if b()-c>1 then
os.sleep(0)
c=b()
end
if not e then
if type(a)=="table"then
if l then l(a)end
elseif a then
p=a or p
end
else
for a,a in ipairs(d)do
G(e,a)
end
end
end
return p or A
