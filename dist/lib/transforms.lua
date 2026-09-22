local a={}
a.internal={}
function a.internal.range_adjust(b,c,d)
checkArg(1,b,"number","nil")
checkArg(2,c,"number","nil")
checkArg(3,d,"number")
if b==nil then b=1 elseif b<0 then b=d+b+1 end
if c==nil then c=d elseif c<0 then c=d+c+1 end
return b,c
end
function a.internal.table_view(d,e,c)
return setmetatable({},{
__index=function(b,b)
return(type(b)~="number"or(b>=e and b<=c))and d[b]or nil
end,
__len=function()return c end,
})
end
local f=a.internal.range_adjust
local i=a.internal.table_view
function a.first(b,c,d,e)
checkArg(1,b,"table")
checkArg(2,c,"function","table")
if type(c)=="table"then
local g=c
c=function(h,j,k)
for l=1,#g do
local h=g[l]
if a.begins(k,h,j)then return true,#h end
end
end
end
local g=#b
d,e=f(d,e,g)
b=i(b,d,e)
for g=d,e do
local d,e=c(b[g],g,b)
if d then
return g,g+(e or 1)-1
end
end
end
function a.begins(c,d,b,e)
checkArg(1,c,"table")
checkArg(2,d,"table")
local g=#d
b,e=f(b,e,#c)
if g>(e-b+1)then return end
for e=1,g do
if c[b+e-1]~=d[e]then return end
end
return true
end
function a.concat(...)
local d,c,e={},0
for g,b in ipairs({...})do
if type(b)~="table"then
return nil,"parameter "..tostring(g).." to concat is not a table"
end
local g=b.n or#b
e=e or b.n
for h=1,g do
c=c+1
d[c]=b[h]
end
end
d.n=e and c or nil
return d
end
function a.sub(c,d,b)
checkArg(1,c,"table")
local e,g={},#c
d,b=f(d,b,g)
b=math.min(b,g)
for g=math.max(d,1),b do
e[#e+1]=c[g]
end
return e
end
function a.partition(c,h,j,b,g)
checkArg(1,c,"table")
checkArg(2,h,"function","table")
checkArg(3,j,"boolean","nil")
if type(h)=="table"then
return a.partition(c,function(d,d,e)
return a.first(e,h,d)
end,j,b,g)
end
local d=#c
b,g=f(b,g,d)
local k=i(c,b,g)
local c={}
local l=true
local function n()if l then c[#c+1]={}l=false end end
local d=b
while d<=g do
local m=k[d]
local b,e=h(m,d,k)
if b==true then b,e=d,d
elseif b==false then b,e=nil,nil end
if b~=nil then
b,e=f(b,e,g)
b=b>=d and b
end
if not b then
n()
table.insert(c[#c],m)
else
local g=a.sub(k,d,not j and e or(b-1))
if#g>0 then
n()
c[#c+math.min(#c[#c],1)]=g
end
local g=math.max(math.max(e or b,b),d)
if e and b and e<b and g==d then
if#c==0 then c[1]={}end
table.insert(c[#c],m)
end
d=g
l=true
end
d=d+1
end
return c
end
function a.foreach(b,c,d,e)
checkArg(1,b,"table")
checkArg(2,c,"function","string")
local g=c
c=type(c)=="string"and function(h)return h[g]end or c
local g=#b
d,e=f(d,e,g)
b=i(b,d,e)
local f={}
for g=d,e do
local d,e=c(b[g],g,b)
if d~=nil then
if e then f[e]=d else f[#f+1]=d end
end
end
return f
end
function a.where(b,c,d,e)
return a.foreach(b,function(b,f,g)return c(b,f,g)and b or nil end,d,e)
end
function a.at(c,d)
checkArg(1,c,"table")
checkArg(2,d,"number","nil")
local b=1
for e,f in pairs(c)do
if b==d then
return e,f
end
b=b+1
end
return nil,b-1
end
return a
