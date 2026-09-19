local computer = require("computer")
local shell = require("shell")
local fs = require("filesystem")

local args, opts = shell.parse(...)

local function die(...)
  io.stderr:write(...)
  os.exit(1)
end

if opts.help then
  print([[Usage: tree [OPTION]... [FILE]...
  -a, --all             do not ignore entries starting with .
      --full-time       with -l, print time in full iso format
  -h, --human-readable  with -l, print human readable sizes
      --si              likewise, but use powers of 1000 not 1024
      --level=LEVEL     descend only LEVEL directories deep
      --color=WHEN      WHEN can be
                        auto - colorize output only if writing to a tty,
                        always - always colorize output,
                        never - never colorize output; (default: auto)
  -l                    use a long listing format
  -f                    print the full path prefix for each file
  -i                    do not print indentation lines
  -p                    append "/" indicator to directories
  -Q, --quote           quote filenames with double quotes
  -r, --reverse         reverse order while sorting
  -S                    sort by file size
  -t                    sort by modification type, newest first
  -X                    sort alphabetically by entry extension
  -C                    do not count files and directories
  -R                    count root directories like other files
      --help            print this help and exit]])
  return 0
end

if #args == 0 then
  args[1] = "."
end
opts.level = tonumber(opts.level) or math.huge
if opts.level < 1 then
  die("Invalid level, must be greater than 0")
end
opts.color = opts.color or "auto"
if opts.color == "auto" then
  opts.color = io.stdout.tty and "always" or "never"
end
if opts.color ~= "always" and opts.color ~= "never" then
  die("Invalid value for --color=WHEN option; WHEN should be auto, always or never")
end

local lastYield = computer.uptime()
local function yieldopt()
  if computer.uptime() - lastYield > 2 then
    lastYield = computer.uptime()
    os.sleep(0)
  end
end

local function stat(path)
  local st = { path = path }
  st.name = fs.name(path) or "/"
  st.sortName = st.name:gsub("^%.", "")
  st.time = fs.lastModified(path)
  st.isLink = fs.isLink(path)
  st.isDirectory = fs.isDirectory(path)
  st.size = st.isLink and 0 or fs.size(path)
  st.extension = st.name:match("(%.[^.]+)$") or ""
  st.fs = fs.get(path)
  return st
end

local colorize
if opts.color == "always" then
  local colors = {}
  for pair in (os.getenv("LS_COLORS") or ""):gmatch("[^:]+") do
    local k, v = pair:match("^(.-)=(.*)$")
    if k then colors[k] = v end
  end
  function colorize(st)
    return st.isLink and colors.ln or st.isDirectory and colors.di or colors["*" .. st.extension] or colors.fi
  end
end

local SORT = {
  S = function(a, b) return a.size < b.size end,
  t = function(a, b) return a.time < b.time end,
  X = function(a, b) return a.extension < b.extension end,
}

--- Содержимое каталога, уже отсортированное.
local function list(path)
  local l = {}
  for entry in fs.list(path) do
    if opts.a or entry:sub(1, 1) ~= "." then
      l[#l + 1] = stat(fs.concat(path, entry))
    end
  end
  table.sort(l, opts.S and SORT.S or opts.t and SORT.t or opts.X and SORT.X or
    function(a, b) return a.sortName < b.sortName end)
  if opts.r then
    for i = 1, math.floor(#l / 2) do l[i], l[#l - i + 1] = l[#l - i + 1], l[i] end
  end
  return l
end

local function nod(n)
  return n and (tostring(n):gsub("(%.[0-9]+)0+$", "%1")) or "0"
end

local function formatFSize(size)
  if not opts.h and not opts["human-readable"] and not opts.si then
    return tostring(size)
  end
  local sizes = { "", "K", "M", "G" }
  local unit = 1
  local power = opts.si and 1000 or 1024
  while size > power and unit < #sizes do
    unit = unit + 1
    size = size / power
  end
  return nod(math.floor(size * 10) / 10) .. sizes[unit]
end

local function pad(txt)
  txt = tostring(txt)
  return #txt >= 2 and txt or "0" .. txt
end

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local function formatTime(epochms)
  if epochms == 0 then return "" end
  local d = os.date("*t", epochms)
  local day, hour, min, sec = nod(d.day), pad(nod(d.hour)), pad(nod(d.min)), pad(nod(d.sec))
  if opts["full-time"] then
    return string.format("%s-%s-%s %s:%s:%s ", d.year, pad(nod(d.month)), pad(day), hour, min, sec)
  end
  return string.format("%s %2s %2s:%2s ", MONTHS[d.month], day, hour, pad(min))
end

local function writeEntry(entry, levels)
  if not opts.i then
    for i, hasNext in ipairs(levels) do
      if i == #levels then
        io.write(hasNext and "├── " or "└── ")
      else
        io.write(hasNext and "│\194\160\194\160 " or "    ") -- неразрывные пробелы, как в OpenOS
      end
    end
  end
  if opts.l then
    io.write("[", entry.isDirectory and "d" or entry.isLink and "l" or "f", "-")
    io.write("r", entry.fs.isReadOnly() and "-" or "w", " ")
    io.write(formatFSize(entry.size), " ", formatTime(entry.time), "] ")
  end
  if opts.Q then io.write('"') end
  if colorize then io.write("\27[" .. colorize(entry) .. "m") end
  io.write(opts.f and entry.path or entry.name)
  if colorize then io.write("\27[0m") end
  if opts.p and entry.isDirectory then io.write("/") end
  if opts.Q then io.write('"') end
  io.write("\n")
end

local dirs, files = 0, 0
local function count(entry, depth)
  if opts.R or depth > 0 then
    if entry.isDirectory then dirs = dirs + 1 else files = files + 1 end
  end
end

-- обход в глубину; levels[i] - есть ли ещё соседи ниже на уровне i
local function walk(path, levels)
  local entries = list(path)
  for i, entry in ipairs(entries) do
    levels[#levels + 1] = i < #entries
    count(entry, #levels)
    writeEntry(entry, levels)
    yieldopt()
    if entry.isDirectory and opts.level > #levels then
      walk(fs.concat(path, entry.name), levels)
    end
    levels[#levels] = nil
  end
end

for _, arg in ipairs(args) do
  local path = shell.resolve(arg)
  local real, reason = fs.realPath(path)
  if not real then
    die("cannot access ", path, ": ", reason or "unknown error")
  elseif not fs.exists(path) then
    die("cannot access ", path, ":", "No such file or directory")
  end
  local root = stat(real)
  count(root, 0)
  writeEntry(root, {})
  if root.isDirectory then
    walk(real, {})
  end
end

if not opts.C then
  io.write("\n", dirs, " director", dirs == 1 and "y" or "ies", ", ", files, " file", files == 1 and "" or "s", "\n")
end
