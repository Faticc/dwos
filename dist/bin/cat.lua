local b=require("shell")
local h=require("filesystem")
local a=b.parse(...)
if#a==0 then
a={"-"}
end
for c=1,#a do
local e=b.resolve(a[c])
if h.isDirectory(e)then
io.stderr:write(string.format("cat %s: Is a directory\n",e))
os.exit(1)
end
local b,f,d,g
if a[c]=="-"then
b,f=io.stdin,"missing stdin"
d,g="readLine",false
else
b,f=h.open(e)
d,g="read",2048
end
if not b then
io.stderr:write(string.format("cat: %s: %s\n",a[c],tostring(f)))
os.exit(1)
end
local c=""
repeat
local a=b[d](b,g)
if a and d=="read"then
a=c..a
local e=#a
for f=#a,math.max(1,#a-3),-1 do
local d=a:byte(f)
if d<0x80 then break end
if d>=0xC0 then
local g=d>=0xF0 and 4 or d>=0xE0 and 3 or 2
if#a-f+1<g then e=f-1 end
break
end
end
c=a:sub(e+1)
a=a:sub(1,e)
elseif not a and c~=""then
a,c=c,""
end
if a then
io.write(a)
end
until not a
b:close()
end
io.stdout:close()
