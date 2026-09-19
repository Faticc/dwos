local component = require("component")
local computer = require("computer")
local shell = require("shell")
local fs = require("filesystem")
local _, opts = shell.parse(...)
if opts.help then
  io.write([[Usage: update [OPTION]...
  --repo=OWNER/REPO  откуда качать (Faticc/dwos)
  --branch=BRANCH    ветка (main)
  --dir=PATH         подкаталог репозитория (dist)
  --to=PATH          что обновлять (/)
  --dry              только показать, что изменится
  --force            скачать всё заново
  --rehash           пересчитать хэши своих файлов
]])
  return 0
end
local DRY, FORCE, REHASH = opts.dry and true, opts.force and true, opts.rehash and true
local STATE = ".dwos"
local function die(s) io.stderr:write(s .. "\n") os.exit(1) end
local crc32
do
  local f = load([[
    local T = {}
    for i = 0, 255 do
      local c = i
      for _ = 1, 8 do
        if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
      end
      T[i] = c
    end
    local byte = string.byte
    return function(crc, s)
      crc = ~crc & 0xFFFFFFFF
      for i = 1, #s do crc = T[(crc ~ byte(s, i)) & 0xFF] ~ (crc >> 8) end
      return ~crc & 0xFFFFFFFF
    end]])
  if f then
    crc32 = f()
  elseif bit32 then
    local band, bxor, rshift, bnot = bit32.band, bit32.bxor, bit32.rshift, bit32.bnot
    local T = {}
    for i = 0, 255 do
      local c = i
      for _ = 1, 8 do
        if band(c, 1) == 1 then c = bxor(0xEDB88320, rshift(c, 1)) else c = rshift(c, 1) end
      end
      T[i] = c
    end
    local byte = string.byte
    crc32 = function(crc, s)
      crc = bnot(crc)
      for i = 1, #s do crc = bxor(T[band(bxor(crc, byte(s, i)), 0xFF)], rshift(crc, 8)) end
      return bnot(crc)
    end
  else
    die("нет ни битовых операций, ни bit32 - хэш считать нечем")
  end
end
local function hex(crc) return ("%08x"):format(crc) end
local lastYield = computer.uptime()
local function breathe()
  if computer.uptime() - lastYield > 1 then
    os.sleep(0)
    lastYield = computer.uptime()
  end
end
local function hashFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local crc, n = 0, 0
  while true do
    local s = f:read(16384)
    if not s then break end
    crc, n = crc32(crc, s), n + #s
    breathe()
  end
  f:close()
  return hex(crc), n
