local h=require("computer")
local aA=require("event")
local W=require("filesystem")
local b=require("gfx")
local X=require("keyboard").keys
local an=require("serialization")
local Y=require("term")
local a=require("tty")
local F=require("unicode")
if not Y.isAvailable()then
io.stderr:write("bench: нужен экран\n")
return 1
end
local s=a.gpu()
local u,A=s.getResolution()
if u<80 or A<25 then
io.stderr:write("bench: нужен экран не меньше 80x25\n")
return 1
end
local d,i,g,o,J,Z=math.floor,math.min,math.max,math.random,math.sin,math.pi
local K,C=os.clock,h.uptime
local P,l=F.wlen,F.sub
local p=b.mix
local m,f,q=0x0B0E14,0x151A24,0x262D3D
local L,r,M=0xD8DEE9,0x6B7489,0xFFCC66
local ao,ap=2,3
local aq="/home/.bench"
local af=false
local function ar(a,c)
if a=="interrupted"or(a=="key_down"and c==X.q)then af=true end
end
local v=u>=120 and 44 or 34
local D,U=v+3,6
local w,y=u-D-1,A-7
local j=b.surface(s)
local a=b.new(s,w,y,{rgb=true,x=D,y=U,background=f})
local b,c=a.pw,a.ph
local N=a.fb
local function V(e,k)
if P(e)>k then return l(e,1,k)end
return e
end
local function ag(e,k,n)
e=V(e,k)
local l=(" "):rep(k-P(e))
return n and l..e or e..l
end
local ah={}
local function n(k,l,t,e,x,z,B)
if t<=0 then return end
e=ag(e,t,B)
local t,B=k*256+l,e..x.."/"..z
if ah[t]~=B then
ah[t]=B
j:set(k,l,e,x,z)
end
end
local function as()
for e=1,#a.shown do a.shown[e]=-1 end
a:touch(1,1,b,c)
a.fg,a.bg=nil,nil
end
local function ai(e)
if e>=1e6 then return("%.2fM"):format(e/1e6)end
if e>=1e4 then return("%.1fK"):format(e/1e3)end
if e>=100 then return tostring(d(e+0.5))end
return("%.1f"):format(e)
end
local function _(e,k,B)
local x,l={},#e-1
for t=0,k-1 do
local z=B and t/k or t/g(1,k-1)
local k=i(l-1,d(z*l))
x[t+1]=p(e[k+1],e[k+2],z*l-k)
end
return x
end
local k={name="Целые",unit="кл/с",color=0x7BD88F,ref=2.4e6,
title="«Жизнь» Конвея",about="клеток поля за секунду процессора"}
do
local t,E,x,G,H,l,I,z
function k.init()
t,E,x,G,H,l,I={},{},{},{},{},{},{}
for e=1,b do
G[e]=e==1 and b or e-1
H[e]=e==b and 1 or e+1
end
for e=1,c do
l[e]=((e==1 and c or e-1)-1)*b
I[e]=((e==c and 1 or e+1)-1)*b
end
for e=1,b*c do
t[e]=o()<0.3 and 1 or 0
E[e],x[e]=0,5
end
z={[0]=0xE8FFE0}
for e=1,5 do z[e]=p(k.color,f,(e-1)/4)end
k.gen,k.seeded=0,0
end
function k.step(aa)
local O,ab=0,b*c
repeat
local e,Q=t,E
for R=1,c do
local B,S,T=(R-1)*b,l[R],I[R]
for l=1,b do
local I,R=G[l],H[l]
local G=e[S+I]+e[S+l]+e[S+R]+e[B+I]+e[B+R]
+e[T+I]+e[T+l]+e[T+R]
if G==3 or(G==2 and e[B+l]==1)then Q[B+l]=1 else Q[B+l]=0 end
end
end
t,E=Q,e
O=O+ab
k.gen=k.gen+1
until K()>=aa
return O
end
function k.draw()
if k.gen-k.seeded>=40 then
k.seeded=k.gen
local e,l=o(1,b-12),o(1,c-12)
for B=l,l+11 do
for l=e,e+11 do t[(B-1)*b+l]=o()<0.45 and 1 or 0 end
end
end
for e=1,b*c do
if t[e]==1 then
N[e]=x[e]>0 and z[0]or z[1]
x[e]=0
else
local l=x[e]
if l<5 then l=l+1 x[e]=l end
N[e]=z[l]
end
end
a:touch(1,1,b,c)
end
end
local l={name="Дробные",unit="ит/с",color=0xFC9867,ref=5.4e6,
title="Множество Мандельброта",about="итераций z² + c за секунду процессора"}
do
local x={
{-0.65,0,3.1,48},
{-0.7453,0.1127,0.014,160},
{-0.235125,0.827215,0.006,200},
{-1.2539,0.3845,0.04,150},
{-0.1592,1.0317,0.035,120},
}
local I=_({0x07104A,0x206BCB,0xEDFFFF,0xFFAA00,0x7A1E00,0x07104A},48,true)
local G,H,e,z
local function E()
l.view=l.view%#x+1
local t=x[l.view]
e=t[3]/b
G,H,z=t[1]-e*b/2,t[2]-e*c/2,t[4]
l.row=1
end
function l.init()l.view,l.row=0,c+1 end
function l.step(Q)
local B,R=0,#I
repeat
if l.row>c then E()end
local E=l.row
local S,T=H+(E-1)*e,(E-1)*b
for O=1,b do
local aa=G+(O-1)*e
local t,x,G,H,e=0,0,0,0,0
while e<z and G+H<4 do
x=2*t*x+S
t=G-H+aa
G,H=t*t,x*x
e=e+1
end
B=B+e
N[T+O]=e>=z and 0 or I[e%R+1]
end
l.row=E+1
until K()>=Q
return B
end
function l.draw()a:touch(1,1,b,c)end
end
local E={name="Строки",unit="оп/с",color=0x78DCE8,ref=1.8e5,
title="Строки и юникод",about="format, gsub, find, upper, concat за секунду процессора"}
do
local z={"альфа","beta","гамма","delta","эпсилон","zeta","омега","lua","dwos","тик"}
local G,t,e
function E.init()G,t,e={},0,0 end
function E.step(O)
local H,x=0,{}
repeat
for B=1,32 do
e=e+1
local I=z[e%#z+1]
local z=("%06d  %s  %04X"):format(e,I,e*7919%65536):gsub("0","·")
local B=F.upper(I)
local F=0
for I=1,#B,2 do F=(F*31+B:byte(I))%65521 end
x[1],x[2],x[3]=z,B,("#%05d"):format(F)
z=table.concat(x,"  ")
if z:find(B,1,true)then H=H+1 end
if e%24==0 then
t=t+1
G[(t-1)%y+1]=z
end
end
until K()>=O
return H
end
function E.draw()a:clear(f)end
function E.overlay()
for e=1,y do
local x=t-y+e
if x>=1 then
local t=e==y and 0xFFFFFF or p(f,E.color,(e/y)^1.5)
a:text(2,e,V(G[(x-1)%y+1],w-2),t,f)
end
end
end
end
local F={name="Таблицы",unit="табл/с",color=0xAB9DF2,ref=8.0e5,
title="Сортировка и сборка мусора",about="созданных таблиц за секунду; внизу - занятая память"}
do
local function G(e,t)return e.id<t.id end
local e,x
function F.init()e,x={},1 end
function F.step(H)
local z=0
repeat
for t=1,8 do
local t,I={},{}
for B=1,32 do
x=x*16807%2147483647
t[B]={id=x%1000,n=B}
end
table.sort(t,G)
for x=1,32 do I[t[x].n]=t[x].id end
table.insert(t,1,table.remove(t))
z=z+34
end
until K()>=H
return z
end
function F.draw()
local t=h.totalMemory()
e[#e+1]=(t-h.freeMemory())/t
local t=d(b/2)
while#e>t do table.remove(e,1)end
a:rect(1,1,b,c,f)
for t=c,1,-8 do a:rect(1,t,b,1,q)end
local B=p(F.color,f,0.6)
for x=1,#e do
local z=b-(#e-x+1)*2+1
local t=g(1,d(e[x]*c+0.5))
a:rect(z,c-t+1,2,t,B)
a:rect(z,c-t+1,2,1,F.color)
end
end
end
local Q={name="Экран",unit="выз/с",color=0xFF6188,ref=3800,kind="real",
title="Прямой вывод на экран",about="вызовов gpu за секунду: упирается в бюджет тика"}
do
local e={0xFF6188,0xFC9867,0xFFD866,0xA9DC76,0x78DCE8,0xAB9DF2}
function Q.init()if s.setActiveBuffer then s.setActiveBuffer(0)end end
function Q.step()
for t=1,16 do
local t,x=o(2,12),o(1,4)
local z,B=D+o(0,w-t),U+o(0,y-x)
s.setBackground(e[o(#e)])
s.fill(z,B,t,x," ")
end
return 32
end
function Q.finish()
j.fg,j.bg=nil,nil
as()
end
end
local aa={name="Кадры",unit="к/с",color=0xFFD866,ref=20,kind="real",
title="Плазма через gfx",about="полных кадров в секунду: расчёт, буфер, вывод"}
do
local z,B,G,H,o,s,t,e
local function x(I,S)
local O={}
for R=0,I-1 do O[R]=d((J(R/I*2*Z)+1)*S)end
return O
end
function aa.init()
z=_({0x1B0B3B,0xAB2F6F,0xFFD866,0x2BB3C0,0x1B0B3B},64,true)
o,s,t=d(b*0.9),d(c*1.3),d((b+c)*0.6)
B,G,H=x(o,10.5),x(s,10.5),x(t,10.5)
e=0
end
function aa.step()
e=e+1
local x,I,O=e*3,e*2,e*5
for e=1,c do
local R,S,T=(e-1)*b,G[(e+I)%s],e+O
for e=1,b do
N[R+e]=z[(B[(e+x)%o]+S+H[(e+T)%t])%64+1]
end
end
a:touch(1,1,b,c)
a.fg,a.bg=nil,nil
a:flush()
return 1
end
end
local G={name="Фигура",unit="к/с",color=0xE879F9,ref=20,kind="real",
title="Тор в 3D",about="поворот, свет, отсечение и заливка граней за кадр"}
do
local R,O,B,z=22,11,1,0.42
local aj,at,ak,al,au,am={},{},{},{},{},{}
local s,t,S,H,T={},{},{},{},{}
local ab,av,aw,ax,U,V
local aB,aC,aD=-0.45,0.6,-0.66
local aE=4
local function o(e,x)return(e%R)*O+(x%O)+1 end
function G.init()
for I=0,R-1 do
local e=I/R*2*Z
local ac,ad=math.cos(e),J(e)
for ae=0,O-1 do
local e=ae/O*2*Z
local x,ay=math.cos(e),J(e)
local e=o(I,ae)
aj[e],at[e],ak[e]=(B+z*x)*ac,z*ay,(B+z*x)*ad
al[e],au[e],am[e]=x*ac,ay,x*ad
end
end
for e=0,R-1 do
for x=0,O-1 do
H[#H+1]={o(e,x),o(e+1,x),o(e+1,x+1),o(e,x+1)}
end
end
ab=_({p(G.color,f,0.88),p(G.color,f,0.35),G.color,0xFFF4FF},40)
av=i(b,c*1.2)*1.05
aw,ax=b/2+0.5,c/2+0.5
U,V=0.5,0
end
local function ay(B,o,x,e,ac,z,aF)
if o>e then B,o,x,e=x,e,B,o end
if e>z then x,e,ac,z=ac,z,x,e end
if o>e then B,o,x,e=x,e,B,o end
if z-o<0.001 then return end
local I,ad=g(1,math.ceil(o-0.5)),i(c,d(z+0.5))
for az=I,ad do
local ad=i(g(az,o),z)
local ae=B+(ac-B)*(ad-o)/(z-o)
local I
if ad<e then I=B+(x-B)*(ad-o)/(e-o)
elseif z>e then I=x+(ac-x)*(ad-e)/(z-e)
else I=x end
if ae>I then ae,I=I,ae end
local e=(az-1)*b
for o=g(1,d(ae+0.5)),i(b,d(I+0.5))do N[e+o]=aF end
end
end
function G.step()
U,V=U+0.045,V+0.07
local I,ac,ad,ae=J(U),math.cos(U),J(V),math.cos(V)
local x,z,B={},{},{}
for e=1,R*O do
local U,o=aj[e]*ae+ak[e]*ad,-aj[e]*ad+ak[e]*ae
local O=at[e]
O,o=O*ac-o*I,O*I+o*ac
local R=av/(o+aE)
s[e],t[e],S[e]=aw+U*R,ax-O*R,o
local R,o=al[e]*ae+am[e]*ad,-al[e]*ad+am[e]*ae
local O=au[e]
x[e],z[e],B[e]=R,O*ac-o*I,O*I+o*ac
end
for e=1,b*c do N[e]=f end
local e=0
for R=1,#H do
local o=H[R]
local I,N,U,O=o[1],o[2],o[3],o[4]
local V=(s[N]-s[I])*(t[O]-t[I])-(t[N]-t[I])*(s[O]-s[I])
if V<0 then
e=e+1
T[e]=R
o.z=S[I]+S[N]+S[U]+S[O]
end
end
for o=e+1,#T do T[o]=nil end
table.sort(T,function(o,I)return H[o].z>H[I].z end)
for o=1,e do
local N=H[T[o]]
local e,H,o,I=N[1],N[2],N[3],N[4]
local N=x[e]+x[H]+x[o]+x[I]
local x=z[e]+z[H]+z[o]+z[I]
local z=B[e]+B[H]+B[o]+B[I]
local B=(N*aB+x*aC+z*aD)/math.sqrt(N*N+x*x+z*z)
local x=ab[g(1,i(#ab,d((0.12+0.88*g(0,B))^1.4*#ab+0.5)))]
ay(s[e],t[e],s[H],t[H],s[o],t[o],x)
ay(s[e],t[e],s[o],t[o],s[I],t[I],x)
end
a:touch(1,1,b,c)
a.fg,a.bg=nil,nil
a:flush()
return 1
end
end
local s={name="Диск",unit="КБ/с",color=0x5AB0F6,ref=1000,kind="real",
title="Файл туда и обратно",about="запись и чтение кусками по 2 КБ"}
do
local ab=("DwOS"):rep(512)
local t,x,e,O,o,z,B,R,ac,ad
local S,H,T,I,N
local function U(V,ae)
local aj,ak=(V-1)%z,d((V-1)/z)
a:rect(ac+aj*B,ad+ak*R,B-1,R-1,ae)
end
function s.init()
t,e=nil,nil
for V,ae in ipairs({"/home","/tmp"})do
local V=W.get(ae)
if V and not V.isReadOnly()then
local aj=V.spaceTotal()-V.spaceUsed()
if aj>=24*1024 then
t,x=ae.."/.bench.tmp",i(64,d(aj/2048/2))
break
end
end
end
S,H,T,I=0,0,0,0
O,o="w",0
if not t then s.about="нет диска, куда можно писать"return end
z=16
B=g(2,d((b-2)/z))
R=g(2,i(B,d((c-2)/math.ceil(x/z))))
ac=d((b-z*B)/2)+1
ad=d((c-math.ceil(x/z)*R)/2)+1
for z=1,x do U(z,q)end
N=C()
end
function s.step()
if not t then return 0 end
local z=0
for B=1,4 do
if O=="w"then
if not e then
for B=1,x do U(B,q)end
e=W.open(t,"wb")
if not e then t=nil return 0 end
end
e:write(ab)
o=o+1
z=z+#ab
S=S+#ab
U(o,p(s.color,f,0.55))
if o>=x then
e:close()
e,O,o=nil,"r",0
local B=C()
H,N=H+B-N,B
end
else
if not e then e=W.open(t,"rb")end
local B=e and e:read(2048)
if B then
o=o+1
z=z+#B
T=T+#B
U(o,s.color)
end
if not B or o>=x then
if e then e:close()end
e,O,o=nil,"w",0
local o=C()
I,N=I+o-N,o
end
end
end
local o={}
if H>0 then o[#o+1]=("запись %s КБ/с"):format(ai(S/1024/H))end
if I>0 then o[#o+1]=("чтение %s КБ/с"):format(ai(T/1024/I))end
o[#o+1]=t
s.about=table.concat(o," · ")
a.fg,a.bg=nil,nil
a:flush()
return z/1024
end
function s.finish()
if e then pcall(e.close,e)e=nil end
if t then W.remove(t)end
end
end
local x={name="Сигналы",unit="сиг/с",color=0xA9DC76,ref=20,kind="real",
title="Очередь сигналов",about="pushSignal и pullSignal за секунду"}
do
local t,N=32,16
local B,e,o,O,R,z
local H={}
function x.init()
O,R=d(b/2),d(c/2)
z=d(i(b,c)/2)-4
B,e,o={},{},0
for I=1,t do
local S=(I-1)/t*2*Z
B[I]={d(O+z*math.cos(S)+0.5),d(R+z*J(S)+0.5)}
e[I]=0
end
for z=0,6 do H[z]=p(q,x.color,z/6)end
H[7]=0xF0FFE0
end
function x.step()
for z=1,N do h.pushSignal("bench_ping",z)end
local z,I=0,0
while z<N and I<4 do
local J,N,N,N=h.pullSignal(0)
if J=="bench_ping"then
z=z+1
o=o%t+1
e[o]=7
elseif J then
ar(J,N)
else
I=I+1
end
end
for o=1,t do
local t=B[o]
a:rect(t[1]-1,t[2]-1,3,3,H[e[o]])
if e[o]>0 then e[o]=e[o]-1 end
end
a.fg,a.bg=nil,nil
a:flush()
return z
end
end
local z=96*1024
local e={name="Память",color=0xF7768E,kind="mem",
title="Сколько памяти достаётся программе",about="заполнение до упора, без очков"}
do
local t,o,B,H
function e.init()
t,o={},h.totalMemory()
B=h.freeMemory()
H=_({p(e.color,f,0.6),e.color,0xFFE0E6},c)
a:rect(1,1,b,c,q)
end
function e.step()
for I=1,4 do
local I=h.freeMemory()
if I<=z then return true end
local J=i(2048,g(64,d((I-z)/24)))
local N,O=pcall(function()
local z={}
for I=1,J do z[I]=I end
return z
end)
if not N then return true end
t[#t+1]=O
end
return false
end
function e.draw()
local z=o-h.freeMemory()
e.value=B-h.freeMemory()
e.progress=z/o
local B=d(z/o*c+0.5)
for z=1,c do
a:rect(1,z,b,1,c-z<B and H[c-z+1]or q)
end
end
function e.show()
return("%.1fM из %.1fM"):format(e.value/1048576,o/1048576)
end
function e.finish()t=nil end
end
local o={k,l,E,F,Q,aa,G,s,x}
local t={k,l,E,F,Q,aa,G,s,x,e}
local function x(e)return 3+(e-1)*2 end
local E=x(#t)+2
local Q={"◐","◓","◑","◒"}
local H=v-20
local z=("%s · ОЗУ %dK · %d×%d"):format(
h.getArchitecture and h.getArchitecture()or _VERSION,
d(h.totalMemory()/1024),u,A)
local k={}
do
local e=io.open(aq)
if e then
k=an.unserialize(e:read("*a")or"")or{}
e:close()
end
end
local O,B,l=0,0,0
local I={}
local function R()
ah,I={},{}
j:fill(1,1,u,A," ",L,m)
j:fill(1,1,u,1," ",L,q)
j:fill(v+1,3,u-v,A-3," ",L,f)
j:set(2,1,"DwOS · бенчмарк",M,q)
j:set(u-P(z)-1,1,z,r,q)
end
local function S()
for F,e in ipairs(t)do
local z=x(F)
local G=e.score or e.done
local x=F==B and not G
local J,N="○",r
if G then J,N="●",e.color elseif x then J,N=Q[l%4+1],e.color end
n(2,z,1,J,N,m)
n(4,z,v-14,e.name,(G or x)and L or r,m)
n(v-9,z,8,e.score and tostring(e.score)or"",e.color,m,true)
local J=e.score and i(1,e.score/2000)or(x or e.done)and(e.progress or 0)or 0
local x=d(i(1,J)*H+0.5)
if I[F]~=x then
I[F]=x
if x>0 then j:set(4,z+1,("━"):rep(x),G and e.color or p(e.color,m,0.4),m)end
if x<H then j:set(4+x,z+1,("─"):rep(H-x),q,m)end
end
local x=""
if e.show then x=e.value and e.show()or""
elseif e.value then x=ai(e.value).." "..e.unit end
n(v-15,z+1,14,x,r,m,true)
end
end
local function x(z)
j.fg,j.bg=nil,nil
S()
local e=t[B]
if e then
n(D,3,w,e.name.." · "..e.title,e.color,f)
n(D,4,w,e.about,r,f)
end
n(2,E,v-3,"Итог",M,m)
n(2,E+1,v-3,z and("%d очков"):format(z)or"идёт замер…",z and M or r,m)
local e=""
if k.last then
e=("прошлый %d · лучший %d"):format(k.last,k.best or k.last)
end
if E+2<A then n(2,E+2,v-3,e,r,m)end
if z then
n(2,A,u-2,"r — ещё раз · q — выход",r,m)
else
n(2,A,u-2,("q — выход · проба %d из %d · %.1f с"):format(B,#t,C()-O),r,m)
end
j:present("replay")
a.fg,a.bg=nil,nil
end
local function m()
local e,u,u,u=h.pullSignal(0)
ar(e,u)
return af
end
local function E(h)
local e=t[h]
B,e.progress,e.value,e.score,e.done=h,0,nil,nil,nil
a:clear(f)
e.init()
if e.kind=="mem"then
local h,u=pcall(function()
repeat
local v=e.step()
e.draw()
l=l+1
x()
a:flush()
until v or m()
end)
e.finish()
e.done=true
if not h then e.about="упёрлись раньше запаса: "..tostring(u)end
x()
return not m()
elseif e.kind=="real"then
x()
local z,u,v=C(),0,0
repeat
u=u+e.step()
local h=C()-z
e.value,e.progress=u/g(h,0.05),h/ap
if h-v>=0.25 then
v,l=h,l+1
x()
end
until h>=ap
if e.finish then e.finish()end
else
local h,u=0,0
while h<ao do
local v=K()
u=u+e.step(v+0.05)
h=h+(K()-v)
e.value,e.progress=u/h,h/ao
e.draw()
l=l+1
x()
a:flush(e.overlay~=nil)
if e.overlay then
e.overlay()
a:present()
end
if m()then return false end
end
end
e.score=e.value and e.value>0 and d(1000*e.value/e.ref+0.5)or nil
x()
return not m()
end
local v={
["0"]="111101101101111",["1"]="010110010010111",["2"]="111001111100111",
["3"]="111001111001111",["4"]="101101111001001",["5"]="111100111001111",
["6"]="111100111101111",["7"]="111001010010010",["8"]="111101111101111",
["9"]="111101111001111",
}
local function F(m)
B=0
a:clear(f)
local h=tostring(m)
local e=g(1,i(d(b*0.8/(#h*4)),d(c*0.3/5)))
local A=d((b-(#h*4-1)*e)/2)+1
local u=3
for c=1,#h do
local B=v[h:sub(c,c)]
for h=0,4 do
local G=p(M,0xFC9867,h/4)
for v=0,2 do
local z=h*3+v+1
if B:sub(z,z)=="1"then
a:rect(A+((c-1)*4+v)*e,u+h*e,e,e,G)
end
end
end
end
local z=d((u+5*e)/2)+2
local c=z+2
local e,h=12,b-19
local b=2000
for u,u in ipairs(o)do b=g(b,u.score or 0)end
local u=e+d(1000/b*h)
local A=k.scores or{}
a:rect(u,(c-1)*2+1,1,#o*2-1,p(M,f,0.4))
for p,u in ipairs(o)do
local v=(c+p-2)*2+1
a:rect(e,v,h,1,q)
if u.score then a:rect(e,v,g(1,d(u.score/b*h)),1,u.color)end
if A[p]then a:rect(e+d(i(A[p],b)/b*h),v,1,2,L)end
end
a:flush(true)
local b="DwMark · 1000 — эталонная машина"
a:text(d((w-P(b))/2)+1,z,b,r,f)
for e,b in ipairs(o)do
a:text(2,c+e-1,ag(b.name,9),b.color,f)
a:text(w-6,c+e-1,ag(b.score and tostring(b.score)or"—",6,true),L,f)
end
if k.last and c+#o+1<=y then
local e=(m-k.last)/k.last*100
local b=("%+.1f%% к прошлому"):format(e)
if m>(k.best or 0)then b=b.." · новый рекорд!"end
a:text(d((w-P(b))/2)+1,c+#o+1,b,e>=0 and 0xA9DC76 or 0xFF6188,f)
end
a:present()
n(D,3,w,"Итог",M,f)
n(D,4,w,("среднее геометрическое %d проб"):format(#o),r,f)
end
local function f(b)
local c={}
for e,h in ipairs(o)do c[e]=h.score end
local e={last=b,best=g(b,k.best or 0),scores=c,runs=(k.runs or 0)+1}
pcall(function()
local b=io.open(aq,"w")
if b then b:write(an.serialize(e))b:close()end
end)
return e
end
local function g()
while true do
af=false
for b,b in ipairs(t)do b.score,b.value,b.progress,b.done=nil,nil,0,nil end
R()
as()
O,l=C(),0
for b=1,#t do
if not E(b)then return end
end
local c,b=0,0
for e,e in ipairs(o)do
if e.score and e.score>0 then c,b=c+math.log(e.score),b+1 end
end
local e=b>0 and d(math.exp(c/b)+0.5)or 0
F(e)
x(e)
k=f(e)
while true do
local c,b,b,b=aA.pull()
if c=="interrupted"then return end
if c=="key_down"then
if b==X.q or b==X.enter then return end
if b==X.r then break end
end
end
end
end
Y.setCursorBlink(false)
local b,c=xpcall(g,debug.traceback)
pcall(s.finish)
a:close()
j:close()
Y.setCursorBlink(true)
Y.clear()
if not b then error(c,0)end
