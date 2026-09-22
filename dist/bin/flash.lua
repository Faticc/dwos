local e=require("component")
local f=require("shell")
local h=require("filesystem")
local d,a=f.parse(...)
if#d<1 and not a.l then
io.write("Usage: flash [-qlr] [<bios.lua>] [label]\n")
io.write(" q: quiet mode, don't ask questions.\n")
io.write(" l: print current contents of installed EEPROM.\n")
io.write(" r: save the current contents of installed EEPROM to file.\n")
return
end
local function g()
repeat
local b=io.read()
until b and b:lower():sub(1,1)=="y"
end
local b=e.eeprom
if a.l then
io.write(b.get())
elseif a.r then
local c=f.resolve(d[1])
if not a.q then
if h.exists(c)then
io.write("Are you sure you want to overwrite "..c.."?\nType `y` to confirm.\n")
g()
end
io.write("Reading EEPROM "..b.address..".\n")
end
local f=assert(io.open(c,"wb"))
f:write(b.get())
f:close()
if not a.q then
io.write("All done!\nThe label is '"..b.getLabel().."'.\n")
end
else
local c=assert(io.open(d[1],"rb"))
local f=c:read("*a")
c:close()
if not a.q then
io.write("Insert the EEPROM you would like to flash.\nWhen ready to write, type `y` to confirm.\n")
g()
io.write("Beginning to flash EEPROM.\n")
end
b=e.eeprom
if not a.q then
io.write("Flashing EEPROM "..b.address..".\n")
io.write("Please do NOT power down or restart your computer during this operation!\n")
end
b.set(f)
local c=d[2]
if not a.q and not c then
io.write("Enter new label for this EEPROM. Leave input blank to leave the label unchanged.\n")
c=io.read()
end
if c and#c>0 then
b.setLabel(c)
if not a.q then
io.write("Set label to '"..b.getLabel().."'.\n")
end
end
if not a.q then
io.write("All done! You can remove the EEPROM and re-insert the previous one now.\n")
end
end
