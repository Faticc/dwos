local a={}
local function c(b)return b&0xFFFFFFFF end
local function e(b)return~(0xFFFFFFFF<<b)end
local function b(f,g,...)
local d=f
for f=1,select("#",...)do
d=g(d,(select(f,...)))
end
return d
end
function a.arshift(d,f)return d//(2^f)end
function a.band(...)return b(0xFFFFFFFF,function(d,f)return d&f end,...)end
function a.bnot(d)return~d end
function a.bor(...)return b(0,function(d,f)return d|f end,...)end
function a.btest(...)return a.band(...)~=0 end
function a.bxor(...)return b(0,function(b,d)return b~d end,...)end
local function f(d,b)
b=b or 1
assert(d>=0,"field cannot be negative")
assert(b>0,"width must be positive")
assert(d+b<=32,"trying to access non-existent bits")
return d,b
end
function a.extract(b,d,g)
local h,i=f(d,g)
return(b>>h)&e(i)
end
function a.replace(g,h,d,i)
local b,j=f(d,i)
local d=e(j)
return(g&~(d<<b))|((h&d)<<b)
end
function a.lrotate(d,b)
if b==0 then return d end
if b<0 then return a.rrotate(d,-b)end
b=b&31
d=c(d)
return c((d<<b)|(d>>(32-b)))
end
function a.rrotate(d,b)
if b==0 then return d end
if b<0 then return a.lrotate(d,-b)end
b=b&31
d=c(d)
return c((d>>b)|(d<<(32-b)))
end
function a.lshift(b,d)return c(b<<d)end
function a.rshift(b,d)return c(b>>d)end
return a
