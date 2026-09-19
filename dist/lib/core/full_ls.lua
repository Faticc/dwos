local fs=require("filesystem")
local shell=require("shell")
local tty=require("tty")
local unicode=require("unicode")
local dirsArg,ops=shell.parse(...)
if ops.help then
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
if#dirsArg==0 then
dirsArg[1]="."
end
local ec=0
local fOut=tty.isAvailable()and io.output().tty
local function perr(msg)io.stderr:write(msg,"\n")ec=2 end
local set_color=function()end
local colorize=function()end
if fOut and not ops["no-color"]then
local LSC={}
for pair in(os.getenv("LS_COLORS")or""):gmatch("[^:]+")do
local k,v=pair:match("^(.-)=(.*)$")
if k then LSC[k]=v end
end
colorize=function(info)
return info.isLink and LSC.ln or info.isDir and LSC.di or LSC["*"..info.ext]or LSC.fi
end
set_color=function(c)
io.write("\27[",c or"","m")
end
end
local msft={reports=0,proxies={}}
function msft.report(files,dirs,used,proxy)
local free=proxy.spaceTotal()-proxy.spaceUsed()
set_color()
io.write(string.format("%5i File(s) %s bytes\n%5i Dir(s)  %11s bytes free\n",files,tostring(used),dirs,tostring(free)))
end
function msft.tail(names)
local fsproxy=fs.get(names.path)
if not fsproxy then return end
local size,nfiles,ndirs=0,0,0
for _,info in ipairs(names)do
if info.isDir then ndirs=ndirs+1 else nfiles=nfiles+1 end
size=size+info.size
end
msft.report(nfiles,ndirs,size,fsproxy)
local p=msft.proxies[fsproxy]or{files=0,dirs=0,used=0}
msft.proxies[fsproxy]=p
p.files,p.dirs,p.used=p.files+nfiles,p.dirs+ndirs,p.used+size
msft.reports=msft.reports+1
end
function msft.final()
if msft.reports<2 then return end
local groups={}
for proxy,report in pairs(msft.proxies)do
groups[#groups+1]={proxy=proxy,report=report}
end
set_color()
print("Total Files Listed:")
for _,pair in ipairs(groups)do
if#groups>1 then
print("As pertaining to: "..pair.proxy.address)
end
msft.report(pair.report.files,pair.report.dirs,pair.report.used,pair.proxy)
end
end
if not ops.M then
msft.tail=function()end
msft.final=function()end
end
local function nod(n)
return n and(tostring(n):gsub("(%.[0-9]+)0+$","%1"))or"0"
end
local function formatSize(size)
if not ops.h and not ops["human-readable"]and not ops.si then
return tostring(size)
end
local sizes={"","K","M","G"}
local unit=1
local power=ops.si and 1000 or 1024
while size>power and unit<#sizes do
unit=unit+1
size=size/power
end
return nod(math.floor(size*10)/10)..sizes[unit]
end
local function pad(txt)
txt=tostring(txt)
return#txt>=2 and txt or"0"..txt
end
local MONTHS={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local function formatDate(epochms)
if epochms==0 then return""end
local d=os.date("*t",epochms)
local day,hour,min,sec=nod(d.day),pad(nod(d.hour)),pad(nod(d.min)),pad(nod(d.sec))
if ops["full-time"]then
return string.format("%s-%s-%s %s:%s:%s ",d.year,pad(nod(d.month)),pad(day),hour,min,sec)
end
return string.format("%s %2s %2s:%2s ",MONTHS[d.month],day,hour,pad(min))
end
local function filter(names)
if ops.a then
return names
end
local set={path=names.path}
for _,info in ipairs(names)do
if fs.name(info.name):sub(1,1)~="."then
set[#set+1]=info
end
end
return set
end
local function sort(names)
local cmp
if ops.S then
cmp=function(a,b)if a.size~=b.size then return a.size>b.size end return a.sort_name<b.sort_name end
elseif ops.t then
cmp=function(a,b)if a.time~=b.time then return a.time>b.time end return a.sort_name<b.sort_name end
elseif ops.X then
cmp=function(a,b)if a.ext~=b.ext then return a.ext<b.ext end return a.sort_name<b.sort_name end
else
cmp=function(a,b)return a.sort_name<b.sort_name end
end
table.sort(names,cmp)
if ops.r or ops.reverse then
for i=1,math.floor(#names/2)do
names[i],names[#names-i+1]=names[#names-i+1],names[i]
end
end
return names
end
local function dig(names,dirs,dir)
if ops.R then
local di=1
for _,info in ipairs(names)do
if info.isDir then
table.insert(dirs,di,dir..(dir:sub(-1)=="/"and""or"/")..info.name)
di=di+1
end
end
end
return names
end
local first_display=true
local function emit(color,name)
first_display=false
set_color(color)
io.write(name)
end
local function display(names)
if ops.l then
local size_w,date_w=1,0
for _,info in ipairs(names)do
size_w=math.max(size_w,formatSize(info.size):len())
date_w=math.max(date_w,formatDate(info.time):len())
end
local format="%s-r%s %"..size_w.."s "..(date_w>0 and"%"..date_w.."s"or"%s")
for _,info in ipairs(names)do
local file_type=info.isLink and"l"or info.isDir and"d"or"f"
local link=info.isLink and string.format(" -> %s",info.link:gsub("/+$","")..(info.isDir and"/"or""))or""
emit(nil,string.format(format,file_type,info.fs.isReadOnly()and"-"or"w",formatSize(info.size),formatDate(info.time)))
emit(colorize(info),info.name..link)
set_color()
print()
end
elseif ops["1"]or not fOut then
for _,info in ipairs(names)do
emit(colorize(info),info.name)
set_color()
print()
end
elseif#names>0 then
local width=tty.getViewport()-1
local lens={}
for i,info in ipairs(names)do lens[i]=unicode.wlen(info.name)end
local rows,cols,colw
for r=1,#names do
rows,cols,colw=r,math.ceil(#names/r),{}
local total=0
for c=1,cols do
local m=0
for i=(c-1)*r+1,math.min(c*r,#names)do m=math.max(m,lens[i])end
colw[c]=m
total=total+m+(c>1 and 2 or 0)
end
if total<width then break end
end
for r=1,rows do
for c=1,cols do
local i=(c-1)*rows+r
local info=names[i]
if info then
local gap=c<cols and 2 or 0
emit(colorize(info),info.name..string.rep(" ",colw[c]-lens[i]+gap))
end
end
set_color()
print()
end
end
msft.tail(names)
end
local header=function()end
if#dirsArg>1 or ops.R then
header=function(path)
if not first_display then print()end
set_color()
io.write(path,":\n")
end
end
local function stat(path,name)
local info={key=name}
info.path=name:sub(1,1)=="/"and""or path
info.full_path=fs.concat(info.path,name)
info.isDir=fs.isDirectory(info.full_path)
info.name=name:gsub("/+$","")..(ops.p and info.isDir and"/"or"")
info.sort_name=info.name:gsub("^%.","")
info.isLink,info.link=fs.isLink(info.full_path)
info.size=info.isLink and 0 or fs.size(info.full_path)
info.time=fs.lastModified(info.full_path)/1000
info.fs=fs.get(info.full_path)
info.ext=info.name:match("(%.[^.]+)$")or""
return info
end
local function displayDirList(dirs)
while#dirs>0 do
local dir=table.remove(dirs,1)
header(dir)
local path=shell.resolve(dir)
local list,reason=fs.list(path)
if not list then
perr(reason)
else
local names={path=path}
for name in list do
names[#names+1]=stat(path,name)
end
display(dig(sort(filter(names)),dirs,dir))
end
end
end
local dir_set,file_set={},{path=shell.getWorkingDirectory()}
for _,dir in ipairs(dirsArg)do
local path=shell.resolve(dir)
local real,why=fs.realPath(path)
local access_msg="cannot access "..tostring(path)..": "
if not real then
perr(access_msg..why)
elseif not fs.exists(path)then
perr(access_msg.."No such file or directory")
elseif fs.isDirectory(path)then
dir_set[#dir_set+1]=dir
else
file_set[#file_set+1]=stat(dir,dir)
end
end
io.output():setvbuf("line")
local ok,msg=pcall(function()
if#file_set>0 then display(sort(file_set))end
displayDirList(dir_set)
msft.final()
end)
io.output():flush()
io.output():setvbuf("no")
assert(ok,msg)
return ec
