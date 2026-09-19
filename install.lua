-- Установка DwOS на дискету, одной командой из обычного OpenOS:
--
--   wget -f https://raw.githubusercontent.com/Faticc/dwos/main/install.lua /tmp/i.lua && /tmp/i.lua
--
-- Дальше: вставь дискету в новый компьютер, загрузись с неё и набери
-- install - система переедет на жёсткий диск.
--
--   --repo=владелец/репо   откуда качать (по умолчанию Faticc/dwos)
--   --branch=ветка         ветка (main)
--   --dir=подкаталог       где в репозитории лежит сборка (dist)
--   --to=/mnt/xxx          куда писать, без вопросов
--   --force                скачать всё заново, даже совпадающее
--   --dry                  только показать, что будет скачано
--
-- Файлы проверяются по manifest.lua: у каждого записаны размер и CRC32.
-- Скачанное ложится в .part и заменяет старое, только если сошлось, -
-- оборванная загрузка полдискеты не испортит.

local component = require("component")
local computer = require("computer")
local shell = require("shell")
local fs = require("filesystem")

local _, opts = shell.parse(...)
local DRY = opts.dry and true or false
local FORCE = opts.force and true or false

local REPO = opts.repo or "Faticc/dwos"
local BRANCH = opts.branch or "main"
local DIR = (opts.dir or "dist"):gsub("/+$", "")
local SUB = DIR ~= "" and (DIR .. "/") or ""

local function die(s) io.stderr:write(s .. "\n") os.exit(1) end

------------------------------------------------------------------ CRC32

--- Процессор бывает и на Lua 5.3 (операторы & ~ >>), и на 5.2 (bit32):
--- код под 5.3 в 5.2 даже не разберётся, поэтому он собирается через load.
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
  local crc = 0
  while true do
    local s = f:read(16384)
    if not s then break end
    crc = crc32(crc, s)
    breathe()
  end
  f:close()
  return hex(crc)
end

------------------------------------------------------------------ сеть

if not component.isAvailable("internet") then die("нужна интернет-карта") end
local internet = require("internet")

