local a=require("computer")
local b=require("sh")
local d,e=a.uptime(),os.clock()
local c=0
if...then
b.execute(nil,...)
c=b.getLastExitCode()
end
local b=a.uptime()-d
local a=os.clock()-e
print(string.format("real%5dm%.3fs",math.floor(b/60),b%60))
print(string.format("cpu %5dm%.3fs",math.floor(a/60),a%60))
return c
