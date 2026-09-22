local e=require("unicode")
local m=require("keyboard")
local g=require("tty")
local o=require("text")
local p=require("computer")
local b=m.keys
local f={}
f.vertical={}
local h=f.vertical
function h:move(c)
local a=math.max(math.min(self.index+c,self.len),0)
if a==self.index then return end
local d,i,c=b.left,a+1,self.index
if a>self.index then
d,i,c=b.right,c+1,a
end
self.index=a
self:echo(d,e.wlen(e.sub(self.data,i,c)))
end
function h:update(a,i)
if not a then
self.tails={}
self.data=""
self.index=0
self.sy=0
self.hindex=0
end
local d=e.sub(self.data,1,self.index)
local c=e.sub(self.data,self.index+1)
if type(a)=="string"then
if i==false then
a,c=a..c,""
else
self.index=self.index+e.len(a)
self:echo(a)
end
self.data=d ..a
elseif a then
local j=a<0 or#c>0
if a<0 then
if self.index<=0 then return end
self:move(a)
d=e.sub(d,1,-1+a)
else
if self.index>=self.len then return end
c=e.sub(c,1+a)
end
self.data=d
if j then
self:echo(self.clear)
end
end
self.len=e.len(self.data)
self:move(i or 0)
if#c>0 then
self:update(c,-e.len(c))
end
end
function h:echo(d,n)
local a=g.window
local i=a.gpu
if not io.stdin.tty then
return
end
local j=io.stdin.stream
if not i then return end
a.nowrap=self.nowrap
if d==""then
local l,c,k=a.width,a.x,a.y
if c>l then
a.x=((c-1)%l)+1
a.y=k+math.floor(c/l)
j:write("")
c,k=a.x,a.y
end
if c<=0 or k<=0 or k>a.height or not i then return end
return table.pack(select(2,pcall(i.get,c+a.dx,k+a.dy)))
elseif d==b.left then
local c,k=a.x-n,a.y
while c<1 do
c=c+a.width-#(self.tails[a.dy+k-self.sy-1]or"")
k=k-1
end
a.x,a.y=c,k
d=""
elseif d==b.right then
local c,k=a.x+n,a.y
while true do
local l=a.width-#(self.tails[a.dy+k-self.sy]or"")
if c<=l then break end
c=c-l
k=k+1
end
a.x,a.y=c,k
d=""
elseif not d or d==true then
local c=self.char_at_cursor
if(d==nil and not c)or(d and not self.blinked)then
c=c or self:echo("")
if not c[1]then return false end
self.blinked=true
if not d then
j:write("\0277")
c.saved=a.saved
i.setForeground(c[4]or c[2],not not c[4])
i.setBackground(c[5]or c[3],not not c[5])
end
j:write("\0277\27[7m"..c[1].."\0278")
elseif(d and self.blinked)or(d==false and c)then
self.blinked=false
i.set(a.x+a.dx,a.y+a.dy,c[1])
if not d then
a.saved=c.saved
j:write("\0278")
c=nil
end
end
self.char_at_cursor=c
return true
end
return j:write(d)
end
function h:handle(d,c,a)
if d=="clipboard"then
self.cache=nil
local i=c:find("\10")or#c
self:update(c:sub(1,i))
self:update(c:sub(i+1),false)
elseif d=="touch"or d=="drag"then
f.touch(self,c,a)
elseif d=="interrupted"then
self:echo("^C\n")
return false,d
elseif d=="key_down"then
local j=self.data
local k=self.cache
self.cache=nil
local d=m.isControlDown()
if d and a==b.d then
return
elseif a==b.tab then
self.cache=k
f.tab(self)
elseif a==b.enter or a==b.numpadenter then
self:move(self.len)
self:update("\n")
elseif a==b.up or a==b.down then
local i=self.hindex+(a==b.up and 1 or-1)
if i>=0 and i<=#self then
self[self.hindex]=j
self.hindex=i
self:move(self.len)
self:update(-self.len)
self:update(self[i])
end
elseif a==b.left or a==b.back or a==b.w and d then
local i=d and((e.sub(j,1,self.index):find("%s[^%s]+%s*$")or 0)-self.index)or-1
if a==b.left then
self:move(i)
else
self:update(i)
end
elseif a==b.right then
self:move(d and((j:find("%s[^%s]",self.index+1)or self.len)-self.index)or 1)
elseif a==b.home then self:move(-self.len)
elseif a==b["end"]then self:move(self.len)
elseif a==b.delete then self:update(1)
elseif c>=32 then self:update(e.char(c))
else self.cache=k
end
end
return true
end
h.clear="\27[J"
function f.new(a,b)
a=a or{}
a.super=a.super or b or h
setmetatable(a,getmetatable(a)or{__index=a.super})
if not a.data then
a:update()
end
return a
end
function f.read(a)
local b=a.next or""
a.next=nil
if#b>0 then
a:handle("clipboard",b)
end
local e={
key_down=g.keyboard,
clipboard=g.keyboard,
touch=g.screen,
drag=g.screen,
drop=g.screen,
}
while true do
local b=a.data:find("\10")
if b then
local c=a.data:sub(1,b)
local d=a.data:sub(b+1)
local b=o.trim(c)
if b~=""and b~=a[1]then
table.insert(a,1,b)
a[(tonumber(os.getenv("HISTSIZE"))or 10)+1]=nil
end
a[0]=nil
a:update()
a.next=d
return c
end
a:echo()
local b=table.pack(p.pullSignal(g.window.blink and.5 or math.huge))
local c=b[1]
a:echo(not c)
if c then
local d=e[c]
if not d or d()==b[2]then
local d,e=a:handle(c,table.unpack(b,3,b.n))
if not d then
return d,e
end
end
end
end
end
require("package").delay(f,"/lib/core/full_cursor.lua")
return f
