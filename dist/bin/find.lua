local shell = require("shell")
local fs = require("filesystem")
local text = require("text")
local USAGE = [==[Usage: find [path] [--type=[dfs]] [--[i]name=EXPR]
  --path  if not specified, path is assumed to be current working directory
  --type  returns results of a given type, d:directory, f:file, and s:symlinks
  --name  specify the file name pattern. Use quote to include *. iname is
          case insensitive
  --help  display this help and exit]==]
local args, options = shell.parse(...)
if options.help then
print(USAGE)
return
end
if #args > 1 then
io.stderr:write(USAGE .. "\n")
return 1
end
local path = args[1] or "."
local want = { d = true, f = true, s = true }
local pattern = ""
local caseSensitive = true
if options.iname and options.name then
io.stderr:write("find cannot define both iname and name\n")
return 1
end
if options.type then
if not want[options.type] then
io.stderr:write(string.format("find: Unknown argument to type: %s\n", options.type))
io.stderr:write(USAGE .. "\n")
return 1
end
want = { [options.type] = true }
end
if options.iname or options.name then
caseSensitive = options.iname == nil
pattern = options.iname or options.name
if type(pattern) ~= "string" then
io.stderr:write("find: missing argument to `name'\n")
return 1
end
if not caseSensitive then
pattern = pattern:lower()
end
pattern = "^" .. text.escapeMagic(pattern):gsub("%%%*", ".*") .. "$"
end
local function matches(spath)
if not fs.exists(spath) then
return false
end
if pattern ~= "" then
local name = spath:gsub(".*/", "")
if name == "" then
return false
end
if not caseSensitive then
name = name:lower()
end
if not name:find(pattern) then
return false
end
end
if fs.isDirectory(spath) then
return want.d
elseif fs.isLink(spath) then
return want.s
end
return want.f
end
local function visit(rpath)
local spath = shell.resolve(rpath)
local clean = rpath:gsub("/+$", "")
if matches(spath) then
print(clean)
end
if fs.isDirectory(spath) then
for item in fs.list(spath) do
visit(clean .. "/" .. item)
end
end
end
visit(path)
