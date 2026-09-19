local fs=require("filesystem")
local shell=require("shell")
local args,options=shell.parse(...)
if#args==0 or options.help then
print([==[Usage: rm [options] <filename1> [<filename2> [...]]

  -f          ignore nonexistent files and arguments, never prompt
  -r          remove directories and their contents recursively
  -v          explain what is being done
      --help  display this help and exit

For complete documentation and more options, run: man rm]==])
return 1
end
local bRec=options.r or options.R or options.recursive
local bForce=options.f or options.force
local bVerbose=(options.v or options.verbose)and not bForce
local bEmptyDirs=options.d or options.dir
local promptLevel=bForce and 0 or(options.I and 3)or(options.i and 1)or 0
local function perr(...)
if not bForce then io.stderr:write(...)end
end
local function pout(...)
if not bForce then io.stdout:write(...)end
end
local function _path(m)return shell.resolve(m.rel)end
local function _link(m)return fs.isLink(_path(m))end
local function _exists(m)return _link(m)or fs.exists(_path(m))end
local function _dir(m)return not _link(m)and fs.isDirectory(_path(m))end
local function _readonly(m)return not _exists(m)or fs.get(_path(m)).isReadOnly()end
local function _empty(m)return _exists(m)and _dir(m)and fs.list(_path(m))()==nil end
local function createMeta(origin,rel)
local m={origin=origin,rel=rel:gsub("/+$","")}
if _dir(m)then
m.rel=m.rel.."/"
end
return m
end
local function confirm()
if bForce then
return true
end
local r=io.read()
return r=="y"or r=="yes"
end
local remove
local function remove_all(parent)
if parent==nil or not _dir(parent)or _empty(parent)then
return true
end
local all_ok=true
if bRec and promptLevel==1 then
pout(string.format("rm: descend into directory `%s'? ",parent.rel))
if not confirm()then
return false
end
for file in fs.list(_path(parent))do
all_ok=remove(createMeta(parent.origin,parent.rel..file))and all_ok
end
end
return all_ok
end
remove=function(meta)
if not remove_all(meta)then
return false
end
if not _exists(meta)then
perr(string.format("rm: cannot remove `%s': No such file or directory\n",meta.rel))
return false
elseif _dir(meta)and not bRec and not(_empty(meta)and bEmptyDirs)then
if not bEmptyDirs then
perr(string.format("rm: cannot remove `%s': Is a directory\n",meta.rel))
else
perr(string.format("rm: cannot remove `%s': Directory not empty\n",meta.rel))
end
return false
end
local ok=true
if promptLevel==1 then
if _dir(meta)then
pout(string.format("rm: remove directory `%s'? ",meta.rel))
elseif _link(meta)then
pout(string.format("rm: remove symbolic link `%s'? ",meta.rel))
else
pout(string.format("rm: remove regular file `%s'? ",meta.rel))
end
ok=confirm()
end
if ok then
if _readonly(meta)then
perr(string.format("rm: cannot remove `%s': Is read only\n",meta.rel))
return false
end
os.remove(_path(meta))
if bVerbose then
pout("removed '"..meta.rel.."'\n")
end
end
return ok
end
local metas={}
for _,arg in ipairs(args)do
metas[#metas+1]=createMeta(arg,arg)
end
if promptLevel==3 and#metas>3 then
pout(string.format("rm: remove %i arguments? ",#metas))
if not confirm()then
return
end
end
local ok=true
for _,meta in ipairs(metas)do
ok=remove(meta)and ok
end
return bForce or ok
