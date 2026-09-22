local e,r,p,v=math.floor,string.char,string.byte,table.unpack or unpack
local s,z,t,A=coroutine.yield,coroutine.create,coroutine.resume,coroutine.status
local f={[0]=1}
for a=1,32 do f[a]=f[a-1]*2 end
local B={3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,
35,43,51,59,67,83,99,115,131,163,195,227,258}
local C={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,
3,3,3,3,4,4,4,4,5,5,5,5,0}
local D={1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,
257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local E={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,
7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local F={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}
local d=1024
local q=33
local function j(g,h)
local b,a,i={},{},{}
for c=0,15 do b[c]=0 end
for k=0,h-1 do
local c=g[k]or 0
b[c]=b[c]+1
end
a[1]=0
for c=1,14 do a[c+1]=a[c]+b[c]end
for k=0,h-1 do
local c=g[k]or 0
if c~=0 then
i[a[c]]=k
a[c]=a[c]+1
end
end
return{count=b,sym=i}
end
local w,x
do
local a={}
for b=0,143 do a[b]=8 end
for b=144,255 do a[b]=9 end
for b=256,279 do a[b]=7 end
for b=280,287 do a[b]=8 end
w=j(a,288)
local a={}
for b=0,29 do a[b]=5 end
x=j(a,30)
end
local function G(l)
local k,g,c,b="",1,0,0
local h=0
local function n()
while g>#k do
k=s()
if k==nil then error("inflate: поток оборвался",0)end
g=1
end
local a=p(k,g)
g=g+1
return a
end
local function a(i)
while b<i do
c=c+n()*f[b]
b=b+8
end
local m=c%f[i]
c=e(c/f[i])
b=b-i
return m
end
local function u(o)
local y,f,i,m=o.count,0,0,0
for H=1,15 do
if b==0 then c,b=n(),8 end
local n=c%2
c,b=e(c/2),b-1
f=f+n
local c=y[H]
if f-c<i then return o.sym[m+f-i]end
m,i=m+c,(i+c)*2
f=f*2
end
error("inflate: битый код",0)
end
local y,m,c,i={},{},0,0
local function n(f)
c=c+1
m[c]=f
if c==d then
local f=r(v(m,1,d))
y[i%q]=f
i,c=i+1,0
h=h+d
s(f)
end
end
local function H(f,I)
for o=1,f do
local o=i*d+c-I
local f=e(o/d)
if f==i then
n(m[o-f*d+1])
else
n(p(y[f%q],o-f*d+1))
end
end
end
local function y(o,p)
while true do
local f=u(o)
if f<256 then
n(f)
elseif f==256 then
return
else
f=f-256
if f>29 then error("inflate: битая длина",0)end
local q=B[f]+a(C[f])
local f=u(p)+1
if f>30 then error("inflate: битое расстояние",0)end
local o=D[f]+a(E[f])
if o>i*d+c then error("inflate: расстояние за началом",0)end
H(q,o)
end
end
end
local function B()
local o,p,d=a(5)+257,a(5)+1,a(4)+4
local f={}
for i=1,d do f[F[i]]=a(3)end
local i=j(f,19)
f={}
local d=0
while d<o+p do
local q=u(i)
if q<16 then
f[d]=q
d=d+1
else
local i,u=0,0
if q==16 then
if d==0 then error("inflate: повтор без длины",0)end
u,i=f[d-1],3+a(2)
elseif q==17 then
i=3+a(3)
else
i=11+a(7)
end
if d+i>o+p then error("inflate: лишние длины",0)end
for q=1,i do f[d]=u d=d+1 end
end
end
local d={}
for i=0,p-1 do d[i]=f[o+i]end
return j(f,o),j(d,p)
end
local function i()
a(b%8)
local d=a(16)
local f=a(16)
if d+f~=65535 then error("inflate: битый несжатый блок",0)end
for f=1,d do n(a(8))end
end
local function f()
repeat until a(8)==0
end
return function()
if l=="gzip"then
if a(8)~=31 or a(8)~=139 then error("inflate: это не gzip",0)end
if a(8)~=8 then error("inflate: не deflate",0)end
local d=a(8)
a(16)a(16)a(16)
if e(d/4)%2==1 then
local j=a(16)
for n=1,j do a(8)end
end
if e(d/8)%2==1 then f()end
if e(d/16)%2==1 then f()end
if e(d/2)%2==1 then a(16)end
elseif l=="zlib"then
local d,f=a(8),a(8)
if d%16~=8 or(d*256+f)%31~=0 then error("inflate: это не zlib",0)end
if e(f/32)%2==1 then error("inflate: zlib со словарём не поддержан",0)end
end
repeat
local e=a(1)
local d=a(2)
if d==0 then i()
elseif d==1 then y(w,x)
elseif d==2 then y(B())
else error("inflate: неизвестный тип блока",0)end
until e==1
if c>0 then
local d=r(v(m,1,c))
h=h+c
c=0
s(d)
end
a(b%8)
if l=="gzip"then
a(16)a(16)
local c=a(16)+a(16)*65536
if c~=h%4294967296 then error("inflate: размер не сошёлся",0)end
elseif l=="zlib"then
a(16)a(16)
end
local c={}
while b>=8 do c[#c+1]=r(a(8))end
return table.concat(c)..k:sub(g),h
end
end
local b={}
b.__index=b
function b:feed(c)
if self.done then
self.rest=self.rest..c
return true
end
local d,a,e=t(self.co,c)
while true do
if not d then error(a,0)end
if A(self.co)=="dead"then
self.done,self.rest,self.size=true,a or"",e
return true
end
if a==nil then return false end
self.sink(a)
d,a,e=t(self.co)
end
end
local a={}
function a.new(e,c)
c=c or"gzip"
local d=setmetatable({sink=e,done=false,rest="",size=0},b)
d.co=z(G(c))
t(d.co)
return d
end
function a.string(d,e)
local b={}
local c=a.new(function(f)b[#b+1]=f end,e)
if not c:feed(d)then error("inflate: поток оборвался",0)end
return table.concat(b),c.rest
end
return a
