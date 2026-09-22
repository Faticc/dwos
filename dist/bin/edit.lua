local g=require("filesystem")
local H=require("keyboard")
local h=H.keys
local b=require("shell")
local s=require("term")
local a4=require("text")
local a=require("unicode")
local at=require("event")
local J=require("computer")
local ar=require("component")
local bg=require("gfx")
local Q=require("tty")
local ah=require("luascan")
if not s.isAvailable()then return end
local c,d=b.parse(...)
if#c==0 then
io.write("Usage: edit [-r] <filename>\n")
return
end
local j=b.resolve(c[1])
local ai=g.path(j)
if g.exists(ai)and not g.isDirectory(ai)then
io.stderr:write(string.format("Not a directory: %s\n",ai))
return 1
end
if g.isDirectory(j)then
io.stderr:write("file is a directory\n")
return 1
end
local k=d.r or g.get(j)==nil or g.get(j).isReadOnly()
if not g.exists(j)and k then
io.stderr:write("file system is read only\n")
return 1
end
local e={
left={{"left"}},
right={{"right"}},
up={{"up"}},
down={{"down"}},
home={{"home"}},
eol={{"end"}},
pageUp={{"pageUp"}},
pageDown={{"pageDown"}},
backspace={{"back"},{"shift","back"}},
delete={{"delete"}},
deleteLine={{"control","delete"},{"shift","delete"}},
newline={{"enter"}},
save={{"control","s"}},
close={{"control","w"}},
find={{"control","f"}},
findnext={{"control","g"},{"control","n"},{"f3"}},
cut={{"control","k"}},
uncut={{"control","u"}},
goto_line={{"control","l"}},
copy={{"control","c"}},
cutSelection={{"control","x"}},
selectAll={{"control","a"}},
undo={{"control","z"}},
redo={{"control","y"}},
complete={{"tab"}},
completeList={{"control","space"}},
unindent={{"shift","tab"}},
run={{"f5"},{"control","r"}},
shell={{"control","e"}},
panel={{"control","o"}},
replace={{"control","h"}},
findprev={{"shift","f3"}},
open={{"control","p"}},
nextDoc={{"control","pageDown"}},
prevDoc={{"control","pageUp"}},
outline={{"control","t"}},
definition={{"f12"}},
usages={{"shift","f12"}},
back={{"control","b"}},
rename={{"f2"}},
problem={{"f8"}},
problemPrev={{"shift","f8"}},
comment={{"control","slash"}},
duplicate={{"control","d"}},
moveUp={{"alt","up"},{"control","shift","up"}},
moveDown={{"alt","down"},{"control","shift","down"}},
fold={{"control","lbracket"}},
debug={{"f6"}},
breakpoint={{"f9"}},
stepGo={{"f5"},{"c"}},
stepOver={{"f10"},{"n"}},
stepInto={{"f11"},{"f7"},{"s"}},
stepOut={{"shift","f11"},{"shift","f7"},{"o"}},
stepStop={{"f4"},{"q"}},
help={{"f1"}},
}
local function f()
local b={}
local c=loadfile("/etc/edit.cfg",nil,b)
if c then pcall(c)end
if type(b.keybinds)~="table"then b.keybinds={}end
local c=false
for d,i in pairs(e)do
if b.keybinds[d]==nil then
b.keybinds[d]=i
c=true
end
end
if c then
local c=g.get("/")
if c and not c.isReadOnly()then
g.makeDirectory("/etc")
local c=io.open("/etc/edit.cfg","w")
if c then
local d=require("serialization")
for e,i in pairs(b)do
c:write(e.."="..tostring(d.serialize(i,math.huge)).."\n")
end
c:close()
end
end
end
return b
end
local au=f()
local function bh(b,m,n,o,p)
local c=au.keybinds[b]
local d=0
for b,b in ipairs(type(c)=="table"and c or{})do
if type(b)=="table"then
local e,f,i,l=false,false,false,nil
for c,c in ipairs(b)do
if c=="alt"then e=true
elseif c=="control"then f=true
elseif c=="shift"then i=true
else l=c end
end
if e==p and f==o and i==n
and m==h[l]and#b>d then
d=#b
end
end
end
return d
end
local function av(c,d)
local b=s.keyboard()
return bh(c,d,not not H.isShiftDown(b),
not not H.isControlDown(b),not not H.isAltDown(b))>0
end
local c={
FG=0xD0D0D0,BG=0x000000,
C_KW=0x66CCFF,C_STR=0x88DD88,C_NUM=0xFFAA00,C_CMT=0x707070,C_BLT=0xFF9966,C_OP=0xBBBBBB,
BAR_BG=0x1B2A3A,BAR_FG=0x7A8A98,BAR_NAME=0xE1E1E1,
BAR_POS=0x66CCFF,BAR_MARK=0xFFAA00,BAR_MSG=0x88DD88,
GUT=0x4E5D6B,GUT_CUR=0x9AA8B4,CUR=0xFFFFFF,
SEL=0x2D4A66,FIND=0xFFAA00,PAIR=0x4E7A2D,
ERR=0xFF6666,WARN=0xE0C050,
BP_BG=0x8A2020,DBG_BG=0x3C3A12,FIND_ALL=0x5A4210,
POP_BG=0x22323F,POP_FG=0xC8D2DA,POP_SEL=0x2D4A66,
}
local aP={}
for b in("and break do else elseif end for function goto if in local not or "..
"repeat return then until while"):gmatch("%S+")do aP[b]=true end
local as={}
for b in("nil true false self _G _ENV require print pairs ipairs type tostring tonumber "..
"string table math os io coroutine error assert pcall xpcall select setmetatable "..
"getmetatable rawget rawset rawequal rawlen next load dofile loadfile unpack "..
"component computer unicode checkArg"):gmatch("%S+")do
as[b]=true
end
local function bi(b)return b:sub(-4)==".lua"or b:sub(-4)==".cfg"end
local K=bi(j)
local function v(d,l)
local n,b,m={},1,#d
local function f(e,i)if e~=""then n[#n+1]={e,i}end end
while b<=m do
if l then
local e="]"..("="):rep(l.level).."]"
local i=d:find(e,b,true)
local o=l.comment and c.C_CMT or c.C_STR
if i then
f(d:sub(b,i+#e-1),o)
b=i+#e
l=nil
else
f(d:sub(b),o)
b=m+1
end
else
local i=d:sub(b,b)
if i:match("%s")then
local o,e=d:find("%s+",b)
f(d:sub(o,e),c.FG)
b=e+1
elseif d:find("^%-%-",b)then
local e=d:match("^%-%-%[(=*)%[",b)
if e then
l={level=#e,comment=true}
f(d:sub(b,b+#e+3),c.C_CMT)
b=b+#e+4
else
f(d:sub(b),c.C_CMT)
b=m+1
end
elseif d:find("^%[=*%[",b)then
local e=d:match("^%[(=*)%[",b)
l={level=#e,comment=false}
f(d:sub(b,b+#e+1),c.C_STR)
b=b+#e+2
elseif i=='"'or i=="'"then
local e=b+1
while e<=m do
local m=d:sub(e,e)
if m=="\\"then
e=e+2
elseif m==i then
e=e+1
break
else
e=e+1
end
end
f(d:sub(b,e-1),c.C_STR)
b=e
elseif i:match("%d")or(i=="."and d:sub(b+1,b+1):match("%d"))then
local e,m=d:find("^0[xX]%x+",b)
if not e then e,m=d:find("^%d+%.?%d*[eE][-+]?%d+",b)end
if not e then e,m=d:find("^%d*%.?%d+",b)end
if not e then e,m=b,b end
f(d:sub(e,m),c.C_NUM)
b=m+1
elseif i:match("[%a_\128-\255]")then
local o,m=d:find("^[%w_\128-\255]+",b)
local e=d:sub(o,m)
f(e,aP[e]and c.C_KW or as[e]and c.C_BLT or c.FG)
b=m+1
else
f(i,c.C_OP)
b=b+1
end
end
end
return n,l
end
local r=Q.gpu()
s.clear()
s.setCursorBlink(false)
local aQ,an=r.getResolution()
local U=0
local y=bg.surface(r,{h=an})
local t,aF=y.w,y.h
local x=aF-1
local e={}
local aR,ab={},1
local d,b=1,1
local z,E=0,0
local aS=true
local o=nil
local q={}
local aT=false
local N=0
local F=nil
local f,Z=nil,{}
local i,L=true,false
local m,aw=nil,nil
local V=2
local aG=nil
local aU
local B,C={},{}
local D={}
local ac,A=nil,nil
local ax,a5=nil,-1
local aj=nil
local ao=0
local W=nil
local aV=nil
local aW,al={},{}
local function p()return e[b]or""end
local function aB()return t-V end
local function aN(l,n)
return a.wlen(a.sub(l,1,n-1))+1
end
local function bt(l,n)
if n>a.wlen(l)then return a.len(l)+1 end
return a.len(a.wtrunc(l,n))+1
end
local function aE(u,l)
if l>=a.wlen(u)then return""end
local w=a.wtrunc(u,l+1)
local n=a.sub(u,a.len(w)+1)
l=l-a.wlen(w)
if l>0 then
n=(" "):rep(a.charWidth(n)-l)..a.sub(n,2)
end
return n
end
local function _(l,n)
if n<1 then return""end
return a.wlen(l)>n and a.wtrunc(l,n+1)or l
end
local function S(l)
if ab>l then ab=l end
end
local function n(l)
l=math.min(l,#e)
while ab<=l do
local l,l=v(e[ab]or"",aR[ab])
aR[ab+1]=l
ab=ab+1
end
end
local function a6(l)
if not K then return{{e[l]or"",c.FG}}end
n(l-1)
return(v(e[l]or"",aR[l]))
end
local function ad(l)Z[l]=true end
local function O()
if not o then return nil end
local l,u,n,v=o[2],o[1],b,d
if l>n or(l==n and u>v)then
l,u,n,v=n,v,l,u
end
if l==n and u==v then return nil end
return l,u,n,v
end
local function a7()
local l,v,u,w=O()
if not l then return nil end
if l==u then
return{a.sub(e[l],v,w-1)}
end
local n={a.sub(e[l],v)}
for v=l+1,u-1 do n[#n+1]=e[v]end
n[#n+1]=a.sub(e[u],1,w-1)
return n
end
local function X()
if o then
i=true
o=nil
end
end
local R,ay={},{}
local ae=nil
local Y=120
local I=0
local function aX()
local l=R[#R]
return l and l.id or 0
end
local function P(u,l,G)
local M,v=u+l-1,G-l
local l={}
for n in pairs(B)do
if n<u then l[#l+1]=n
elseif n>M then l[#l+1]=n+v
elseif n-u<G then l[#l+1]=n end
end
for n in pairs(B)do B[n]=nil end
for n,n in ipairs(l)do B[n]=true end
local n={}
for l,w in pairs(C)do
if M<l then n[l+v]=w+v
elseif u>w then n[l]=w
elseif u==l and M==l and G>0 then n[l]=w+v end
end
for l in pairs(C)do C[l]=nil end
for l,u in pairs(n)do if u>l then C[l]=u end end
end
local function T(l,v,n)
P(l,v,#n)
local u={}
for w=l+v,#e do u[#u+1]=e[w]end
for v=#e,l,-1 do e[v]=nil end
for v=1,#n do e[l+v-1]=n[v]end
for v=1,#u do e[l+#n+v-1]=u[v]end
if#e==0 then e[1]=""end
end
local function w()ae=nil end
local function l(n,u)
b=math.max(1,math.min(#e,math.floor(u)))
d=math.max(1,math.min(a.len(e[b]or"")+1,math.floor(n)))
end
local function u(n,G,v,M)
local P={}
for aa=n,n+G-1 do P[#P+1]=e[aa]or""end
local aa=ae and M and ae.kind==M and ae.at==n
and#ae.new==1 and G==1 and#v==1
if aa then
ae.new=v
else
I=I+1
ae={at=n,old=P,new=v,kind=M,cx=d,cy=b,id=I}
R[#R+1]=ae
if#R>Y then table.remove(R,1)end
ay={}
end
T(n,G,v)
N=N+1
L=aX()~=ao
aj=J.uptime()+0.5
if A then A=nil i=true end
f=nil
if m then ad(m.line)m=nil end
S(n)
if G~=#v then i=true else ad(n)end
end
local function bj(G,v)
local n=table.remove(G)
if not n then
f="нечего отменять"
return
end
T(n.at,#n.new,n.old)
n.old,n.new=n.new,n.old
local G,I=n.cx,n.cy
n.cx,n.cy=d,b
v[#v+1]=n
w()
o=nil
l(G,I)
S(n.at)
N=N+1
L=aX()~=ao
aj=J.uptime()+0.5
i=true
end
local S={}
local function M(v,G,I,P,T)
if I==""then return end
local Y=a.wlen(I)
for n,n in ipairs(S)do
if G>=n.y1 and G<=n.y2 and v<=n.x2 and v+Y-1>=n.x1 then
if v<n.x1 then M(v,G,_(I,n.x1-v),P,T)end
if v+Y-1>n.x2 then M(n.x2+1,G,aE(I,n.x2-v+1),P,T)end
return
end
end
y:set(v,G,I,P,T)
end
local am=""
local P
local function ag(v)
local n,T={},1
while P and#n<40 do
local G,I=P(v,T)
if not G or I<G then break end
n[#n+1]={a.len(v:sub(1,G-1))+1,a.len(v:sub(1,I))+1}
T=I+1
end
return n
end
local function aC(v)
local Y=al[v]
if not Y then return end
local aa=e[v]
if not aa then
M(1,Y,(" "):rep(t),c.FG,c.BG)
return
end
local T=tostring(v)
local I=D[v]
local n,G=c.GUT,c.BG
if(I and I.err)or(A and A.l==v)or aU(v)then n=c.ERR
elseif I and I.warn then n=c.WARN
elseif v==b then n=c.GUT_CUR end
if B[v]then n,G=0xFFFFFF,c.BP_BG end
if aV==v then n,G=0x000000,c.WARN end
M(1,Y,(" "):rep(V-1-#T)..T.." ",n,G)
local ap=aV==v and c.DBG_BG or c.BG
local n={}
local G,ak,af,az=O()
local T,aq
if G and v>=G and v<=af then
T=(v==G)and ak or 1
aq=(v==af)and az or math.huge
n[#n+1],n[#n+2]=T,aq
end
local af,az
if m and m.line==v then
af,az=m.from,m.from+m.len
n[#n+1],n[#n+2]=af,az
end
local aD=m and ag(aa)or{}
for G,G in ipairs(aD)do n[#n+1],n[#n+2]=G[1],G[2]end
local aA={}
if I and I.marks then
for G,G in ipairs(I.marks)do
local ag=a.len(aa:sub(1,G[1]-1))+1
local ak=ag+a.len(aa:sub(G[1],G[1]+G[2]-1))
aA[#aA+1]={ag,ak}
n[#n+1],n[#n+2]=ag,ak
end
end
local aH={}
if aw then
for G,G in ipairs(aw)do
if G[2]==v then
aH[G[1]]=true
n[#n+1],n[#n+2]=G[1],G[1]+1
end
end
end
local ag=(v==b)and d or nil
if ag then n[#n+1],n[#n+2]=d,d+1 end
table.sort(n)
local function aI(G,ak)
if G==ag then return c.BG,k and 0x88AAFF or c.CUR end
if aH[G]then return 0xFFFFFF,c.PAIR end
if af and G>=af and G<az then return c.BG,c.FIND end
for af,af in ipairs(aA)do
if G>=af[1]and G<af[2]then ak=I.err and c.ERR or c.WARN end
end
if T and G>=T and G<aq then return ak,c.SEL end
for I,I in ipairs(aD)do
if G>=I[1]and G<I[2]then return ak,c.FIND_ALL end
end
return ak,ap
end
local aq,I,af=aB(),1,V
local function ak(G,aA,aD)
local az=a.wlen(G)
if I+az-1>z and I<=z+aq then
local T=I-z
if T<1 then
G=aE(G,z-I+1)
T=1
end
G=_(G,aq-T+1)
if G~=""then
M(V+T,Y,G,aA,aD)
af=V+T+a.wlen(G)-1
end
end
I=I+az
end
local az,T=1,1
for G,I in ipairs(a6(v))do
local G,aA=I[1],I[2]
local I=az
while G~=""do
while n[T]and n[T]<=I do T=T+1 end
local aq=n[T]and(n[T]-I)or math.huge
local n=G
if aq<a.len(G)then
n=a.sub(G,1,aq)
G=a.sub(G,aq+1)
else
G=""
end
local G,T=aI(I,aA)
if n=="\t"and I==ag then n=" "end
ak(n,G,T)
I=I+a.len(n)
end
az=I
end
if ag and d>a.len(aa)then
local n=F and F.text or""
local G=a.sub(n,1,1)
ak(G~=""and G or" ",aI(d,c.FG))
if a.len(n)>1 then ak(a.sub(n,2),c.GUT,c.BG)end
end
if C[v]then ak(" ... ещё "..(C[v]-v).." стр.",c.GUT,ap)end
if af<t then M(af+1,Y,(" "):rep(t-af),c.FG,ap)end
end
local function af()
local G={}
local function n(ag,v)
local I=type(au.keybinds)=="table"and au.keybinds[v]
if type(I)~="table"or type(I[1])~="table"then return end
local T,Y,aa,M
for v,v in ipairs(I[1])do
if v=="alt"then T=true
elseif v=="control"then Y=true
elseif v=="shift"then aa=true
else M=v end
end
if not M then return end
G[#G+1]=(Y and"^"or T and"M-"or aa and"S-"or"")..
a.upper(M).." "..ag
end
n("сохранить","save")
n("выход","close")
n("запуск","run")
n("оболочка","shell")
n("отладка","debug")
n("поиск","find")
n("клавиши","help")
return table.concat(G,"  ")
end
local ak=af()
local function af(v)
local n=1
for G,G in ipairs(v)do
local v=G[1]
if v~=""and n<=t then
v=_(v,t-n+1)
y:set(n,aF,v,G[2],G[3]or c.BAR_BG)
n=n+a.wlen(v)
end
end
if n<=t then y:set(n,aF,(" "):rep(t-n+1),c.BAR_FG,c.BAR_BG)end
end
local I,T={},1
local function ap(v)
if A and A.l==v then return A.msg,c.ERR end
local n=D[v]
if n and n.err then return n.err,c.ERR end
local G=aU(v)
if G then return"не заполнено: "..table.concat(G,"; "),c.ERR end
if n and n.warn then return n.warn,c.WARN end
end
local function aq()
local v=string.format("%d,%d",b,d)
local n,G=0,0
for M,M in pairs(D)do
if M.err then n=n+1 elseif M.warn then G=G+1 end
end
if A then n=n+1 end
if n+G>0 then
v=(n>0 and(n.." ош ")or"")..(G>0 and(G.." пред ")or"").." "..v
end
local n,G,G=O()
if n then
v=string.format("выд %d  %s",G-n+1,v)
elseif#q>0 then
v=string.format("#%d  %s",#q,v)
end
v=v.." "
local aa=a.wlen(v)
local Y=g.name(j)..(#I>1 and string.format(" [%d/%d]",T,#I)or"")
Y=_(Y,math.max(1,t-aa-4))
local ag=k and" [чтение]"or L and" *"or""
local M
if f then
M={{f,c.BAR_MSG}}
elseif aG then
M=aG
elseif F then
M={{"Tab → "..F.word..(F.more>0 and("   ещё "..F.more)or""),c.BAR_POS}}
else
local n,G=ap(b)
M=n and{{n,G}}or{{ak,c.BAR_FG}}
end
local ak=1+a.wlen(Y)+a.wlen(ag)
local G=t-aa-ak-2
local n={{" ",c.BAR_FG},{Y,c.BAR_NAME},{ag,c.BAR_MARK}}
if G>0 then
n[#n+1]={"  ",c.BAR_FG}
for Y,Y in ipairs(M)do
if G<=0 then break end
local M=_(Y[1],G)
n[#n+1]={M,Y[2]}
G=G-a.wlen(M)
end
n[#n+1]={(" "):rep(math.max(0,G)),c.BAR_FG}
else
n[#n+1]={(" "):rep(math.max(0,t-aa-ak)),c.BAR_FG}
end
n[#n+1]={v,c.BAR_POS}
af(n)
end
local aH
local function aA()
local n=#tostring(math.max(#e,1))+1
if n~=V then
V=n
i=true
end
end
local aI={["("]=")",["["]="]",["{"]="}"}
local a8={[")"]="(",["]"]="[",["}"]="{"}
local function bk()
local ag=aw
aw=nil
local G=a.sub(p(),d,d)
local M,aa
if aI[G]then M,aa=1,aI[G]
elseif a8[G]then M,aa=-1,a8[G]
else
if ag then i=true end
return
end
local Y,v,n=0,b,d
while e[v]do
local ak=e[v]
while n>=1 and n<=a.len(ak)do
local ap=a.sub(ak,n,n)
if ap==G then Y=Y+1
elseif ap==aa then
Y=Y-1
if Y==0 then
aw={{d,b},{n,v}}
i=true
return
end
end
n=n+M
end
v=v+M
if math.abs(v-b)>400 then break end
n=M>0 and 1 or a.len(e[v]or"")
end
if ag then i=true end
end
local function ap(n)
for v,G in pairs(C)do
if n>v and n<=G then return v end
end
end
local function Y(n,G)
n=n+G
while n>=1 and n<=#e do
local v=ap(n)
if not v then return n end
n=G>0 and C[v]+1 or v
end
end
local function az(n,v)
local G=v<0 and-1 or 1
for M=1,math.abs(v)do n=Y(n,G)or n end
return n
end
local function aa()
local M=z..":"..E
local n=ap(b)
while n do
C[n]=nil
i=true
n=ap(b)
end
if b<=E then E=b-1 end
local v=E+1
if ap(v)then v=ap(v)end
local n,G=b,1
while n>v and G<=x do
n=Y(n,-1)or v
G=G+1
end
if G>x then v=az(b,-(x-1))end
E=math.max(0,v-1)
local v,G=aN(p(),d),aB()
if v-z<1 then z=v-1 end
if v-z>G then z=v-G end
if z<0 then z=0 end
if M~=(z..":"..E)then i=true end
aW,al={},{}
n=E+1
for v=1,x do
aW[v],al[n]=n,v
n=n<#e and(Y(n,1)or#e+1)or n+1
end
end
local ak=nil
local function M()
aA()
aa()
if i or o then
for n=1,x do aC(aW[n])end
i=false
Z={}
else
if aH then Z[aH]=true end
Z[b]=true
for n in pairs(Z)do aC(n)end
Z={}
end
aH=b
aq()
if ak then ak()end
y:present()
end
local function G(n,v,Z)
if not Z then X()end
l(n,v)
if o then i=true end
w()
end
local function bl(n)G(1,b,n)end
local function bu(n)G(a.len(p())+1,b,n)end
local function bm(n)
if d>1 then
G(d-1,b,n)
return true
elseif Y(b,-1)then
G(math.huge,Y(b,-1),n)
return true
end
end
local function bv(n)
if d<=a.len(p())then G(d+1,b,n)
elseif Y(b,1)then G(1,Y(b,1),n)end
end
local function al()
local n,v,Z,aa=O()
if not n then return false end
local ag=a.sub(e[n],1,v-1)
local aq=a.sub(e[Z],aa)
o=nil
d,b=v,n
u(n,Z-n+1,{ag..aq})
l(v,n)
i=true
return true
end
local function Z(n,aa)
if not n or n==""then return end
al()
local v=p()
u(b,1,{a.sub(v,1,d-1)..n..a.sub(v,d)},aa or"type")
l(d+a.len(n),b)
end
local function ag(aa)
local v=aa:match("^[ \t]*")or""
local n=aa:gsub("%-%-[^%[].*$",""):gsub("%s+$","")
if n:match("[%({]$")or n:match("[%w_%)\"']%s*then$")or n:sub(-4)=="then"
or n:sub(-2)=="do"or n:sub(-4)=="else"or n:sub(-6)=="repeat"then
v=v.."  "
end
return v
end
local function bw()
al()
local v=p()
local n=a.sub(v,1,d-1)
local aa=a.sub(v,d)
local v=K and ag(n)or(n:match("^[ \t]*")or"")
u(b,1,{n,v..aa})
l(a.len(v)+1,b+1)
w()
end
local function aY(n)
if al()then return end
if n then
if#e>1 then u(b,1,{})else u(1,1,{""})end
l(1,b)
return
end
local n=p()
if d<=a.len(n)then
u(b,1,{a.sub(n,1,d-1)..a.sub(n,d+1)},"erase")
elseif b<#e then
u(b,2,{n..e[b+1]})
end
end
local function aA(aa,v,ag)
local n=v or""
while true do
local aq=t-a.wlen(aa)-3
local v=n
while aq>0 and a.wlen(v)>aq do v=a.sub(v,2)end
af({{" ",c.BAR_FG},{aa,c.BAR_MARK},{v,c.BAR_NAME},{" ",c.BAR_BG,c.BAR_POS}})
y:present()
local aq,aB,aa,v=at.pull()
if aq=="key_down"and aB==s.keyboard()then
if v==h.enter or v==h.numpadenter then
f=nil
return n
elseif v==1 then
f=nil
return nil
elseif v==h.back then
if n==""then
f=nil
return nil
end
n=a.sub(n,1,-2)
elseif v==h.tab and ag then
n=ag(n)or n
elseif aa and not H.isControl(aa)then
n=n..a.char(aa)
end
elseif aq=="clipboard"then
n=n..tostring(aa):gsub("\n.*","")
end
end
end
local function aJ(n,aa)
af({{" ",c.BAR_FG},{n,c.BAR_MARK}})
y:present()
while true do
local v,af,ag,n=at.pull()
if v=="key_down"and af==s.keyboard()then
for v in aa:gmatch(".")do
if n==h[v]or ag==v:byte()then return v end
end
if n==h.c or n==h.back or n==1 then return nil end
end
end
end
local function a9(v)
local n=aJ(v,"yn")
if n then return n=="y"end
end
local aZ,bn
do
local n
local function aK(v)
am,n=v,v:match("^/(.+)$")
if n then
if not pcall(string.find,"",n)then
P=nil
f="плохой шаблон: "..n
return false
end
P=function(aa,af)return aa:find(n,af)end
elseif a.lower(v)~=v then
P=function(aa,af)return aa:find(v,af,true)end
else
P=function(aa,af)return a.lower(aa):find(v,af,true)end
end
return true
end
local function aD(v,aa,af)
l(a.len(e[v]:sub(1,aa-1))+1,v)
m={line=v,from=d,len=a.len(e[v]:sub(aa,af))}
i=true
end
local function v(aC,ag,aq)
if not P then return end
local aa=#e
for af=0,aa do
local aB=aq and((ag-1-af)%aa+1)or((ag-1+af)%aa+1)
local aL=e[aB]
local aM=#a.sub(aL,1,aC-1)
local aO,ag=(not aq and af==0)and aM+1 or 1,nil
while true do
local aa,aC=P(aL,aO)
if not aa or aC<aa then break end
if not aq then
aD(aB,aa,aC)
return true
end
if af==0 and aa>aM then break end
ag={aa,aC}
aO=aa+1
end
if ag then
aD(aB,ag[1],ag[2])
return true
end
end
f="не найдено: "..am
end
function aZ(aa,af)
if m then
ad(m.line)
m=nil
i=true
end
if aa and am~=""then
if af then v(d,b,true)else v(d+1,b)end
return
end
local aa=aA("Поиск: ")
if aa and aa~=""and aK(aa)then v(d,b)end
end
local function aL(af,aa)
if n then return(af:gsub(n,aa,1))end
return aa
end
local function aO(a_)
local aa,aB,ag,aM=nil,nil,0,{}
for aC,am in ipairs(e)do
local n,af={},1
while true do
local aq,aD=P(am,af)
if not aq or aD<aq then break end
n[#n+1]=am:sub(af,aq-1)
n[#n+1]=aL(am:sub(aq,aD),a_)
af=aD+1
ag=ag+1
end
if af>1 then
n[#n+1]=am:sub(af)
aM[aC]=table.concat(n)
aa,aB=aa or aC,aC
end
end
if ag>0 then
local n={}
for af=aa,aB do n[#n+1]=aM[af]or e[af]end
u(aa,aB-aa+1,n)
w()
end
return ag
end
function bn()
if k then return end
local n=aA("Заменить: ")
if not n or n==""or not aK(n)then return end
local aq=aA("Заменить \""..n.."\" на: ")
if not aq then return end
local af,aB,am,aa=0,b,d,false
local n,aC=b,d
v(d,b)
while m do
if m.line<n or(m.line==n and m.from<aC)then aa=true end
if aa and(m.line>aB or(m.line==aB and m.from>=am))then break end
n,aC=m.line,m.from
M()
local aD=aJ("Заменить? Y - да, N - дальше, A - все в файле, C - хватит","yna")
local ag=m.line
if aD=="a"then
m=nil
af=af+aO(aq)
break
elseif aD=="y"then
local n=e[ag]
local aK=#a.sub(n,1,m.from-1)+1
local aa,aJ=P(n,aK)
if aa~=aK then break end
local P=aL(n:sub(aa,aJ),aq)
m=nil
u(ag,1,{n:sub(1,aa-1)..P..n:sub(aJ+1)})
w()
af=af+1
l(a.len(n:sub(1,aa-1)..P)+1,ag)
if ag==aB and aa<#a.sub(n,1,am-1)then
am=am+a.len(P)-a.len(n:sub(aa,aJ))
end
aC=d
if not v(d,b)then break end
elseif aD=="n"then
if not v(m.from+1,ag)then break end
else
break
end
end
if m then ad(m.line)m=nil end
i=true
f="заменено: "..af
end
end
local aB,ba,aJ,a_,bb,bo,aC,af,aD,ag,bc,bd
local aK=nil
do
function aB()
local n=a.sub(p(),1,d-1)
return n:match("[%a_][%w_%.:]*$")
end
local a0,am,aq,aL=nil,-1,-2,""
local a1={}
function ba()
if a0 and(am==N or J.uptime()-aq<1)then
return a0
end
local v={}
for n,P in ipairs(e)do
if P:find("local",1,true)then
P=P:gsub("%-%-.*$","")
local n,aa=P:match("local%s+([%a_][%w_]*)%s*=%s*require%s*%(?%s*[\"']([%w_%.]+)[\"']")
if n then
v[n]={aa}
else
n,aa=P:match("local%s+([%a_][%w_]*)%s*=%s*component%.proxy%s*%(%s*component%.list%s*%(%s*[\"']([%w_]+)[\"']")
if n then
v[n]={"component",aa}
else
local aa
n,aa=P:match("local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_%.]*)%s*;?%s*$")
if n and aa~=n then
local P={}
for aM in aa:gmatch("[^%.]+")do P[#P+1]=aM end
v[n]=P
end
end
end
end
end
local n={}
for P,aa in pairs(v)do n[#n+1]=P.."="..table.concat(aa,".")end
table.sort(n)
local P=table.concat(n," ")
if P~=aL then
aL=P
a1={}
end
a0,am,aq=v,N,J.uptime()
return v
end
function ag(aa,P)
local n
for am,v in ipairs(aa)do
if am==1 then
n=rawget(_G,v)or package.loaded[v]
if n==nil and(P or 0)<3 then
local aa=ba()[v]
if aa then n=ag(aa,(P or 0)+1)end
end
if n==nil and g.exists("/lib/"..v..".lua")then
local P,aa=pcall(require,v)
n=P and aa or nil
end
else
if type(n)~="table"then return nil end
local P,aa=pcall(function()return n[v]end)
n=P and aa or nil
end
if n==nil then return nil end
end
return n
end
local function P(am,v,aa)
pcall(function()
for n in pairs(am)do
if type(n)=="string"and not aa[n]then
aa[n]=true
v[#v+1]=n
end
end
end)
end
local a2,am,aq=nil,-1,-2
local be={}
local function aM()
if a2 and(am==N or J.uptime()-aq<1)then
return a2
end
local n,v={},{}
for aa,aL in ipairs(e)do
for aa in aL:gmatch("[%a_][%w_]*")do
if not v[aa]then v[aa]=true n[#n+1]=aa end
end
end
for aa in pairs(aP)do if not v[aa]then v[aa]=true n[#n+1]=aa end end
for aa in pairs(as)do if not v[aa]then v[aa]=true n[#n+1]=aa end end
P(_G,n,v)
P(package.loaded,n,v)
table.sort(n,function(v,aa)return v:lower()<aa:lower()end)
a2,am,aq=n,N,J.uptime()
return n
end
function aD(n)
local v,aa={},n
local am=n:match("^(.*)[%.:][%w_]*$")
if am then
aa=n:match("[%.:]([%w_]*)$")or""
for n in am:gmatch("[^%.:]+")do v[#v+1]=n end
end
return v,aa
end
local function aL(v)
if#v==0 then return aM()end
local am=table.concat(v,".")
local aq=v[1]=="component"
local n=be[am]
if n~=nil and J.uptime()-n.at<(aq and 1 or 3)then
return n.list or nil
end
local as=ag(v)
local n,aa={},{}
if type(as)=="table"then
P(as,n,aa)
if aq and#v==1 then
pcall(function()
for v,v in ar.list()do
if not aa[v]then aa[v]=true n[#n+1]=v end
end
end)
end
table.sort(n,function(v,P)return v:lower()<P:lower()end)
else
n=false
end
be[am]={list=n,at=J.uptime()}
return n or nil
end
local function aO(aa,am)
local n,v=1,#aa+1
while n<v do
local P=math.floor((n+v)/2)
if aa[P]:lower()<am then n=P+1 else v=P end
end
return n
end
local function bp(n)
local aa,P=aD(n)
local v=aL(aa)
if not v then return nil end
local aa=P:lower()
local n={}
for aq=aO(v,aa),#v do
local am=v[aq]
if am:lower():sub(1,#aa)~=aa then break end
if am~=P then n[#n+1]=am end
if#n>300 then break end
end
table.sort(n,function(v,aa)
if#v~=#aa then return#v<#aa end
return v<aa
end)
return n,P
end
function aJ()
local aa=F
F=nil
repeat
if k or o then break end
if d<=a.len(p())then break end
local v=aB()
if not v then break end
local n,P=aD(v)
if#n==0 and a.len(P)<2 then break end
local n=bp(v)
if not n or#n==0 then break end
local v=n[1]
if a.len(v)<=a.len(P)then break end
F={
word=v,
text=a.sub(v,a.len(P)+1),
more=#n-1,
}
until true
if aa or F then ad(b)end
end
local function bq(n,P)
if n>0 then
local v=p()
u(b,1,{a.sub(v,1,d-n-1)..a.sub(v,d)})
l(d-n,b)
end
Z(P)
w()
end
local br={}
for n,n in ipairs({"lshift","rshift","lcontrol","rcontrol","lmenu","rmenu"})do
if h[n]then br[h[n]]=true end
end
local aq={}
local function a3(aa,am,P)
local as=table.concat(am,".").."."..P
if aq[as]~=nil then return aq[as]or nil end
local n
pcall(function()
local aM=am[1]=="component"and#am==1
if type(aa)=="table"and type(rawget(aa,"address"))=="string"then
n=ar.doc(aa.address,P)
end
if not n and aM then
local v=ar.list(P,true)()
if v then n="устройство "..P.." -- адрес "..v end
end
if n then return end
local v
if#am==0 then
v=rawget(_G,P)
if v==nil then v=package.loaded[P]end
elseif type(aa)=="table"then
if aM then v=rawget(aa,P)else v=aa[P]end
end
local P=type(v)
if P=="function"then
n="функция"
elseif P=="table"then
local aa=0
for am in pairs(v)do aa=aa+1 end
n="таблица, полей "..aa
elseif P=="string"then
n="строка "..string.format("%q",v)
elseif P=="number"or P=="boolean"then
n=(P=="number"and"число "or"")..tostring(v)
end
end)
aq[as]=n or false
return n
end
function aC(v,aq,aa,am)
local n=nil
for P in aq:gmatch("%S+")do
while a.wlen(P)>aa do
if n then v[#v+1]={n,am}n=nil end
v[#v+1]={_(P,aa),am}
P=aE(P,aa)
end
if n and a.wlen(n)+1+a.wlen(P)<=aa then
n=n.." "..P
else
if n then v[#v+1]={n,am}end
n=P
end
end
if n then v[#v+1]={n,am}end
end
function af(n,v)
n=_(n,v)
return n..(" "):rep(v-a.wlen(n))
end
local am={}
local function bs(aa)
if am[aa]~=nil then return am[aa]or nil end
local ar,v=aa:match("^function%((.-)%)(.*)$")
local n=false
if ar then
local P=(v:match("^(.-)%s*%-%-")or v):gsub("%s+$","")
n={params={},ret=P}
local v,P,aq=0,"",false
local function as()
local _=P:gsub("^%s+",""):gsub("%s+$","")
if _~=""then
n.params[#n.params+1]={
text=_,name=_:match("^[^:]+"),
optional=aq or _:sub(1,3)=="...",
}
end
P,aq="",false
end
for _ in ar:gmatch(".")do
if _=="["then v=v+1
elseif _=="]"then v=v-1
elseif _==","then as()
else
if P:find("^%s*$")and _:find("%S")then aq=v>0 end
P=P.._
end
end
as()
end
am[aa]=n
return n or nil
end
local function as(P)
local n={}
for v,v in ipairs(a6(P))do
if v[2]==c.C_STR then n[#n+1]=("0"):rep(#v[1])
elseif v[2]==c.C_CMT then n[#n+1]=(" "):rep(#v[1])
else n[#n+1]=v[1]end
end
return table.concat(n)
end
local function aE(P,am)
local v=P:sub(1,am-1):match("([%a_][%w_%.]*)%s*$")
if not v or v:sub(-1)=="."then return nil end
local n={}
for _ in v:gmatch("[^%.]+")do n[#n+1]=_ end
if#n<2 then return nil end
local aM=table.remove(n)
local v=ag(n)
if type(v)~="table"then return nil end
local _=a3(v,n,aM)
local bf=_ and bs(_)
if not bf then return nil end
local _,v,aq,ar={},0,am+1,nil
for aa=am+1,#P do
local n=P:sub(aa,aa)
if n=="("or n=="["or n=="{"then
v=v+1
elseif n==")"or n=="]"or n=="}"then
if v==0 then ar=aa break end
v=v-1
elseif n==","and v==0 then
_[#_+1]={aq,aa-1}
aq=aa+1
end
end
_[#_+1]={aq,(ar or#P+1)-1}
return{name=aM,sig=bf,args=_,close=ar,code=P}
end
local function am(v,P)
local n=v.args[P]
return n and v.code:sub(n[1],n[2]):find("%S")~=nil
end
local function aq(v)
local n={}
for _,P in ipairs(v.sig.params)do
if not P.optional and not am(v,_)then n[#n+1]=P.name end
end
return n
end
aU=function(n)
local v=e[n]
if not K or not v or not v:find("(",1,true)then return nil end
local P=a1[v]
if P~=nil then return P or nil end
local _=as(n)
local n
for aa in _:gmatch("()%(")do
local P=aE(_,aa)
if P and P.close then
local _=aq(P)
if#_>0 then
n=n or{}
n[#n+1]=P.name..": "..table.concat(_,", ")
end
end
end
a1[v]=n or false
return n
end
local function ar()
if not K then return nil end
local _=as(b)
local aa=#a.sub(p(),1,d-1)
local v=0
for P=aa,1,-1 do
local n=_:sub(P,P)
if n==")"or n=="]"or n=="}"then
v=v+1
elseif n=="("or n=="["or n=="{"then
if v>0 then
v=v-1
elseif n=="("then
local n=aE(_,P)
if n then return n,aa+1 end
end
end
end
end
function a_()
aG=nil
local v,n=ar()
if not v then return end
local ar=#v.args
for P,_ in ipairs(v.args)do
if n<=_[2]+1 then ar=P break end
end
local n={{v.name.."(",c.BAR_NAME}}
for _,P in ipairs(v.sig.params)do
if _>1 then n[#n+1]={", ",c.BAR_FG}end
local aa=c.BAR_FG
if _==ar then aa=c.BAR_MARK
elseif not P.optional and not am(v,_)then aa=c.ERR end
n[#n+1]={P.optional and("["..P.text.."]")or P.text,aa}
end
n[#n+1]={")"..v.sig.ret,c.BAR_NAME}
local P=aq(v)
if#P>0 then
n[#n+1]={"   не хватает: "..table.concat(P,", "),c.ERR}
end
aG=n
end
function bc(aq)
local P=aL(aq)
if not P or#P==0 then return false end
local bf=table.concat(aq,".")
local ar=#aq>0 and ag(aq)or nil
local n,_=1,1
F=nil
local function aL()
ak=nil
S={}
f=nil
i=true
end
while true do
local v=aB()or""
local aa,aM=aD(v)
if v==""then aa,aM={},""end
if table.concat(aa,".")~=bf then return aL()end
local aa=aM:lower()
local v={}
for am=aO(P,aa),#P do
local ag=P[am]
if ag:lower():sub(1,#aa)~=aa then break end
v[#v+1]=ag
end
if#v==0 then return aL()end
if n>#v then n=#v end
local P=math.min(10,#v,x-1)
if n<_ then _=n end
if n>_+P-1 then _=n-P+1 end
local ag=0
for aa=1,#v do ag=math.max(ag,a.wlen(v[aa]))end
ag=math.min(ag+3,t-4)
local aa=V+aN(p(),d-a.len(aM))-z
aa=math.max(1,math.min(aa,t-ag))
local aO=b-E+P<=x
local aN=aO and(b-E+1)or math.max(1,b-E-P)
local am=a3(ar,aq,v[n])
local a3,aq,ar={},nil,nil
if am then
local as=t-(aa+ag)
if as>=24 then
aq,ar=aa+ag,math.min(52,as)
elseif aa-1>=24 then
ar=math.min(52,aa-1)
aq=aa-ar
end
if aq then
local aE,as=am:match("^(.-)%s*%-%-%s*(.*)$")
aC(a3,aE or am,ar-2,c.BAR_POS)
if as and as~=""then aC(a3,as,ar-2,c.POP_FG)end
end
end
local aE=math.min(#a3,math.max(P,6),x-1)
local as=aO and aN or(aN+P-aE)
if aO and as+aE-1>x then as=x-aE+1 end
if as<1 then as=1 end
for aO,aO in ipairs(S)do
for bx=aO.y1,aO.y2 do ad(bx+E)end
end
S={{x1=aa,y1=aN,x2=aa+ag-1,y2=aN+P-1}}
if aE>0 then S[2]={x1=aq,y1=as,x2=aq+ar-1,y2=as+aE-1}end
for aO,aO in ipairs(S)do
for bx=aO.y1,aO.y2 do ad(bx+E)end
end
ak=function()
for aO=0,P-1 do
local bx=(aO==0 and _>1)and"^"or(aO==P-1 and _+P-1<#v)and"v"or" "
y:set(aa,aN+aO," "..af(v[_+aO],ag-2)..bx,c.POP_FG,
(_+aO==n)and c.POP_SEL or c.POP_BG)
end
for aa=1,aE do
local ag=a3[aa]
y:set(aq,as+aa-1," "..af(ag[1],ar-1),ag[2],c.BAR_BG)
end
end
f=string.format("%s%s: %d из %d   Enter - вставить",bf,bf~=""and"."or"",
n,#v)
if am and not aq then f=am end
M()
local ag=table.pack(at.pull())
local ar,as,aq,aa=ag[1],ag[2],ag[3],ag[4]
if ar=="key_down"and as==s.keyboard()then
if aa==h.up then
n=n>1 and n-1 or#v
elseif aa==h.down then
n=n<#v and n+1 or 1
elseif aa==h.pageUp then
n=math.max(1,n-P)
elseif aa==h.pageDown then
n=math.min(#v,n+P)
elseif aa==h.enter or aa==h.numpadenter or aa==h.tab then
aL()
bq(a.len(aM),v[n])
local v=am and am:find("^function%(")and bs(am)
if v and a.sub(p(),d,d)~="("then
Z("()")
if#v.params>0 then l(d-1,b)end
w()
end
return true
elseif aa==h.back and aM~=""then
local v=p()
u(b,1,{a.sub(v,1,d-2)..a.sub(v,d)},"erase")
l(d-1,b)
n,_=1,1
elseif aq and aq>32 and not H.isControl(aq)and a.char(aq):match("[%w_]")
and not H.isControlDown(s.keyboard())then
Z(a.char(aq))
n,_=1,1
elseif not br[aa]then
aL()
aK=ag
return true
end
elseif ar~="key_up"and ar~="interrupted"then
aL()
aK=ag
return true
end
end
end
function bb()
local v=aB()
if not v then return false end
local n,P=bp(v)
if not n or#n==0 then
f="нечем дополнить"
return true
end
if#n==1 then
bq(a.len(P),n[1])
else
bc((aD(v)))
end
return true
end
local function aa()
if not K then return false end
local n,P=1,d-1
for v,v in ipairs(a6(b))do
local _=a.len(v[1])
if P>=n and P<n+_ then return v[2]~=c.C_CMT and v[2]~=c.C_STR end
n=n+_
end
return true
end
function bo()
local n=aB()
if not n or n:sub(-1)~="."or n:find("..",1,true)or not aa()then return end
bc((aD(n)))
end
function bd()
a0,a2=nil,nil
be,a1={},{}
end
end
local function aD(_)
local v,n,aa=O()
if not v then
if _ then
local n=p()
local P=n:match("^  ")and 2 or(n:match("^ ")and 1 or 0)
if P>0 then
u(b,1,{a.sub(n,P+1)})
l(math.max(1,d-P),b)
end
else
Z("  ")
end
return
end
local n={}
for ag=v,aa do
local P=e[ag]
if _ then
local _=P:match("^  ")and 2 or(P:match("^ ")and 1 or 0)
n[#n+1]=a.sub(P,_+1)
else
n[#n+1]="  "..P
end
end
local P=o
u(v,aa-v+1,n)
o=P
i=true
end
local function ag()
if k then return true end
local v=not g.exists(j)
if not v and W and g.lastModified(j)~=W then
if not a9(g.name(j).." изменён на диске. Записать поверх? [Y/n, C - отмена]")then
f=nil
return false
end
end
local n
if not v then
n=j.."~"
for P=1,math.huge do
if not g.exists(n)then break end
n=j.."~"..P
end
g.copy(j,n)
end
if not g.exists(ai)then g.makeDirectory(ai)end
local P,_=io.open(j,"w")
if not P then
f=tostring(_)
return false
end
local _=0
for am,aa in ipairs(e)do
P:write(am==1 and aa or("\n"..aa))
_=_+a.len(aa)
end
P:write("\n")
P:close()
w()
ao=aX()
L=false
W=g.lastModified(j)
f=string.format(v and[["%s" [новый] %dL,%dC записано]]or[["%s" %dL,%dC записано]],
g.name(j),#e,_)
if not v then g.remove(n)end
return true
end
local am,aq,ar,aE,v
do
function am()
I[T]={
filename=j,parent=ai,readonly=k,lua=K,
buffer=e,cx=d,cy=b,scrollX=z,scrollY=E,
modified=L,undoStack=R,redoStack=ay,
savedId=ao,stamp=W,bps=B,folds=C,diag=D,
syntaxErr=ac,runErr=A,
}
end
local function _()
aR,ab={},1
o,F,m,aw,aG,ae=nil,nil,nil,nil,nil,nil
ax,a5=nil,-1
N=N+1
bd()
aH=nil
i=true
f=nil
aj=J.uptime()+0.1
end
local function aa(n)
local m=I[n]
T=n
j,ai,k,K=m.filename,m.parent,m.readonly,m.lua
e,d,b,z,E=m.buffer,m.cx,m.cy,m.scrollX,m.scrollY
L,R,ay,ao,W=m.modified,m.undoStack,m.redoStack,m.savedId,m.stamp
B,C,D,ac,A=m.bps,m.folds,m.diag,m.syntaxErr,m.runErr
_()
end
local function ab(ae)
local m,P={},0
local n=io.open(ae)
if n then
for ae in n:lines()do
m[#m+1]=ae
P=P+a.len(ae)
end
n:close()
end
if#m==0 then m[1]=""end
return m,P,n~=nil
end
function v()
if not W or not g.exists(j)or g.lastModified(j)==W then return end
local m=g.lastModified(j)
if L and not a9(g.name(j).." изменён на диске. Перечитать, потеряв правки? [Y/n]")then
W=m
f=nil
return
end
local n=ab(j)
u(1,#e,n)
w()
l(d,b)
ao,L,W=aX(),false,m
i=true
f="перечитан с диска"
end
function aq(m,ae)
for n,P in ipairs(I)do
if(n==T and j or P.filename)==m then
ar(n)
return true
end
end
if g.isDirectory(m)then
f="это каталог: "..m
return false
end
local n=g.get(m)
local P=ae or n==nil or n.isReadOnly()
if P and not g.exists(m)then
f="нет файла, а записать некуда: "..m
return false
end
if#I>0 then am()end
local ae,as,n=ab(m)
T=#I+1
j,ai,k,K=m,g.path(m),P,bi(m)
e,d,b,z,E=ae,1,1,0,0
L,R,ay,ao=false,{},{},0
W=n and g.lastModified(m)or nil
B,C,D,ac,A={},{},{},nil,nil
_()
am()
if n then
f=string.format(k and[["%s" [только чтение] %dL,%dC]]or[["%s" %dL,%dC]],
g.name(m),#e,as)
else
f=string.format([==["%s" [новый файл]]==],g.name(m))
end
return true
end
function ar(m)
if m==T or not I[m]then return end
am()
aa(m)
v()
end
function aE()
if L and not k then
local m=a9(g.name(j).." изменён. Сохранить перед закрытием? [Y/n, C - остаться]")
if m==nil then
f=nil
return
end
if m and not ag()then return end
end
table.remove(I,T)
if#I==0 then
aS=false
return
end
aa(math.min(T,#I))
v()
end
end
local P,ao
do
local function W(m)return _ENV[m]~=nil end
function P(m)
if not K then return nil end
if a5~=N or not ax or(m and ax.name~=m)then
local n=table.concat(e,"\n")
ax,a5=nil,N
if J.freeMemory()>#n*3+65536 then
local N,E=pcall(ah.analyze,n,{known=W,name=m})
if N then
ax=E
E.name=m
end
end
end
return ax
end
function ao()
aj=nil
D,ac={},nil
if K then
local m,n=load(table.concat(e,"\n"),"="..g.name(j),"t",{})
if not m then
n=tostring(n)
local m,E=n:match(":(%d+): (.*)$")
m=math.min(tonumber(m)or#e,#e)
ac={l=m,msg=E or n}
D[m]={err="синтаксис: "..ac.msg}
local n=tonumber(ac.msg:match("at line (%d+)"))
if n and not D[n]then D[n]={err="не закрыто, см. строку "..m}end
else
local n=P()
for m,m in ipairs(n and n.diags or{})do
local n=D[m.l]or{marks={}}
D[m.l]=n
n.warn=n.warn and(n.warn.."; "..m.msg)or m.msg
n.marks[#n.marks+1]={m.c,m.len}
end
end
end
i=true
end
end
local m,n=1,1
local function as()
y:close()
r=Q.gpu()
aQ,an=r.getResolution()
if U>0 then U=math.max(6,math.floor(an/3))end
y=bg.surface(r,{h=an-U})
t,aF=y.w,y.h
x=aF-1
S={}
aH=nil
i=true
end
local function aF(E)
if E==(U>0)then return end
U=E and 1 or 0
as()
if E then
if r.setActiveBuffer then r.setActiveBuffer(0)end
r.setBackground(0x000000)
r.setForeground(0xFFFFFF)
r.fill(1,an-U+1,aQ,U," ")
m,n=1,1
end
end
local function N(W)
aF(true)
M()
if r.setActiveBuffer then r.setActiveBuffer(0)end
local E=Q.window
local _,aa,ab,ae,ai,aw=Q.getViewport()
local ax=E.fullscreen
E.fullscreen=false
Q.setViewport(aQ,U,0,an-U,m,n)
r.setBackground(0x000000)
r.setForeground(0xFFFFFF)
s.setCursorBlink(true)
local aG,aH=xpcall(W,debug.traceback)
if not aG then io.stderr:write(tostring(aH),"\n")end
s.setCursorBlink(false)
m,n=Q.getCursor()
Q.setViewport(_,aa,ab,ae,ai,aw)
E.fullscreen=ax
as()
bd()
v()
end
local aG,aH,aL
do
local function v(E)
local m=io.stderr
while type(rawget(m,"fd"))=="table"and rawget(m,"_closed")~=nil do
m=rawget(m,"fd")
end
local W,_,n=rawget(m,"write"),m.write,{}
rawset(m,"write",function(aa,...)
for ab=1,select("#",...)do n[#n+1]=tostring((select(ab,...)))end
return _(aa,...)
end)
local _,aa=pcall(E)
rawset(m,"write",W)
if not _ then io.stderr:write(tostring(aa),"\n")end
return table.concat(n)
end
local function aM(E)
local m=""
N(function()
if Q.getCursor()>1 then io.write("\n")end
io.write("\27[33m> "..g.name(j).."\27[37m\n")
m=v(function()
local v=require("sh")
local W,n=v.execute(_ENV,'"'..E..'"')
if not W and n then io.stderr:write(tostring(n),"\n")end
end)
end)
return m
end
local function aN(m,n)
A=nil
local E=n:gsub("%p","%%%0")
local v=m:sub(1,(m:find("stack traceback:",1,true)or#m+1)-1)
local n=v:match("([^\n]+)\n*$")or""
local v=n:match(E..":(%d+):")
if not v then
v=m:match(E..":(%d+):")
end
if not v then return end
n=n:gsub("^"..E..":%d+: ",""):gsub(":$","")
A={l=math.min(tonumber(v),#e),msg="ошибка: "..n}
X()
l(1,A.l)
i=true
return A
end
function aG()
if L and not k and not ag()then return end
f="работает "..g.name(j)
local m=aM(j)
f=not aN(m,j)and"вывод внизу, ^O скрыть панель"or nil
end
function aH()
if L and not k then ag()end
local v="оболочка внизу, exit - обратно в редактор"
f=v
N(function()
local n=require("sh")
local m={hint=n.hintHandler}
while true do
if Q.getCursor()>1 then io.write("\n")end
io.write(n.expand(os.getenv("PS1")or"$ "))
Q.window.cursor=m
local m=io.stdin:readLine(false)
Q.window.cursor=nil
if m==nil then return end
if m then
m=a4.trim(m)
if m=="exit"then return end
if m~=""then
local N,E=n.execute(_ENV,m)
if not N and E then io.stderr:write(tostring(E),"\n")end
end
end
end
end)
if f==v then f=nil end
end
local E=nil
local function aO()
local m=3
while debug.getinfo(m,"l")do m=m+1 end
return m
end
local function aR(m,n)
local N=type(m)
if N=="string"then
local v=string.format("%q",m):gsub("\\\n","\\n")
return v
elseif N=="table"then
if n then return"{..}"end
local n,v={},0
pcall(function()
for Q,W in pairs(m)do
v=v+1
if#n<5 then
n[#n+1]=(type(Q)=="number"and""or(tostring(Q).."="))..aR(W,true)
end
end
end)
return"{"..table.concat(n,", ")..(v>#n and", .."or"").."}"..
(v>0 and("  #"..v)or"")
elseif N=="function"then
local N,n=pcall(debug.getinfo,m,"S")
local v=N and n and n.linedefined or 0
return"функция"..(v>0 and(" стр "..v)or"")
end
return tostring(m)
end
local function ae(ai,m)
local v={}
local function ab(Q,n,N,W)
v[#v+1]={depth=Q,key=n,v=N,path=W}
if type(N)~="table"or not m[W]or Q>6 or#v>400 then return end
local m={}
pcall(function()for n in pairs(N)do m[#m+1]=n end end)
table.sort(m,function(n,_)
local aa,aw=type(n)=="number",type(_)=="number"
if aa~=aw then return aa end
if aa then return n<_ end
return tostring(n)<tostring(_)
end)
for _=1,math.min(#m,200)do
local n=m[_]
local m,_=pcall(function()return N[n]end)
ab(Q+1,type(n)=="string"and n or("["..tostring(n).."]"),m and _ or nil,
W.."\0"..tostring(n))
end
end
for m,m in ipairs(ai)do ab(0,m[1],m[2],m[1])end
return v
end
local function aX(n)
aV=n.line
X()
l(1,n.line)
local aw,v,aa,Q,W={},1,1,false,nil
while not W do
local _=ae(n.vars,aw)
if v>#_ then v=math.max(1,#_)end
local ae=math.max(26,math.min(60,math.floor(t*0.45)))
local a0=t-ae+1
local m={}
aC(m,n.title,ae-2,c.BAR_MARK)
if n.err then aC(m,n.err,ae-2,c.ERR)end
if n.stack and n.stack~=""then aC(m,"стек: "..n.stack,ae-2,c.BAR_FG)end
m[#m+1]={#_>0 and(Q and"переменные (Tab - к коду)"or"переменные (Tab - выбрать)")
or"local здесь не видно",c.BAR_POS}
local N=math.max(1,x-#m)
if v<aa then aa=v end
if v>aa+N-1 then aa=v-N+1 end
S={{x1=a0,y1=1,x2=t,y2=x}}
ak=function()
for ab=1,x do
local ax,ai,aC="",c.POP_FG,c.POP_BG
if m[ab]then
ax,ai,aC=m[ab][1],m[ab][2],c.BAR_BG
else
local N=_[aa+ab-#m-1]
if N then
local a1=type(N.v)=="table"and(aw[N.path]and"- "or"+ ")or"  "
ax=("  "):rep(N.depth)..a1..N.key.." = "..aR(N.v)
if Q and aa+ab-#m-1==v then aC=c.POP_SEL end
if type(N.v)=="string"then ai=c.C_STR
elseif type(N.v)=="number"then ai=c.C_NUM
elseif N.v==nil or type(N.v)=="boolean"then ai=c.C_BLT end
end
end
y:set(a0,ab," "..af(ax,ae-1),ai,aC)
end
end
f=n.final and"F5 или Enter - закрыть"or
"F5 дальше  F10 шаг  F11 внутрь  S-F11 наружу  F4 стоп  F9 точка"..
"  (или C N S O Q)"
i=true
M()
local aa=table.pack(at.pull())
local N,ab,m,m=aa[1],aa[2],aa[3],aa[4]
if N=="key_down"and ab==s.keyboard()then
if av("stepGo",m)or(n.final and(m==h.enter or m==h.back))then
W="run"
elseif not n.final and av("stepOver",m)then W="over"
elseif not n.final and av("stepOut",m)then W="out"
elseif not n.final and av("stepInto",m)then W="into"
elseif not n.final and av("stepStop",m)then W="stop"
elseif av("breakpoint",m)then B[b]=not B[b]or nil
elseif m==h.tab then Q=not Q and#_>0
elseif Q and m==h.up then v=math.max(1,v-1)
elseif Q and m==h.down then v=math.min(#_,v+1)
elseif Q and(m==h.enter or m==h.right or m==h.left)then
local n=_[v]
if n and type(n.v)=="table"then aw[n.path]=m~=h.left or nil end
elseif m==h.up or m==h.down then
G(d,Y(b,m==h.up and-1 or 1)or b)
elseif m==h.pageUp or m==h.pageDown then
G(d,az(b,(m==h.pageUp and-1 or 1)*(x-1)))
end
elseif N=="scroll"then
G(d,az(b,-(aa[5]or 0)*3))
elseif E and N~="key_up"and N~="key_down"and N~="touch"and N~="drag"
and N~="drop"and N~="clipboard"and N~="interrupted"then
E.queue[#E.queue+1]=aa
end
end
S,ak,aV,f={},nil,nil,nil
i=true
M()
return W
end
local function W(v,n)
local m,N={},E.names[v]or{}
if n then
local v=table.pack(pcall(n))
for n,Q in ipairs(N)do m[#m+1]={Q,v[1]and v[n+1]or nil}end
end
return m
end
local function ab(v,_)
local m=E
if not m then return end
if m.stop then error("остановлено отладчиком",0)end
m.lastL,m.lastF=v,_
local n
local N=B[v]~=nil
if not N and m.mode~="run"then
n=aO()
N=m.mode=="into"or(m.mode=="over"and n<=m.depth)or(m.mode=="out"and n<m.depth)
end
if not N then return end
n=n or aO()
local Q={}
for aa=3,40 do
local ae,N=pcall(debug.getinfo,aa,"Sln")
if not ae or not N then break end
if N.source=="="..m.tmp and(N.currentline or 0)>0 then
Q[#Q+1]=(N.name or"main")..":"..N.currentline
end
end
local ae,ai=r.getForeground(),r.getBackground()
local N=r.getActiveBuffer and r.getActiveBuffer()
local aa,av=r.getResolution()
if aa~=aQ or av~=an then as()end
if N and N~=0 then r.setActiveBuffer(0)end
s.setCursorBlink(false)
local aa=aX({line=v,vars=W(v,_),stack=table.concat(Q," < "),
title="пауза, строка "..v})
s.setCursorBlink(true)
if N and N~=0 then r.setActiveBuffer(N)end
r.setForeground(ae)
r.setBackground(ai)
local v=m.queue
m.queue={}
for r,r in ipairs(v)do J.pushSignal(table.unpack(r,1,r.n))end
m.mode,m.depth=aa,n
if aa=="stop"then
m.stop=true
error("остановлено отладчиком",0)
end
end
function aL()
if not K then
f="отладка - только для .lua"
return
end
if L and not k and not ag()then return end
ao()
if ac then
X()
l(1,ac.l)
return
end
local N=ah.analyze(table.concat(e,"\n"),{hooks=true})
local n,v,r={},{},{}
for m,L in ipairs(e)do n[m]=L end
for m,L in pairs(N.hooks)do
local N=ah.names(L.at)
local Q="__dwdbg("..m..(#N>0 and(",function()return "..table.concat(N,",").." end")or"")..");"
n[m]=n[m]:sub(1,L.c-1)..Q..n[m]:sub(L.c)
v[m],r[m]=N,true
end
local L
for m=1,60 do
local m,N=load(table.concat(n,"\n"),"=x","t",{})
if m then L=true break end
local m=tonumber(tostring(N):match(":(%d+):"))or 0
while m>0 and not r[m]do m=m-1 end
if m==0 then break end
n[m],r[m],v[m]=e[m],nil,nil
end
if not L then
f="не вышло подготовить файл к отладке"
return
end
local r="/tmp/dwdbg/"..g.name(j)
g.makeDirectory("/tmp/dwdbg")
local m=io.open(r,"w")
if not m then
f="некуда положить копию для отладки"
return
end
m:write(table.concat(n,"\n"),"\n")
m:close()
E={mode=next(B)and"run"or"into",depth=0,names=v,tmp=r,queue={}}
_ENV.__dwdbg=ab
f="отладка "..g.name(j)
local v=aM(r)
_ENV.__dwdbg=nil
local m=E
E=nil
g.remove(r)
if m.stop then
f="отладка остановлена"
return
end
local n=aN(v,r)
if n then
local r={}
if m.lastF then
E=m
r=W(m.lastL,m.lastF)
E=nil
end
aX({line=n.l,vars=r,final=true,err=n.msg,
title="упала на строке "..n.l..(m.lastL and m.lastL~=n.l and
(", переменные строки "..m.lastL)or"")})
f=n.msg
else
f="отладка закончена"
end
end
end
local Q,aw,ax,aC,aM,aN,ai,aO
do
local W={}
local function v()
W[#W+1]={j,d,b}
if#W>50 then table.remove(W,1)end
end
local function E(m,n)return a.len((e[m]or""):sub(1,n-1))+1 end
local function ab()return#a.sub(p(),1,d-1)+1 end
local function an()
local n,m=p(),ab()
while m>1 and n:sub(m-1,m-1):match("[%w_]")do m=m-1 end
return n:match("^[%a_][%w_]*",m),m
end
local function r(m,n)
X()
l(n and E(m,n)or 1,m)
i=true
end
function Q(av,aQ,N)
local E,L,aR,as,m="",1,nil,nil,1
while true do
local n={}
local _=a.lower(E)
for aa,ac in ipairs(aQ)do
if _==""or a.lower(ac.text):find(_,1,true)then n[#n+1]=aa end
end
if N then
for _,aa in ipairs(n)do if aa==N then m=_ end end
N=nil
end
if m>#n then m=math.max(1,#n)end
local _=math.min(t-2,76)
local N=math.max(3,math.min(x-2,#n+1))
local ac,ae,aa=math.floor((t-_)/2)+1,2,N-1
if m<L then L=m end
if m>L+aa-1 then L=m-aa+1 end
S={{x1=ac,y1=ae,x2=ac+_-1,y2=ae+N-1}}
if N~=as then i=true end
as=N
ak=function()
y:set(ac,ae," "..af(av..(E~=""and("   фильтр: "..E)or""),_-1),
c.BAR_MARK,c.BAR_BG)
for as=1,aa do
local av=n[L+as-1]
local N=av and aQ[av]
local aQ=N and N.hint or""
local aV=N and af(" "..N.text,_-a.wlen(aQ)-1)..aQ.." "or""
y:set(ac,ae+as,af(aV,_),N and N.colour or c.POP_FG,
(av and L+as-1==m)and c.POP_SEL or c.POP_BG)
end
end
M()
local _,ac,N,c=at.pull()
if _=="key_down"and ac==s.keyboard()then
if c==h.up then m=m>1 and m-1 or#n
elseif c==h.down then m=m<#n and m+1 or 1
elseif c==h.pageUp then m=math.max(1,m-aa)
elseif c==h.pageDown then m=math.min(#n,m+aa)
elseif c==h.enter or c==h.numpadenter then
aR=n[m]
break
elseif c==h.back then
if E==""then break end
E,m,L=a.sub(E,1,-2),1,1
elseif c==1 then
break
elseif N and N>=32 and not H.isControl(N)
and not H.isControlDown(s.keyboard())then
E,m,L=E..a.char(N),1,1
end
end
end
S,ak={},nil
i=true
return aR
end
function aw()
local c=table.remove(W)
if not c then
f="назад некуда"
return
end
if c[1]~=j and not aq(c[1])then return end
X()
l(c[2],c[3])
i=true
end
local function E(m,c)
local n=package.searchpath(m,package.path)
if not n then
f="модуль не найден: "..m
return
end
v()
if not aq(n)then return end
if not c then return end
local L=P()
for m,m in ipairs(L and L.funcs or{})do
if m.name==c or m.name=="local "..c or m.name:match("[%.:]"..c.."$")then
return r(m.l)
end
end
for L,N in ipairs(e)do
local m=N:find("[%.:]"..c.."%s*=")
if m then return r(L,m+1)end
end
f=c.." в "..g.name(n).." не нашёл"
end
function ax()
local N,L=p(),ab()
for c,m,n in N:gmatch("()require%s*%(?%s*[\"']([^\"']+)[\"']%s*%)?()")do
if L>=c and L<=n then return E(m)end
end
local c,S=an()
local n=P(c)
if not n then
f="переход к определению - только в .lua"
return
end
if not c then
f="под курсором нет имени"
return
end
local m=N:sub(1,S-1):match("([%a_][%w_%.]*)[%.:]$")
if m then
for N,N in ipairs(n.funcs)do
if N.name==m.."."..c or N.name==m..":"..c then
v()
return r(N.l)
end
end
local N=ba()[m]
if N and#N==1 then return E(N[1],c)end
if package.searchpath(m,package.path)and not m:find("%.")then return E(m,c)end
for N,N in ipairs(n.funcs)do
if N.name:match("[%.:]"..c.."$")then
v()
return r(N.l)
end
end
f="не нашёл, где задано "..m.."."..c
return
end
local m=ah.refAt(n,b,L)
if m and m.decl then
v()
return r(m.decl.l,m.decl.c)
end
local m=n.globals[c]
if m then
v()
return r(m.l,m.c)
end
if package.searchpath(c,package.path)then return E(c)end
f="определение "..c.." не найдено"
end
function aC()
local E=P((an()))
local n=E and ah.refAt(E,b,ab())
if not n then
f="под курсором нет переменной"
return
end
local c,L={},1
for m,m in ipairs(ah.occurrences(E,n))do
c[#c+1]={text=string.format("%4d  %s",m.l,a4.trim(e[m.l]or"")),l=m.l,c=m.c}
if m.l==b then L=#c end
end
local m=Q(n.name..(n.decl and""or" (глобальная)")..": мест "..#c,c,L)
if m then
v()
r(c[m].l,c[m].c)
end
end
function aM()
if k then return end
local E=P((an()))
local n=E and ah.refAt(E,b,ab())
if not n then
f="под курсором нет переменной"
return
end
local c=aA("Новое имя для "..n.name..": ",n.name)
if not c or c==n.name then return end
if not c:match("^[%a_][%w_]*$")or aP[c]then
f="не годится в имена: "..c
return
end
local m=ah.occurrences(E,n)
local n,N=m[1].l,m[#m].l
local E={}
for L=n,N do E[#E+1]=e[L]end
for S=#m,1,-1 do
local L=m[S]
local S=E[L.l-n+1]
E[L.l-n+1]=S:sub(1,L.c-1)..c..S:sub(L.c+L.len)
end
local c,L=d,b
u(n,N-n+1,E)
w()
l(c,L)
i=true
f="переименовано мест: "..#m
end
function aN()
local n=P()
if not n or#n.funcs==0 then
f="функций не нашёл"
return
end
local c,E={},1
for m,m in ipairs(n.funcs)do
c[#c+1]={text=("  "):rep(m.depth)..m.name,hint=tostring(m.l),l=m.l}
if m.l<=b then E=#c end
end
local m=Q("Функции файла",c,E)
if m then
v()
r(c[m].l)
end
end
function ai(n)
local c,L={},{}
local function m(E)if not L[E]then L[E]=true c[#c+1]=E end end
for E in pairs(D)do m(E)end
if A then m(A.l)end
for A=1,#e do
if e[A]:find("(",1,true)and aU(A)then m(A)end
end
if#c==0 then
f="замечаний нет"
return
end
table.sort(c)
local m=n and c[#c]or c[1]
for E=1,#c do
local A=n and c[#c-E+1]or c[E]
if(n and A<b)or(not n and A>b)then m=A break end
end
local c=D[m]and D[m].marks and D[m].marks[1]
r(m,c and c[1])
end
local function D(c)
local n,m=c:match("^(.-)([^/]*)$")
local A=n:sub(1,1)=="/"and n or g.concat(g.path(j),n)
local c={}
local r=g.list(A)
if not r then return end
for A in r do
if A:sub(1,#m)==m then c[#c+1]=A end
end
if#c==0 then return end
local m=c[1]
for r,r in ipairs(c)do
while r:sub(1,#m)~=m do m=m:sub(1,-2)end
end
return n..m
end
function aO()
local c=aA("Открыть (Tab - дописать, пусто - открытые): ",nil,D)
if not c then return end
if c==""then
am()
local m={}
for n,n in ipairs(I)do
m[#m+1]={text=g.name(n.filename)..(n.modified and" *"or""),hint=n.parent}
end
local n=Q("Открытые файлы",m,T)
if n then ar(n)end
return
end
if c:sub(1,1)~="/"then c=g.concat(g.path(j),c)end
v()
aq(g.canonical(c))
end
end
local E,L,r,N
do
local function v()
local g,c,c,m=O()
if not g then return b,b end
if m==1 and c>g then c=c-1 end
return g,c
end
function E()
if k then return end
local n,A=v()
local D,g=true,math.huge
for m=n,A do
local c=e[m]
if c:find("%S")then
if not c:match("^%s*%-%-")then D=false end
g=math.min(g,#c:match("^%s*"))
end
end
if g==math.huge then return end
local c={}
for S=n,A do
local m=e[S]
if not m:find("%S")then c[#c+1]=m
elseif D then c[#c+1]=(m:gsub("^(%s*)%-%- ?","%1",1))
else c[#c+1]=m:sub(1,g).."-- "..m:sub(g+1)end
end
local g,m=o,d
u(n,A-n+1,c)
w()
o=g
l(math.max(1,m+(D and-3 or 3)),b)
i=true
end
function L()
if k then return end
local g,m=v()
local c,n={},m-g+1
for A=g,m do c[#c+1]=e[A]end
for A=g,m do c[#c+1]=e[A]end
local m,A,D=o,d,b
u(g,n,c)
w()
if m then o={m[1],m[2]+n}end
l(A,D+n)
i=true
end
function r(c)
if k then return end
local g,n=v()
if(c<0 and g==1)or(c>0 and n==#e)then return end
local m={}
if c>0 then m[1]=e[n+1]end
for v=g,n do m[#m+1]=e[v]end
if c<0 then m[#m+1]=e[g-1]end
local v,A,D=o,d,b
u(math.min(g,g+c),n-g+2,m)
w()
if v then o={v[1],v[2]+c}end
l(A,D+c)
i=true
end
function N()
if C[b]then
C[b]=nil
i=true
return
end
local c,g
local n=P()
if n then
for m,m in ipairs(n.blocks)do
if m.first==b and(not g or m.last>g)then c,g=m.first,m.last end
end
if not c then
for m,m in ipairs(n.blocks)do
if m.first<b and m.last>=b and(not c or m.first>c)then c,g=m.first,m.last end
end
end
else
local n=#p():match("^%s*")
local m=b+1
while e[m]and(not e[m]:find("%S")or#e[m]:match("^%s*")>n)do
if e[m]:find("%S")then g=m end
m=m+1
end
if g then c=b end
end
if not c then
f="здесь нечего сворачивать"
return
end
X()
C[c]=g
l(d,c)
i=true
end
end
local n={
left=function(c)bm(c)end,
right=function(c)bv(c)end,
up=function(c)G(d,Y(b,-1)or b,c)end,
down=function(c)G(d,Y(b,1)or b,c)end,
home=function(c)bl(c)end,
eol=function(c)bu(c)end,
pageUp=function(c)G(d,az(b,-(x-1)),c)end,
pageDown=function(c)G(d,az(b,x-1),c)end,
backspace=function()
if k then return end
if al()then return end
local c=p()
local g,m=a.sub(c,d-1,d-1),a.sub(c,d,d)
if d>1 and m~=""and(aI[g]==m or((g=='"'or g=="'")and m==g))then
u(b,1,{a.sub(c,1,d-2)..a.sub(c,d+1)},"erase")
l(d-1,b)
return
end
if d==1 and ap(b-1)then
C[ap(b-1)]=nil
i=true
end
if bm()then aY()end
end,
delete=function()if not k then aY()end end,
deleteLine=function()if not k then aY(true)end end,
newline=function()if not k then bw()end end,
save=ag,
close=aE,
find=function()aZ(false)end,
findnext=function()aZ(true)end,
findprev=function()aZ(true,true)end,
replace=bn,
cut=function()
if k then return end
if O()then
q=a7()
al()
f="вырезано строк: "..#q
return
end
if not aT then q={}end
q[#q+1]=p()
aT=true
aY(true)
bl()
end,
cutSelection=function()
if k or not O()then return end
q=a7()
al()
f="вырезано строк: "..#q
end,
copy=function()
local c=a7()
if c then
q=c
f="скопировано строк: "..#q
else
q={p()}
f="скопирована строка"
end
X()
end,
uncut=function()
if k or#q==0 then return end
al()
local c=p()
local g,m=a.sub(c,1,d-1),a.sub(c,d)
if#q==1 then
u(b,1,{g..q[1]..m})
l(d+a.len(q[1]),b)
else
local c={g..q[1]}
for g=2,#q-1 do c[#c+1]=q[g]end
c[#c+1]=q[#q]..m
u(b,1,c)
l(a.len(q[#q])+1,b+#q-1)
end
w()
end,
selectAll=function()
o={1,1}
l(a.len(e[#e])+1,#e)
i=true
end,
undo=function()if not k then bj(R,ay)end end,
redo=function()if not k then bj(ay,R)end end,
complete=function()
if k then return end
if O()then
aD(false)
elseif F and not(aB()or""):match("[%.:]$")then
Z(F.text)
w()
F=nil
elseif not bb()then
Z("  ")
end
end,
completeList=function()
if not k then bb()end
end,
unindent=function()if not k then aD(true)end end,
run=aG,
shell=aH,
panel=function()aF(U==0)end,
debug=aL,
breakpoint=function()
B[b]=not B[b]or nil
ad(b)
end,
open=aO,
nextDoc=function()ar(T%#I+1)end,
prevDoc=function()ar((T-2)%#I+1)end,
outline=aN,
definition=ax,
usages=aC,
back=aw,
rename=aM,
problem=function()ai(false)end,
problemPrev=function()ai(true)end,
comment=E,
duplicate=L,
moveUp=function()r(-1)end,
moveDown=function()r(1)end,
fold=N,
goto_line=function()
local g=aA("Строка: ")
local c=tonumber(g)
if c then
X()
l(1,c)
i=true
end
end,
}
n.help=function()
local g={
{"save","сохранить"},{"close","закрыть файл (последний - выйти)"},
{"open","открыть файл; пусто - список открытых"},
{"nextDoc","следующий открытый файл"},{"prevDoc","предыдущий открытый файл"},
{"run","сохранить и запустить"},{"debug","запустить под отладчиком"},
{"breakpoint","точка останова (или щелчок по номеру)"},
{"stepGo","отладчик: дальше"},{"stepOver","отладчик: шаг"},
{"stepInto","отладчик: внутрь вызова"},{"stepOut","отладчик: наружу"},
{"stepStop","отладчик: остановить"},
{"shell","оболочка в панели"},{"panel","показать или скрыть панель"},
{"problem","к следующей ошибке"},{"problemPrev","к предыдущей ошибке"},
{"find","поиск (/шаблон - шаблон Lua)"},{"findnext","искать дальше"},
{"findprev","искать назад"},{"replace","найти и заменить"},
{"goto_line","к строке по номеру"},{"outline","функции файла"},
{"definition","к определению (и в модуль по require)"},
{"usages","где ещё стоит эта переменная"},{"back","назад после перехода"},
{"rename","переименовать переменную"},
{"complete","дополнить; с выделением - отступ"},{"completeList","список вариантов"},
{"unindent","убрать отступ"},{"comment","закомментировать строки"},
{"duplicate","повторить строки"},{"moveUp","строки вверх"},{"moveDown","строки вниз"},
{"fold","свернуть или развернуть блок"},
{"undo","отменить"},{"redo","повторить отменённое"},
{"selectAll","выделить всё"},{"copy","копировать"},{"cutSelection","вырезать выделенное"},
{"cut","вырезать строку"},{"uncut","вставить"},{"deleteLine","удалить строку"},
}
local c={}
for m,r in ipairs(g)do
local g=au.keybinds[r[1]]
local m={}
for q,v in ipairs(type(g)=="table"and g or{})do
if type(v)=="table"then
local q={}
for g,g in ipairs(v)do
q[#q+1]=g=="control"and"Ctrl"or g=="shift"and"Shift"or g=="alt"and"Alt"
or(a.upper(g:sub(1,1))..g:sub(2))
end
m[#m+1]=table.concat(q,"+")
end
end
if#m>0 then c[#c+1]={text=af(table.concat(m,", "),26)..r[2]}end
end
c[#c+1]={text=af("Tab",26).."отладчик: переменные, Enter - раскрыть"}
Q("Клавиши (буквы - фильтр, Backspace - выйти)",c)
end
local m={
left=true,right=true,up=true,down=true,
home=true,eol=true,pageUp=true,pageDown=true,
}
local function E(q)
local c,r=nil,0
local g=s.keyboard()
local v=not not H.isShiftDown(g)
local A=not not H.isControlDown(g)
local C=not not H.isAltDown(g)
for g,D in pairs(au.keybinds)do
if type(D)=="table"and n[g]then
local D=bh(g,q,v,A,C)
if D>r then r,c=D,g end
end
end
if not c and v and not A and not C then
for g,r in pairs(au.keybinds)do
if m[g]and type(r)=="table"then
for v,v in ipairs(r)do
if#v==1 and q==h[v[1]]then c=g end
end
end
end
end
return c and n[c],c
end
local function r(g,n)
f=nil
local c,f=E(n)
local q=not not H.isShiftDown(s.keyboard())
if c then
if m[f]then
if q and not o then o={d,b}end
c(q)
else
c()
end
if f~="cut"then aT=false end
elseif k and n==h.q then
aS=false
elseif not k and g and not H.isControl(g)then
local c=a.char(g)
local f=a.sub(p(),d,d)
if(a8[c]or c=='"'or c=="'")and f==c then
G(d+1,b)
elseif K and aI[c]and not O()then
Z(c..aI[c])
l(d-1,b)
w()
elseif K and(c=='"'or c=="'")and not f:match("[%w_]")and not O()then
Z(c..c)
l(d-1,b)
w()
else
Z(c)
if c=="."and not O()then bo()end
end
aT=false
end
end
local function q(f)
if k then return end
al()
f=f:gsub("\r\n","\n"):gsub("\r","\n")
local c={}
for g in(f.."\n"):gmatch("(.-)\n")do
c[#c+1]=a4.detab(g,2)
end
if#c==1 then
Z(c[1],"paste")
w()
return
end
local h=p()
local m=a.sub(h,1,d-1)
local p=m:match("^ *")
local g
for v,n in ipairs(c)do
local f=#n:match("^ *")
if n:find("%S")and(v>1 or f>0)and(not g or f<g)then
g=f
end
end
g=g or 0
for n,f in ipairs(c)do
local v=#f:match("^ *")
f=f:sub(math.min(v,g)+1)
if n>1 and f~=""then f=p..f end
c[n]=f
end
local g=c[#c]
local f={m..c[1]}
for m=2,#c-1 do f[#f+1]=c[m]end
f[#f+1]=g..a.sub(h,d)
u(b,1,f)
l(a.len(g)+1,b+#c-1)
w()
end
aq(j,k)
local function h(a,f,c,j,k)
if a=="interrupted"or(f~=s.keyboard()and f~=s.screen())then return end
if a=="key_down"then
r(c,j)
aJ()
bk()
a_()
M()
elseif a=="clipboard"then
q(c)
aJ()
bk()
a_()
M()
elseif a=="touch"or a=="drag"then
local m,n=s.getGlobalArea()
local f,g=c-m+1,j-n+1
if f>=1 and g>=1 and f<=t and g<=x then
local c=math.min(aW[g]or#e,#e)
if a=="touch"and f<V then
B[c]=not B[c]or nil
ad(c)
M()
return
end
if a=="touch"then
X()
elseif not o then
o={d,b}
end
l(bt(e[c]or"",math.max(1,f-V+z)),c)
w()
aJ()
a_()
if o then i=true end
M()
end
elseif a=="scroll"then
G(d,az(b,-(k or 0)*12))
aJ()
i=true
M()
end
end
local function b()
M()
while aS do
local c=aj and math.max(0.05,aj-J.uptime())
local a=table.pack(at.pull(c))
if a[1]then
h(table.unpack(a,1,a.n))
elseif aj and J.uptime()>=aj then
ao()
M()
end
while aK and aS do
local a=aK
aK=nil
h(table.unpack(a,1,a.n or#a))
end
end
end
local a,c=xpcall(b,debug.traceback)
y:close()
s.setCursorBlink(true)
s.clear()
if not a then error(c,0)end
