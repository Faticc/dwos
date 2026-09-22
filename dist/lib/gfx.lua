local d={}
local z="\226\150\132"
local u,h,q,i=string.rep,math.floor,math.max,math.min
local m=table.move or function(a,b,e,c)
if c>b then
for f=e-b,0,-1 do a[c+f]=a[b+f]end
else
for f=0,e-b do a[c+f]=a[b+f]end
end
return a
end
local c={
set={1/64,1/128,1/256},copy={1/16,1/32,1/64},
fill={1/32,1/64,1/128},color={1/32,1/64,1/128},
blit={0.5,1,2},
}
d.budget=0.9
local function k(b)
local a=b.maxResolution()
return a>=160 and 3 or a>=80 and 2 or 1
end
local function l(a,b,e)
if not a.allocateBuffer then return nil end
local f,g=pcall(a.allocateBuffer,b,e)
return f and g or nil
end
function d.art(b)
local f,a=#b,#b[1]
local g={w=a,h=f}
for e=1,f do
local f=b[e]
if#f~=a then error(("row %d is %d wide, not %d"):format(e,#f,a))end
for b=1,a do
local j=f:sub(b,b)
g[(e-1)*a+b]=j~="."and tonumber(j,16)or false
end
end
return g
end
function d.flip(a)
local b={w=a.w,h=a.h}
for e=0,a.h-1 do
for f=1,a.w do b[e*a.w+f]=a[e*a.w+(a.w+1-f)]end
end
return b
end
local j={}
local function r(a,b,e,n,f,g,o)
a.gpu,a.ox,a.oy,a.bw,a.bh=b,e,n,f,g
a.pal=o
a.cost,a.log,a.ln=0,{},0
a.fg,a.bg=nil,nil
a.lfg,a.lbg=nil,nil
local e=k(b)
a.cset,a.ccopy,a.cfill,a.ccolor=c.set[e],c.copy[e],c.fill[e],c.color[e]
local k,n=b.maxResolution()
a.cblit=c.blit[e]*(f*g)/(k*n)
a.limit=i(a.cblit,d.budget)
a.buf=l(b,f,g)
a.calls,a.screenCalls=0,0
a.was={fg={b.getForeground()},bg={b.getBackground()}}
end
local function k(a)
if a.buf then a.gpu.setActiveBuffer(a.buf)end
end
local function s(a,b,c)
local e=a.gpu
if c~=a.bg then e.setBackground(c,a.pal)a.bg=c a.calls=a.calls+1 end
if b~=a.fg then e.setForeground(b,a.pal)a.fg=b a.calls=a.calls+1 end
end
local function g(a,b,n,o,p,c,e,f)
if not a.buf then return end
local l=a.ln+1
a.log[l]={b,n,o,p,c,e,f}
a.ln=l
if b=="s"or b=="f"then
if e~=a.lbg then a.cost=a.cost+a.ccolor a.lbg=e end
if b=="s"and c~=a.lfg then a.cost=a.cost+a.ccolor a.lfg=c end
if b=="f"and f~=" "and c~=a.lfg then a.cost=a.cost+a.ccolor a.lfg=c end
a.cost=a.cost+(b=="s"and a.cset or a.cfill)
else
a.cost=a.cost+a.ccopy
end
end
function j.present(a,b)
local c=a.gpu
if not a.buf then return end
if a.ln==0 and not a.stale then c.setActiveBuffer(0)return end
c.setActiveBuffer(0)
if b~="blit"and not a.stale and(b=="replay"or a.cost<=a.limit)then
local e,f,l,n=nil,nil,a.ox-1,a.oy-1
local o=a.log
for p=1,a.ln do
local b=o[p]
local t=b[1]
if t=="c"then
c.copy(l+b[2],n+b[3],b[4],b[5],b[6],b[7])
else
if b[6]~=f then c.setBackground(b[6],a.pal)f=b[6]end
if t=="s"then
if b[5]~=e then c.setForeground(b[5],a.pal)e=b[5]end
c.set(l+b[2],n+b[3],b[4])
else
if b[7]~=" "and b[5]~=e then c.setForeground(b[5],a.pal)e=b[5]end
c.fill(l+b[2],n+b[3],b[4],b[5+3]or 1,b[7])
end
end
a.screenCalls=a.screenCalls+1
o[p]=nil
end
a.fg,a.bg=e or a.fg,f or a.bg
else
c.bitblt(0,a.ox,a.oy,a.bw,a.bh,a.buf,1,1)
a.screenCalls=a.screenCalls+1
for b=1,a.ln do a.log[b]=nil end
end
a.ln,a.cost,a.stale=0,0,false
a.lfg,a.lbg=nil,nil
end
function j.close(a)
if a.buf then
a.gpu.setActiveBuffer(0)
pcall(a.gpu.freeBuffer,a.buf)
a.buf=nil
end
if a.was then
pcall(a.gpu.setBackground,table.unpack(a.was.bg))
pcall(a.gpu.setForeground,table.unpack(a.was.fg))
a.fg,a.bg,a.was=nil,nil,nil
end
end
local a={}
a.__index=a
function d.surface(e,b)
b=b or{}
local f,l=e.getResolution()
local c=setmetatable({},a)
r(c,e,b.x or 1,b.y or 1,b.w or f,b.h or l,b.palette and true or false)
c.w,c.h=c.bw,c.bh
return c
end
local function c(b)return not b.buf end
function a:set(f,l,n,b,e,o)
b,e=b or self.fg or 0xFFFFFF,e or self.bg or 0
k(self)
s(self,b,e)
if c(self)then
self.gpu.set(self.ox+f-1,self.oy+l-1,n,o)
else
self.gpu.set(f,l,n,o)
if o then self.stale=true else g(self,"s",f,l,n,b,e)end
end
self.calls=self.calls+1
end
function a:fill(o,p,e,f,b,l,n)
if e<=0 or f<=0 then return end
l,n=l or self.fg or 0xFFFFFF,n or self.bg or 0
b=b or" "
k(self)
s(self,l,n)
if c(self)then
self.gpu.fill(self.ox+o-1,self.oy+p-1,e,f,b)
else
self.gpu.fill(o,p,e,f,b)
local s=self.ln
g(self,"f",o,p,e,l,n,b)
self.log[s+1][8]=f
end
self.calls=self.calls+1
end
function a:copy(b,e,f,l,n,o)
k(self)
if c(self)then
self.gpu.copy(self.ox+b-1,self.oy+e-1,f,l,n,o)
else
self.gpu.copy(b,e,f,l,n,o)
g(self,"c",b,e,f,l,n,o)
end
self.calls=self.calls+1
end
function a:get(b,e)
k(self)
if c(self)then return self.gpu.get(self.ox+b-1,self.oy+e-1)end
return self.gpu.get(b,e)
end
function a:sync()
if self.buf then
self.gpu.bitblt(self.buf,1,1,self.bw,self.bh,0,self.ox,self.oy)
self.fg,self.bg=nil,nil
end
end
function a:release()
if self.buf then self.gpu.setActiveBuffer(0)end
end
a.present=j.present
a.close=j.close
local b={}
b.__index=b
function d.new(l,c,e,f)
f=f or{}
local a,p=l.maxResolution()
local n,o=f.x or 1,f.y or 1
c=i(c or a,a-n+1)
e=i(e or p,p-o+1)
if not f.keepResolution and n==1 and o==1 then
local a,p=l.getResolution()
if a~=c or p~=e then l.setResolution(c,e)end
end
local a=setmetatable({
w=c,h=e,pw=c,ph=e*2,
fb={},shown={},saved={},top=1,
sp={},bl={},
dr={},dn=0,rmin={},rmax={},rlist={},
rgb=f.rgb and true or false,
},b)
r(a,l,n,o,c,e,not a.rgb)
a.mul=a.rgb and 16777216 or 16
local l=f.background or 0
for f=1,a.pw*a.ph do a.fb[f]=l end
for f=1,c*e do a.shown[f]=-1 end
return a
end
function b:palette(f)
local e=self.gpu
for a=0,15 do
local c=f[a]
if c then
local f,l=pcall(e.getPaletteColor,a)
if not f or l~=c then pcall(e.setPaletteColor,a,c)end
end
end
self.fg,self.bg=nil,nil
end
function b:reserveTop(a)self.top=a+1 end
function b:touch(a,c,e,n)
local f,l=a+e-1,c+n-1
local e=(self.top-1)*2+1
if a<1 then a=1 end
if c<e then c=e end
if f>self.pw then f=self.pw end
if l>self.ph then l=self.ph end
if f<a or l<c then return end
local e,n=self.dn,self.dr
n[e+1],n[e+2],n[e+3],n[e+4]=a,c,f,l
self.dn=e+4
end
function b:clear(a)
local c=self.fb
for e=1,self.pw*self.ph do c[e]=a end
self.dn=0
self:touch(1,1,self.pw,self.ph)
end
function b:rect(a,c,e,f,o)
local p,l,n=self.fb,self.pw,self.ph
if a<1 then e=e+a-1 a=1 end
if c<1 then f=f+c-1 c=1 end
if a+e-1>l then e=l-a+1 end
if c+f-1>n then f=n-c+1 end
if e<=0 or f<=0 then return end
self:touch(a,c,e,f)
for n=c,c+f-1 do
local c=(n-1)*l
for f=a,a+e-1 do p[c+f]=o end
end
end
function b:pixel(a,c,e)
if a>=1 and c>=1 and a<=self.pw and c<=self.ph then
self.fb[(c-1)*self.pw+a]=e
self:touch(a,c,1,1)
end
end
function b:tile(f,l,a)
local p,n,r=self.fb,self.pw,self.ph
local c=a.w
self:touch(f,l,c,a.h)
for o=0,a.h-1 do
local e=l+o
if e>=1 and e<=r then
local l,r=(e-1)*n,o*c
for e=1,c do
local c=f+e-1
if c>=1 and c<=n then
local f=a[r+e]
if f then p[l+c]=f end
end
end
end
end
end
b.blit=b.tile
function b:stamp(e,f,l)
local s,r,p=self.fb,self.pw,self.ph
local a,c=q(1,e),q(1,f)
local n,o=i(r,e+l.w-1),i(p,f+l.h-1)
if n<a or o<c then return end
local q={x=a,y=c,w=n-a+1,h=o-c+1}
local p=0
for t=c,o do
local c=(t-1)*r
for o=a,n do p=p+1 q[p]=s[c+o]end
end
self.saved[#self.saved+1]=q
self:tile(e,f,l)
end
function b:restore()
local l,n,c=self.fb,self.pw,self.saved
for f=#c,1,-1 do
local a=c[f]
self:touch(a.x,a.y,a.w,a.h)
local e=0
for o=a.y,a.y+a.h-1 do
local p=(o-1)*n
for n=a.x,a.x+a.w-1 do e=e+1 l[p+n]=a[e]end
end
c[f]=nil
end
end
function b:scroll(a)
if a==0 then return end
local f,o,c,p=self.pw,self.ph,self.w,self.h
local q,l=self.fb,self.shown
local e=(self.top-1)*2
local n=p-self.top+1
if math.abs(a)>=f then
for r=(self.top-1)*c+1,c*p do l[r]=-1 end
return
end
for r=e,o-1 do
local e=r*f
if a>0 then m(q,e+1+a,e+f,e+1)
else m(q,e+1,e+f+a,e+1-a)end
end
for q=self.top-1,p-1 do
local e=q*c
if a>0 then
m(l,e+1+a,e+c,e+1)
for p=e+c-a+1,e+c do l[p]=-1 end
else
m(l,e+1,e+c+a,e+1-a)
for m=e+1,e-a do l[m]=-1 end
end
end
local e=self.dr
for l=1,self.dn,4 do e[l],e[l+2]=e[l]-a,e[l+2]-a end
if a>0 then self:touch(f-a+1,1,a,o)else self:touch(1,1,-a,o)end
local e=self.gpu
if self.buf then
e.setActiveBuffer(self.buf)
if a>0 then e.bitblt(self.buf,1,self.top,c-a,n,self.buf,1+a,self.top)
else e.bitblt(self.buf,1-a,self.top,c+a,n,self.buf,1,self.top)end
g(self,"c",1,self.top,c,n,-a,0)
self.calls=self.calls+2
else
e.copy(self.ox,self.oy+self.top-1,c,n,-a,0)
self.screenCalls=self.screenCalls+1
end
end
function b:setfg(a)
if a~=self.fg then self.gpu.setForeground(a,not self.rgb)self.fg=a self.calls=self.calls+1 end
end
function b:setbg(a)
if a~=self.bg then self.gpu.setBackground(a,not self.rgb)self.bg=a self.calls=self.calls+1 end
end
local function s(a,c,e)
local f=e==" "and a.sp or a.bl
local a=f[c]
if not a then a=u(e,c)f[c]=a end
return a
end
function b:text(a,c,e,f,l)
local m=self.gpu
f,l=f or(self.rgb and 0xFFFFFF or 15),l or 0
k(self)
self:setbg(l)
self:setfg(f)
if self.buf then
m.set(a,c,e)
g(self,"s",a,c,e,f,l)
else
m.set(self.ox+a-1,self.oy+c-1,e)
self.screenCalls=self.screenCalls+1
end
self.calls=self.calls+1
if c>=self.top then
local f=(c-1)*self.w
for l=a,i(self.w,a+#e-1)do self.shown[f+l]=-1 end
self:touch(a,c*2-1,#e,2)
end
end
local function t(a,e,f,m,l)
local u,n,v,A=a.gpu,a.fb,a.shown,a.mul
local c=a.w
if e<a.top then e=a.top end
if f>a.h then f=a.h end
if m<1 then m=1 end
if l>c then l=c end
local o=a.buf~=nil
local p,q=0,0
if not o then p,q=a.ox-1,a.oy-1 end
for i=e,f do
local r=(i*2-2)*c
local w=r+c
local x=(i-1)*c
local c=m
while c<=l do
local f,m=n[r+c],n[w+c]
local y=f*A+m
if y==v[x+c]then
c=c+1
else
local e=1
while c+e<=l and n[r+c+e]==f and n[w+c+e]==m do e=e+1 end
local l
if f==m then
a:setbg(f)
l=s(a,e," ")
u.set(c+p,i+q,l)
if o then g(a,"s",c,i,l,a.fg or f,f)end
else
a:setbg(f)
a:setfg(m)
l=s(a,e,z)
u.set(c+p,i+q,l)
if o then g(a,"s",c,i,l,m,f)end
end
a.calls=a.calls+1
if not o then a.screenCalls=a.screenCalls+1 end
for a=0,e-1 do v[x+c+a]=y end
c=c+e
end
end
end
end
function b:present(a)
j.present(self,a)
end
function b:flush(m)
local c,a=self.dn,self.dr
if c==0 then
if not m then self:present()end
return
end
k(self)
local f=0
for e=1,c,4 do
f=f+(a[e+2]-a[e]+1)*(a[e+3]-a[e+1]+1)
end
if self.fullScan or f*2>self.pw*self.ph or c>320 then
t(self,self.top,self.h,1,self.w)
else
local e,f,n=self.rmin,self.rmax,self.rlist
local g=0
for i=1,c,4 do
local k,l=a[i],a[i+2]
for c=h((a[i+1]+1)/2),h((a[i+3]+1)/2)do
local a=e[c]
if a==nil then
g=g+1
n[g]=c
e[c],f[c]=k,l
else
if k<a then e[c]=k end
if l>f[c]then f[c]=l end
end
end
end
for c=1,g do
local a=n[c]
t(self,a,a,e[a],f[a])
e[a]=nil
end
end
self.dn=0
if not m then self:present()end
end
b.close=j.close
function d.savePalette(c)
local a={}
for b=0,15 do
local e,f=pcall(c.getPaletteColor,b)
a[b]=e and f or nil
end
return a
end
function d.restorePalette(c,b)
for a=0,15 do
if b[a]then
local e,f=pcall(c.getPaletteColor,a)
if not e or f~=b[a]then pcall(c.setPaletteColor,a,b[a])end
end
end
end
function d.mix(b,c,e)
local function a(f,g)return h(f/g)%256 end
local f=h(a(b,65536)+(a(c,65536)-a(b,65536))*e+0.5)
local g=h(a(b,256)+(a(c,256)-a(b,256))*e+0.5)
local i=h(a(b,1)+(a(c,1)-a(b,1))*e+0.5)
return f*65536+g*256+i
end
return d
