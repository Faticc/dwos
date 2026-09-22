local d=require("event")
local a=require("tty")
local e={...}
local b=a.gpu()
local c=io.output().tty
local f,g
if c then
f,g=b.getForeground()
end
io.write("Press 'Ctrl-C' to exit\n")
pcall(function()
local a
repeat
if#e>0 then
a=table.pack(d.pullMultiple("interrupted",table.unpack(e)))
else
a=table.pack(d.pull())
end
local d,e=tostring(a[1]),tostring(a[2])
if c then b.setForeground(0xCC2200)end
io.write("["..os.date("%T").."] ")
if c then b.setForeground(0x44CC00)end
io.write(d..string.rep(" ",math.max(10-#d,0)+1))
if c then b.setForeground(0xB0B00F)end
io.write(e..string.rep(" ",37-#e))
if c then b.setForeground(0xFFFFFF)end
for d=3,a.n do
io.write("  "..tostring(a[d]))
end
io.write("\n")
until a[1]=="interrupted"
end)
if c then
b.setForeground(f,g)
end
