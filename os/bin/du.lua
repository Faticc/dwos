local shell = require("shell")
local fs = require("filesystem")

local args, options = shell.parse(...)
if #args == 0 then
  args[1] = "."
end

if options.help then
  print([[
Usage: du [OPTION]... [FILE]...
Summarize disk usage of each FILE, recursively for directories.

  -h, --human-readable  print sizes in human readable format (e.g., 1K 234M 2G)
  -s, --summarize       display only a total for each argument
      --help     display this help and exit
      --version  output version information and exit]])
  return true
end
if options.version then
  print("du (DwOS bin) 1.0\nWritten by payonel, patterned after GNU coreutils du")
  return true
end

local function opCheck(shortName, longName)
  local enabled = options[shortName] or options[longName]
  options[shortName], options[longName] = nil, nil
  return enabled
end
local bHuman = opCheck("h", "human-readable")
local bSummary = opCheck("s", "summarize")

if next(options) then
  for op in pairs(options) do
    io.stderr:write(string.format("du: invalid option -- '%s'\n", op))
  end
  io.stderr:write("Try 'du --help' for more information.\n")
  return 1
end

local function formatSize(size)
  if not bHuman then
    return tostring(size)
  end
  local sizes = { "", "K", "M", "G" }
  local unit = 1
  while size > 1024 and unit < #sizes do
    unit = unit + 1
    size = size / 1024
  end
  return math.floor(size * 10) / 10 .. sizes[unit]
end

local function printSize(size, rpath)
  io.write(string.format("%-12s%s\n", formatSize(size), rpath))
end

local function visitor(rpath)
  local subtotal, dirs = 0, 0
  local spath = shell.resolve(rpath)
  if fs.isDirectory(spath) then
    local prefix = rpath:sub(-1) == "/" and rpath or rpath .. "/"
    for item in fs.list(spath) do
      local vtotal, vdirs = visitor(prefix .. item)
      subtotal = subtotal + vtotal
      dirs = dirs + vdirs
    end
    if dirs == 0 and not bSummary then -- печатаются только листья
      printSize(subtotal, rpath)
    end
  elseif not fs.isLink(spath) then
    subtotal = fs.size(spath)
  end
  return subtotal, dirs
end

for _, arg in ipairs(args) do
  local path = shell.resolve(arg)
  if not fs.exists(path) then
    io.stderr:write(string.format("du: cannot access '%s': no such file or directory\n", arg))
    return 1
  end
  if fs.isDirectory(path) then
    local total = visitor(arg)
    if bSummary then
      printSize(total, arg)
    end
  elseif fs.isLink(path) then
    printSize(0, arg)
  else
    printSize(fs.size(path), arg)
  end
end

return true
