local c=require("shell")
local a=require("process")
local b,d=c.parse(...)
if#b~=1 then
io.stderr:write("specify a single file to source\n")
return 1
end
local c,e=io.open(b[1],"r")
if not c then
if not d.q then
io.stderr:write(string.format("could not source %s because: %s\n",b[1],e))
end
return 1
end
for f in c:lines()do
local b=a.info().data
local d=a.load((assert(os.getenv("SHELL"),"no $SHELL set")))
local e=a.list[d].data
e.aliases=b.aliases
e.vars=b.vars
a.internal.continue(d,_ENV,f)
end
c:close()
