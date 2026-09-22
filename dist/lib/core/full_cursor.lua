local d=require("core/cursor")
local b=require("unicode")
local h=require("keyboard")
local f=require("tty")
d.horizontal={}
local g=d.horizontal
function d.touch(c,i,j)
if c.len>0 then
local a=f.window
i,j=i-a.dx,j-a.dy
while true do
local k,l,m=a.x,a.y,a.width
local e=((j*m+i)-(l*m+k))
if e==1 then
e=b.wlen(b.sub(c.data,c.index+1,c.index+1))==2 and 0 or e
end
if e==0 then
break
end
c:move(e>0 and 1 or-1)
if k==a.x and l==a.y then
break
end
end
end
end
function d.tab(a)
local e=a.hint
if not e then return end
if not a.cache then
a.cache=type(e)=="table"and e or e(a.data,a.index+1)or{}
a.cache.i=-1
end
local c=a.cache
if#c==1 and c.i==0 then
a.cache=e(c[1],a.index+1)
if not a.cache then return end
a.cache.i=-1
c=a.cache
end
local e=h.isShiftDown()and-1 or 1
c.i=(c.i+e)%math.max(#c,1)
local e=c[c.i+1]
if e then
local c=b.len(a.data)-a.index
a:move(a.len)
a:update(-a.len)
a:update(e,-c)
end
end
function g:scroll(a,c)
self:move(self.vindex-self.index)
self.vindex=self.vindex+a
self.index=self.index+a
self:echo("\0277"..b.sub(self.data,self.index+1).."\27[K\0278")
self:move(c-self.index)
end
function g:echo(e,i)
local a=f.window
a.nowrap=self.nowrap
if e==""then
local c=a.width
if a.x>=c then
c=c-math.max(b.wlen(b.sub(self.data,self.index+1,self.index+1))-1,0)
if a.x>c then
local j=b.sub(self.data,self.vindex+1,self.index)
self:scroll(b.len(b.wtrunc(j,a.x-c+1)),self.index)
end
end
elseif e==h.keys.left then
if self.index<self.vindex then
local c=b.sub(self.data,self.index+1)
a.x=a.x-i+b.wlen(b.sub(c,1,self.vindex-self.index))
local b=a.x
self:echo(c)
a.x=b
self.vindex=self.index
return true
end
elseif e==h.keys.right then
a.x=a.x+i
return self:echo("")
end
return d.vertical.echo(self,e,i)
end
function g:update(a,b)
if b then
self:update(a,false)
local c=f.window.x
self:echo(a)
f.window.x=c
self:move(self.len-self.index+b)
return true
elseif not a then
self.nowrap=true
self.clear="\27[K"
self.vindex=0
end
return d.vertical.update(self,a,b)
end
setmetatable(g,{__index=d.vertical})
