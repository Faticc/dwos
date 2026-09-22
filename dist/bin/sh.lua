local a=require("shell")
local c=require("tty")
local d=require("text")
local b=require("sh")
local e=a.parse(...)
a.prime()
if#e>0 then
return b.execute(...)
end
local a
local e={hint=b.hintHandler}
while true do
if io.stdin.tty and io.stdout.tty then
if not a then
a=true
dofile("/etc/profile.lua")
end
if c.getCursor()>1 then
io.write("\n")
end
io.write(b.expand(os.getenv("PS1")or"$ "))
end
c.window.cursor=e
local a=io.stdin:readLine(false)
c.window.cursor=nil
if a then
a=d.trim(a)
if a=="exit"then
return
elseif a~=""then
local d,c=b.execute(_ENV,a)
if not d and c then
io.stderr:write(tostring(c),"\n")
end
end
elseif a==nil then
return
end
end
