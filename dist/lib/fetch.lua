local i=require("component")
local k=require("computer")
local n=require("inflate")
local a={}
a.parallel=4
a.timeout=30
a.agent="dwos"
do
local b=load([[
    local T = {}
    for i = 0, 255 do
      local c = i
      for _ = 1, 8 do
        if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
      end
      T[i] = c
    end
    local byte = string.byte
    return function(crc, s)
      crc = ~crc & 0xFFFFFFFF
      for i = 1, #s do crc = T[(crc ~ byte(s, i)) & 0xFF] ~ (crc >> 8) end
      return ~crc & 0xFFFFFFFF
    end]])
if b then
a.crc32=b()
elseif bit32 then
local e,c,d,f=bit32.band,bit32.bxor,bit32.rshift,bit32.bnot
local g={}
for h=0,255 do
local b=h
for j=1,8 do
if e(b,1)==1 then b=c(0xEDB88320,d(b,1))else b=d(b,1)end
end
g[h]=b
end
local j=string.byte
a.crc32=function(b,h)
b=f(b)
for l=1,#h do b=c(g[e(c(b,j(h,l)),0xFF)],d(b,8))end
return f(b)
end
end
end
function a.hex(b)return("%08x"):format(b)end
local function o(d,b)
if type(d)~="table"then return nil end
b=b:lower()
for e,c in pairs(d)do
if type(e)=="string"and e:lower()==b then
return type(c)=="table"and c[1]or c
end
end
end
function a.many(b,f)
f=f or{}
local p=i.internet
local q=math.max(1,math.min(f.parallel or a.parallel,16))
local h,c,i={},{},0
for d=1,#b do h[d]=b[d]end
local g=1
local function d(b,e,l)
for j=#c,1,-1 do if c[j]==b then table.remove(c,j)end end
if b.h then pcall(b.h.close)end
b.h=nil
if not e then i=i+1 end
if b.job.finish then b.job.finish(e,l)end
end
local function r(b)
local j={["user-agent"]=a.agent}
if not b.plain then j["accept-encoding"]="gzip"end
for e,l in pairs(b.headers or{})do j[e]=l end
local m,l,e=pcall(p.request,b.url,b.post,j)
if not m or not l then
e=tostring(m and e or l)
if e:find("too many",1,true)then return"wait"end
if b.finish then b.finish(e)end
return
end
c[#c+1]={job=b,h=l,t0=k.uptime(),got=0}
end
local function l(b)
if b.code then return true end
local e,j,j=b.h.response()
if not e then
if k.uptime()-b.t0>(f.timeout or a.timeout)then
d(b,"сервер не ответил за "..(f.timeout or a.timeout).." с")
end
return false
end
b.code=e
if e<200 or e>=300 then
d(b,"HTTP "..tostring(e),e)
return false
end
local e=b.job
if(o(j,"content-encoding")or""):lower():find("gzip",1,true)then
b.z=n.new(function(f)
b.got=b.got+#f
if e.write then e.write(f)end
end,"gzip")
end
return true
end
local function m(b)
local f,e,j=pcall(b.h.read,2048)
if not f or(e==nil and j)then
return d(b,tostring(f and j or e))
end
local f=b.job
if e==nil then
if b.z and not b.z.done then return d(b,"поток оборвался")end
if f.size and b.got~=f.size then
return d(b,("пришло %d Б, а ждали %d"):format(b.got,f.size))
end
return d(b,nil,b.code)
end
if e==""then return end
if b.z then
local j,o=pcall(b.z.feed,b.z,e)
if not j then return d(b,tostring(o))end
if b.z.done then return d(b,nil,b.code)end
else
b.got=b.got+#e
if f.write then
local j,o=pcall(f.write,e)
if not j then return d(b,tostring(o))end
end
if f.size and b.got>=f.size then return d(b,nil,b.code)end
end
end
while g<=#h or#c>0 do
local b=false
if g<=#h and#c<q then
local d=r(h[g])
if d~="wait"then g,b=g+1,true end
end
if not b then
local b
for e=1,#c do
local d=c[e]
if d and l(d)then b=d break end
end
if b then
m(b)
elseif#c>0 then
os.sleep(0.05)
end
end
end
return i
end
function a.get(f,b)
b=b or{}
local c,d,e={},nil,nil
a.many({{
url=f,size=b.size,headers=b.headers,plain=b.plain,
write=function(f)c[#c+1]=f end,
finish=function(f,g)d,e=f,g end,
}},b)
if d then return nil,d,e end
return table.concat(c),nil,e
end
function a.unpack(j,e)
local g,c,b,d,f=0,nil,nil,0,0
local function h()
if b then b:close()end
if e.close then e.close(c,a.hex(f),b~=nil)end
c,b=nil,nil
end
local function i()
while true do
g=g+1
c=j[g]
if not c then return false end
d,f=c.size or 0,0
b=e.open(c)
if d>0 then return true end
h()
end
end
local function l(j)
local e=1
while e<=#j do
if not c and not i()then return end
local g=j:sub(e,e+d-1)
e,d=e+#g,d-#g
if b then
b:write(g)
f=a.crc32(f,g)
end
if d==0 then h()end
end
end
local function d()
if c then
if b then b:close()end
return false
end
if i()then
if b then b:close()end
return false
end
return true
end
return l,d
end
local function t(b)return 2+2*math.ceil(b/2048)end
a.memory=65536
function a.files(b)
local i=require("filesystem")
local j,o={},0
for c,c in ipairs(b.need)do j[c]=true o=o+1 end
local p,q=0,{}
local function r(d,c)return b.url and b.url(d,c)or(b.base..c)end
local function e(d)
local c=d:match("^(.*)/[^/]*$")
if c and c~=""and not i.exists(c)then i.makeDirectory(c)end
end
local function u(d)
local f=b.path(d)
e(f)
local g,s=0,0
local m=d.size or 0
local e,h,c,l
if m<=a.memory and k.freeMemory()>m*4+32768 then
e={}
else
h=i.exists(f)and(f..".part")or f
end
local m={}
function m.write(k)
if b.progress and math.floor((g+#k)/65536)>math.floor(g/65536)then b.progress(d,g+#k)end
g,s=g+#k,a.crc32(s,k)
if e then
e[#e+1]=k
else
if not c and not l then c,l=io.open(h,"wb")end
if c then c:write(k)end
end
end
function m.drop()
if c then c:close()c=nil end
if h then i.remove(h)end
e=nil
end
function m.finish()
local v=a.hex(s)
local k
if l then
k=tostring(l)
elseif(d.size and g~=d.size)or(d.crc and v~=d.crc)then
k=("пришло %d Б с хэшем %s, а ждали %s Б с хэшем %s")
:format(g,v,tostring(d.size),tostring(d.crc))
elseif e then
local s,v=io.open(f,"wb")
if not s then
k=tostring(v)
else
for v=1,#e do s:write(e[v])end
s:close()
end
else
if not c then c,l=io.open(h,"wb")end
if c then c:close()c=nil end
if h~=f then
i.remove(f)
local c,l=i.rename(h,f)
if not c then k="не переименовать .part: "..tostring(l)end
end
end
if k then
m.drop()
return k
end
e=nil
j[d]=nil
p=p+1
if b.done then b.done(d,g)end
end
return m
end
if b.pack and b.all and o>0 then
local c=0
for d,d in ipairs(b.need)do c=c+t((d.size or 0)/3)end
if t(b.pack.size or math.huge)<c then
local c
local e,f=a.unpack(b.all,{
open=function(d)
if not j[d]then return nil end
c=u(d)
local d=c
return{write=function(g,g)d.write(g)end,close=function()end}
end,
close=function(d,d,d)
if d and c then c.finish()end
c=nil
end,
})
local d=n.new(e,"gzip")
local e
a.many({{
url=r(b.pack,b.pack[1]),size=b.pack.size,plain=true,
write=function(g)d:feed(g)end,
finish=function(g)e=g end,
}})
if not e and d.done then f()end
if c then c.drop()c=nil end
end
end
for c=1,2 do
local e={}
for c,c in ipairs(b.need)do
if j[c]then
local f=u(c)
local d={
url=r(c,c[1]),size=c.size,
write=f.write,
finish=function(g,h)
if g then f.drop()else g=f.finish()end
q[c]=g and{err=g,code=h}or nil
end,
}
if c.gz then
local g=n.new(f.write,"gzip")
d.url,d.size,d.plain=r(c,c.gz),c.gzsize,true
d.write=function(c)g:feed(c)end
local f=d.finish
d.finish=function(c,h)
if not c and not g.done then c="сжатый поток оборвался"end
f(c,h)
end
end
e[#e+1]=d
end
end
if#e==0 then break end
a.many(e)
local c=false
for d,e in pairs(q)do if e.code~=404 and j[d]then c=true end end
if not c then break end
end
local e={}
for c,c in ipairs(b.need)do
if j[c]then
local d=q[c]or{err="не скачался"}
e[#e+1]={entry=c,err=d.err,code=d.code}
if b.done then b.done(c,nil,d.err,d.code)end
end
end
return p,e
end
return a
