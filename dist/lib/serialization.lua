local j={}
local function o(a)
local b=getmetatable(a)
return(b and b.__pairs or pairs)(a)
end
local p={}
for a in("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+")do
p[a]=true
end
function j.serialize(q,d)
local k={}
local l={}
local function a(b)l[#l+1]=b end
local function g(b,h)
local e=type(b)
if e=="number"then
if b~=b then
a("0/0")
elseif b==math.huge then
a("math.huge")
elseif b==-math.huge then
a("-math.huge")
else
a(tostring(b))
end
elseif e=="string"then
a((string.format("%q",b):gsub("\\\n","\\n")))
elseif e=="nil"or e=="boolean"or d and(e~="table"or(getmetatable(b)or{}).__tostring)then
a(tostring(b))
elseif e=="table"then
if k[b]then
if d then
a("recursion")
return
end
error("tables with cycles are not supported")
end
k[b]=true
local m
if d then
local c,i,n={},{},{}
for f in o(b)do
if type(f)=="number"then
c[#c+1]=f
elseif type(f)=="string"then
i[#i+1]=f
else
n[#n+1]=f
end
end
table.sort(c)
table.sort(i)
for f,f in ipairs(i)do c[#c+1]=f end
for f,f in ipairs(n)do c[#c+1]=f end
local f=0
m=table.pack(function()
f=f+1
local i=c[f]
if i~=nil then
return i,b[i]
end
end)
else
m=table.pack(o(b))
end
local f=1
local i=true
a("{")
for c,n in table.unpack(m)do
if not i then
a(",")
if d then
a("\n"..string.rep(" ",h))
end
end
i=nil
local i=type(c)
if i=="number"and c==f then
f=f+1
g(n,h+1)
else
if i=="string"and not p[c]and c:match("^[%a_][%w_]*$")then
a(c)
else
a("[")
g(c,h+1)
a("]")
end
a("=")
g(n,h+1)
end
end
k[b]=nil
a("}")
else
error("unsupported type: "..e)
end
end
g(q,1)
local b=table.concat(l)
if d then
local c=type(d)=="number"and d or 10
local a=0
while c>0 and a do
a=string.find(b,"\n",a+1,true)
c=c-1
end
if a then
return b:sub(1,a).."..."
end
end
return b
end
function j.unserialize(a)
checkArg(1,a,"string")
local b,c=load("return "..a,"=data",nil,{math={huge=math.huge}})
if not b then
return nil,c
end
local c,a=pcall(b)
if not c then
return nil,a
end
return a
end
return j
