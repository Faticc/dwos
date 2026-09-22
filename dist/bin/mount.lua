local d=require("filesystem")
local h=require("shell")
local function e()
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
local b,a=h.parse(...)
a.readonly=a.r or a.readonly
if a.h or a.help then
e()
end
local function i()
local f={}
for c,j in d.mounts()do
local g=f[c.address]or{}
f[c.address]=g
g[#g+1]={
mount_path=j,
rw_ro=c.isReadOnly()and"ro"or"rw",
fs_label=c.getLabel()or c.address,
}
end
local c={}
for g,j in pairs(f)do
c[#c+1]={g,j}
end
table.sort(c,function(f,g)return f[1]<g[1]end)
for f,f in ipairs(c)do
for c,c in ipairs(f[2])do
io.write(string.format("%-8s on %-10s %s %s\n",
f[1]:sub(1,8),c.mount_path,"("..c.rw_ro..")","\""..c.fs_label.."\""))
end
end
end
local function f()
local c,g=d.proxy(b[1],a)
if not c then
io.stderr:write("Failed to mount: ",tostring(g),"\n")
os.exit(1)
end
local g,j=d.mount(c,h.resolve(b[2]))
if not g then
io.stderr:write(j,"\n")
os.exit(2)
end
end
if#b==0 then
if next(a)then
io.stderr:write("Missing argument\n")
e()
else
i()
end
elseif#b==2 then
f()
else
io.stderr:write("wrong number of arguments: ",#b,"\n")
e()
end
