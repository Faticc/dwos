local k=require("computer")
local e=require("shell")
local b=require("filesystem")
local c,a=e.parse(...)
if a.help then
io.write([[Usage: install [OPTION]...
  --from=ADDR        install filesystem at ADDR
                     default: builds list of
                     candidates and prompts user
  --to=ADDR          same as --from but for target
  --fromDir=PATH     install PATH from source
  --root=PATH        same as --fromDir but target
  --toDir=PATH       same as --root
  -u, --update       update files interactively
  --label            override label from .prop
  --nosetlabel       do not label target
  --nosetboot        do not use target for boot
  --noreboot         do not reboot after install
  --text             plain text interface
]])
return nil
end
local f=b.get("/")
if not f then
io.stderr:write("no root filesystem, aborting\n")
os.exit(1)
end
local g=c[1]
a.label=g
local function h(i)
local c=a[i]
if not c then return nil end
local d=e.resolve(c)
if b.isDirectory(d)then
local e=b.get(d)
a[i]=d
return e.address,e
end
return c
end
local e,l=h("from")
local i,n=h("to")
local h=require("component").list("filesystem")
local c={}
for d,j in b.mounts()do
if h[d.address]then
local h=c[d]
c[d]=h and#h<#j and h or j
end
end
local d=b.get("/dev")
c[d==f or d]=nil
local m=k.tmpAddress()
local d={}
for h,k in pairs(c)do
local j=h.address
local o=h==n and a.to or k
local k=i and j:find(i,1,true)==1
if h.isReadOnly()then
if k then
io.stderr:write("Cannot install to "..a.to..", it is read only\n")
os.exit(1)
end
elseif k or
not(e and j:find(e,1,true)==1)and
not i and j~=m then
d[#d+1]={dev=h,path=o,specified=k}
end
end
if#d==1 then
c[d[1].dev]=nil
end
local h={}
for i,j in pairs(c)do
local k=i.address
local n=i==l and a.from or j
local l=e and k:find(e,1,true)==1
if b.list(n)()and(l or not e and k~=m)then
local c,m={},false
local e=b.open(j.."/.prop")
if e then
m=true
local o=e:read(math.maxinteger or math.huge)
e:close()
local b=load("return "..o)
c=b and b()
if not c then
io.stderr:write("Ignoring "..j.." due to malformed prop file\n")
c={ignore=true}
end
end
local b=l or m
or k~=f.address or f.isReadOnly()
if not c.ignore and b and
(not g or g:lower()==(c.label or i.getLabel()or""):lower())then
h[#h+1]={dev=i,path=n,prop=c,specified=l}
end
end
end
table.sort(h,function(b,c)return b.path<c.path end)
table.sort(d,function(b,c)return b.path<c.path end)
return{
options=a,
sources=h,
targets=d,
label=g,
}
