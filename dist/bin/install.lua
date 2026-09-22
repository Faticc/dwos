local g=require("computer")
local d=require("filesystem")
local b
do
local a,c=loadfile("/lib/core/install_basics.lua","bt",_G)
if not a then
io.stderr:write("failed to load install: "..tostring(c).."\n")
return 1
end
b=a(...)
end
if not b then return end
local a,h,e,f=b.options,b.sources,b.targets,b.label
local m,n=a.from,a.to
local k=io.stdin.tty and io.stdout.tty and not a.text
local b
do
local c,i=loadfile("/lib/core/install_ui.lua","bt",_G)
if not c then
io.stderr:write("failed to load install ui: "..tostring(i).."\n")
return 1
end
b=c(k)
end
local function j(c)
b.close()
os.exit(c)
end
local c=h[1]
if#h~=1 then
c=b.select("sources",h,a)
end
if not c then j()end
a={
from=c.path.."/",
fromDir=d.canonical(a.fromDir or c.prop.fromDir or""),
root=d.canonical(a.root or a.toDir or c.prop.root or""),
update=a.update or a.u,
label=c.prop.label or f,
setlabel=not(a.nosetlabel or a.nolabelset)and c.prop.setlabel,
setboot=not(a.nosetboot or a.noboot)and c.prop.setboot,
reboot=not a.noreboot and c.prop.reboot,
}
local i=a.label or c.dev.getLabel()or c.path
local f=e[1]
for l,o in ipairs(e)do
if o.dev==c.dev then
table.remove(e,l)
f=e[1]
break
end
end
if#e~=1 then
if#h==1 then
b.note(i.." selected for install")
end
f=b.select("targets",e,a)
end
if not f then j()end
a.to=f.path.."/"
local function l(h)
return d.concat(a.from,a.fromDir).."/"..h
end
local h=d.concat(a.to,a.root)
local j={
{
{l("."),h},
{
cmd="cp",
r=true,v=not k,x=true,u=a.update,i=a.update,
skip={l(".prop")},
},
},
}
if c.prop.noclobber and#c.prop.noclobber>0 then
local o={cmd="cp",v=not k,n=true}
for k,k in ipairs(c.prop.noclobber)do
local c=l(k)
table.insert(j[1][2].skip,c)
table.insert(j,{{c,d.concat(h,k)},o})
end
end
local k=""
if#e>1 or n or m then
k=" to "..j[1][1][2]
end
local c
if b.graphic then
b.note(i.."  →  "..h)
c=b.ask("Установить "..i.." на "..h.."?")
else
c=b.ask("Install "..i..k.."?")
end
if not c then
b.close()
io.write("Installation cancelled\n")
os.exit()
end
local c=a.from.."/.install"
if d.exists(c)then
b.close()
local e,h=loadfile(c,"bt",setmetatable({install=a},{__index=_G}))
if not e then
io.stderr:write("installer failed to load: "..tostring(h).."\n")
os.exit(1)
end
os.exit(e())
end
if g.freeMemory()<50000 then
if not b.graphic then print("Low memory, collecting garbage")end
for c=1,20 do os.sleep(0)end
end
local c=require("tools/transfer")
if b.graphic then
b.progress(0)
local l=d.concat(a.from,a.fromDir)
local e=0
local function h(i)
for k in d.list(i)do
local m=d.concat(i,k)
if k:sub(-1)=="/"then h(m)else e=e+1 end
end
end
local d=pcall(h,l)
b.progress(d and e or 0)
c.onFile=b.step
end
local d
for e,h in ipairs(j)do
local e=c.batch(table.unpack(h))
if e~=nil and e~=0 then
d=e
break
end
end
c.onFile=nil
if d then
b.close()
return d
end
local c={"Installation complete!"}
if a.setlabel then
pcall(f.dev.setLabel,a.label)
end
if a.setboot then
local d=f.dev.address
if g.setBootAddress(d)then
c[#c+1]="Boot address set to "..d
end
end
if b.graphic then
b.note(table.concat(c,"  ·  "))
if a.reboot then
if b.ask("Установка завершена. Перезагрузить компьютер сейчас?")then
b.close()
print("\nRebooting now!\n")
g.shutdown(true)
end
else
b.finish(table.concat(c,"\n"))
b.pause()
end
b.close()
return
end
for d,d in ipairs(c)do print(d)end
if a.reboot and b.ask("Reboot now?")then
print("\nRebooting now!\n")
g.shutdown(true)
end
print("Returning to shell.\n")
