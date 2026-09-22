local a=require("shell")
local b,c=a.parse(...)
local a=b[1]
if a then
local b,d=io.open("/etc/hostname","w")
if not b then
io.stderr:write("failed to open for writing: ",d,"\n")
return 1
end
b:write(a)
b:close()
c.update=true
else
local b=io.open("/etc/hostname")
if b then
a=b:read("*l")
b:close()
end
end
if c.update then
os.setenv("HOSTNAME_SEPARATOR",a and#a>0 and":"or"")
os.setenv("HOSTNAME",a)
elseif a then
print(a)
else
io.stderr:write("Hostname not set\n")
return 1
end
