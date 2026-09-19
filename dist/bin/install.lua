local computer=require("computer")
local fs=require("filesystem")
local info
do
local basics,reason=loadfile("/lib/core/install_basics.lua","bt",_G)
if not basics then
io.stderr:write("failed to load install: "..tostring(reason).."\n")
return 1
end
info=basics(...)
end
if not info then return end
local options,sources,targets,label=info.options,info.sources,info.targets,info.label
local had_from,had_to=options.from,options.to
local graphic=io.stdin.tty and io.stdout.tty and not options.text
local ui
do
local load_ui,reason=loadfile("/lib/core/install_ui.lua","bt",_G)
if not load_ui then
io.stderr:write("failed to load install ui: "..tostring(reason).."\n")
return 1
end
ui=load_ui(graphic)
end
local function bail(code)
ui.close()
os.exit(code)
end
local source=sources[1]
if#sources~=1 then
source=ui.select("sources",sources,options)
end
if not source then bail()end
options={
from=source.path.."/",
fromDir=fs.canonical(options.fromDir or source.prop.fromDir or""),
root=fs.canonical(options.root or options.toDir or source.prop.root or""),
update=options.update or options.u,
label=source.prop.label or label,
setlabel=not(options.nosetlabel or options.nolabelset)and source.prop.setlabel,
setboot=not(options.nosetboot or options.noboot)and source.prop.setboot,
reboot=not options.noreboot and source.prop.reboot,
}
local source_display=options.label or source.dev.getLabel()or source.path
local target=targets[1]
for index,entry in ipairs(targets)do
if entry.dev==source.dev then
table.remove(targets,index)
target=targets[1]
break
end
end
if#targets~=1 then
if#sources==1 then
ui.note(source_display.." selected for install")
end
target=ui.select("targets",targets,options)
end
if not target then bail()end
options.to=target.path.."/"
local function resolveFrom(path)
return fs.concat(options.from,options.fromDir).."/"..path
end
local fullTargetPath=fs.concat(options.to,options.root)
local transfer_args={
{
{resolveFrom("."),fullTargetPath},
{
cmd="cp",
r=true,v=not graphic,x=true,u=options.update,i=options.update,
skip={resolveFrom(".prop")},
},
},
}
if source.prop.noclobber and#source.prop.noclobber>0 then
local keep={cmd="cp",v=not graphic,n=true}
for _,name in ipairs(source.prop.noclobber)do
local from=resolveFrom(name)
table.insert(transfer_args[1][2].skip,from)
table.insert(transfer_args,{{from,fs.concat(fullTargetPath,name)},keep})
end
end
local special_target=""
if#targets>1 or had_to or had_from then
special_target=" to "..transfer_args[1][1][2]
end
local agreed
if ui.graphic then
ui.note(source_display.."  →  "..fullTargetPath)
agreed=ui.ask("Установить "..source_display.." на "..fullTargetPath.."?")
else
agreed=ui.ask("Install "..source_display..special_target.."?")
end
if not agreed then
ui.close()
io.write("Installation cancelled\n")
os.exit()
end
local installer_path=options.from.."/.install"
if fs.exists(installer_path)then
ui.close()
local installer,reason=loadfile(installer_path,"bt",setmetatable({install=options},{__index=_G}))
if not installer then
io.stderr:write("installer failed to load: "..tostring(reason).."\n")
os.exit(1)
end
os.exit(installer())
end
if computer.freeMemory()<50000 then
if not ui.graphic then print("Low memory, collecting garbage")end
for _=1,20 do os.sleep(0)end
end
local transfer=require("tools/transfer")
if ui.graphic then
ui.progress(0)
local from=fs.concat(options.from,options.fromDir)
local count=0
local function walk(dir)
for name in fs.list(dir)do
local full=fs.concat(dir,name)
if name:sub(-1)=="/"then walk(full)else count=count+1 end
end
end
local ok=pcall(walk,from)
ui.progress(ok and count or 0)
transfer.onFile=ui.step
end
local code
for _,inst in ipairs(transfer_args)do
local ec=transfer.batch(table.unpack(inst))
if ec~=nil and ec~=0 then
code=ec
break
end
end
transfer.onFile=nil
if code then
ui.close()
return code
end
local done={"Installation complete!"}
if options.setlabel then
pcall(target.dev.setLabel,options.label)
end
if options.setboot then
local address=target.dev.address
if computer.setBootAddress(address)then
done[#done+1]="Boot address set to "..address
end
end
if ui.graphic then
ui.note(table.concat(done,"  ·  "))
if options.reboot then
if ui.ask("Установка завершена. Перезагрузить компьютер сейчас?")then
ui.close()
print("\nRebooting now!\n")
computer.shutdown(true)
end
else
ui.finish(table.concat(done,"\n"))
ui.pause()
end
ui.close()
return
end
for _,s in ipairs(done)do print(s)end
if options.reboot and ui.ask("Reboot now?")then
print("\nRebooting now!\n")
computer.shutdown(true)
end
print("Returning to shell.\n")
