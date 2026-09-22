local i=require("component")
local j=require("computer")
local r=require("inflate")
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
for k=1,8 do
if e(b,1)==1 then b=c(0xEDB88320,d(b,1))else b=d(b,1)end
end
g[h]=b
end
local k=string.byte
a.crc32=function(b,h)
b=f(b)
for l=1,#h do b=c(g[e(c(b,k(h,l)),0xFF)],d(b,8))end
return f(b)
end
end
end
function a.hex(b)return("%08x"):format(b)end
local function n(d,b)
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
local o=i.internet
local p=math.max(1,math.min(f.parallel or a.parallel,16))
local h,c,i={},{},0
for d=1,#b do h[d]=b[d]end
local g=1
local function d(b,e,l)
for k=#c,1,-1 do if c[k]==b then table.remove(c,k)end end
if b.h then pcall(b.h.close)end
b.h=nil
if not e then i=i+1 end
if b.job.finish then b.job.finish(e,l)end
end
local function q(b)
local k={["user-agent"]=a.agent}
if not b.plain then k["accept-encoding"]="gzip"end
for e,l in pairs(b.headers or{})do k[e]=l end
local m,l,e=pcall(o.request,b.url,b.post,k)
if not m or not l then
e=tostring(m and e or l)
if e:find("too many",1,true)then return"wait"end
if b.finish then b.finish(e)end
return
end
c[#c+1]={job=b,h=l,t0=j.uptime(),got=0}
end
local function l(b)
if b.code then return true end
local e,k,k=b.h.response()
if not e then
if j.uptime()-b.t0>(f.timeout or a.timeout)then
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
if(n(k,"content-encoding")or""):lower():find("gzip",1,true)then
b.z=r.new(function(f)
b.got=b.got+#f
if e.write then e.write(f)end
end,"gzip")
end
return true
end
local function m(b)
local f,e,k=pcall(b.h.read,2048)
if not f or(e==nil and k)then
return d(b,tostring(f and k or e))
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
local k,n=pcall(b.z.feed,b.z,e)
if not k then return d(b,tostring(n))end
if b.z.done then return d(b,nil,b.code)end
else
b.got=b.got+#e
if f.write then
local k,n=pcall(f.write,e)
if not k then return d(b,tostring(n))end
end
if f.size and b.got>=f.size then return d(b,nil,b.code)end
end
end
while g<=#h or#c>0 do
local b=false
if g<=#h and#c<p then
local d=q(h[g])
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
function a.unpack(k,e)
local g,c,b,d,f=0,nil,nil,0,0
local function h()
if b then b:close()end
if e.close then e.close(c,a.hex(f),b~=nil)end
c,b=nil,nil
end
local function i()
while true do
g=g+1
c=k[g]
if not c then return false end
d,f=c.size or 0,0
b=e.open(c)
if d>0 then return true end
h()
end
end
local function l(k)
local e=1
while e<=#k do
if not c and not i()then return end
local g=k:sub(e,e+d-1)
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
local function s(b)return 2+2*math.ceil(b/2048)end
a.memory=65536
function a.files(b)
local h=require("filesystem")
local i,n={},0
for c,c in ipairs(b.need)do i[c[1]]=c n=n+1 end
local o,p=0,{}
local function e(d)
local c=d:match("^(.*)/[^/]*$")
if c and c~=""and not h.exists(c)then h.makeDirectory(c)end
end
local function t(d)
local f=b.path(d)
e(f)
local k,q=0,0
local m=d.size or 0
local e,g,c,l
if m<=a.memory and j.freeMemory()>m*4+32768 then
e={}
else
g=h.exists(f)and(f..".part")or f
end
local m={}
function m.write(j)
k,q=k+#j,a.crc32(q,j)
if e then
e[#e+1]=j
else
if not c and not l then c,l=io.open(g,"wb")end
if c then c:write(j)end
end
end
function m.drop()
if c then c:close()c=nil end
if g then h.remove(g)end
e=nil
end
function m.finish()
local u=a.hex(q)
local j
if l then
j=tostring(l)
elseif(d.size and k~=d.size)or(d.crc and u~=d.crc)then
j=("пришло %d Б с хэшем %s, а ждали %s Б с хэшем %s")
:format(k,u,tostring(d.size),tostring(d.crc))
elseif e then
local q,u=io.open(f,"wb")
if not q then
j=tostring(u)
else
for u=1,#e do q:write(e[u])end
q:close()
end
else
if not c then c,l=io.open(g,"wb")end
if c then c:close()c=nil end
if g~=f then
h.remove(f)
local c,l=h.rename(g,f)
if not c then j="не переименовать .part: "..tostring(l)end
end
end
if j then
m.drop()
return j
end
e=nil
i[d[1]]=nil
o=o+1
if b.done then b.done(d,k)end
end
return m
end
if b.pack and b.all and n>0 then
local c=0
for d,d in ipairs(b.need)do c=c+s((d.size or 0)/3)end
if s(b.pack.size or math.huge)<c then
local c
local e,f=a.unpack(b.all,{
open=function(d)
if not i[d[1]]then return nil end
c=t(d)
local d=c
return{write=function(g,g)d.write(g)end,close=function()end}
end,
close=function(d,d,d)
if d and c then c.finish()end
c=nil
end,
})
local d=r.new(e,"gzip")
local e
a.many({{
url=b.base..b.pack[1],size=b.pack.size,plain=true,
write=function(g)d:feed(g)end,
finish=function(g)e=g end,
}})
if not e and d.done then f()end
if c then c.drop()c=nil end
end
end
for c=1,2 do
local d={}
for c,c in ipairs(b.need)do
if i[c[1]]then
local f=t(c)
d[#d+1]={
url=b.base..c[1],size=c.size,
write=f.write,
finish=function(e,g)
if e then f.drop()else e=f.finish()end
p[c[1]]=e and{err=e,code=g}or nil
end,
}
end
end
if#d==0 then break end
a.many(d)
local c=false
for d,e in pairs(p)do if e.code~=404 and i[d]then c=true end end
if not c then break end
end
local e={}
for c,c in ipairs(b.need)do
if i[c[1]]then
local d=p[c[1]]or{err="не скачался"}
e[#e+1]={entry=c,err=d.err,code=d.code}
if b.done then b.done(c,nil,d.err,d.code)end
end
end
return o,e
end
return a
