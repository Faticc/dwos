local l=require("component")
local w=require("computer")
local b=require("filesystem")
local a=require("shell")
local t=require("unicode")
local q=require("fetch")
local o,e=a.parse(...)
local x,A=e.dry and true or false,e.force and true or false
local B=e.rehash and true or false
local c=table.remove(o,1)or"list"
local function h(a)io.stderr:write(a.."\n")os.exit(1)end
if c=="help"or e.help then
print([[Использование: get [команда] [ИМЯ]...
  get                    что есть, что стоит, место на дисках
  get install ИМЯ...     поставить: игру, ролик, программу или весь набор
  get update [ИМЯ...]    обновить всё поставленное (или только это)
  get remove ИМЯ...      убрать
  --dry   только показать    --force   качать заново
  --rehash               пересчитать хэши своих файлов
  --disk=ПУТЬ            класть сюда (/mnt/...); с install - и перенести
                         уже стоящее. Без него get раскладывает сам]])
return 0
end
if c=="ls"then c="list"end
if c=="rm"then c="remove"end
if c~="list"and c~="install"and c~="update"and c~="remove"then
h("get: неизвестная команда "..c.." (get help)")
end
local k="Faticc/dwos"
local s={
{name="dwos",title="DwOS",sub="dist",system=true},
{name="games",title="Игры и ролики",sub="games",dir="/home/games"},
{name="dwapps",alias="apps",title="Программы",sub="apps",dir="/home/dwapps"},
}
local m={["Faticc/ocgames"]=true,["Faticc/dwapps"]=true}
do
local a=io.open("/etc/get.cfg")
if a then
local d=a:read("*a")
a:close()
local a=load("return "..d,"=/etc/get.cfg","t",{})
local f,d=pcall(a or error)
if f and type(d)=="table"then
for a,a in ipairs(d.sources or{})do
if type(a)=="table"and a.name and a.repo then s[#s+1]=a end
end
end
end
end
local function y(a,g)
g=g or""
local d=type(a)
if d=="string"then return("%q"):format(a)end
if d=="number"or d=="boolean"then return tostring(a)end
if d~="table"then return"nil"end
local i={}
for d in pairs(a)do i[#i+1]=d end
table.sort(i,function(d,f)return tostring(d)<tostring(f)end)
local d,j={"{\n"},g.." "
for f,f in ipairs(i)do
local i=type(f)=="string"and f:match("^[%a_][%w_]*$")and f or("["..y(f).."]")
d[#d+1]=j ..i.." = "..y(a[f],j)..",\n"
end
d[#d+1]=g.."}"
return table.concat(d)
end
local function d(f)
local a=io.open(f,"r")
if not a then return nil end
local f=a:read("*a")
a:close()
local g=load("return "..f,"=state","t",{})
local f,a=pcall(g or error)
return f and type(a)=="table"and a or nil
end
for a,a in ipairs(s)do
a.dir=a.system and"/"or(a.dir or("/home/"..a.name)):gsub("/+$","")
a.statePath=a.system and"/.dwos"or(a.dir.."/.installed")
a.state=d(a.statePath)
a.installed=a.system or a.state~=nil
local d=a.state or{}
if d.repo and not m[d.repo]then
a.repo,a.branch,a.sub=d.repo,d.branch or a.branch,d.dir or a.sub
end
a.repo=a.repo or k
a.branch=a.branch or"main"
a.sub=a.sub or""
if a.sub~=""and a.sub:sub(-1)~="/"then a.sub=a.sub.."/"end
end
if not l.isAvailable("internet")then h("нужна интернет-карта")end
local function G(i)
local d,f={},{}
for a,a in ipairs(i)do
local j=a.repo.."@"..a.branch
if not f[j]then
local k,g={ref=a.branch},{}
f[j]=k
d[#d+1]={
url=("https://api.github.com/repos/%s/commits/%s"):format(a.repo,a.branch),
headers={["accept"]="application/vnd.github.sha"},
write=function(a)g[#g+1]=a end,
finish=function(j)
local a=not j and table.concat(g):match("^%s*(%x+)%s*$")
if a and#a==40 then k.ref=a end
end,
}
end
end
q.many(d)
d={}
for a,a in ipairs(i)do
a.ref=f[a.repo.."@"..a.branch].ref
a.base=("https://raw.githubusercontent.com/%s/%s/%s"):format(a.repo,a.ref,a.sub)
local f={}
d[#d+1]={
url=a.base.."manifest.lua",
write=function(g)f[#f+1]=g end,
finish=function(g)
if g then a.err="manifest.lua: "..g return end
local i,j=load("return "..table.concat(f),"="..a.name,"t",{})
local g,f=pcall(i or error,j)
if g and type(f)=="table"and type(f.files)=="table"then a.manifest=f
else a.err="manifest.lua не читается: "..tostring(g and"не манифест"or f)end
end,
}
end
q.many(d)
end
local j=b.get("/")
local n=65536
local r=1048576
local p=512
local m,k={},{}
do
local a=l.list("filesystem")
local g=w.tmpAddress()
for d,i in b.mounts()do
local f=d.address
if a[f]and f~=g then
local a=k[f]
if not a then
local l,g=pcall(d.spaceTotal)
local u,v=pcall(d.spaceUsed)
local z,C=pcall(d.isReadOnly)
local D,E=pcall(d.getLabel)
g=l and tonumber(g)or 0
a={
dev=d,address=f,total=g,ro=not z or C,
free=g-(u and tonumber(v)or g),
label=D and E or nil,
root=j~=nil and f==j.address,
}
a.small=g<r
k[f]=a
m[#m+1]=a
end
if a.root then a.path="/"
elseif not a.path or(i:match("^/mnt/[^/]+$")and not a.path:match("^/mnt/[^/]+$"))then
a.path=i
end
end
end
table.sort(m,function(a,d)return a.path<d.path end)
end
local function i(d)
local a=b.get(d)
return a and k[a.address]or(j and k[j.address])
end
local function g(a)return a.free-(a.root and n or 0)end
local function k(a)
if a>=1048576 then return("%.1f МБ"):format(a/1048576)end
return("%d КБ"):format(math.max(0,math.ceil(a/1024)))
end
local d
if e.disk then
local a=e.disk:gsub("/+$","")
if a==""then a="/"end
for f,f in ipairs(m)do
if f.path==a or f.address:find(e.disk,1,true)==1 or f.label==e.disk then d=f end
end
if not d and a:sub(1,1)=="/"and b.exists(a)then d=i(a)end
if not d then h("диска "..e.disk.." не видно")end
if d.ro then h("на "..d.path.." писать нельзя")end
end
local function H(a)
local j=a.manifest
a.items,a.core={},{}
if a.system then
local e={src=a,key=a.name,title="система "..(j.version or""),files={},kind="system"}
for f,f in ipairs(j.files)do f.lname=f[1]e.files[#e.files+1]=f end
a.items[1]=e
return
end
local f,l={},{}
for e,e in ipairs(j.packages or{})do
local n={src=a,key=e[1],title=e[2]..(e[3]and(" - "..e[3])or""),files={},kind="game"}
f[#f+1]=n
l[e[1]]=n
end
local u,r={},{}
local function v(e)
e.lname=e[2]or e[1]
if e.video then
r[#r+1]=e
elseif e.pkg=="core"then
a.core[#a.core+1]=e
elseif not j.packages or not e.pkg then
if not l[a.name]then
local n={src=a,key=a.name,title=a.title,files={},kind="app"}
f[#f+1]=n
l[a.name]=n
end
local n=l[a.name]
n.files[#n.files+1]=e
else
local n=l[e.pkg]
if not n then
n={src=a,key=e.pkg,title=e.pkg,files={},kind="game"}
f[#f+1]=n
l[e.pkg]=n
end
n.files[#n.files+1]=e
end
end
for e,e in ipairs(j.files)do v(e)end
for e,e in ipairs(j.videos or{})do e.video=true v(e)end
for e,e in ipairs(r)do
local l=e.lname:gsub("%.[^.]*$","")
if e.title then u[l]=e.title end
end
for e,e in ipairs(r)do
local n,r=e.lname:match("^(.*)%.([^.]+)$")
local l={src=a,key=e.lname,base=n,files={e},kind="video"}
l.title=(u[n]or n)..(r=="dfpwm"and" - звук для кассеты"or"")
if e.secs then l.title=l.title..(" %d:%02d"):format(math.floor(e.secs/60),e.secs%60)end
f[#f+1]=l
end
for e,e in ipairs(f)do
e.aliases={}
for l,l in ipairs(j.bin or{})do
for j,j in ipairs(e.files)do
if j.lname==l[2]then e.aliases[#e.aliases+1]=l[1]end
end
end
end
a.items=f
end
local function C(a)
if not a.state then return{}end
return a.state.files or{}
end
local function r(f,j)
local e=C(f)[j.lname]
local a
if e and e.path then a=e.path
elseif f.system then a="/"..j.lname
elseif e then a=f.dir.."/"..j.lname end
if a and b.exists(a)and not b.isDirectory(a)then return a,e end
end
local function z(f)
for a,a in ipairs(f.files)do
local e=r(f.src,a)
if e and e:sub(-#a.lname-1)=="/"..a.lname then return e:sub(1,-#a.lname-2)end
end
end
local function D(a,f)
local e=f.src
if f.kind=="video"then return a.path=="/"and"/home/videos"or(a.path.."/videos")end
if a==i(e.dir)then return e.dir end
return(a.path=="/"and"/home/"or(a.path.."/"))..e.name
end
local function E(a,e)
if not a.system then return false end
for f,f in ipairs(a.manifest.keep or{})do
if f==e.lname and b.exists("/"..f)then return true end
end
return e.lname==".prop"and not b.exists("/.prop")
end
local function u(e)
local a=io.open(e,"rb")
if not a then return nil end
local e=0
while true do
local f=a:read(16384)
if not f then break end
e=q.crc32(e,f)
end
a:close()
return q.hex(e)
end
local function F(j,e)
local a,f=r(j,e)
if not a then return false end
if A or not e.crc then return false,a end
local j,l=b.size(a),b.lastModified(a)
if e.size and j~=e.size then return false,a end
local n=not B and f and f.size==j and f.mtime==l and f.crc or u(a)
return n==e.crc,a,{size=j,crc=n,mtime=l}
end
local function B(a)
for e,e in ipairs(a.files)do if r(a.src,e)then return true end end
return false
end
local f={}
for a,a in ipairs(s)do
if c=="list"or c=="install"or a.installed then f[#f+1]=a end
end
G(f)
local u={}
for a,a in ipairs(f)do
if a.manifest then H(a)
else
io.stderr:write(("%s: %s\n"):format(a.name,tostring(a.err)))
u[#u+1]=a.title
end
end
local function v(a)
local l,e=a:match("^([^/]+)/(.+)$")
e=(e or a):lower()
local a={}
for j,j in ipairs(f)do
local n=not l or j.name==l or j.alias==l
if j.items and n then
if not l and(e==j.name or e==j.alias)then
for l,l in ipairs(j.items)do
if l.kind~="video"then a[#a+1]=l end
end
if#a>0 then return a end
end
for l,l in ipairs(j.items)do
local j=l.key:lower()==e or(l.base and l.base:lower()==e)
for n,n in ipairs(l.aliases or{})do if n:lower()==e then j=true end end
if j then a[#a+1]=l end
end
end
if#a>0 then return a end
end
return a
end
local function l(a,e)
local j=t.wlen(a)
if j>=e then
return t.wtrunc(a,e).." "
end
return a..(" "):rep(e-j)
end
if c=="list"then
local G=math.min(80,(require("term").getViewport()))
for a,a in ipairs(f)do
if a.items then
print(("%s  %s@%s/%s"):format(a.title,a.repo,a.branch,a.sub:gsub("/$","")))
for e,e in ipairs(a.items)do
local n,j,t=0,false,false
for s,s in ipairs(e.files)do
n=n+(s.size or 0)
if not E(a,s)then
local H,A=F(a,s)
if A then j=true end
if A and not H then t=true end
end
end
if e.kind=="system"then j=true end
local s=j and(t and"обновить"or"стоит")or""
local t=j and not a.system and z(e)
local j=t and i(t)
if j and j~=i(a.dir)then s=s.." "..j.path end
local a=e.key..(#(e.aliases or{})>0 and e.aliases[1]~=e.key and("  "..table.concat(e.aliases,","))or"")
print("  "..l(a,20)..l(e.title or"",G-44)..l(k(n),10)..s)
end
end
end
local e={}
for a,a in ipairs(m)do
if not a.ro then
e[#e+1]=("%s %s%s"):format(a.path,k(math.max(0,a.free)),a.small and" (дискета)"or"")
end
end
print("Свободно: "..table.concat(e,", "))
print("get install ИМЯ - поставить, get update - обновить всё, get help")
return 0
end
local s={}
local function n(a)
s[a]=s[a]or{want={},gone={}}
return s[a]
end
if c=="install"or c=="remove"then
if#o==0 then h("get "..c..": что именно? (get - список)")end
for a,a in ipairs(o)do
local e=v(a)
if#e==0 then h("не знаю, что такое "..a.." (get - список)")end
for a,a in ipairs(e)do
local e=n(a.src)
if c=="install"then e.want[a]=true else e.gone[a]=true end
end
end
end
if c=="update"then
local e
if#o>0 then
e={}
for a,a in ipairs(o)do
local j=v(a)
if#j==0 then h("не знаю, что такое "..a)end
for a,a in ipairs(j)do e[a]=true end
end
end
local j={}
for a,l in ipairs(f)do
local f={}
for a,a in ipairs(l.items or{})do
if(not e or e[a])and(a.kind=="system"or B(a))then
n(l).want[a]=true
f[#f+1]=a.kind=="system"and(l.manifest.version or"")or a.key
end
end
if#f>0 then j[#j+1]=l.title.." "..table.concat(f,", ")end
end
if#j>0 then print("Проверяю: "..table.concat(j,"; "))end
end
local l={}
local e={same=0,get=0,bytes=0,gone=0}
local A={}
local B={}
for a,o in pairs(s)do
local f=a.state or{}
local t={
repo=a.repo,branch=a.branch,
dir=(a.sub~=""and a.sub:gsub("/+$",""))or nil,
files={},bin={},
}
if a.system then t.version=a.manifest.version end
A[a]=t
local j,f={},false
for n in pairs(o.want)do
f=true
for v,v in ipairs(n.files)do j[v]=n end
end
local H={src=a,key=a.name,title=a.title,files=a.core,kind="core"}
local n,G={},{}
for v,v in ipairs(a.core)do
n[#n+1]=v
if f then j[v]=H end
end
for f,v in ipairs(a.items)do
for f,f in ipairs(v.files)do
n[#n+1]=f
if o.gone[v]then j[f]=nil f.gone=true end
end
end
local v={}
for f,f in ipairs(n)do
G[f.lname]=true
local n,o=r(a,f)
if f.gone then
if n then l[#l+1]={path=n,name=f.lname}end
elseif j[f]==nil or E(a,f)then
local E=o and o.path and o.path:match("^(/mnt/[^/]+)/")
if o and(n or(E and not b.exists(E)))then t.files[f.lname]=o end
else
local o=j[f]
local j,E,E=F(a,f)
f.src,f.cur,f.fresh=a,n,j
if j then
e.same=e.same+1
if not a.system then E.path=n end
t.files[f.lname]=E
end
if not v[o]then
v[o]={it=o,s=a,need={}}
B[#B+1]=v[o]
end
if not j then table.insert(v[o].need,f)end
end
end
if c~="remove"then
for f,n in pairs(C(a))do
if not G[f]then
local j=n.path or(a.system and("/"..f)or(a.dir.."/"..f))
if b.exists(j)and not f:match("%.bin$")and not f:match("%.dfpwm$")then
l[#l+1]={path=j,name=f,stale=true}
end
end
end
end
end
local function E(a,f)
local j=b.exists(f)and not b.isDirectory(f)and b.size(f)or nil
if j and(a.size or 0)<=65536 then return(a.size or 0)-j end
return(a.size or 0)+p
end
local function F(j,n)
local a=0
for f,f in ipairs(j)do a=a+E(f,n.."/"..f.lname)end
return a
end
local function G(j,a)
if d then return g(d)>=j and d or nil end
if a and not a.ro and g(a)>=j then return a end
local f
for a,a in ipairs(m)do
if not a.ro and not a.small and g(a)>=j and(not f or g(a)>g(f))then f=a end
end
return f
end
local f,C,n={},{},{}
local o={}
for a,a in ipairs(B)do
local v,t=a.it,a.s
if v.kind=="system"or v.kind=="core"then
for j,j in ipairs(a.need)do
j.to=j.cur or(t.system and("/"..j.lname)or(t.dir.."/"..j.lname))
local t=i(j.to)
t.free=t.free-E(j,j.to)
if t.free<0 then n[#n+1]=("%s: на %s не хватает места"):format(j.lname,t.path)end
f[#f+1]=j
end
else
local t=z(v)
local j=t and i(t)
local v=c=="install"and d and j and j~=d
if t and not v then
local c=F(a.need,t)
if c<=0 or c<=g(j)then
j.free=j.free-c
for c,c in ipairs(a.need)do c.to=c.cur or(t.."/"..c.lname)f[#f+1]=c end
else
o[#o+1]=a
a.from=j
end
elseif#a.need>0 or v then
o[#o+1]=a
a.from=v and j or nil
end
end
end
local j,t={},{}
for a,a in ipairs(o)do
a.size=p
for c,c in ipairs(a.it.files)do a.size=a.size+(c.size or 0)+p end
local o=a.it.kind=="video"and(a.s.name.."/"..a.it.base)
local c=o and t[o]
if not c then
c={jobs={},size=0,it=a.it}
j[#j+1]=c
if o then t[o]=c end
end
c.jobs[#c.jobs+1]=a
c.size=c.size+a.size
c.from=c.from or a.from
end
table.sort(j,function(a,c)return a.size>c.size end)
for a,a in ipairs(j)do
local j=a.it
local t=i(D(i(j.src.dir),j))
local c
if j.kind=="video"then
local B,v={},{}
for o,o in ipairs(a.jobs)do B[o.it]=true end
for o,o in ipairs(j.src.items)do
local E=o.kind=="video"and o.base==j.base and not B[o]and z(o)
if E then c=E v[#v+1]=o end
end
local j=c and i(c)
if j and g(j)>=a.size and(not d or d==j)then
t=j
elseif j then
c=nil
for o,o in ipairs(v)do
local v={it=o,s=o.src,need={},from=j,size=p}
for z,z in ipairs(o.files)do z.src=o.src v.size=v.size+(z.size or 0)+p end
a.jobs[#a.jobs+1]=v
a.size=a.size+v.size
a.from=a.from or j
end
end
end
local j=G(a.size,a.from==nil and t or(t~=a.from and t or nil))
local o={}
for p,p in ipairs(a.jobs)do o[#o+1]=p.it.key end
o=table.concat(o,", ")
if not j then
local p
for v,v in ipairs(m)do
if not v.ro and not v.small and(not p or g(v)>g(p))then p=v end
end
n[#n+1]=("%s (%s) не влезает%s"):format(o,k(a.size),
d and(" на "..d.path..", там свободно "..k(g(d)))
or p and(": свободнее всего на "..p.path.." - "..k(g(p)))or"")
else
j.free=j.free-a.size
for g,g in ipairs(a.jobs)do
local m=(c and j==i(c))and c or D(j,g.it)
for c,c in ipairs(g.from and g.it.files or g.need)do
c.to=m.."/"..c.lname
f[#f+1]=c
if c.fresh then e.same=e.same-1 end
local i=c.cur or r(g.s,c)
if i and i~=c.to then l[#l+1]={path=i,name=c.lname,unless=c}end
end
end
if j~=t or a.from then
C[#C+1]=("  %s -> %s%s"):format(o,j.path,
a.from and(" (с "..a.from.path..")")or d and""or" (на своём диске не влезает)")
end
end
end
if#n>0 then
for a,a in ipairs(n)do io.stderr:write("  "..a.."\n")end
h("места не хватит - освободи диск, вставь ещё один или get remove ...")
end
for a,a in ipairs(C)do print(a)end
local a=0
for c,c in ipairs(f)do a=a+(c.gzsize or c.size or 0)end
if#f>0 then
print(("%s %d файлов, %s%s"):format(x and"Скачалось бы"or"Качаю",#f,k(a),
x and""or" - по четыре разом, сжатыми"))
end
if x then
for a,a in ipairs(f)do print(("  %-24s -> %s"):format(a.lname,a.to))end
for a,a in ipairs(l)do print(("  %-24s удалится: %s"):format(a.name,a.path))end
return 0
end
local g={}
local function d(c,a)
if#c==0 then return end
local i,j=q.files{
need=c,
url=function(c,i)return(c.src or a).base..i end,
path=function(c)return c.to end,
all=a and a.manifest.files,pack=a and a.manifest.pack,
progress=function(a,c)
if(a.size or 0)>262144 then
io.write(("\r  %-24s %3d%%"):format(a.lname,math.floor(c*100/a.size)))
end
end,
done=function(a,c)
if not c then return end
a.got=true
e.get,e.bytes=e.get+1,e.bytes+c
local m=A[a.src]
local i={size=c,crc=a.crc,mtime=b.lastModified(a.to)}
if not a.src.system then i.path=a.to end
m.files[a.lname]=i
io.write(("\r  %-24s %s\n"):format(a.lname,k(c)))
end,
}
for a,a in ipairs(j)do
if not(a.entry.opt and a.code==404)then g[#g+1]=a end
end
end
local i,a={},{}
for c,c in ipairs(f)do
if c.src.system then i[#i+1]=c else a[#a+1]=c end
end
local q=w.uptime()
local j
for c in pairs(s)do if c.system then j=c end end
d(i,j)
d(a,nil)
for a,a in ipairs(l)do
if not a.unless or a.unless.got then
b.remove(a.path)
e.gone=e.gone+1
if not a.unless then
print(("  %-24s удалён%s"):format(a.name,a.stale and" - его больше нет в репозитории"or""))
end
local c=a.path:match("^(/mnt/[^/]+/.+)/[^/]+$")
while c do
local a=b.list(c)
if not a or a()~=nil then break end
b.remove(c)
c=c:match("^(/mnt/[^/]+/.+)/[^/]+$")
end
end
end
local l="-- ярлык на "
local function n(c)
local a=io.open(c,"rb")
if not a then return false end
local c=a:read(#l)
a:close()
return c==l
end
for a,f in pairs(A)do
if not a.system then
local d=a.manifest
local m=d.lib and d.lib:gsub("^/+",""):gsub("/+$","")
local o={}
for c,c in ipairs(d.bin or{})do
local p=f.files[c[2]]
local d=p and(p.path or(a.dir.."/"..c[2]))
if d and b.exists(d)then
o[c[1]]=true
f.bin[#f.bin+1]=c[1]
local p=""
if m and m~=""and d:sub(-#c[2]-1)=="/"..c[2]then
local r=d:sub(1,-#c[2]-2).."/"..m
p=("package.path = %q .. package.path\n"):format(r.."/?.lua;")
end
local m=("%s%s\nlocal a = { ... }\n%sreturn assert(loadfile(%q))(table.unpack(a))\n")
:format(l,d,p,d)
local d="/bin/"..c[1]..".lua"
local c
local l=io.open(d,"r")
if l then c=l:read("*a")l:close()end
if c~=m and(c==nil or n(d))then
local c=io.open(d,"w")
if c then c:write(m)c:close()end
end
end
end
for c,d in ipairs((a.state or{}).bin or{})do
local c="/bin/"..d..".lua"
if not o[d]and b.exists(c)and n(c)then b.remove(c)end
end
end
if not a.system and next(f.files)==nil then
b.remove(a.statePath)
else
if not b.exists(a.dir)then b.makeDirectory(a.dir)end
local b=io.open(a.statePath,"w")
if b then b:write(y(f),"\n")b:close()end
end
end
if#u>0 then
h("не проверено - манифест не пришёл: "..table.concat(u,", "))
end
if#g>0 then
for a,a in ipairs(g)do io.stderr:write(("  %s: %s\n"):format(a.entry.lname,tostring(a.err)))end
h(("не скачалось файлов: %d"):format(#g))
end
if e.get==0 and e.gone==0 then
print(("Всё свежее, файлов: %d."):format(e.same))
else
print(("Готово за %.1f с: скачано %d (%s), без изменений %d, удалено %d.")
:format(w.uptime()-q,e.get,k(e.bytes),e.same,e.gone))
if j and#i>0 then print("Система обновилась - перезагрузись: reboot")end
end
return 0
