local event=require("event")
local tty=require("tty")
local args={...}
local gpu=tty.gpu()
local interactive=io.output().tty
local color,isPal
if interactive then
color,isPal=gpu.getForeground()
end
io.write("Press 'Ctrl-C' to exit\n")
pcall(function()
local evt
repeat
if#args>0 then
evt=table.pack(event.pullMultiple("interrupted",table.unpack(args)))
else
evt=table.pack(event.pull())
end
local name,addr=tostring(evt[1]),tostring(evt[2])
if interactive then gpu.setForeground(0xCC2200)end
io.write("["..os.date("%T").."] ")
if interactive then gpu.setForeground(0x44CC00)end
io.write(name..string.rep(" ",math.max(10-#name,0)+1))
if interactive then gpu.setForeground(0xB0B00F)end
io.write(addr..string.rep(" ",37-#addr))
if interactive then gpu.setForeground(0xFFFFFF)end
for i=3,evt.n do
io.write("  "..tostring(evt[i]))
end
io.write("\n")
until evt[1]=="interrupted"
end)
if interactive then
gpu.setForeground(color,isPal)
end
