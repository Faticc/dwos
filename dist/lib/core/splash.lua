local j=...
local h,r,s,t,k=0x0A0E14,0x1C2733,0x3FB8FF,0x8FA3B8,0x3C4A5A
local u,v,w=0x5CE1FF,0x2F6BFF,0x06090D
local x={
D={"####.","#...#","#...#","#...#","#...#","#...#","####."},
w={".....",".....","#...#","#...#","#.#.#","#.#.#",".#.#."},
O={".###.","#...#","#...#","#...#","#...#","#...#",".###."},
S={".####","#....","#....",".###.","....#","....#","####."},
}
local a={"D","w","O","S"}
local c={}
c.__index=c
function c.start(i)
local l,g=i.getResolution()
local d=j.new(i,l,g,{rgb=true,keepResolution=true,background=h})
local e,p=d.pw,d.ph
local b=e>=150 and 3 or e>=80 and 2 or 1
local m,n=5*b,(b>1 and b or 1)+1
local f=#a*m+(#a-1)*n
local o=7*b
local y=math.floor((e-f)/2)+1
local f=math.max(1,math.floor(p/2-o)-b*2)
if f%2==0 then f=f+1 end
d:clear(h)
for p=1,2 do
local q=p==1 and 1 or 0
for z,A in ipairs(a)do
local B=x[A]
local x=y+(z-1)*(m+n)+q
for a=1,7 do
local m=B[a]
local n=p==1 and w or j.mix(u,v,(a-1)/6)
for j=1,5 do
if m:sub(j,j)=="#"then
d:rect(x+(j-1)*b,f+(a-1)*b+q,b,b,n)
end
end
end
end
end
local a=setmetatable({cv=d,gpu=i,w=l,h=g},c)
a.barW=math.max(10,math.floor(e*(e>=80 and 0.4 or 0.6)))
a.barX=math.floor((e-a.barW)/2)+1
a.barY=f+o+b*4
if a.barY%2==0 then a.barY=a.barY+1 end
a.textRow=math.min(g,(a.barY+1)/2+2)
a.filled=0
d:rect(a.barX,a.barY,a.barW,2,r)
d:flush(true)
a:text(g,_OSVERSION or"",k)
d:present()
return a
end
function c:text(e,a,f)
local b=self.w
a=tostring(a)
if#a>b-2 then a=a:sub(1,b-5).."..."end
local d=math.floor((b-#a)/2)
self.cv:text(1,e,(" "):rep(d)..a..(" "):rep(b-d-#a),f,h)
end
function c:status(d,e)
local a=self.cv
if e then
local b=math.floor(self.barW*math.max(0,math.min(1,e))+0.5)
if b>self.filled then
a:rect(self.barX+self.filled,self.barY,b-self.filled,2,s)
self.filled=b
end
end
a:flush(true)
if d then self.msg=d end
if self.msg then self:text(self.textRow,self.msg,t)end
self:text(self.h,_OSVERSION or"",k)
a:present()
end
function c:finish()
self:status(nil,1)
self.cv:close()
local a=self.gpu
a.setBackground(0x000000)
a.setForeground(0xFFFFFF)
end
return c
