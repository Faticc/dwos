local b=require("shell")
local e,a=b.parse(...)
if a.help then
print([[Usage: sleep NUMBER[SUFFIX]...
Pause for NUMBER seconds.  SUFFIX may be 's' for seconds (the default),
'm' for minutes, 'h' for hours or 'd' for days.  Unlike most implementations
that require NUMBER be an integer, here NUMBER may be an arbitrary floating
point number.  Given two or more arguments, pause for the amount of time
specified by the sum of their values.]])
end
a.help=nil
local function c(b)
print("sleep: invalid option -- '"..tostring(b).."'")
print("Try 'sleep --help' for more information.")
return 1
end
if next(a)then
return c(next(a))
end
local f={[""]=1,s=1,m=60,h=3600,d=86400}
local b=0
for a,d in ipairs(e)do
local a,e=d:match("^([%d%.]+)([smhd]?)$")
a=tonumber(a)
if not a or a<0 then
return c(d)
end
b=b+f[e]*a
end
local a=io.stdin.stream
if a.pull then
a:pull(b,"interrupted")
else
require("event").pull(b,"interrupted")
end
