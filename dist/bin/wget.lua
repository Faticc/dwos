local a=require("component")
local g=require("filesystem")
local j=require("fetch")
local d=require("shell")
local h=require("text")
if not a.isAvailable("internet")then
io.stderr:write("This program requires an internet card to run.")
return
end
local b,c=d.parse(...)
c.q=c.q or c.Q
if#b<1 then
io.write("Usage: wget [-fq] <url> [<filename>]\n")
io.write(" -f: Force overwriting existing files.\n")
io.write(" -q: Quiet mode - no status messages.\n")
io.write(" -Q: Superquiet mode - no error messages.")
return
end
local function e(a,f)
if not c.Q then io.stderr:write(a)end
return nil,f or a
end
local f=h.trim(b[1])
local a=b[2]
if not a then
a=f:match("/([^/]*)$")or f
a=a:match("^[^?]*")
end
a=h.trim(a)
if a==""then
return e("could not infer filename, please specify one","missing target filename")
end
a=d.resolve(a)
local h
if g.exists(a)then
h=true
if not c.f then
return e("file already exists")
end
end
local b,d=io.open(a,"a")
if not b then
return e("failed opening file for writing: "..d)
end
b:close()
b=nil
if not c.q then
io.write("Downloading... ")
end
local i
j.many({{
url=f,headers={["user-agent"]="Wget/OpenComputers"},
write=function(f)
if not b then
b,d=io.open(a,"wb")
assert(b,"failed opening file for writing: "..tostring(d))
end
b:write(f)
end,
finish=function(f)i,d=not f,f end,
}})
if not i then
if not c.q then
io.stderr:write("failed.\n")
end
if b then b:close()end
if not h then g.remove(a)end
return e("HTTP request failed: "..tostring(d).."\n",d)
end
if b then
b:close()
end
if not c.q then
io.write("success.\nSaved data to "..a.."\n")
end
return true
