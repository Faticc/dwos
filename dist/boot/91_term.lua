local a=require("event")
local d=require("keyboard")
a.listen("component_available",function(b,b)
local c=require("component")
local e=require("tty")
if(b=="screen"and c.isAvailable("gpu"))or
(b=="gpu"and c.isAvailable("screen"))then
local b,f=c.gpu,c.screen
local c=f.address
if b.getScreen()~=c then
b.bind(c)
end
local f=math.floor(2^(b.getDepth()))
os.setenv("TERM","term-"..f.."color")
a.push("gpu_bound",b.address,c)
if e.gpu()~=b then
e.bind(b)
a.push("term_available")
end
end
end)
local function b(c,e,e,f)
d.pressedChars[e]=c=="key_down"or nil
d.pressedCodes[f]=c=="key_down"or nil
end
a.listen("key_down",b)
a.listen("key_up",b)
local function e(b,f,c)
local d=require("tty").window
if not d then
return
end
if b=="component_available"or b=="component_unavailable"then
c=f
end
if b=="component_removed"or b=="component_unavailable"then
if c=="gpu"and d.gpu.address==f then
d.gpu=nil
d.keyboard=nil
elseif c=="keyboard"then
d.keyboard=nil
end
if(c=="screen"or c=="gpu")and not require("tty").isAvailable()then
a.push("term_unavailable")
end
elseif(b=="component_added"or b=="component_available")and c=="keyboard"then
d.keyboard=nil
end
end
a.listen("component_removed",e)
a.listen("component_added",e)
a.listen("component_available",e)
a.listen("component_unavailable",e)
