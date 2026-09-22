local c=require("shell")
local d=require("tools/transfer")
local b,a=c.parse(...)
a.h=a.h or a.help
if#b<2 or a.h then
io.write([[Usage: mv [OPTIONS] <from> <to>
  -f         overwrite without prompt
  -i         prompt before overwriting
             unless -f
  -v         verbose
  -n         do not overwrite an existing file
  --skip=P   ignore paths matching lua regex P
  -h, --help show this help
]])
return not not a.h
end
return d.batch(b,{
cmd="mv",
f=a.f,i=a.i,v=a.v,n=a.n,
skip={a.skip},
P=true,r=true,x=true,
})
