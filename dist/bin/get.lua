local m=require("component")
local t=require("computer")
local b=require("filesystem")
local a=require("shell")
local s=require("unicode")
local l=require("fetch")
local k,d=a.parse(...)
local p,x=d.dry and true or false,d.force and true or false
local c=table.remove(k,1)or"list"
local function f(a)io.stderr:write(a.."\n")os.exit(1)end
if c=="help"or d.help then
print([[Использование: get [команда] [ИМЯ]...
  get                    что есть и что стоит
  get install ИМЯ...     поставить: игру, ролик, программу или весь набор
  get update [ИМЯ...]    обновить всё поставленное (или только это)
  get remove ИМЯ...      убрать
  --dry   только показать    --force   качать заново
  --disk=ПУТЬ            куда класть новые игры и ролики (/mnt/...)]])
return 0
end
if c=="ls"then c="list"end
if c=="rm"then c="remove"end
if c~="list"and c~="install"and c~="update"and c~="remove"then
f("get: неизвестная команда "..c.." (get help)")
end
local n={
{name="dwos",title="DwOS",repo="Faticc/dwos",sub="dist",system=true},
{name="games",title="Игры и ролики",repo="Faticc/ocgames",dir="/home/games"},
{name="dwapps",title="Программы",repo="Faticc/dwapps",dir="/home/dwapps"},
}
do
local a=io.open("/etc/get.cfg")
if a then
local e=a:read("*a")
a:close()
local a=load("return "..e,"=/etc/get.cfg","t",{})
local g,e=pcall(a or error)
if g and type(e)=="table"then
for a,a in ipairs(e.sources or{})do
if type(a)=="table"and a.name and a.repo then n[#n+1]=a end
end
end
end
end
local function q(a,h)
h=h or""
local e=type(a)
if e=="string"then return("%q"):format(a)end
if e=="number"or e=="boolean"then return tostring(a)end
if e~="table"then return"nil"end
local i={}
for e in pairs(a)do i[#i+1]=e end
table.sort(i,function(e,g)return tostring(e)<tostring(g)end)
local e,j={"{\n"},h.." "
for g,g in ipairs(i)do
local i=type(g)=="string"and g:match("^[%a_][%w_]*$")and g or("["..q(g).."]")
e[#e+1]=j ..i.." = "..q(a[g],j)..",\n"
end
e[#e+1]=h.."}"
return table.concat(e)
end
local function e(g)
local a=io.open(g,"r")
if not a then return nil end
local g=a:read("*a")
a:close()
local h=load("return "..g,"=state","t",{})
local g,a=pcall(h or error)
return g and type(a)=="table"and a or nil
end
for a,a in ipairs(n)do
a.dir=a.system and"/"or(a.dir or("/home/"..a.name)):gsub("/+$","")
a.statePath=a.system and"/.dwos"or(a.dir.."/.installed")
a.state=e(a.statePath)
a.installed=a.system or a.state~=nil
local e=a.state or{}
a.repo=e.repo or a.repo
a.branch=e.branch or a.branch or"main"
a.sub=e.dir or a.sub or""
if a.sub~=""and a.sub:sub(-1)~="/"then a.sub=a.sub.."/"end
end
if not m.isAvailable("internet")then f("нужна интернет-карта")end
local function y(i)
local e={}
for a,a in ipairs(i)do
a.ref=a.branch
local g={}
e[#e+1]={
url=("https://api.github.com/repos/%s/commits/%s"):format(a.repo,a.branch),
headers={["accept"]="application/vnd.github.sha"},
write=function(h)g[#g+1]=h end,
finish=function(j)
local h=not j and table.concat(g):match("^%s*(%x+)%s*$")
if h and#h==40 then a.ref=h end
end,
}
end
l.many(e)
e={}
for a,a in ipairs(i)do
a.base=("https://raw.githubusercontent.com/%s/%s/%s"):format(a.repo,a.ref,a.sub)
local g={}
e[#e+1]={
url=a.base.."manifest.lua",
write=function(h)g[#g+1]=h end,
finish=function(h)
if h then a.err="manifest.lua: "..h return end
local i,j=load("return "..table.concat(g),"="..a.name,"t",{})
local h,g=pcall(i or error,j)
if h and type(g)=="table"and type(g.files)=="table"then a.manifest=g
else a.err="manifest.lua не читается: "..tostring(h and"не манифест"or g)end
end,
}
end
l.many(e)
end
local r=b.get("/")
local function w(e)
local a=b.get(e)
if not a or(r and a.address==r.address)then return"/"end
for g,e in b.mounts()do
if g.address==a.address and e:match("^/mnt/[^/]+$")then return e end
end
return"/"
end
local m
if d.disk then
for e,a in b.mounts()do
if a==d.disk:gsub("/+$","")or e.address:find(d.disk,1,true)==1 then
m=a
end
end
if not m then f("диска "..d.disk.." не видно")end
end
local function i(a)
if a>=1048576 then return("%.1f МБ"):format(a/1048576)end
return("%d КБ"):format(math.ceil(a/1024))
end
local function z(a)
local g=a.manifest
a.items,a.core={},{}
if a.system then
local d={src=a,key=a.name,title="система "..(g.version or""),files={},kind="system"}
for e,e in ipairs(g.files)do e.lname=e[1]d.files[#d.files+1]=e end
a.items[1]=d
return
end
local e,h={},{}
for d,d in ipairs(g.packages or{})do
local j={src=a,key=d[1],title=d[2]..(d[3]and(" - "..d[3])or""),files={},kind="game"}
e[#e+1]=j
h[d[1]]=j
end
local u,o={},{}
local function v(d)
d.lname=d[2]or d[1]
if d.video then
o[#o+1]=d
elseif not g.packages or d.pkg=="core"or not d.pkg then
if g.packages then a.core[#a.core+1]=d
else
if not h[a.name]then
local j={src=a,key=a.name,title=a.title,files={},kind="app"}
e[#e+1]=j
h[a.name]=j
end
local j=h[a.name]
if d.lname=="install.lua"then a.core[#a.core+1]=d else j.files[#j.files+1]=d end
end
else
local j=h[d.pkg]
if not j then
j={src=a,key=d.pkg,title=d.pkg,files={},kind="game"}
e[#e+1]=j
h[d.pkg]=j
end
j.files[#j.files+1]=d
end
end
for d,d in ipairs(g.files)do v(d)end
for d,d in ipairs(g.videos or{})do d.video=true v(d)end
for d,d in ipairs(o)do
local h=d.lname:gsub("%.[^.]*$","")
if d.title then u[h]=d.title end
end
for d,d in ipairs(o)do
local j,o=d.lname:match("^(.*)%.([^.]+)$")
local h={src=a,key=d.lname,base=j,files={d},kind="video"}
h.title=(u[j]or j)..(o=="dfpwm"and" - звук для кассеты"or"")
if d.secs then h.title=h.title..(" %d:%02d"):format(math.floor(d.secs/60),d.secs%60)end
e[#e+1]=h
end
for d,d in ipairs(e)do
d.aliases={}
for h,h in ipairs(g.bin or{})do
for g,g in ipairs(d.files)do
if g.lname==h[2]and h[2]~="install.lua"then d.aliases[#d.aliases+1]=h[1]end
end
end
end
a.items=e
end
local function u(a)
if not a.state then return{}end
return a.state.files or{}
end
local function o(e,g)
local d=u(e)[g.lname]
local a
if d and d.path then a=d.path
elseif e.system then a="/"..g.lname
elseif d then a=e.dir.."/"..g.lname end
if a and b.exists(a)and not b.isDirectory(a)then return a,d end
end
local function v(a,d)
if not a.system then return false end
for e,e in ipairs(a.manifest.keep or{})do
if e==d.lname and b.exists("/"..e)then return true end
end
return d.lname==".prop"and not b.exists("/.prop")
end
local function A(e,a,d)
if e.system then return"/"..d.lname end
if a and a.kind=="video"then
local g=m or w(e.dir)
return(g=="/"and"/home/videos"or(g.."/videos")).."/"..d.lname
end
if a and a.kind=="game"and m then return m.."/games/"..d.lname end
return e.dir.."/"..d.lname
end
local function m(d)
local a=io.open(d,"rb")
if not a then return nil end
local d=0
while true do
local e=a:read(16384)
if not e then break end
d=l.crc32(d,e)
end
a:close()
return l.hex(d)
end
local function w(g,d)
local a,e=o(g,d)
if not a then return false end
if x or not d.crc then return false,a end
local g,h=b.size(a),b.lastModified(a)
if d.size and g~=d.size then return false,a end
local j=e and e.size==g and e.mtime==h and e.crc or m(a)
return j==d.crc,a,{size=g,crc=j,mtime=h}
end
local function B(a)
for d,d in ipairs(a.files)do if o(a.src,d)then return true end end
return false
end
local d={}
for a,a in ipairs(n)do
if c=="list"or c=="install"or a.installed then d[#d+1]=a end
end
y(d)
for a,a in ipairs(d)do
if a.manifest then z(a)else io.stderr:write(("%s: %s\n"):format(a.name,tostring(a.err)))end
end
local function n(a)
local h,e=a:match("^([^/]+)/(.+)$")
e=(e or a):lower()
local a={}
for g,g in ipairs(d)do
if g.items and(not h or g.name==h)then
if not h and e==g.name then
for h,h in ipairs(g.items)do
if h.kind~="video"then a[#a+1]=h end
end
if#a>0 then return a end
end
for h,h in ipairs(g.items)do
local g=h.key:lower()==e or(h.base and h.base:lower()==e)
for j,j in ipairs(h.aliases or{})do if j:lower()==e then g=true end end
if g then a[#a+1]=h end
end
end
if#a>0 then return a end
end
return a
end
local function g(a,e)
local h=s.wlen(a)
if h>e then
return s.wtrunc(a,e).." "
end
return a..(" "):rep(e-h)
end
if c=="list"then
local y=math.min(80,(require("term").getViewport()))
for a,e in ipairs(d)do
if e.items then
print(("%s  %s@%s"):format(e.title,e.repo,e.branch))
for a,a in ipairs(e.items)do
local h,j,s=0,false,false
for m,m in ipairs(a.files)do
h=h+(m.size or 0)
if not v(e,m)then
local z,x=w(e,m)
if x then j=true end
if x and not z then s=true end
end
end
if a.kind=="system"then j=true end
local e=j and(s and"обновить"or"стоит")or""
local j=a.key..(#(a.aliases or{})>0 and a.aliases[1]~=a.key and("  "..table.concat(a.aliases,","))or"")
print("  "..g(j,20)..g(a.title or"",y-44)..g(i(h),10)..e)
end
end
end
print("get install ИМЯ - поставить, get update - обновить всё, get help")
return 0
end
local m={}
local function e(a)
m[a]=m[a]or{want={},gone={}}
return m[a]
end
if c=="install"or c=="remove"then
if#k==0 then f("get "..c..": что именно? (get - список)")end
for a,a in ipairs(k)do
local g=n(a)
if#g==0 then f("не знаю, что такое "..a.." (get - список)")end
for a,a in ipairs(g)do
local g=e(a.src)
if c=="install"then g.want[a]=true else g.gone[a]=true end
end
end
end
if c=="update"then
local a
if#k>0 then
a={}
for g,g in ipairs(k)do
local h=n(g)
if#h==0 then f("не знаю, что такое "..g)end
for g,g in ipairs(h)do a[g]=true end
end
end
for g,g in ipairs(d)do
for d,d in ipairs(g.items or{})do
if(not a or a[d])and(d.kind=="system"or B(d))then e(g).want[d]=true end
end
end
end
local g,j={},{}
local d={same=0,get=0,bytes=0,gone=0}
local s={}
for a,x in pairs(m)do
local e=a.state or{}
local h={
repo=a.repo,branch=a.branch,
dir=(a.sub~=""and a.sub:gsub("/+$",""))or nil,
files={},bin={},seen=e.seen,
}
if a.system then h.version=a.manifest.version end
s[a]=h
local k,y={},false
for e in pairs(x.want)do
y=true
for n,n in ipairs(e.files)do k[n]=e end
end
if not a.system then
h.seen=h.seen or{}
for e,e in ipairs(a.items)do h.seen[e.key]=true end
end
local n,z={},{}
for e,e in ipairs(a.core)do
n[#n+1]=e
if y then k[e]=k[e]or false end
end
for e,y in ipairs(a.items)do
for e,e in ipairs(y.files)do
n[#n+1]=e
if x.gone[y]then k[e]=nil e.gone=true end
end
end
for e,e in ipairs(n)do
z[e.lname]=true
local n,x=o(a,e)
if e.gone then
if n then j[#j+1]={path=n,name=e.lname}end
elseif k[e]==nil or v(a,e)then
if x and n then h.files[e.lname]=x end
else
local v,o,o=w(a,e)
if v then
d.same=d.same+1
if not a.system then o.path=n end
h.files[e.lname]=o
else
e.src=a
e.to=n or A(a,k[e]or nil,e)
g[#g+1]=e
end
end
end
if c~="remove"then
for c,h in pairs(u(a))do
if not z[c]then
local e=h.path or(a.system and("/"..c)or(a.dir.."/"..c))
if b.exists(e)and not c:match("%.bin$")and not c:match("%.dfpwm$")then
j[#j+1]={path=e,name=c,stale=true}
end
end
end
end
end
do
local c={}
for a,a in ipairs(g)do
local e=b.get(a.to:match("^(.*)/[^/]*$")~=""and a.to or"/")or r
local h=b.exists(a.to)and b.size(a.to)or 0
c[e]=(c[e]or 0)+(a.size or 0)-h+512
end
for a,e in pairs(c)do
local c=(a.spaceTotal()or 0)-(a.spaceUsed()or 0)
if e>c then
f(("на диске %s не хватит места: нужно %s, свободно %s (--disk=/mnt/...)")
:format(a.getLabel()or a.address:sub(1,8),i(e),i(c)))
end
end
end
local a=0
for c,c in ipairs(g)do a=a+(c.gzsize or c.size or 0)end
if#g>0 then
print(("%s %d файлов, %s%s"):format(p and"Скачалось бы"or"Качаю",#g,i(a),
p and""or" - по четыре разом, сжатыми"))
end
if p then
for a,a in ipairs(g)do print(("  %-24s -> %s"):format(a.lname,a.to))end
for a,a in ipairs(j)do print(("  %-24s удалится: %s"):format(a.name,a.path))end
return 0
end
local e={}
local function n(c,a)
if#c==0 then return end
local h,k=l.files{
need=c,
url=function(c,h)return c.src.base..h end,
path=function(c)return c.to end,
all=a and a.manifest.files,pack=a and a.manifest.pack,
progress=function(a,c)
if(a.size or 0)>262144 then
io.write(("\r  %-24s %3d%%"):format(a.lname,math.floor(c*100/a.size)))
end
end,
done=function(a,c)
if not c then return end
d.get,d.bytes=d.get+1,d.bytes+c
local l=s[a.src]
local h={size=c,crc=a.crc,mtime=b.lastModified(a.to)}
if not a.src.system then h.path=a.to end
l.files[a.lname]=h
io.write(("\r  %-24s %s\n"):format(a.lname,i(c)))
end,
}
for a,a in ipairs(k)do
if not(a.entry.opt and a.code==404)then e[#e+1]=a end
end
end
local h,a={},{}
for c,c in ipairs(g)do
if c.src.system then h[#h+1]=c else a[#a+1]=c end
end
local r=t.uptime()
local k
for c in pairs(m)do if c.system then k=c end end
n(h,k)
n(a,nil)
for a,a in ipairs(j)do
b.remove(a.path)
d.gone=d.gone+1
print(("  %-24s удалён%s"):format(a.name,a.stale and" - его больше нет в репозитории"or""))
end
local l="-- ярлык на "
local function o(c)
local a=io.open(c,"rb")
if not a then return false end
local c=a:read(#l)
a:close()
return c==l
end
for a,g in pairs(s)do
if not a.system then
local j=a.manifest
local m
if j.lib then
local c=j.lib:gsub("^/+",""):gsub("/+$","")
if c~=""then m=a.dir.."/"..c end
end
local p={}
for c,c in ipairs(j.bin or{})do
local n=g.files[c[2]]
local j=n and(n.path or(a.dir.."/"..c[2]))
if j and b.exists(j)then
p[c[1]]=true
g.bin[#g.bin+1]=c[1]
local n=""
if c[2]=="install.lua"then
n=("table.insert(a, 1, %q)\n"):format("--to="..a.dir)
elseif m then
n=("package.path = %q .. package.path\n"):format(m.."/?.lua;")
end
local m=("%s%s\nlocal a = { ... }\n%sreturn assert(loadfile(%q))(table.unpack(a))\n")
:format(l,j,n,j)
local j="/bin/"..c[1]..".lua"
local c
local l=io.open(j,"r")
if l then c=l:read("*a")l:close()end
if c~=m and(c==nil or o(j))then
local c=io.open(j,"w")
if c then c:write(m)c:close()end
end
end
end
for c,j in ipairs((a.state or{}).bin or{})do
local c="/bin/"..j..".lua"
if not p[j]and b.exists(c)and o(c)then b.remove(c)end
end
end
if not a.system and next(g.files)==nil then
b.remove(a.statePath)
else
if not b.exists(a.dir)then b.makeDirectory(a.dir)end
local b=io.open(a.statePath,"w")
if b then b:write(q(g),"\n")b:close()end
end
end
if#e>0 then
for a,a in ipairs(e)do io.stderr:write(("  %s: %s\n"):format(a.entry.lname,tostring(a.err)))end
f(("не скачалось файлов: %d"):format(#e))
end
if d.get==0 and d.gone==0 then
print(("Всё свежее, файлов: %d."):format(d.same))
else
print(("Готово за %.1f с: скачано %d (%s), без изменений %d, удалено %d.")
:format(t.uptime()-r,d.get,i(d.bytes),d.same,d.gone))
if k and#h>0 then print("Система обновилась - перезагрузись: reboot")end
end
return 0
