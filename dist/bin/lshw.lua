local computer=require("computer")
local shell=require("shell")
local text=require("text")
local args,options=shell.parse(...)
local devices=computer.getDeviceInfo()
local columns={}
if not next(options,nil)then
options.t,options.d,options.p=true,true,true
end
for _,c in ipairs({{"t","Class"},{"d","Description"},{"p","Product"},{"v","Vendor"},
{"c","Capacity"},{"w","Width"},{"s","Clock"}})do
if options[c[1]]then columns[#columns+1]=c[2]end
end
local m={}
for _,info in pairs(devices)do
for col,name in ipairs(columns)do
m[col]=math.max(m[col]or 1,(info[name:lower()]or""):len())
end
end
io.write(text.padRight("Address",10))
for col,name in ipairs(columns)do
io.write(text.padRight(name,m[col]+2))
end
io.write("\n")
for address,info in pairs(devices)do
io.write(text.padRight(address:sub(1,5).."...",10))
for col,name in ipairs(columns)do
io.write(text.padRight(info[name:lower()]or"",m[col]+2))
end
io.write("\n")
end
