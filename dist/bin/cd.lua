local b=require("shell")
local e=require("filesystem")
local c,f=b.parse(...)
local a
local d=false
if f.help then
print("Usage cd [dir]\nFor more options, run: man cd")
return
end
if#c==0 then
a=os.getenv("HOME")
if not a then
io.stderr:write("cd: HOME not set\n")
return 1
end
elseif c[1]=="-"then
d=true
a=os.getenv("OLDPWD")
if not a then
io.stderr:write("cd: OLDPWD not set\n")
return 1
end
else
a=c[1]
end
local c=b.resolve(a)
if not e.exists(c)then
io.stderr:write("cd: ",a,": No such file or directory\n")
return 1
end
local a=b.getWorkingDirectory()
local e,f=b.setWorkingDirectory(c)
if not e then
io.stderr:write("cd: ",c,": ",f)
return 1
end
os.setenv("OLDPWD",a)
if d then
os.execute("pwd")
end
