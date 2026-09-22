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
-- Скачанное поверх стоящего ложится в .part и заменяет старое, только если
-- сошлось, - оборванная загрузка полдискеты не испортит.
--
-- Качает lib/fetch.lua из самой сборки (грузится в память, на диск не
-- пишется): сжатым пакетом одним запросом, если ставить почти всё, и по
-- файлу, по четыре запроса разом, если не хватает немногого.

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

------------------------------------------------------------------ сеть

if not component.isAvailable("internet") then die("нужна интернет-карта") end
local inet = component.internet

-- raw.githubusercontent.com держит файлы в кэше до пяти минут: манифест и
-- файлы могли бы прийти от разных публикаций. По хэшу коммита кэш
-- устаревшего не отдаёт, поэтому ветка сначала превращается в хэш. Не вышло
-- (лимит API) - качаем по имени ветки.

--- Скачать целиком, без сжатия: так приходят только два файла библиотек,
--- дальше всё качает fetch из самой сборки.
local function raw(url, headers)
  local ok, h = pcall(inet.request, url, nil, headers or { ["user-agent"] = "dwos" })
  if not ok or not h then return nil, tostring(h) end
  local code
  for _ = 1, 600 do
    code = h.response()
    if code then break end
    os.sleep(0.05)
  end
  if code ~= 200 then pcall(h.close) return nil, "HTTP " .. tostring(code) end
  local parts = {}
  while true do
    local chunk, why = h.read(2048)
    if not chunk then
      pcall(h.close)
      if why then return nil, tostring(why) end
      break
    end
    parts[#parts + 1] = chunk
  end
  return table.concat(parts)
end

local REF = BRANCH
do
  local sha = raw(("https://api.github.com/repos/%s/commits/%s"):format(REPO, BRANCH),
    { ["user-agent"] = "dwos", ["accept"] = "application/vnd.github.sha" })
  sha = sha and sha:match("^%s*(%x+)%s*$")
  if sha and #sha == 40 then REF = sha end
end
local BASE = ("https://raw.githubusercontent.com/%s/%s/%s"):format(REPO, REF, SUB)

--- Библиотека из сборки: грузится в память, на диск не пишется.
local function lib(name)
  local src, why = raw(BASE .. "lib/" .. name .. ".lua")
  if not src then die(("lib/%s.lua: %s"):format(name, tostring(why))) end
  local chunk, err = load(src, "=" .. name, "t", _G)
  if not chunk then die(("lib/%s.lua: %s"):format(name, tostring(err))) end
  local m = chunk()
  package.loaded[name] = m
  return m
end
local saved = { inflate = package.loaded.inflate, fetch = package.loaded.fetch }
lib("inflate")
local fetch = lib("fetch")
-- чужой системе свои модули не оставляем
package.loaded.inflate, package.loaded.fetch = saved.inflate, saved.fetch

local function hashFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local crc = 0
  while true do
    local s = f:read(16384)
    if not s then break end
    crc = fetch.crc32(crc, s)
  end
  f:close()
  return fetch.hex(crc)
end

------------------------------------------------------------------ манифест

print(("DwOS: %s@%s%s/%s"):format(REPO, BRANCH, REF ~= BRANCH and (" (" .. REF:sub(1, 7) .. ")") or "",
  SUB ~= "" and SUB or "."))
local src, why = fetch.get(BASE .. "manifest.lua")
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

local todo, same = {}, 0
for _, entry in ipairs(manifest.files) do
  local name = entry[1]
  local to = TO .. "/" .. name
  local have = not FORCE and fs.exists(to) and not fs.isDirectory(to)
    and entry.crc and fs.size(to) == entry.size and hashFile(to) == entry.crc
  if have then
    same = same + 1
  else
    todo[#todo + 1] = entry
    if DRY then print(("  %-28s %s"):format(name, fs.exists(to) and "обновится" or "скачается")) end
  end
end

local got, fresh = 0, 0
if not DRY and #todo > 0 then
  local t0 = computer.uptime()
  local placed, bad = fetch.files{
    base = BASE, need = todo, all = manifest.files, pack = manifest.pack,
    path = function(e) return TO .. "/" .. e[1] end,
    done = function(e, n)
      if n then
        got, fresh = got + n, fresh + 1
        print(("  %-28s %d Б"):format(e[1], n))
      end
    end,
  }
  if #bad > 0 then
    for _, b in ipairs(bad) do print(("  %-28s %s"):format(b.entry[1], tostring(b.err))) end
    die(("не скачалось файлов: %d"):format(#bad))
  end
  print(("Скачано за %.1f с"):format(computer.uptime() - t0))
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
print("Игры и программы потом - из самой DwOS: get (get install mario).")
io.write("Сделать эту дискету загрузочной прямо сейчас? [y/N] ")
if (io.read() or "n"):match("^%s*[Yy]") then
  if computer.setBootAddress(target.dev.address) then
    print("Загрузка теперь с " .. target.dev.address)
    io.write("Перезагрузиться? [y/N] ")
    if (io.read() or "n"):match("^%s*[Yy]") then computer.shutdown(true) end
  end
end
