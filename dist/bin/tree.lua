local b=require("computer")
local i=require("shell")
local c=require("filesystem")
local h,a=i.parse(...)
local function f(...)
io.stderr:write(...)
os.exit(1)
end
if a.help then
print([[Usage: tree [OPTION]... [FILE]...
  -a, --all             do not ignore entries starting with .
      --full-time       with -l, print time in full iso format
  -h, --human-readable  with -l, print human readable sizes
      --si              likewise, but use powers of 1000 not 1024
      --level=LEVEL     descend only LEVEL directories deep
      --color=WHEN      WHEN can be
                        auto - colorize output only if writing to a tty,
                        always - always colorize output,
                        never - never colorize output; (default: auto)
  -l                    use a long listing format
  -f                    print the full path prefix for each file
  -i                    do not print indentation lines
  -p                    append "/" indicator to directories
  -Q, --quote           quote filenames with double quotes
  -r, --reverse         reverse order while sorting
  -S                    sort by file size
  -t                    sort by modification type, newest first
  -X                    sort alphabetically by entry extension
  -C                    do not count files and directories
  -R                    count root directories like other files
      --help            print this help and exit]])
return 0
end
if#h==0 then
h[1]="."
end
a.level=tonumber(a.level)or math.huge
if a.level<1 then
f("Invalid level, must be greater than 0")
end
a.color=a.color or"auto"
if a.color=="auto"then
a.color=io.stdout.tty and"always"or"never"
end
if a.color~="always"and a.color~="never"then
f("Invalid value for --color=WHEN option; WHEN should be auto, always or never")
end
local d=b.uptime()
local function p()
if b.uptime()-d>2 then
d=b.uptime()
os.sleep(0)
end
end
local function j(d)
local b={path=d}
b.name=c.name(d)or"/"
b.sortName=b.name:gsub("^%.","")
b.time=c.lastModified(d)
b.isLink=c.isLink(d)
b.isDirectory=c.isDirectory(d)
b.size=b.isLink and 0 or c.size(d)
b.extension=b.name:match("(%.[^.]+)$")or""
b.fs=c.get(d)
return b
end
local g
if a.color=="always"then
local b={}
for e in(os.getenv("LS_COLORS")or""):gmatch("[^:]+")do
local d,k=e:match("^(.-)=(.*)$")
if d then b[d]=k end
end
function g(d)
return d.isLink and b.ln or d.isDirectory and b.di or b["*"..d.extension]or b.fi
end
end
local d={
S=function(b,e)return b.size<e.size end,
t=function(b,e)return b.time<e.time end,
X=function(b,e)return b.extension<e.extension end,
}
local function q(e)
local b={}
for k in c.list(e)do
if a.a or k:sub(1,1)~="."then
b[#b+1]=j(c.concat(e,k))
end
end
table.sort(b,a.S and d.S or a.t and d.t or a.X and d.X or
function(d,e)return d.sortName<e.sortName end)
if a.r then
for d=1,math.floor(#b/2)do b[d],b[#b-d+1]=b[#b-d+1],b[d]end
end
return b
end
local function d(b)
return b and(tostring(b):gsub("(%.[0-9]+)0+$","%1"))or"0"
end
local function n(b)
if not a.h and not a["human-readable"]and not a.si then
return tostring(b)
end
local k={"","K","M","G"}
local e=1
local l=a.si and 1000 or 1024
while b>l and e<#k do
e=e+1
b=b/l
end
return d(math.floor(b*10)/10)..k[e]
end
local function e(b)
b=tostring(b)
return#b>=2 and b or"0"..b
end
local o={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local function r(k)
if k==0 then return""end
local b=os.date("*t",k)
local k,l,m,s=d(b.day),e(d(b.hour)),e(d(b.min)),e(d(b.sec))
if a["full-time"]then
return string.format("%s-%s-%s %s:%s:%s ",b.year,e(d(b.month)),e(k),l,m,s)
end
return string.format("%s %2s %2s:%2s ",o[b.month],k,l,e(m))
end
local function k(b,d)
if not a.i then
for l,e in ipairs(d)do
if l==#d then
io.write(e and"├── "or"└── ")
else
io.write(e and"│\194\160\194\160 "or"    ")
end
end
end
if a.l then
io.write("[",b.isDirectory and"d"or b.isLink and"l"or"f","-")
io.write("r",b.fs.isReadOnly()and"-"or"w"," ")
io.write(n(b.size)," ",r(b.time),"] ")
end
if a.Q then io.write('"')end
if g then io.write("\27["..g(b).."m")end
io.write(a.f and b.path or b.name)
if g then io.write("\27[0m")end
if a.p and b.isDirectory then io.write("/")end
if a.Q then io.write('"')end
io.write("\n")
end
local d,e=0,0
local function l(b,g)
if a.R or g>0 then
if b.isDirectory then d=d+1 else e=e+1 end
end
end
local function m(n,b)
local o=q(n)
for q,g in ipairs(o)do
b[#b+1]=q<#o
l(g,#b)
k(g,b)
p()
if g.isDirectory and a.level>#b then
m(c.concat(n,g.name),b)
end
b[#b]=nil
end
end
for b,g in ipairs(h)do
local b=i.resolve(g)
local g,h=c.realPath(b)
if not g then
f("cannot access ",b,": ",h or"unknown error")
elseif not c.exists(b)then
f("cannot access ",b,":","No such file or directory")
end
local b=j(g)
l(b,0)
k(b,{})
if b.isDirectory then
m(g,{})
end
end
if not a.C then
io.write("\n",d," director",d==1 and"y"or"ies",", ",e," file",e==1 and""or"s","\n")
end
