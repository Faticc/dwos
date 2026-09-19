local fs = require("filesystem")
local shell = require("shell")

local args = shell.parse(...)
local dirs = {}
for path in string.gmatch(os.getenv("MANPATH") or "/usr/man", "[^:]+") do
  dirs[#dirs + 1] = path
end

if #args == 0 then
  -- без темы: список всех страниц в несколько колонок
  local topics, seen = {}, {}
  for _, dir in ipairs(dirs) do
    local real = shell.resolve(dir)
    if dir ~= "." and fs.isDirectory(real) then
      for name in fs.list(real) do
        name = name:gsub("/$", "")
        if not seen[name] then
          seen[name] = true
          topics[#topics + 1] = name
        end
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
for _, path in ipairs(dirs) do
  path = shell.resolve(fs.concat(path, topic), "man")
  if path and fs.exists(path) and not fs.isDirectory(path) then
    os.execute((os.getenv("PAGER") or "less") .. " " .. path)
    os.exit()
  end
end
io.stderr:write("No manual entry for " .. topic .. "\n")
return 1
