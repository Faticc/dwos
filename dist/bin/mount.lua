local fs=require("filesystem")
local shell=require("shell")
local function usage()
io.stderr:write([==[
Usage: mount [OPTIONS] [device] [path]
  If no args are given, all current mount points are printed.
  <Options> Note that multiple options can be used together
  -r, --ro    Mount the filesystem read only
      --bind  Create a mount bind point, folder to folder
  <Args>
  device      Specify filesystem device by one of:
              a. label
              b. address (can be abbreviated)
              c. folder path (requires --bind)
  path        Target folder path to mount to

See `man mount` for more details
]==])
os.exit(1)
end
local args,opts=shell.parse(...)
opts.readonly=opts.r or opts.readonly
if opts.h or opts.help then
usage()
end
local function print_mounts()
local mounts={}
for proxy,path in fs.mounts()do
local list=mounts[proxy.address]or{}
mounts[proxy.address]=list
list[#list+1]={
mount_path=path,
rw_ro=proxy.isReadOnly()and"ro"or"rw",
fs_label=proxy.getLabel()or proxy.address,
}
end
local sorted={}
for key,value in pairs(mounts)do
sorted[#sorted+1]={key,value}
end
table.sort(sorted,function(a,b)return a[1]<b[1]end)
for _,dev in ipairs(sorted)do
for _,device in ipairs(dev[2])do
io.write(string.format("%-8s on %-10s %s %s\n",
dev[1]:sub(1,8),device.mount_path,"("..device.rw_ro..")","\""..device.fs_label.."\""))
end
end
end
local function do_mount()
local proxy,reason=fs.proxy(args[1],opts)
if not proxy then
io.stderr:write("Failed to mount: ",tostring(reason),"\n")
os.exit(1)
end
local result,mount_failure=fs.mount(proxy,shell.resolve(args[2]))
if not result then
io.stderr:write(mount_failure,"\n")
os.exit(2)
end
end
if#args==0 then
if next(opts)then
io.stderr:write("Missing argument\n")
usage()
else
print_mounts()
end
elseif#args==2 then
do_mount()
else
io.stderr:write("wrong number of arguments: ",#args,"\n")
usage()
end
