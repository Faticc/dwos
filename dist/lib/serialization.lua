local serialization={}
local function local_pairs(tbl)
local mt=getmetatable(tbl)
return(mt and mt.__pairs or pairs)(tbl)
end
local KEYWORDS={}
for kw in("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+")do
KEYWORDS[kw]=true
end
function serialization.serialize(value,pretty)
local ts={}
local out={}
local function emit(s)out[#out+1]=s end
local function recurse(v,depth)
local t=type(v)
if t=="number"then
if v~=v then
emit("0/0")
elseif v==math.huge then
emit("math.huge")
elseif v==-math.huge then
emit("-math.huge")
else
emit(tostring(v))
end
elseif t=="string"then
emit((string.format("%q",v):gsub("\\\n","\\n")))
elseif t=="nil"or t=="boolean"or pretty and(t~="table"or(getmetatable(v)or{}).__tostring)then
emit(tostring(v))
elseif t=="table"then
if ts[v]then
if pretty then
emit("recursion")
return
end
error("tables with cycles are not supported")
end
ts[v]=true
local f
if pretty then
local ks,sks,oks={},{},{}
for k in local_pairs(v)do
if type(k)=="number"then
ks[#ks+1]=k
elseif type(k)=="string"then
sks[#sks+1]=k
else
oks[#oks+1]=k
end
end
table.sort(ks)
table.sort(sks)
for _,k in ipairs(sks)do ks[#ks+1]=k end
for _,k in ipairs(oks)do ks[#ks+1]=k end
local n=0
f=table.pack(function()
n=n+1
local k=ks[n]
if k~=nil then
return k,v[k]
end
end)
else
f=table.pack(local_pairs(v))
end
local i=1
local first=true
emit("{")
for k,val in table.unpack(f)do
if not first then
emit(",")
if pretty then
emit("\n"..string.rep(" ",depth))
end
end
first=nil
local tk=type(k)
if tk=="number"and k==i then
i=i+1
recurse(val,depth+1)
else
if tk=="string"and not KEYWORDS[k]and k:match("^[%a_][%w_]*$")then
emit(k)
else
emit("[")
recurse(k,depth+1)
emit("]")
end
emit("=")
recurse(val,depth+1)
end
end
ts[v]=nil
emit("}")
else
error("unsupported type: "..t)
end
end
recurse(value,1)
local result=table.concat(out)
if pretty then
local limit=type(pretty)=="number"and pretty or 10
local truncate=0
while limit>0 and truncate do
truncate=string.find(result,"\n",truncate+1,true)
limit=limit-1
end
if truncate then
return result:sub(1,truncate).."..."
end
end
return result
end
function serialization.unserialize(data)
checkArg(1,data,"string")
local result,reason=load("return "..data,"=data",nil,{math={huge=math.huge}})
if not result then
return nil,reason
end
local ok,output=pcall(result)
if not ok then
return nil,output
end
return output
end
return serialization
