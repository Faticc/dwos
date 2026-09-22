local e=require("filesystem")
local t=require("process")
local f=require("shell")
local b=require("text")
local c=require("unicode")
local a=require("sh")
local k=a.internal.isWordOf
function a.internal.command_passed(d)
return a.internal.command_result_as_code(d)==0
end
function a.internal.buildCommandRedirects(n)
local l={}
local i=1
local o,g,d
local p="syntax error near unexpected token "
while true do
local j=n[i]
if not j then break end
local m=j[1]
local h=not j[2]and not m.qr and m.txt or""
local q,q,q,r,s=h:find("(%d*)([<>]>?)%&?(.*)")
if r then
if d then
return nil,p..h
end
d=assert(({["<"]="r",[">"]="w",[">>"]="a"})[r],"redirect failed to detect mode")
o=q~=""and tonumber(q)or d=="r"and 0 or 1
g=s~=""and tonumber(s)
elseif d then
h=a.internal.evaluate({j})
if#h>1 then
return nil,string.format("%s: ambiguous redirect",m.txt)
end
g=h[1]
else
i=i+1
end
if d then
table.remove(n,i)
end
if g then
l[#l+1]={o,g,d}
d,g=nil,nil
end
end
if d then
return nil,p.."newline"
end
return l
end
function a.internal.openCommandRedirects(d)
local g=t.info().data.io
for h,i in ipairs(d)do
local h,d,j=table.unpack(i)
if type(d)=="number"then
g[h]=io.dup(g[d])
else
local i,l=io.open(f.resolve(d),j)
if not i then
io.stderr:write("could not open '"..d.."': "..l.."\n")
os.exit(1)
end
g[h]=i
end
end
end
function a.internal.glob(j)
local l={{"*",".*"},{"?","."}}
local g=""
local i
for d,h in ipairs(j)do
local d=h.txt
if not h.qr then
local m=b.escapeMagic(d)
d=m
for h,h in ipairs(l)do
local n=b.escapeMagic(h[1]):rep(2)
while true do
local o=d
d=d:gsub(n,h[1])
if o==d then break end
end
d=d:gsub("%%%"..h[1],h[2])
end
i=i or d~=m
end
g=g..d
end
if not i then
return{j.txt}
end
local d=b.split(g,{"/"},true)
local h={}
for i,m in ipairs(d)do h[i]=m:match("^%%%.")==nil end
local function o(i,m)
return not h[m]or i:match("^%.")==nil
end
local function n(h)
for i,i in ipairs(l)do
if(" "..h):match("[^%%]"..b.escapeMagic(i[2]))then
return true
end
end
end
local i=g:sub(1,1)=="/"
local l=i and""or f.getWorkingDirectory():gsub("([^/])$","%1/")
local h={i and"/"or""}
local i=""
for p,m in ipairs(d)do
local q=string.format("^(%s)/?$",m)
local d={}
for g,g in ipairs(h)do
if e.isDirectory(l..g)then
if n(m)then
for n in e.list(l..g)do
if n:match(q)and o(n,p)then
d[#d+1]=g..i..n:gsub("/+$","")
end
end
else
local n=b.removeEscapes(m)
local m=l..g..i..n
if e.exists(m)then
d[#d+1]=g..i..n:gsub("/+$","")
end
end
end
end
h=d
if not next(h)then
return{j.txt}
end
i="/"
end
return h
end
function a.getMatchingPrograms(g)
if not g or g==""then return{}end
local h,i={},{}
local function j(d)
if d:find(g,1,true)==1 and not i[d]then
h[#h+1]=d
i[d]=true
end
end
for d in f.aliases()do
j(d)
end
for d in string.gmatch(os.getenv("PATH"),"[^:]+")do
for g in e.list(f.resolve(d))do
j((g:gsub("%.lua$","")))
end
end
return h
end
function a.getMatchingFiles(d)
local g=d:gsub("^.*/","")
local i=c.sub(d,1,-c.len(g)-1)
local j=f.resolve(i)
local d,h={}
if e.isDirectory(j)and g==""then
h="^(.-)/?$"
else
h="^("..b.escapeMagic(g)..".-)/?$"
end
for l in e.list(j)do
local g=l:match(h)
if g then
d[#d+1]=i..g:gsub("(%s)","\\%1")
end
end
if#d==1 and e.isDirectory(f.resolve(d[1]))then
d[1]=d[1].."/"
end
return d
end
function a.internal.hintHandlerSplit(e)
if e:match("\\$")then return nil end
local d=b.internal.tokenize(e,{show_escapes=true})
if not d then
return nil
end
local f=#d
local g=0
for h=f,1,-1 do
if k(d[h],{";","&&","||","|"})then
g=h
break
end
end
if g==f then
return nil
end
local h=d[f]
local d=b.internal.normalize({h})[1]
if c.sub(e,-c.len(d))~=d then
return e,nil,""
end
local h=c.sub(e,1,-c.len(d)-1)
d=b.internal.normalize(b.internal.tokenize(d),true)[1]
if g==f-1 then
return h,d,nil
end
return h,nil,d
end
function a.internal.hintHandlerImpl(d,e)
local h=c.sub(d,1,e-1)
local i=c.sub(d,e)
local f,g,e=a.internal.hintHandlerSplit(h)
if not f then
return{}
end
local d
local j=g and not g:find("/")
if j then
d=a.getMatchingPrograms(g)
else
if e then
local h=e:find("=[^=]*$")
if h then
f=f..c.sub(e,1,h)
e=c.sub(e,h+1)
end
end
d=a.getMatchingFiles(g or e)
end
local e=i
if#d>0 and c.sub(d[1],-1)~="/"and
not i:sub(1,1):find("%s")and
#d==1 or j then
e=" "..e
end
table.sort(d)
for c=1,#d do
d[c]=f..d[c]..e
end
return d
end
function a.internal.hasValidPiping(d,e)
checkArg(1,d,"table")
checkArg(2,e,"table","nil")
if#d==0 then
return true
end
e=e or{"&&","||?"}
local c=""
for g=1,#d do
local f=d[g]
for g=1,#f do
local d=f[g]
if d.qr then
c=nil
elseif d.txt==""then
c=nil
elseif#b.split(d.txt,e,true)==0 then
local e=c
c=d.txt
if e then
f=nil
break
end
else
c=nil
end
end
if not f then
break
end
end
if c then
return false,"syntax error near unexpected token "..c
end
return true
end
function a.internal.boolean_executor(h,f)
local function m(c,d)
return a.internal.command_passed(c)and 1 or 0,d
end
local e=true
local n
local p,i,j=1,2,0
local d=i
local l=false
for o=1,#h do
local c=h[o]
local g=#c==1 and#c[1]==1 and not c[1][1].qr and c[1][1].txt
if g=="||"or g=="&&"then
if d~=j or#h==0 then
return nil,"syntax error near unexpected token '"..g.."'"
end
local h=a.internal.command_passed(e)
if(g=="||")==h then
l=true
end
d=p
elseif not l then
local g=#c
local h=a.internal.remove_negation(c)
g=g~=#c
if h then
local h=f
f=function(p,q)
local r,s=m(h(p,q))
f=h
return r,s
end
end
if g then
d=i
end
if#c>0 then
e,n=f(c,o)
d=j
end
else
l=false
d=j
end
end
if d==i then
e=m(e)
end
return e,n
end
local function e(g,h,i)
local d,c={},nil
for f,f in ipairs(g)do
if k(f,h)then
if i then d[#d+1]={f}end
c=nil
else
if not c then
c={}
d[#d+1]=c
end
c[#c+1]=f
end
end
return d
end
function a.internal.splitStatements(c,d)
checkArg(1,c,"table")
checkArg(2,d,"string","nil")
return e(c,{d or";"})
end
function a.internal.splitChains(c,d)
checkArg(1,c,"table")
checkArg(2,d,"string","nil")
return e(c,{d or"|"})
end
function a.internal.groupChains(c)
checkArg(1,c,"table")
return e(c,{"&&","||"},true)
end
function a.internal.remove_negation(c)
if k(c[1],{"!"})then
table.remove(c,1)
return not a.internal.remove_negation(c)
end
return false
end
function a.internal.execute_complex(d,f,g)
local c=a.internal.splitStatements(d)
for d=1,#c do
local e,h=a.internal.hasValidPiping(c[d])
if not e then return nil,h end
end
for d=1,#c do
local e=a.internal.groupChains(c[d])
local h,i=a.internal.boolean_executor(e,function(j,k)
local l=a.internal.splitChains(j)
local j=k==#e and d==#c and f or{}
return a.internal.executePipes(l,j,g)
end)
a.internal.ec.last=a.internal.command_result_as_code(h,i)
end
return a.internal.ec.last==0
end
function a.internal.evaluate(c)
local e,d=a.internal.buildCommandRedirects(c)
if not e then
return nil,d
end
do
local d=table.concat(b.internal.normalize(c)," ")
local f=a.internal.parse_sub(d)
if f~=d then
c=b.internal.tokenize(f)
end
end
local f=false
for d,g in ipairs(c)do
for d,d in pairs(g)do
if not(d.qr or{})[3]then
local g=a.expand(d.txt)
if g~=d.txt then
d.txt=g
f=true
end
end
end
end
if f then
c=b.internal.tokenize(table.concat(b.internal.normalize(c)," "))
end
local d={}
for b,f in ipairs(c)do
local b={txt=""}
for c,c in ipairs(f)do
b.txt=b.txt..c.txt
b[#b+1]={qr=c.qr,txt=c.txt}
end
for c,c in ipairs(a.internal.glob(b))do
d[#d+1]=c
end
end
return d,e
end
function a.internal.parse_sub(b,a)
if a and a[1]=="`"then
b=string.format("`%s`",b)
a[1],a[2]="",""
end
local a={}
local c,d=1,#b
while c<=d do
local d,e,f=b:find("`([^`]*)`",c)
if not d then
a[#a+1]=b:sub(c)
break
end
a[#a+1]=b:sub(c,d-1)
local b=io.popen(f)
local d=b:read("*a")
b:close()
a[#a+1]=(d:gsub("\n+$",""))
c=e+1
end
return table.concat(a)
end
