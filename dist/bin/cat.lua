local shell=require("shell")
local fs=require("filesystem")
local args=shell.parse(...)
if#args==0 then
args={"-"}
end
for i=1,#args do
local arg=shell.resolve(args[i])
if fs.isDirectory(arg)then
io.stderr:write(string.format("cat %s: Is a directory\n",arg))
os.exit(1)
end
local file,reason,method,param
if args[i]=="-"then
file,reason=io.stdin,"missing stdin"
method,param="readLine",false
else
file,reason=fs.open(arg)
method,param="read",2048
end
if not file then
io.stderr:write(string.format("cat: %s: %s\n",args[i],tostring(reason)))
os.exit(1)
end
local carry=""
repeat
local chunk=file[method](file,param)
if chunk and method=="read"then
chunk=carry..chunk
local cut=#chunk
for i=#chunk,math.max(1,#chunk-3),-1 do
local b=chunk:byte(i)
if b<0x80 then break end
if b>=0xC0 then
local need=b>=0xF0 and 4 or b>=0xE0 and 3 or 2
if#chunk-i+1<need then cut=i-1 end
break
end
end
carry=chunk:sub(cut+1)
chunk=chunk:sub(1,cut)
elseif not chunk and carry~=""then
chunk,carry=carry,""
end
if chunk then
io.write(chunk)
end
until not chunk
file:close()
end
io.stdout:close()