local function open(path)
  local url = ("https://raw.githubusercontent.com/%s/%s/%s%s"):format(REPO, BRANCH, SUB, path)
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
  local ok, err = pcall(function()
    for chunk in h do parts[#parts + 1] = chunk end
  end)
  pcall(h.close)
  if not ok then return nil, tostring(err) end
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
  local ok, err = pcall(function()
    for chunk in h do
      f:write(chunk)
      n, crc = n + #chunk, crc32(crc, chunk)
      breathe()
    end
  end)
  f:close()
  pcall(h.close)
  if not ok then return nil, tostring(err) end
  return n, hex(crc)
end

--- Скачать в .part, сверить с манифестом и только тогда подменить файл.
local function put(entry, to)
  local part = to .. ".part"
  local last
  for try = 1, 2 do
    local n, crc = download(entry[1], part)
    if not n then
      fs.remove(part)
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

------------------------------------------------------------------ манифест

print(("DwOS: %s@%s/%s"):format(REPO, BRANCH, SUB ~= "" and SUB or "."))
local src, why = fetch("manifest.lua")
if not src then die("manifest.lua: " .. tostring(why)) end
local chunk, perr = load("return " .. src, "=manifest", "t", {})
if not chunk then die("manifest.lua не читается: " .. tostring(perr)) end
local manifest = chunk()
if type(manifest) ~= "table" or type(manifest.files) ~= "table" then
  die("manifest.lua не похож на манифест")
end

local need = 0
for _, e in ipairs(manifest.files) do need = need + (e.size or 0) + 512 end
print(("Сборка %s %s: %d файлов, примерно %d КБ на диске")
  :format(manifest.name or "DwOS", manifest.version or "", #manifest.files,
          math.floor(need / 1024 + 0.5)))

------------------------------------------------------------------ куда писать

local rootfs = fs.get("/")
local comps = component.list("filesystem")
local devices = {}
for dev, path in fs.mounts() do
  if comps[dev.address] then
    local known = devices[dev]
    devices[dev] = known and #known < #path and known or path
  end
end
local devdev = fs.get("/dev")
devices[devdev == rootfs or devdev] = nil

local targets = {}
for dev, path in pairs(devices) do
  local ok, total = pcall(dev.spaceTotal)
  if not dev.isReadOnly() and dev.address ~= computer.tmpAddress()
     and dev.address ~= rootfs.address then
    targets[#targets + 1] = { dev = dev, path = path, total = ok and total or math.huge }
  end
end
-- дискеты первыми: они меньше всех
table.sort(targets, function(a, b)
  if a.total ~= b.total then return a.total < b.total end
  return a.path < b.path
end)

if #targets == 0 then die("некуда писать: вставь чистую дискету") end

local target
if opts.to then
  local want = opts.to:gsub("/+$", "")
  for _, t in ipairs(targets) do
    if t.path == want or t.dev.address:find(opts.to, 1, true) == 1 then target = t end
  end
  if not target then die("не нашёл диск " .. opts.to) end
elseif #targets == 1 then
  target = targets[1]
else
  print("Куда ставить DwOS?")
  for i, t in ipairs(targets) do
    local label = t.dev.getLabel()
    print(("%d) %s  %s  %d КБ свободно"):format(
      i, t.path, label and ("[" .. label .. "]") or t.dev.address:sub(1, 8),
      math.floor((t.total - t.dev.spaceUsed()) / 1024)))
  end
  io.write("Номер (q - отмена): ")
  local answer = io.read() or "q"
  if answer == "q" then print("Отменено.") return end
  target = targets[tonumber(answer) or 0]
  if not target then die("нет такого номера") end
end

local TO = target.path == "/" and "" or target.path
local free = target.total - target.dev.spaceUsed()
print(("Ставлю на %s (%d КБ свободно)"):format(target.path, math.floor(free / 1024)))
if free < need and not DRY then
  io.write("Места, похоже, не хватит. Всё равно пробовать? [y/N] ")
  if not ((io.read() or "n"):match("^%s*[Yy]")) then print("Отменено.") return end
end

------------------------------------------------------------------ загрузка

local got, fresh, same = 0, 0, 0
for _, entry in ipairs(manifest.files) do
  local name = entry[1]
  local to = TO .. "/" .. name
  local have = not FORCE and fs.exists(to) and not fs.isDirectory(to)
    and entry.crc and fs.size(to) == entry.size and hashFile(to) == entry.crc
  if have then
    same = same + 1
  elseif DRY then
    print(("  %-28s %s"):format(name, fs.exists(to) and "обновится" or "скачается"))
  else
    io.write(("  %-28s "):format(name))
    local n, crc = put(entry, to)
    if not n then
      print("")
      die("не скачался " .. name .. ": " .. tostring(crc))
    end
    got, fresh = got + n, fresh + 1
    print(("%d Б"):format(n))
  end
end

if DRY then
  print(("Проба: скачать надо %d файлов, %d уже совпадают."):format(#manifest.files - same, same))
  return
end

-- чтобы update с дискеты знал, откуда обновляться
do
  local f = io.open(TO .. "/.dwos", "w")
  if f then
    f:write(("{ repo = %q, branch = %q, dir = %q, version = %q, files = {} }\n")
      :format(REPO, BRANCH, DIR, tostring(manifest.version)))
    f:close()
  end
end

pcall(target.dev.setLabel, manifest.label or "DwOS")

print(("Готово: скачано %d файлов (%d Б), совпадало %d."):format(fresh, got, same))
print("")
print("Дальше: вставь дискету в компьютер, где её видно первой,")
print("загрузись с неё и набери install - система переедет на HDD.")
io.write("Сделать эту дискету загрузочной прямо сейчас? [y/N] ")
if (io.read() or "n"):match("^%s*[Yy]") then
  if computer.setBootAddress(target.dev.address) then
    print("Загрузка теперь с " .. target.dev.address)
    io.write("Перезагрузиться? [y/N] ")
    if (io.read() or "n"):match("^%s*[Yy]") then computer.shutdown(true) end
  end
end
