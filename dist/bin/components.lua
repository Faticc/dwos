local component = require("component")
local shell = require("shell")
local text = require("text")
local args, options = shell.parse(...)
local count = tonumber(options.limit) or math.huge
local components = {}
local padTo = 1
if #args == 0 then
args[1] = ""
end
for _, filter in ipairs(args) do
for address, name in component.list(filter) do
if name:len() > padTo then
padTo = name:len() + 2
end
components[address] = name
end
end
padTo = padTo + 8 - padTo % 8
for address, name in pairs(components) do
io.write(text.padRight(name, padTo) .. address .. "\n")
if options.l then
local proxy = component.proxy(address)
local width = 1
local methods = {}
for mname, member in pairs(proxy) do
if type(member) == "table" or type(member) == "function" then
if mname:len() > width then
width = mname:len() + 2
end
methods[#methods + 1] = mname
end
end
table.sort(methods)
width = width + 8 - width % 8
for _, mname in ipairs(methods) do
local doc = component.doc(address, mname) or tostring(proxy[mname])
io.write("  " .. text.padRight(mname, width) .. doc .. "\n")
end
end
count = count - 1
if count <= 0 then
break
end
end
