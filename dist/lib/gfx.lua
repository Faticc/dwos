local gfx={}
local BLOCK="\226\150\132"
local rep,floor,max,min=string.rep,math.floor,math.max,math.min
local move=table.move or function(a,f,e,t)
if t>f then
for i=e-f,0,-1 do a[t+i]=a[f+i]end
else
for i=0,e-f do a[t+i]=a[f+i]end
end
return a
end
local COST={
set={1/64,1/128,1/256},copy={1/16,1/32,1/64},
fill={1/32,1/64,1/128},color={1/32,1/64,1/128},
blit={0.5,1,2},
}
gfx.budget=0.9
local function tierOf(gpu)
local w=gpu.maxResolution()
return w>=160 and 3 or w>=80 and 2 or 1
end
local function allocate(gpu,w,h)
if not gpu.allocateBuffer then return nil end
local ok,id=pcall(gpu.allocateBuffer,w,h)
return ok and id or nil
end
function gfx.art(rows)
local h,w=#rows,#rows[1]
local a={w=w,h=h}
for y=1,h do
local r=rows[y]
if#r~=w then error(("row %d is %d wide, not %d"):format(y,#r,w))end
for x=1,w do
local c=r:sub(x,x)
a[(y-1)*w+x]=c~="."and tonumber(c,16)or false
end
end
return a
end
function gfx.flip(a)
local b={w=a.w,h=a.h}
for y=0,a.h-1 do
for x=1,a.w do b[y*a.w+x]=a[y*a.w+(a.w+1-x)]end
end
return b
end
local Log={}
local function logInit(s,gpu,x,y,w,h,pal)
s.gpu,s.ox,s.oy,s.bw,s.bh=gpu,x,y,w,h
s.pal=pal
s.cost,s.log,s.ln=0,{},0
s.fg,s.bg=nil,nil
s.lfg,s.lbg=nil,nil
local t=tierOf(gpu)
s.cset,s.ccopy,s.cfill,s.ccolor=COST.set[t],COST.copy[t],COST.fill[t],COST.color[t]
local mw,mh=gpu.maxResolution()
s.cblit=COST.blit[t]*(w*h)/(mw*mh)
s.limit=min(s.cblit,gfx.budget)
s.buf=allocate(gpu,w,h)
s.calls,s.screenCalls=0,0
s.was={fg={gpu.getForeground()},bg={gpu.getBackground()}}
end
local function target(s)
if s.buf then s.gpu.setActiveBuffer(s.buf)end
end
local function colors(s,fg,bg)
local g=s.gpu
if bg~=s.bg then g.setBackground(bg,s.pal)s.bg=bg s.calls=s.calls+1 end
if fg~=s.fg then g.setForeground(fg,s.pal)s.fg=fg s.calls=s.calls+1 end
end
local function logOp(s,op,a,b,c,d,e,f)
if not s.buf then return end
local n=s.ln+1
s.log[n]={op,a,b,c,d,e,f}
s.ln=n
if op=="s"or op=="f"then
if e~=s.lbg then s.cost=s.cost+s.ccolor s.lbg=e end
if op=="s"and d~=s.lfg then s.cost=s.cost+s.ccolor s.lfg=d end
if op=="f"and f~=" "and d~=s.lfg then s.cost=s.cost+s.ccolor s.lfg=d end
s.cost=s.cost+(op=="s"and s.cset or s.cfill)
else
s.cost=s.cost+s.ccopy
end
end
function Log.present(s,force)
local g=s.gpu
if not s.buf then return end
if s.ln==0 and not s.stale then g.setActiveBuffer(0)return end
g.setActiveBuffer(0)
if force~="blit"and not s.stale and(force=="replay"or s.cost<=s.limit)then
local fg,bg,ox,oy=nil,nil,s.ox-1,s.oy-1
local log=s.log
for i=1,s.ln do
local o=log[i]
local op=o[1]
if op=="c"then
g.copy(ox+o[2],oy+o[3],o[4],o[5],o[6],o[7])
else
if o[6]~=bg then g.setBackground(o[6],s.pal)bg=o[6]end
if op=="s"then
if o[5]~=fg then g.setForeground(o[5],s.pal)fg=o[5]end
g.set(ox+o[2],oy+o[3],o[4])
else
if o[7]~=" "and o[5]~=fg then g.setForeground(o[5],s.pal)fg=o[5]end
g.fill(ox+o[2],oy+o[3],o[4],o[5+3]or 1,o[7])
end
end
s.screenCalls=s.screenCalls+1
log[i]=nil
end
s.fg,s.bg=fg or s.fg,bg or s.bg
else
g.bitblt(0,s.ox,s.oy,s.bw,s.bh,s.buf,1,1)
s.screenCalls=s.screenCalls+1
for i=1,s.ln do s.log[i]=nil end
end
s.ln,s.cost,s.stale=0,0,false
s.lfg,s.lbg=nil,nil
end
function Log.close(s)
if s.buf then
s.gpu.setActiveBuffer(0)
pcall(s.gpu.freeBuffer,s.buf)
s.buf=nil
end
if s.was then
pcall(s.gpu.setBackground,table.unpack(s.was.bg))
pcall(s.gpu.setForeground,table.unpack(s.was.fg))
s.fg,s.bg,s.was=nil,nil,nil
end
end
local T={}
T.__index=T
function gfx.surface(gpu,o)
o=o or{}
local sw,sh=gpu.getResolution()
local s=setmetatable({},T)
logInit(s,gpu,o.x or 1,o.y or 1,o.w or sw,o.h or sh,o.palette and true or false)
s.w,s.h=s.bw,s.bh
return s
end
local function direct(s)return not s.buf end
function T:set(x,y,str,fg,bg,vertical)
fg,bg=fg or self.fg or 0xFFFFFF,bg or self.bg or 0
target(self)
colors(self,fg,bg)
if direct(self)then
self.gpu.set(self.ox+x-1,self.oy+y-1,str,vertical)
else
self.gpu.set(x,y,str,vertical)
if vertical then self.stale=true else logOp(self,"s",x,y,str,fg,bg)end
end
self.calls=self.calls+1
end
function T:fill(x,y,w,h,ch,fg,bg)
if w<=0 or h<=0 then return end
fg,bg=fg or self.fg or 0xFFFFFF,bg or self.bg or 0
ch=ch or" "
target(self)
colors(self,fg,bg)
if direct(self)then
self.gpu.fill(self.ox+x-1,self.oy+y-1,w,h,ch)
else
self.gpu.fill(x,y,w,h,ch)
local n=self.ln
logOp(self,"f",x,y,w,fg,bg,ch)
self.log[n+1][8]=h
end
self.calls=self.calls+1
end
function T:copy(x,y,w,h,tx,ty)
target(self)
if direct(self)then
self.gpu.copy(self.ox+x-1,self.oy+y-1,w,h,tx,ty)
else
self.gpu.copy(x,y,w,h,tx,ty)
logOp(self,"c",x,y,w,h,tx,ty)
end
self.calls=self.calls+1
end
function T:get(x,y)
target(self)
if direct(self)then return self.gpu.get(self.ox+x-1,self.oy+y-1)end
return self.gpu.get(x,y)
end
function T:sync()
if self.buf then
self.gpu.bitblt(self.buf,1,1,self.bw,self.bh,0,self.ox,self.oy)
self.fg,self.bg=nil,nil
end
end
function T:release()
if self.buf then self.gpu.setActiveBuffer(0)end
end
T.present=Log.present
T.close=Log.close
local S={}
S.__index=S
function gfx.new(gpu,w,h,o)
o=o or{}
local mw,mh=gpu.maxResolution()
local ox,oy=o.x or 1,o.y or 1
w=min(w or mw,mw-ox+1)
h=min(h or mh,mh-oy+1)
if not o.keepResolution and ox==1 and oy==1 then
local cw,ch=gpu.getResolution()
if cw~=w or ch~=h then gpu.setResolution(w,h)end
end
local s=setmetatable({
w=w,h=h,pw=w,ph=h*2,
fb={},shown={},saved={},top=1,
sp={},bl={},
dr={},dn=0,rmin={},rmax={},rlist={},
rgb=o.rgb and true or false,
},S)
logInit(s,gpu,ox,oy,w,h,not s.rgb)
s.mul=s.rgb and 16777216 or 16
local bgc=o.background or 0
for i=1,s.pw*s.ph do s.fb[i]=bgc end
for i=1,w*h do s.shown[i]=-1 end
return s
end
function S:palette(pal)
local g=self.gpu
for i=0,15 do
local c=pal[i]
if c then
local ok,cur=pcall(g.getPaletteColor,i)
if not ok or cur~=c then pcall(g.setPaletteColor,i,c)end
end
end
self.fg,self.bg=nil,nil
end
function S:reserveTop(rows)self.top=rows+1 end
function S:touch(x,y,w,h)
local x2,y2=x+w-1,y+h-1
local ytop=(self.top-1)*2+1
if x<1 then x=1 end
if y<ytop then y=ytop end
if x2>self.pw then x2=self.pw end
if y2>self.ph then y2=self.ph end
if x2<x or y2<y then return end
local n,dr=self.dn,self.dr
dr[n+1],dr[n+2],dr[n+3],dr[n+4]=x,y,x2,y2
self.dn=n+4
end
function S:clear(c)
local fb=self.fb
for i=1,self.pw*self.ph do fb[i]=c end
self.dn=0
self:touch(1,1,self.pw,self.ph)
end
function S:rect(x,y,w,h,c)
local fb,pw,ph=self.fb,self.pw,self.ph
if x<1 then w=w+x-1 x=1 end
if y<1 then h=h+y-1 y=1 end
if x+w-1>pw then w=pw-x+1 end
if y+h-1>ph then h=ph-y+1 end
if w<=0 or h<=0 then return end
self:touch(x,y,w,h)
for yy=y,y+h-1 do
local o=(yy-1)*pw
for xx=x,x+w-1 do fb[o+xx]=c end
end
end
function S:pixel(x,y,c)
if x>=1 and y>=1 and x<=self.pw and y<=self.ph then
self.fb[(y-1)*self.pw+x]=c
self:touch(x,y,1,1)
end
end
function S:tile(x,y,a)
local fb,pw,ph=self.fb,self.pw,self.ph
local aw=a.w
self:touch(x,y,aw,a.h)
for ay=0,a.h-1 do
local yy=y+ay
if yy>=1 and yy<=ph then
local o,ao=(yy-1)*pw,ay*aw
for ax=1,aw do
local xx=x+ax-1
if xx>=1 and xx<=pw then
local c=a[ao+ax]
if c then fb[o+xx]=c end
end
end
end
end
end
S.blit=S.tile
function S:stamp(x,y,a)
local fb,pw,ph=self.fb,self.pw,self.ph
local x0,y0=max(1,x),max(1,y)
local x1,y1=min(pw,x+a.w-1),min(ph,y+a.h-1)
if x1<x0 or y1<y0 then return end
local box={x=x0,y=y0,w=x1-x0+1,h=y1-y0+1}
local k=0
for yy=y0,y1 do
local o=(yy-1)*pw
for xx=x0,x1 do k=k+1 box[k]=fb[o+xx]end
end
self.saved[#self.saved+1]=box
self:tile(x,y,a)
end
function S:restore()
local fb,pw,saved=self.fb,self.pw,self.saved
for i=#saved,1,-1 do
local b=saved[i]
self:touch(b.x,b.y,b.w,b.h)
local k=0
for yy=b.y,b.y+b.h-1 do
local o=(yy-1)*pw
for xx=b.x,b.x+b.w-1 do k=k+1 fb[o+xx]=b[k]end
end
saved[i]=nil
end
end
function S:scroll(dx)
if dx==0 then return end
local pw,ph,w,h=self.pw,self.ph,self.w,self.h
local fb,sh=self.fb,self.shown
local y0=(self.top-1)*2
local rows=h-self.top+1
if math.abs(dx)>=pw then
for i=(self.top-1)*w+1,w*h do sh[i]=-1 end
return
end
for y=y0,ph-1 do
local o=y*pw
if dx>0 then move(fb,o+1+dx,o+pw,o+1)
else move(fb,o+1,o+pw+dx,o+1-dx)end
end
for row=self.top-1,h-1 do
local o=row*w
if dx>0 then
move(sh,o+1+dx,o+w,o+1)
for i=o+w-dx+1,o+w do sh[i]=-1 end
else
move(sh,o+1,o+w+dx,o+1-dx)
for i=o+1,o-dx do sh[i]=-1 end
end
end
local dr=self.dr
for i=1,self.dn,4 do dr[i],dr[i+2]=dr[i]-dx,dr[i+2]-dx end
if dx>0 then self:touch(pw-dx+1,1,dx,ph)else self:touch(1,1,-dx,ph)end
local g=self.gpu
if self.buf then
g.setActiveBuffer(self.buf)
if dx>0 then g.bitblt(self.buf,1,self.top,w-dx,rows,self.buf,1+dx,self.top)
else g.bitblt(self.buf,1-dx,self.top,w+dx,rows,self.buf,1,self.top)end
logOp(self,"c",1,self.top,w,rows,-dx,0)
self.calls=self.calls+2
else
g.copy(self.ox,self.oy+self.top-1,w,rows,-dx,0)
self.screenCalls=self.screenCalls+1
end
end
function S:setfg(c)
if c~=self.fg then self.gpu.setForeground(c,not self.rgb)self.fg=c self.calls=self.calls+1 end
end
function S:setbg(c)
if c~=self.bg then self.gpu.setBackground(c,not self.rgb)self.bg=c self.calls=self.calls+1 end
end
local function run(self,n,ch)
local cache=ch==" "and self.sp or self.bl
local s=cache[n]
if not s then s=rep(ch,n)cache[n]=s end
return s
end
function S:text(x,row,str,fg,bg)
local g=self.gpu
fg,bg=fg or(self.rgb and 0xFFFFFF or 15),bg or 0
target(self)
self:setbg(bg)
self:setfg(fg)
if self.buf then
g.set(x,row,str)
logOp(self,"s",x,row,str,fg,bg)
else
g.set(self.ox+x-1,self.oy+row-1,str)
self.screenCalls=self.screenCalls+1
end
self.calls=self.calls+1
if row>=self.top then
local o=(row-1)*self.w
for i=x,min(self.w,x+#str-1)do self.shown[o+i]=-1 end
self:touch(x,row*2-1,#str,2)
end
end
local function scan(self,row1,row2,col1,col2)
local g,fb,sh,mul=self.gpu,self.fb,self.shown,self.mul
local w=self.w
if row1<self.top then row1=self.top end
if row2>self.h then row2=self.h end
if col1<1 then col1=1 end
if col2>w then col2=w end
local buffered=self.buf~=nil
local dx,dy=0,0
if not buffered then dx,dy=self.ox-1,self.oy-1 end
for row=row1,row2 do
local o1=(row*2-2)*w
local o2=o1+w
local c0=(row-1)*w
local x=col1
while x<=col2 do
local t,b=fb[o1+x],fb[o2+x]
local cur=t*mul+b
if cur==sh[c0+x]then
x=x+1
else
local n=1
while x+n<=col2 and fb[o1+x+n]==t and fb[o2+x+n]==b do n=n+1 end
local str
if t==b then
self:setbg(t)
str=run(self,n," ")
g.set(x+dx,row+dy,str)
if buffered then logOp(self,"s",x,row,str,self.fg or t,t)end
else
self:setbg(t)
self:setfg(b)
str=run(self,n,BLOCK)
g.set(x+dx,row+dy,str)
if buffered then logOp(self,"s",x,row,str,b,t)end
end
self.calls=self.calls+1
if not buffered then self.screenCalls=self.screenCalls+1 end
for k=0,n-1 do sh[c0+x+k]=cur end
x=x+n
end
end
end
end
function S:present(force)
Log.present(self,force)
end
function S:flush(hold)
local dn,dr=self.dn,self.dr
if dn==0 then
if not hold then self:present()end
return
end
target(self)
local area=0
for i=1,dn,4 do
area=area+(dr[i+2]-dr[i]+1)*(dr[i+3]-dr[i+1]+1)
end
if self.fullScan or area*2>self.pw*self.ph or dn>320 then
scan(self,self.top,self.h,1,self.w)
else
local rmin,rmax,rlist=self.rmin,self.rmax,self.rlist
local n=0
for i=1,dn,4 do
local x1,x2=dr[i],dr[i+2]
for r=floor((dr[i+1]+1)/2),floor((dr[i+3]+1)/2)do
local lo=rmin[r]
if lo==nil then
n=n+1
rlist[n]=r
rmin[r],rmax[r]=x1,x2
else
if x1<lo then rmin[r]=x1 end
if x2>rmax[r]then rmax[r]=x2 end
end
end
end
for k=1,n do
local r=rlist[k]
scan(self,r,r,rmin[r],rmax[r])
rmin[r]=nil
end
end
self.dn=0
if not hold then self:present()end
end
S.close=Log.close
function gfx.savePalette(gpu)
local p={}
for i=0,15 do
local ok,v=pcall(gpu.getPaletteColor,i)
p[i]=ok and v or nil
end
return p
end
function gfx.restorePalette(gpu,p)
for i=0,15 do
if p[i]then
local ok,cur=pcall(gpu.getPaletteColor,i)
if not ok or cur~=p[i]then pcall(gpu.setPaletteColor,i,p[i])end
end
end
end
function gfx.mix(a,b,t)
local function ch(c,s)return floor(c/s)%256 end
local r=floor(ch(a,65536)+(ch(b,65536)-ch(a,65536))*t+0.5)
local g=floor(ch(a,256)+(ch(b,256)-ch(a,256))*t+0.5)
local bl=floor(ch(a,1)+(ch(b,1)-ch(a,1))*t+0.5)
return r*65536+g*256+bl
end
return gfx
