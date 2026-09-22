local c=require("shell")
local d=require("tools/transfer")
local b,a=c.parse(...)
a.h=a.h or a.help
if#b<2 or a.h then
io.write([[Usage: cp [OPTIONS] <from...> <to>
 -i: prompt before overwrite (overrides -n option).
 -n: do not overwrite an existing file.
 -r: copy directories recursively.
 -u: copy only when the SOURCE file differs from the destination
     file or when the destination file is missing.
 -P: preserve attributes, e.g. symbolic links.
 -v: verbose output.
 -x: stay on original source file system.
 --skip=P: skip files matching lua regex P
]])
return not not a.h
end
return d.batch(b,{
cmd="cp",
i=a.i,f=a.f,n=a.n,r=a.r,
u=a.u,P=a.P,v=a.v,x=a.x,
skip={a.skip},
})
