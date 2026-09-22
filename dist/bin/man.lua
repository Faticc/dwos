local a=require("filesystem")
local c=require("shell")
local g=c.parse(...)
local d={}
for b in string.gmatch(os.getenv("MANPATH")or"/usr/man","[^:]+")do
d[#d+1]=b
end
local h="pages"
local function i(e)
local b=io.open(a.concat(e,h),"rb")
if not b then return nil end
local f=b:read("*l")=="DWMAN1"
local e=f and tonumber(b:read("*l")or"")
if not e then b:close()return nil end
local f,j={},{}
for k=1,e do
local e,l,m=(b:read("*l")or""):match("^(%S+) (%d+) (%d+)$")
if not e then b:close()return nil end
f[e]={tonumber(l),tonumber(m)}
j[k]=e
end
return b,f,j,b:seek()
end
local function k(e,f)
local b,j,l,l=i(e)
if not b then return nil end
local e=j[f]
if not e then b:close()return nil end
b:seek("set",l+e[1])
local f=b:read(e[2])
b:close()
return f
end
if#g==0 then
local b,f={},{}
local function j(e)
if not f[e]then
f[e]=true
b[#b+1]=e
end
end
for e,e in ipairs(d)do
local f=c.resolve(e)
if e~="."and a.isDirectory(f)then
for e in a.list(f)do
e=e:gsub("/$","")
if e~=h then j(e)end
end
local e,h,h=i(f)
if e then
e:close()
for e,e in ipairs(h)do j(e)end
end
end
end
table.sort(b)
io.write("Usage: man <topic>\nСправка есть по темам:\n")
local e=1
for f,f in ipairs(b)do e=math.max(e,#f+2)end
local f=math.max(1,math.floor(((require("tty").getViewport())or 80)/e))
for i,h in ipairs(b)do
io.write(h,string.rep(" ",e-#h))
if i%f==0 then io.write("\n")end
end
if#b%f~=0 then io.write("\n")end
return 1
end
local b=g[1]
local f=os.getenv("PAGER")or"less"
for e,g in ipairs(d)do
local e=c.resolve(g)
local d=c.resolve(a.concat(g,b),"man")
if d and a.exists(d)and not a.isDirectory(d)then
os.execute(f.." "..d)
os.exit()
end
if e and a.isDirectory(e)then
local c=k(e,b)
if c then
local d="/tmp/man."..b:gsub("[^%w%._-]","_")
local e=io.open(d,"wb")
if not e then
io.write(c)
os.exit()
end
e:write(c)
e:close()
os.execute(f.." "..d)
a.remove(d)
os.exit()
end
end
end
io.stderr:write("No manual entry for "..b.."\n")
return 1