end
local function serialize(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "string" then return ("%q"):format(v) end
  if t == "number" or t == "boolean" then return tostring(v) end
  if t ~= "table" then return "nil" end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out, ind2 = { "{\n" }, ind .. " "
  for _, k in ipairs(keys) do
    local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. serialize(k) .. "]")
    out[#out + 1] = ind2 .. key .. " = " .. serialize(v[k], ind2) .. ",\n"
  end
  out[#out + 1] = ind .. "}"
  return table.concat(out)
end
local function readState(dir)
  local f = io.open(dir .. "/" .. STATE, "r")
  if not f then return nil end
  local src = f:read("*a")
  f:close()
  local chunk = load("return " .. src, "=" .. STATE, "t", {})
  local ok, st = pcall(chunk or error)
  return ok and type(st) == "table" and st or nil
end
local function writeState(dir, st)
  local f = io.open(dir .. "/" .. STATE, "w")
  if not f then return false end
  f:write(serialize(st), "\n")
  f:close()
  return true
end
local TO = (opts.to or "/"):gsub("/+$", "")
if TO == "" then TO = "/" end
local old = readState(TO) or {}
local REPO = opts.repo or old.repo or "Faticc/dwos"
local BRANCH = opts.branch or old.branch or "main"
local DIR = opts.dir or old.dir or "dist"
local SUB = DIR ~= "" and (DIR:gsub("/+$", "") .. "/") or ""
local function at(name)
  return (TO == "/" and "" or TO) .. "/" .. name
end
if not component.isAvailable("internet") then die("нужна интернет-карта") end
local internet = require("internet")
local REF = BRANCH
do
  local ok, h = pcall(internet.request,
    ("https://api.github.com/repos/%s/commits/%s"):format(REPO, BRANCH), nil,
    { ["user-agent"] = "dwos", ["accept"] = "application/vnd.github.sha" })
  if ok and h then
    local body = {}
    pcall(function() for chunk in h do body[#body + 1] = chunk end end)
    pcall(h.close)
    local sha = table.concat(body):match("^%s*(%x+)%s*$")
    if sha and #sha == 40 then REF = sha end
  end
end
local function open(path)
  local url = ("https://raw.githubusercontent.com/%s/%s/%s%s"):format(REPO, REF, SUB, path)
  local ok, h = pcall(internet.request, url, nil, { ["user-agent"] = "dwos" })
  if not ok then return nil, tostring(h) end
  local code
  for _ = 1, 200 do
    code = h.response()
    if code then break end
    os.sleep(0.05)
  end
  if code and code ~= 200 then pcall(h.close) return nil, "HTTP " .. code, code end
  return h
end
local function fetch(path)
  local h, why = open(path)
  if not h then return nil, why end
  local parts = {}
  local got, err = pcall(function()
    for chunk in h do parts[#parts + 1] = chunk end
  end)
  pcall(h.close)
  if not got then return nil, tostring(err) end
  return table.concat(parts)
end
local function mkdir(path)
  local dir = path:match("^(.*)/[^/]*$")
  if dir and dir ~= "" and not fs.exists(dir) then fs.makeDirectory(dir) end
end
local function download(path, to)
  local h, why, code = open(path)
  if not h then return nil, why, code end
  mkdir(to)
  local f, werr = io.open(to, "wb")
  if not f then pcall(h.close) return nil, tostring(werr) end
  local n, crc = 0, 0
  local got, err = pcall(function()
    for chunk in h do
      f:write(chunk)
      n, crc = n + #chunk, crc32(crc, chunk)
      breathe()
    end
  end)
  f:close()
  pcall(h.close)
  if not got then return nil, tostring(err) end
  return n, hex(crc)
end
local function install(entry, to)
  local part = to .. ".part"
  local last
  for try = 1, 2 do
    local n, crc, code = download(entry[1], part)
    if not n then
      fs.remove(part)
      if code == 404 then return nil, crc, 404 end
      last = crc
    elseif (entry.size and n ~= entry.size) or (entry.crc and crc ~= entry.crc) then
      fs.remove(part)
      last = ("пришло %d Б с хэшем %s, а ждали %s Б с хэшем %s")
        :format(n, crc, tostring(entry.size), tostring(entry.crc))
    else
      if fs.exists(to) then fs.remove(to) end
      local ok, rerr = fs.rename(part, to)
      if not ok then fs.remove(part) return nil, "не переименовать .part: " .. tostring(rerr) end
      return n, crc
    end
    if try == 1 then print("   повтор: " .. tostring(last)) end
  end
  return nil, last
end
print(("DwOS: %s@%s%s/%s"):format(REPO, BRANCH, REF ~= BRANCH and (" (" .. REF:sub(1, 7) .. ")") or "",
  SUB ~= "" and SUB or "."))
local src, why = fetch("manifest.lua")
if not src then die("manifest.lua: " .. tostring(why)) end
local chunk, perr = load("return " .. src, "=manifest", "t", {})
if not chunk then die("manifest.lua не читается: " .. tostring(perr)) end
local manifest = chunk()
if type(manifest) ~= "table" or type(manifest.files) ~= "table" then
  die("manifest.lua не похож на манифест")
end
print(("Ставится в %s%s"):format(TO, DRY and "   (проба, ничего не меняю)" or ""))
local keep = {}
for _, name in ipairs(manifest.keep or {}) do keep[name] = true end
local oldFiles = old.files or {}
local new = { repo = REPO, branch = BRANCH, dir = DIR, version = manifest.version, files = {} }
local function upToDate(entry, to)
  if FORCE or not fs.exists(to) or fs.isDirectory(to) then return false end
  if not entry.crc then return false end
  local size, mtime = fs.size(to), fs.lastModified(to)
  if entry.size and size ~= entry.size then return false end
  local rec = oldFiles[entry[1]]
  local crc
  if not REHASH and rec and rec.crc and rec.size == size and rec.mtime == mtime then
    crc = rec.crc
  else
    crc = hashFile(to)
  end
  if crc == entry.crc then
    new.files[entry[1]] = { size = size, crc = crc, mtime = mtime }
    return true
  end
  return false
end
local got, same, fresh, gone, kept = 0, 0, 0, 0, 0
local wanted = {}
for _, entry in ipairs(manifest.files) do
  local name = entry[1]
  local to = at(name)
  wanted[name] = true
  if keep[name] and fs.exists(to) then
    kept = kept + 1
  elseif upToDate(entry, to) then
    same = same + 1
  elseif DRY then
    io.write(("  %-28s "):format(name))
    print(fs.exists(to) and "обновится" or "скачается")
  else
    io.write(("  %-28s "):format(name))
    local had = fs.exists(to)
    local n, crc, code = install(entry, to)
    if n then
      got, fresh = got + n, fresh + 1
      new.files[name] = { size = n, crc = crc, mtime = fs.lastModified(to) }
      print(("%s, %d Б"):format(had and "обновлён" or "скачан", n))
    elseif code == 404 then
      print("в репозитории нет, пропускаю")
    else
      print("")
      for k, v in pairs(oldFiles) do
        if not new.files[k] and wanted[k] then new.files[k] = v end
      end
      writeState(TO, new)
      die("не скачался " .. name .. ": " .. tostring(crc))
    end
  end
end
for name in pairs(oldFiles) do
  if not wanted[name] then
    local path = at(name)
    if fs.exists(path) and not fs.isDirectory(path) then
      print(("  %-28s %s"):format(name, DRY and "удалится" or "удалён - его больше нет в сборке"))
      if not DRY then fs.remove(path) end
      gone = gone + 1
    end
  end
end
if DRY then
  print(("Проба: без изменений %d, своих не трогаю %d, к удалению %d."):format(same, kept, gone))
  return 0
end
if not writeState(TO, new) then
  print("  внимание: не записать " .. TO .. "/" .. STATE)
end
if fresh == 0 and gone == 0 then
  print(("Всё свежее, файлов %d (своих не трогал %d)."):format(same, kept))
else
  print(("Готово: скачано %d (%d Б), без изменений %d, удалено %d."):format(fresh, got, same, gone))
  print("Перезагрузись, чтобы новая система заработала целиком: reboot")
end
return 0
