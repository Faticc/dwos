local o=require("component")
local b=require("shell")
local a=require("filesystem")
local c,c=b.parse(...)
if c.help then
io.write([[Usage: update [OPTION]...
  --repo=OWNER/REPO  откуда качать (Faticc/dwos)
  --branch=BRANCH    ветка (main)
  --dir=PATH         подкаталог репозитория (dist)
  --to=PATH          что обновлять (/)
  --dry              только показать, что изменится
  --force            скачать всё заново
  --rehash           пересчитать хэши своих файлов
]])
return 0
end
local e,p,q=c.dry and true,c.force and true,c.rehash and true
local k=".dwos"
local function g(b)io.stderr:write(b.."\n")os.exit(1)end
local h=require("fetch")
local function s(d)
local b=io.open(d,"rb")
if not b then return nil end
local d,f=0,0
while true do
local i=b:read(16384)
if not i then break end
d,f=h.crc32(d,i),f+#i
end
b:close()
return h.hex(d),f
end
local function l(b,i)
i=i or""
local d=type(b)
if d=="string"then return("%q"):format(b)end
if d=="number"or d=="boolean"then return tostring(b)end
if d~="table"then return"nil"end
local j={}
for d in pairs(b)do j[#j+1]=d end
table.sort(j,function(d,f)return tostring(d)<tostring(f)end)
local d,m={"{\n"},i.." "
for f,f in ipairs(j)do
local j=type(f)=="string"and f:match("^[%a_][%w_]*$")and f or("["..l(f).."]")
d[#d+1]=m ..j.." = "..l(b[f],m)..",\n"
end
d[#d+1]=i.."}"
return table.concat(d)
end
local function d(f)
local b=io.open(f.."/"..k,"r")
if not b then return nil end
local f=b:read("*a")
b:close()
local i=load("return "..f,"="..k,"t",{})
local f,b=pcall(i or error)
return f and type(b)=="table"and b or nil
end
local function v(f,i)
local b=io.open(f.."/"..k,"w")
if not b then return false end
b:write(l(i),"\n")
b:close()
return true
end
local b=(c.to or"/"):gsub("/+$","")
if b==""then b="/"end
local f=d(b)or{}
local j=c.repo or f.repo or"Faticc/dwos"
local i=c.branch or f.branch or"main"
local m=c.dir or f.dir or"dist"
local n=m~=""and(m:gsub("/+$","").."/")or""
local function l(c)
return(b=="/"and""or b).."/"..c
end
if not o.isAvailable("internet")then g("нужна интернет-карта")end
local d=i
do
local c=h.get(("https://api.github.com/repos/%s/commits/%s"):format(j,i),
{headers={["accept"]="application/vnd.github.sha"}})
c=c and c:match("^%s*(%x+)%s*$")
if c and#c==40 then d=c end
end
local w=("https://raw.githubusercontent.com/%s/%s/%s"):format(j,d,n)
print(("DwOS: %s@%s%s/%s"):format(j,i,d~=i and(" ("..d:sub(1,7)..")")or"",
n~=""and n or"."))
local c,d=h.get(w.."manifest.lua")
if not c then g("manifest.lua: "..tostring(d))end
local n,d=load("return "..c,"=manifest","t",{})
if not n then g("manifest.lua не читается: "..tostring(d))end
local d=n()
if type(d)~="table"or type(d.files)~="table"then
g("manifest.lua не похож на манифест")
end
print(("Ставится в %s%s"):format(b,e and"   (проба, ничего не меняю)"or""))
local x={}
for c,c in ipairs(d.keep or{})do x[c]=true end
local r=f.files or{}
local f={repo=j,branch=i,dir=m,version=d.version,files={}}
local function y(c,i)
if p or not a.exists(i)or a.isDirectory(i)then return false end
if not c.crc then return false end
local n,o=a.size(i),a.lastModified(i)
if c.size and n~=c.size then return false end
local j=r[c[1]]
local m
if not q and j and j.crc and j.size==n and j.mtime==o then
m=j.crc
else
m=s(i)
end
if m==c.crc then
f.files[c[1]]={size=n,crc=m,mtime=o}
return true
end
return false
end
local s,i,m,j,n=0,0,0,0,0
local o,p,t={},{},{}
for c,u in ipairs(d.files)do
local c=u[1]
local q=l(c)
o[c]=true
if x[c]and a.exists(q)then
n=n+1
elseif c==".prop"and not a.exists(q)then
o[c]=nil
elseif y(u,q)then
i=i+1
else
p[#p+1]=u
t[c]=a.exists(q)
if e then print(("  %-28s %s"):format(c,t[c]and"обновится"or"скачается"))end
end
end
if not e and#p>0 then
local c,q=h.files{
base=w,need=p,all=d.files,pack=d.pack,
path=function(c)return l(c[1])end,
done=function(c,d,h,h)
if d then
s,m=s+d,m+1
f.files[c[1]]={size=d,crc=c.crc,mtime=a.lastModified(l(c[1]))}
print(("  %-28s %s, %d Б"):format(c[1],t[c[1]]and"обновлён"or"скачан",d))
elseif h==404 then
print(("  %-28s в репозитории нет, пропускаю"):format(c[1]))
end
end,
}
local c
for d,d in ipairs(q)do
if d.code~=404 then c=c or d end
end
if c then
for d,h in pairs(r)do
if not f.files[d]and o[d]then f.files[d]=h end
end
v(b,f)
g("не скачался "..c.entry[1]..": "..tostring(c.err))
end
end
for c in pairs(r)do
if not o[c]then
local d=l(c)
if a.exists(d)and not a.isDirectory(d)then
print(("  %-28s %s"):format(c,e and"удалится"or"удалён - его больше нет в сборке"))
if not e then a.remove(d)end
j=j+1
end
end
end
if e then
print(("Проба: без изменений %d, своих не трогаю %d, к удалению %d."):format(i,n,j))
return 0
end
if not v(b,f)then
print("  внимание: не записать "..b.."/"..k)
end
if m==0 and j==0 then
print(("Всё свежее, файлов %d (своих не трогал %d)."):format(i,n))
else
print(("Готово: скачано %d (%d Б), без изменений %d, удалено %d."):format(m,s,i,j))
print("Перезагрузись, чтобы новая система заработала целиком: reboot")
end
return 0
