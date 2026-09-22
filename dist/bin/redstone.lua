local f=require("colors")
local b=require("component")
local c=require("shell")
local g=require("sides")
if not b.isAvailable("redstone")then
io.stderr:write("This program requires a redstone card or redstone I/O block.\n")
return 1
end
local a=b.redstone
local b,d=c.parse(...)
if#b==0 and not d.w and not d.f then
io.write("Usage:\n")
io.write("  redstone <side> [<value>]\n")
if a.setBundledOutput then
io.write("  redstone -b <side> <color> [<value>]\n")
end
if a.setWirelessOutput then
io.write("  redstone -w [<value>]\n")
io.write("  redstone -f [<frequency>]\n")
end
return
end
local e={["true"]=true,on=true,yes=true}
if d.w or d.f then
if not a.setWirelessOutput then
io.stderr:write("wireless redstone not available\n")
return 1
end
if d.w then
if#b>0 then
local c=b[1]
if tonumber(c)then
c=tonumber(c)>0
else
c=e[c]~=nil
end
a.setWirelessOutput(c)
end
io.write("in: "..tostring(a.getWirelessInput()).."\n")
io.write("out: "..tostring(a.getWirelessOutput()).."\n")
else
if#b>0 then
if not tonumber(b[1])then
io.stderr:write("invalid frequency\n")
return 1
end
a.setWirelessFrequency(tonumber(b[1]))
end
io.write("freq: "..tostring(a.getWirelessFrequency()).."\n")
end
return
end
local c=g[b[1]]
if not c then
io.stderr:write("invalid side\n")
return 1
end
if type(c)=="string"then
c=g[c]
end
if d.b then
if not a.setBundledOutput then
io.stderr:write("bundled redstone not available\n")
return 1
end
local d=f[b[2]]
if not d then
io.stderr:write("invalid color\n")
return 1
end
if type(d)=="string"then
d=f[d]
end
if#b>2 then
local f=tonumber(b[3])or(e[b[3]]and 255 or 0)
a.setBundledOutput(c,d,f)
end
io.write("in: "..a.getBundledInput(c,d).."\n")
io.write("out: "..a.getBundledOutput(c,d).."\n")
else
if#b>1 then
local d=tonumber(b[2])or(e[b[2]]and 15 or 0)
a.setOutput(c,d)
end
io.write("in: "..a.getInput(c).."\n")
io.write("out: "..a.getOutput(c).."\n")
end
