local gfx=...
local BG,BAR_BG,BAR,TEXT,DIM=0x0A0E14,0x1C2733,0x3FB8FF,0x8FA3B8,0x3C4A5A
local TOP_C,BOT_C,SHADOW=0x5CE1FF,0x2F6BFF,0x06090D
local GLYPHS={
D={"####.","#...#","#...#","#...#","#...#","#...#","####."},
w={".....",".....","#...#","#...#","#.#.#","#.#.#",".#.#."},
O={".###.","#...#","#...#","#...#","#...#","#...#",".###."},
S={".####","#....","#....",".###.","....#","....#","####."},
}
local WORD={"D","w","O","S"}
local splash={}
splash.__index=splash
function splash.start(gpu)
local w,h=gpu.getResolution()
local cv=gfx.new(gpu,w,h,{rgb=true,keepResolution=true,background=BG})
local pw,ph=cv.pw,cv.ph
local scale=pw>=150 and 3 or pw>=80 and 2 or 1
local gw,gap=5*scale,(scale>1 and scale or 1)+1
local lw=#WORD*gw+(#WORD-1)*gap
local lh=7*scale
local lx=math.floor((pw-lw)/2)+1
local ly=math.max(1,math.floor(ph/2-lh)-scale*2)
if ly%2==0 then ly=ly+1 end
cv:clear(BG)
for pass=1,2 do
local off=pass==1 and 1 or 0
for i,ch in ipairs(WORD)do
local rows=GLYPHS[ch]
local gx=lx+(i-1)*(gw+gap)+off
for r=1,7 do
local line=rows[r]
local c=pass==1 and SHADOW or gfx.mix(TOP_C,BOT_C,(r-1)/6)
for col=1,5 do
if line:sub(col,col)=="#"then
cv:rect(gx+(col-1)*scale,ly+(r-1)*scale+off,scale,scale,c)
end
end
end
end
end
local s=setmetatable({cv=cv,gpu=gpu,w=w,h=h},splash)
s.barW=math.max(10,math.floor(pw*(pw>=80 and 0.4 or 0.6)))
s.barX=math.floor((pw-s.barW)/2)+1
s.barY=ly+lh+scale*4
if s.barY%2==0 then s.barY=s.barY+1 end
s.textRow=math.min(h,(s.barY+1)/2+2)
s.filled=0
cv:rect(s.barX,s.barY,s.barW,2,BAR_BG)
cv:flush(true)
s:text(h,_OSVERSION or"",DIM)
cv:present()
return s
end
function splash:text(row,msg,color)
local w=self.w
msg=tostring(msg)
if#msg>w-2 then msg=msg:sub(1,w-5).."..."end
local left=math.floor((w-#msg)/2)
self.cv:text(1,row,(" "):rep(left)..msg..(" "):rep(w-left-#msg),color,BG)
end
function splash:status(msg,frac)
local cv=self.cv
if frac then
local n=math.floor(self.barW*math.max(0,math.min(1,frac))+0.5)
if n>self.filled then
cv:rect(self.barX+self.filled,self.barY,n-self.filled,2,BAR)
self.filled=n
end
end
cv:flush(true)
if msg then self.msg=msg end
if self.msg then self:text(self.textRow,self.msg,TEXT)end
self:text(self.h,_OSVERSION or"",DIM)
cv:present()
end
function splash:finish()
self:status(nil,1)
self.cv:close()
local gpu=self.gpu
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
end
return splash
