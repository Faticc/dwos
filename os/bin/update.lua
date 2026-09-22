-- update: обновление DwOS из репозитория одной командой.
--
-- В manifest.lua у каждого файла записаны размер и CRC32 (их проставляет
-- tools/dwosbuild.py). Обновлялка сверяет их со своими файлами и качает
-- только то, что отличается или чего нет. Скачанное поверх стоящего
-- ложится сначала в .part и заменяет старый файл, только если размер и хэш
-- сошлись, - оборванная загрузка рабочую систему не портит.
--
-- Качает lib/fetch.lua: сжатым gzip, по четыре запроса разом, а если
-- меняется почти всё - одним сжатым пакетом всей системы (all.gz).
--
-- Что и с каким хэшем стоит, записано в <корень>/.dwos; там же помнится,
-- откуда обновлялись, чтобы в следующий раз хватило одного "update".

local component = require("component")
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

local fetch = require("fetch")

local function hashFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local crc, n = 0, 0
  while true do
    local s = f:read(16384)
    if not s then break end
    crc, n = fetch.crc32(crc, s), n + #s
  end
  f:close()
  return fetch.hex(crc), n
end

------------------------------------------------------------------ состояние

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

------------------------------------------------------------------ сеть

if not component.isAvailable("internet") then die("нужна интернет-карта") end

-- raw.githubusercontent.com держит файлы в кэше до пяти минут (max-age=300):
-- сразу после публикации по имени ветки может прийти старый манифест, и
-- update скажет "всё свежее". Адрес с хэшем коммита кэш устаревшим не
-- отдаст, поэтому ветка сначала превращается в хэш. Не вышло (лимит API,
-- нет сети до api.github.com) - качаем по имени ветки, как раньше.
local REF = BRANCH
do
  local sha = fetch.get(("https://api.github.com/repos/%s/commits/%s"):format(REPO, BRANCH),
    { headers = { ["accept"] = "application/vnd.github.sha" } })
  sha = sha and sha:match("^%s*(%x+)%s*$")
  if sha and #sha == 40 then REF = sha end
end
local BASE = ("https://raw.githubusercontent.com/%s/%s/%s"):format(REPO, REF, SUB)

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
print(("Ставится в %s%s"):format(TO, DRY and "   (проба, ничего не меняю)" or ""))

-- файлы, которые правит пользователь: раз уж они есть, не трогаем
local keep = {}
for _, name in ipairs(manifest.keep or {}) do keep[name] = true end

local oldFiles = old.files or {}
local new = { repo = REPO, branch = BRANCH, dir = DIR, version = manifest.version, files = {} }

--- Совпадает ли файл на диске с манифестом. Записанному хэшу верим, если
--- размер и время изменения те же, что и при записи, - иначе считаем.
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
local wanted, todo, had = {}, {}, {}

for _, entry in ipairs(manifest.files) do
  local name = entry[1]
  local to = at(name)
  wanted[name] = true
  if keep[name] and fs.exists(to) then
    kept = kept + 1
  elseif name == ".prop" and not fs.exists(to) then
    -- .prop есть только у установочного носителя: install его на HDD не
    -- переносит, и update не должен превращать HDD в "дискету"
    wanted[name] = nil
  elseif upToDate(entry, to) then
    same = same + 1
  else
    todo[#todo + 1] = entry
    had[name] = fs.exists(to)
    if DRY then print(("  %-28s %s"):format(name, had[name] and "обновится" or "скачается")) end
  end
end

if not DRY and #todo > 0 then
  -- пакетом, если меняется почти всё, иначе по файлу, по четыре разом
  local _, bad = fetch.files{
    base = BASE, need = todo, all = manifest.files, pack = manifest.pack,
    path = function(e) return at(e[1]) end,
    done = function(e, n, err, code)
      if n then
        got, fresh = got + n, fresh + 1
        new.files[e[1]] = { size = n, crc = e.crc, mtime = fs.lastModified(at(e[1])) }
        print(("  %-28s %s, %d Б"):format(e[1], had[e[1]] and "обновлён" or "скачан", n))
      elseif code == 404 then
        print(("  %-28s в репозитории нет, пропускаю"):format(e[1]))
      end
    end,
  }
  local fatal
  for _, b in ipairs(bad) do
    if b.code ~= 404 then fatal = fatal or b end
  end
  if fatal then
    for k, v in pairs(oldFiles) do
      if not new.files[k] and wanted[k] then new.files[k] = v end
    end
    writeState(TO, new)
    die("не скачался " .. fatal.entry[1] .. ": " .. tostring(fatal.err))
  end
end

-- то, что ставили прежде, а в манифесте больше нет
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
