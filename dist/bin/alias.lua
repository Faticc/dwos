local b=require("shell")
local c,a=b.parse(...)
if a.help then
print("Usage: alias: [name[=value] ... ]")
return
end
local d=0
if not next(c)then
for a,e in b.aliases()do
print(string.format("alias %s='%s'",a,e))
end
return d
end
for a,a in ipairs(c)do
checkArg(1,a,"string")
local c=a:find("=")
if not c or c==1 then
local e=b.getAlias(a)
if not e then
io.stderr:write(string.format("alias: %s: not found\n",a))
d=1
else
io.write(string.format("alias %s='%s'\n",a,e))
end
else
local e,f=a:sub(1,c-1),a:sub(c+1)
if e:match("[/%$`=|&;%(%)<> \t]")then
io.stderr:write(string.format("alias: `%s': invalid alias name\n",e))
else
b.setAlias(e,f)
end
end
end
return d
