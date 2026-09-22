local a=require("text")
local b=require("unicode")
local k=require("process")
local l=require("buffer")
function a.tokenize(e,c)
checkArg(1,e,"string")
checkArg(2,c,"table","nil")
c=c or{}
local d,f=a.internal.tokenize(e,c)
if type(d)~="table"then
return nil,f
end
if c.doNotNormalize then
return d
end
return a.internal.normalize(d)
end
function a.split(c,e,i,d)
checkArg(1,c,"string")
checkArg(2,e,"table")
checkArg(3,i,"boolean","nil")
checkArg(4,d,"number","nil")
if#c==0 then return{}end
d=d or 1
local f={c}
if d>#e then return f end
local function g(j,c,m,n,o)
local h=j:sub(n,o)
if#h==0 then return c end
local j=m and a.split(h,e,i,m)or{h}
for h=1,#j do
table.insert(f,c+h-1,j[h])
end
return c+#j
end
local c,m=1,e[d]
while true do
local e=table.remove(f,c)
if not e then break end
local j,h=e:find(m)
if j and h and h~=0 then
c=g(e,c,d+1,1,j-1)
c=i and c or g(e,c,false,j,h)
c=g(e,c,d,h+1)
else
c=g(e,c,d+1,1,#e)
end
end
return f
end
function a.internal.splitWords(e,f)
checkArg(1,e,"table")
checkArg(2,f,"table")
local d={}
local c
local function g(h)
if c then
d[#d+1]={}
end
table.insert(d[#d],h)
c=false
end
for i=1,#e do
local h=e[i]
c=true
for i=1,#h do
local e=h[i]
local h=e.qr
if h then
g(e)
else
for i,i in ipairs(a.split(e.txt,f))do
local e=#a.split(i,f,true)==0
c=c or e
g({txt=i,qr=h})
c=e
end
end
end
end
return d
end
function a.internal.normalize(c,f)
checkArg(1,c,"table")
checkArg(2,f,"boolean","nil")
local e={}
for d,g in ipairs(c)do
local c={}
for d,d in ipairs(g)do
if not f and d.qr then
c[#c+1]=d.qr[1]
c[#c+1]=d.txt
c[#c+1]=d.qr[2]
else
c[#c+1]=d.txt
end
end
e[#e+1]=table.concat(c)
end
return e
end
function a.internal.stream_base(c)
return{
binary=c,
plen=c and string.len or b.len,
psub=c and string.sub or b.sub,
seek=function(d,f,e)
if not d.txt then
return nil,"bad file descriptor"
end
e=e or 0
local c=d:indexbytes()
if f=="cur"then
c=c+e
elseif f=="set"then
c=e
elseif f=="end"then
c=d.len+e
end
c=math.max(0,math.min(c,d.len))
d:byteindex(c)
return c
end,
indexbytes=function(c)
return c.psub(c.txt,1,c.index):len()
end,
byteindex=function(c,d)
c.index=c.plen(string.sub(c.txt,1,d))
end,
}
end
function a.internal.reader(c,d)
checkArg(1,c,"string")
local g=setmetatable({
txt=c,
len=string.len(c),
index=0,
read=function(c,e)
checkArg(1,e,"number")
if not c.txt then
return nil,"bad file descriptor"
end
if c.index>=c.plen(c.txt)then
return nil
end
local f=c.psub(c.txt,c.index+1,c.index+e)
c.index=c.index+c.plen(f)
return f
end,
close=function(c)
if not c.txt then
return nil,"bad file descriptor"
end
c.txt=nil
return true
end,
},{__index=a.internal.stream_base((d or""):match("b"))})
return k.addHandle(l.new((d or"r"):match("[rb]+"),g))
end
function a.internal.writer(d,e,f)
if type(d)=="table"then
local c=getmetatable(d)or{}
checkArg(1,c.__call,"function")
end
checkArg(1,d,"function","table")
checkArg(2,f,"string","nil")
local h=setmetatable({
txt="",
index=0,
len=0,
write=function(c,...)
if not c.txt then
return nil,"bad file descriptor"
end
local i=c.psub(c.txt,1,c.index)
local j=c.psub(c.txt,c.index+1)
local g=table.concat({...})
c.index=c.index+c.plen(g)
c.txt=i..g..j
c.len=string.len(c.txt)
return true
end,
close=function(c)
if not c.txt then
return nil,"bad file descriptor"
end
d((f or"")..c.txt)
c.txt=nil
return true
end,
},{__index=a.internal.stream_base((e or""):match("b"))})
return k.addHandle(l.new((e or"w"):match("[awb]+"),h))
end
function a.detab(d,c)
checkArg(1,d,"string")
checkArg(2,c,"number","nil")
c=c or 8
local function f(e)
return e..string.rep(" ",c-e:len()%c)
end
return(d:gsub("([^\n]-)\t",f))
end
function a.padLeft(c,d)
checkArg(1,c,"string","nil")
checkArg(2,d,"number")
if not c or b.wlen(c)==0 then
return string.rep(" ",d)
end
return string.rep(" ",d-b.wlen(c))..c
end
function a.padRight(c,d)
checkArg(1,c,"string","nil")
checkArg(2,d,"number")
if not c or b.wlen(c)==0 then
return string.rep(" ",d)
end
return c..string.rep(" ",d-b.wlen(c))
end
function a.wrap(c,f,g)
checkArg(1,c,"string")
checkArg(2,f,"number")
checkArg(3,g,"number")
local d,h=c:match("([^\r\n]*)(\r?\n?)")
if b.wlen(d)>f then
local e=b.wtrunc(d,f)
local f=e:match("(.*[^a-zA-Z0-9._()'`=])")
if f or b.wlen(d)>g then
e=f or e
return e,b.sub(c,b.len(e)+1),true
end
return"",c,true
end
local e=b.len(d)+b.len(h)+1
return d,e<=b.len(c)and b.sub(c,e)or nil,b.len(h)>0
end
function a.wrappedLines(b,d,e)
local c
return function()
if b then
c,b=a.wrap(b,d,e)
return c
end
end
end
