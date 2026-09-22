local a=require("component")
local c=require("filesystem")
local g=require("internet")
local d=require("shell")
if not a.isAvailable("internet")then
io.stderr:write("This program requires an internet card to run.")
return
end
local a,h=d.parse(...)
local function i(f,e)
local b,j=io.open(e,"w")
if not b then
io.stderr:write("Failed opening file for writing: "..j)
return
end
io.write("Downloading from pastebin.com... ")
local k,j=pcall(g.request,"https://pastebin.com/raw/"..f)
if k then
io.write("success.\n")
for f in j do
if not h.k then
f=f:gsub("\r\n","\n")
end
b:write(f)
end
b:close()
io.write("Saved data to "..e.."\n")
else
io.write("failed.\n")
b:close()
c.remove(e)
io.stderr:write("HTTP request failed: "..j.."\n")
end
end
local function f(b)
if b then
b=b:gsub("([^%w ])",function(e)return string.format("%%%02X",string.byte(e))end)
b=b:gsub(" ","+")
end
return b
end
local function k(e,...)
local b=os.tmpname()
i(e,b)
io.write("Running...\n")
local e,j=d.execute(b,nil,...)
if not e then
io.stderr:write(j)
end
c.remove(b)
end
local function l(j)
local b={}
local e=loadfile("/etc/pastebin.conf","t",b)
if e then
local m,n=pcall(e)
if not m then
io.stderr:write("Failed loading config: "..n)
end
end
b.key=b.key or"fd92bd40a84c127eeb6804b146793c97"
local e,m=io.open(j,"r")
if not e then
io.stderr:write("Failed opening file for reading: "..m)
return
end
local m=e:read("*a")
e:close()
io.write("Uploading to pastebin.com... ")
local n,e=pcall(g.request,
"https://pastebin.com/api/api_post.php",
"api_option=paste&"..
"api_dev_key="..b.key.."&"..
"api_paste_format=lua&"..
"api_paste_expire_date=N&"..
"api_paste_name="..f(c.name(j)).."&"..
"api_paste_code="..f(m))
if not n then
io.write("failed.\n")
io.stderr:write(e)
return
end
local b=""
for f in e do
b=b..f
end
if b:match("^Bad API request, ")then
io.write("failed.\n")
io.write(b)
else
io.write("success.\n")
local e=b:match("[^/]+$")
io.write("Uploaded as "..b.."\n")
io.write('Run "pastebin get '..e..'" to download anywhere.')
end
end
local b=a[1]
if b=="put"and#a==2 then
l(d.resolve(a[2]))
return
elseif b=="get"and#a==3 then
local e=d.resolve(a[3])
if c.exists(e)then
if not h.f or not os.remove(e)then
io.stderr:write("file already exists")
return
end
end
i(a[2],e)
return
elseif b=="run"and#a>=2 then
k(a[2],table.unpack(a,3))
return
end
io.write("Usages:\n")
io.write("pastebin put [-f] <file>\n")
io.write("pastebin get [-f] <id> <file>\n")
io.write("pastebin run [-f] <id> [<arguments...>]\n")
io.write(" -f: Force overwriting existing files.\n")
io.write(" -k: keep line endings as-is (will convert\n")
io.write("     Windows line endings to Unix otherwise).")
