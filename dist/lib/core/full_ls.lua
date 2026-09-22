local d=require("filesystem")
local h=require("shell")
local m=require("tty")
local w=require("unicode")
local i,b=h.parse(...)
if b.help then
print([[Usage: ls [OPTION]... [FILE]...
  -a, --all                  do not ignore entries starting with .
      --full-time            with -l, print time in full iso format
  -h, --human-readable       with -l and/or -s, print human readable sizes
      --si                   likewise, but use powers of 1000 not 1024
  -l                         use a long listing format
  -r, --reverse              reverse order while sorting
  -R, --recursive            list subdirectories recursively
  -S                         sort by file size
  -t                         sort by modification time, newest first
  -X                         sort alphabetically by entry extension
  -1                         list one file per line
  -p                         append / indicator to directories
  -M                         display Microsoft-style file and directory
                             count after listing
      --no-color             Do not colorize the output (default colorized)
      --help                 display this help and exit
For more info run: man ls]])
return 0
end
if#i==0 then
i[1]="."
end
local s=0
local o=m.isAvailable()and io.output().tty
local function n(a)io.stderr:write(a,"\n")s=2 end
local f=function()end
local j=function()end
if o and not b["no-color"]then
local a={}
for e in(os.getenv("LS_COLORS")or""):gmatch("[^:]+")do
local c,g=e:match("^(.-)=(.*)$")
if c then a[c]=g end
end
j=function(c)
return c.isLink and a.ln or c.isDir and a.di or a["*"..c.ext]or a.fi
end
f=function(a)
io.write("\27[",a or"","m")
end
end
local c={reports=0,proxies={}}
function c.report(e,g,k,a)
local l=a.spaceTotal()-a.spaceUsed()
f()
io.write(string.format("%5i File(s) %s bytes\n%5i Dir(s)  %11s bytes free\n",e,tostring(k),g,tostring(l)))
end
function c.tail(a)
local e=d.get(a.path)
if not e then return end
local g,k,l=0,0,0
for p,p in ipairs(a)do
if p.isDir then l=l+1 else k=k+1 end
g=g+p.size
end
c.report(k,l,g,e)
local a=c.proxies[e]or{files=0,dirs=0,used=0}
c.proxies[e]=a
a.files,a.dirs,a.used=a.files+k,a.dirs+l,a.used+g
c.reports=c.reports+1
end
function c.final()
if c.reports<2 then return end
local e={}
for a,g in pairs(c.proxies)do
e[#e+1]={proxy=a,report=g}
end
f()
print("Total Files Listed:")
for a,a in ipairs(e)do
if#e>1 then
print("As pertaining to: "..a.proxy.address)
end
c.report(a.report.files,a.report.dirs,a.report.used,a.proxy)
end
end
if not b.M then
c.tail=function()end
c.final=function()end
end
local function e(a)
return a and(tostring(a):gsub("(%.[0-9]+)0+$","%1"))or"0"
end
local function l(a)
if not b.h and not b["human-readable"]and not b.si then
return tostring(a)
end
local k={"","K","M","G"}
local g=1
local p=b.si and 1000 or 1024
while a>p and g<#k do
g=g+1
a=a/p
end
return e(math.floor(a*10)/10)..k[g]
end
local function g(a)
a=tostring(a)
return#a>=2 and a or"0"..a
end
local t={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local function p(k)
if k==0 then return""end
local a=os.date("*t",k)
local k,q,r,u=e(a.day),g(e(a.hour)),g(e(a.min)),g(e(a.sec))
if b["full-time"]then
return string.format("%s-%s-%s %s:%s:%s ",a.year,g(e(a.month)),g(k),q,r,u)
end
return string.format("%s %2s %2s:%2s ",t[a.month],k,q,g(r))
end
local function x(a)
if b.a then
return a
end
local e={path=a.path}
for g,g in ipairs(a)do
if d.name(g.name):sub(1,1)~="."then
e[#e+1]=g
end
end
return e
end
local function t(a)
local e
if b.S then
e=function(g,k)if g.size~=k.size then return g.size>k.size end return g.sort_name<k.sort_name end
elseif b.t then
e=function(g,k)if g.time~=k.time then return g.time>k.time end return g.sort_name<k.sort_name end
elseif b.X then
e=function(g,k)if g.ext~=k.ext then return g.ext<k.ext end return g.sort_name<k.sort_name end
else
e=function(g,k)return g.sort_name<k.sort_name end
end
table.sort(a,e)
if b.r or b.reverse then
for e=1,math.floor(#a/2)do
a[e],a[#a-e+1]=a[#a-e+1],a[e]
end
end
return a
end
local function y(e,q,g)
if b.R then
local a=1
for k,k in ipairs(e)do
if k.isDir then
table.insert(q,a,g..(g:sub(-1)=="/"and""or"/")..k.name)
a=a+1
end
end
end
return e
end
local u=true
local function g(a,e)
u=false
f(a)
io.write(e)
end
local function v(a)
if b.l then
local k,e=1,0
for q,q in ipairs(a)do
k=math.max(k,l(q.size):len())
e=math.max(e,p(q.time):len())
end
local q="%s-r%s %"..k.."s "..(e>0 and"%"..e.."s"or"%s")
for e,e in ipairs(a)do
local k=e.isLink and"l"or e.isDir and"d"or"f"
local r=e.isLink and string.format(" -> %s",e.link:gsub("/+$","")..(e.isDir and"/"or""))or""
g(nil,string.format(q,k,e.fs.isReadOnly()and"-"or"w",l(e.size),p(e.time)))
g(j(e),e.name..r)
f()
print()
end
elseif b["1"]or not o then
for e,e in ipairs(a)do
g(j(e),e.name)
f()
print()
end
elseif#a>0 then
local z=m.getViewport()-1
local o={}
for e,k in ipairs(a)do o[e]=w.wlen(k.name)end
local p,e,q
for k=1,#a do
p,e,q=k,math.ceil(#a/k),{}
local r=0
for l=1,e do
local m=0
for w=(l-1)*k+1,math.min(l*k,#a)do m=math.max(m,o[w])end
q[l]=m
r=r+m+(l>1 and 2 or 0)
end
if r<z then break end
end
for l=1,p do
for k=1,e do
local m=(k-1)*p+l
local l=a[m]
if l then
local p=k<e and 2 or 0
g(j(l),l.name..string.rep(" ",q[k]-o[m]+p))
end
end
f()
print()
end
end
c.tail(a)
end
local g=function()end
if#i>1 or b.R then
g=function(a)
if not u then print()end
f()
io.write(a,":\n")
end
end
local function j(f,e)
local a={key=e}
a.path=e:sub(1,1)=="/"and""or f
a.full_path=d.concat(a.path,e)
a.isDir=d.isDirectory(a.full_path)
a.name=e:gsub("/+$","")..(b.p and a.isDir and"/"or"")
a.sort_name=a.name:gsub("^%.","")
a.isLink,a.link=d.isLink(a.full_path)
a.size=a.isLink and 0 or d.size(a.full_path)
a.time=d.lastModified(a.full_path)/1000
a.fs=d.get(a.full_path)
a.ext=a.name:match("(%.[^.]+)$")or""
return a
end
local function k(a)
while#a>0 do
local b=table.remove(a,1)
g(b)
local e=h.resolve(b)
local g,f=d.list(e)
if not g then
n(f)
else
local f={path=e}
for l in g do
f[#f+1]=j(e,l)
end
v(y(t(x(f)),a,b))
end
end
end
local f,a={},{path=h.getWorkingDirectory()}
for b,b in ipairs(i)do
local e=h.resolve(b)
local h,i=d.realPath(e)
local g="cannot access "..tostring(e)..": "
if not h then
n(g..i)
elseif not d.exists(e)then
n(g.."No such file or directory")
elseif d.isDirectory(e)then
f[#f+1]=b
else
a[#a+1]=j(b,b)
end
end
io.output():setvbuf("line")
local b,d=pcall(function()
if#a>0 then v(t(a))end
k(f)
c.final()
end)
io.output():flush()
io.output():setvbuf("no")
assert(b,d)
return s
