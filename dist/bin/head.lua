local a=require("shell")
local c,b=a.parse(...)
local e=0
local function a(f,g)
local d=b[f]
b[f]=nil
if d and g then
local g=tonumber(d)
if not g then
io.stderr:write(string.format("use --%s=n where n is a number\n",f))
b.help=true
e=1
end
d=g
end
return d
end
local d=a("bytes",true)
local f=a("lines",true)
local h,i,j=a("q"),a("quiet"),a("silent")
local g=h or i or j
local i,j=a("v"),a("verbose")
local h=i or j
local i=a("help")
if i or next(b)then
local a=next(b)
if a then
a=string.format("invalid option: %s\n",a)
e=1
else
a=""
end
print(a..[[Usage: head [--lines=n] file
Print the first 10 lines of each FILE to stdout.
For more info run: man head]])
os.exit(e)
end
if#c==0 then
c={"-"}
end
if g and h then
g=false
end
local function e()
return{
open=true,
capacity=math.abs(f or d or 10),
bytes=d,
buffer=(f and f<0 and{})or(d and d<0 and""),
}
end
local function d(a)
if a.buffer then
if type(a.buffer)=="table"then
a.buffer=table.concat(a.buffer)
end
io.stdout:write(a.buffer)
a.buffer=nil
end
a.open=false
end
local function f(a,b)
if not b then
return d(a)
end
local g=a.bytes and b:len()or 1
a.capacity=a.capacity-g
if not a.buffer then
if a.bytes and a.capacity<0 then
b=b:sub(1,a.capacity-1)
end
io.write(b)
if a.capacity<=0 then
return d(a)
end
elseif type(a.buffer)=="table"then
a.buffer[#a.buffer+1]=b
if a.capacity<0 then
table.remove(a.buffer,1)
a.capacity=0
end
else
a.buffer=a.buffer..b
if a.capacity<0 then
a.buffer=a.buffer:sub(-a.capacity+1)
a.capacity=0
end
end
end
for a=1,#c do
local b=c[a]
local a,d
if b=="-"then
b="standard input"
a=io.stdin
else
a,d=io.open(b,"r")
if not a then
io.stderr:write(string.format([[head: cannot open '%s' for reading: %s]],b,d))
end
end
if a then
if h or#c>1 then
io.write(string.format("==> %s <==\n",b))
end
local b=e()
while b.open do
f(b,a:read("*L"))
end
a:close()
end
end
