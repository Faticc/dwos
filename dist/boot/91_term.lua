local event=require("event")
local keyboard=require("keyboard")
event.listen("component_available",function(_,componentType)
local component=require("component")
local tty=require("tty")
if(componentType=="screen"and component.isAvailable("gpu"))or
(componentType=="gpu"and component.isAvailable("screen"))then
local gpu,screen=component.gpu,component.screen
local screen_address=screen.address
if gpu.getScreen()~=screen_address then
gpu.bind(screen_address)
end
local depth=math.floor(2^(gpu.getDepth()))
os.setenv("TERM","term-"..depth.."color")
event.push("gpu_bound",gpu.address,screen_address)
if tty.gpu()~=gpu then
tty.bind(gpu)
event.push("term_available")
end
end
end)
local function onKeyChange(ev,_,char,code)
keyboard.pressedChars[char]=ev=="key_down"or nil
keyboard.pressedCodes[code]=ev=="key_down"or nil
end
event.listen("key_down",onKeyChange)
event.listen("key_up",onKeyChange)
local function components_changed(ename,address,ctype)
local window=require("tty").window
if not window then
return
end
if ename=="component_available"or ename=="component_unavailable"then
ctype=address
end
if ename=="component_removed"or ename=="component_unavailable"then
if ctype=="gpu"and window.gpu.address==address then
window.gpu=nil
window.keyboard=nil
elseif ctype=="keyboard"then
window.keyboard=nil
end
if(ctype=="screen"or ctype=="gpu")and not require("tty").isAvailable()then
event.push("term_unavailable")
end
elseif(ename=="component_added"or ename=="component_available")and ctype=="keyboard"then
window.keyboard=nil
end
end
event.listen("component_removed",components_changed)
event.listen("component_added",components_changed)
event.listen("component_available",components_changed)
event.listen("component_unavailable",components_changed)
