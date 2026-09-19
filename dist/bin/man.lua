local fs = require("filesystem")
local shell = require("shell")
local args = shell.parse(...)
local dirs = {}
for path in string.gmatch(os.getenv("MANPATH") or "/usr/man", "[^:]+") do
  dirs[#dirs + 1] = path
end
local ARCHIVE = "pages"
local function openArchive(dir)
  local f = io.open(fs.concat(dir, ARCHIVE), "rb")
  if not f then return nil end
  local ok = f:read("*l") == "DWMAN1"
  local n = ok and tonumber(f:read("*l") or "")
  if not n then f:close() return nil end
  local index, order = {}, {}
  for i = 1, n do
    local name, off, len = (f:read("*l") or ""):match("^(%S+) (%d+) (%d+)$")
    if not name then f:close() return nil end
    index[name] = { tonumber(off), tonumber(len) }
    order[i] = name
  end
  return f, index, order, f:seek()
end
local function fromArchive(dir, topic)
  local f, index, _, base = openArchive(dir)
  if not f then return nil end
  local entry = index[topic]
  if not entry then f:close() return nil end
  f:seek("set", base + entry[1])
  local data = f:read(entry[2])
  f:close()
  return data
end
if #args == 0 then
  local topics, seen = {}, {}
  local function add(name)
    if not seen[name] then
      seen[name] = true
      topics[#topics + 1] = name
    end
  end
  for _, dir in ipairs(dirs) do
    local real = shell.resolve(dir)
    if dir ~= "." and fs.isDirectory(real) then
      for name in fs.list(real) do
        name = name:gsub("/$", "")
        if name ~= ARCHIVE then add(name) end
      end
      local f, _, order = openArchive(real)
      if f then
        f:close()
        for _, name in ipairs(order) do add(name) end
      end
    end
  end
  table.sort(topics)
  io.write("Usage: man <topic>\nСправка есть по темам:\n")
  local width = 1
  for _, t in ipairs(topics) do width = math.max(width, #t + 2) end
  local cols = math.max(1, math.floor(((require("tty").getViewport()) or 80) / width))
  for i, t in ipairs(topics) do
    io.write(t, string.rep(" ", width - #t))
    if i % cols == 0 then io.write("\n") end
  end
  if #topics % cols ~= 0 then io.write("\n") end
  return 1
end
local topic = args[1]
local pager = os.getenv("PAGER") or "less"
for _, dir in ipairs(dirs) do
  local real = shell.resolve(dir)
  local path = shell.resolve(fs.concat(dir, topic), "man")
  if path and fs.exists(path) and not fs.isDirectory(path) then
    os.execute(pager .. " " .. path)
    os.exit()
  end
  if real and fs.isDirectory(real) then
    local data = fromArchive(real, topic)
    if data then
      local tmp = "/tmp/man." .. topic:gsub("[^%w%._-]", "_")
      local out = io.open(tmp, "wb")
      if not out then
        io.write(data)
        os.exit()
      end
      out:write(data)
      out:close()
      os.execute(pager .. " " .. tmp)
      fs.remove(tmp)
      os.exit()
    end
  end
end
io.stderr:write("No manual entry for " .. topic .. "\n")
return 1
