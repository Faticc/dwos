-- get: система, игры и программы из репозитория DwOS - одной командой.
--
--   get                    что есть, что стоит и сколько места на дисках
--   get install ИМЯ...     поставить (игру, ролик, программу или весь набор)
--   get update [ИМЯ...]    обновить всё поставленное (или только это)
--   get remove ИМЯ...      убрать
--   --dry  только показать   --force  качать заново   --disk=ПУТЬ  класть сюда
--
-- Всё лежит в одном репозитории Faticc/dwos: система - в dist/, игры и
-- ролики - в games/, программы - в apps/. Веб-установщик ставит только
-- систему, остальное - get. Свои источники дописываются в /etc/get.cfg.
-- Состояние - в <каталог>/.installed (у системы - /.dwos), ярлыки - в /bin
-- с пометкой "-- ярлык на". Поставленное когда-то из прежних отдельных
-- репозиториев (Faticc/ocgames, Faticc/dwapps) get подхватывает сам, а их
-- установщики и ярлыки games-update/dwapps-update убирает.
--
-- Раскладка по дискам: позиция (игра, ролик, набор программ) лежит целиком
-- на одном диске - игры читают свои файлы из своего каталога. Новая
-- позиция ложится на диск своего каталога (/home/games, /home/videos, ...),
-- а не влезает - на тот, где свободнее, в /mnt/xxx/games, /mnt/xxx/videos
-- и так далее. Сначала раскладываются самые крупные. Дискеты get сам не
-- занимает (вынул - и игры нет), на системном диске оставляет запас.
-- Обновление, которому не хватает места на своём диске, переезжает целиком
-- на другой; --disk переносит уже стоящее туда.
--
-- Всё, что можно, делается разом: хэш коммита и манифесты всех
-- источников - одним заходом, файлы - по четыре запроса сжатыми (lib/fetch),
-- ролики - сжатыми двойниками (.gz), систему целиком - одним пакетом.
-- Интернет-карта берёт тик за каждый запрос и по два тика за каждые 2 КБ,
-- поэтому считаются не секунды, а запросы и байты.

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local shell = require("shell")
local unicode = require("unicode")
local fetch = require("fetch")

local args, opts = shell.parse(...)
local DRY, FORCE = opts.dry and true or false, opts.force and true or false
local cmd = table.remove(args, 1) or "list"

local function die(s) io.stderr:write(s .. "\n") os.exit(1) end

if cmd == "help" or opts.help then
  print([[Использование: get [команда] [ИМЯ]...
  get                    что есть, что стоит, место на дисках
  get install ИМЯ...     поставить: игру, ролик, программу или весь набор
  get update [ИМЯ...]    обновить всё поставленное (или только это)
  get remove ИМЯ...      убрать
  --dry   только показать    --force   качать заново
  --disk=ПУТЬ            класть сюда (/mnt/...); с install - и перенести
                         уже стоящее. Без него get раскладывает сам]])
  return 0
end
if cmd == "ls" then cmd = "list" end
if cmd == "rm" then cmd = "remove" end
if cmd ~= "list" and cmd ~= "install" and cmd ~= "update" and cmd ~= "remove" then
  die("get: неизвестная команда " .. cmd .. " (get help)")
end

------------------------------------------------------------------ источники

local REPO = "Faticc/dwos"
local SOURCES = {
  { name = "dwos", title = "DwOS", sub = "dist", system = true },
  { name = "games", title = "Игры и ролики", sub = "games", dir = "/home/games" },
  { name = "dwapps", alias = "apps", title = "Программы", sub = "apps", dir = "/home/dwapps" },
}
-- прежние отдельные репозитории: поставленное оттуда переезжает сюда
local MOVED = { ["Faticc/ocgames"] = true, ["Faticc/dwapps"] = true }
do
  local f = io.open("/etc/get.cfg")
  if f then
    local src = f:read("*a")
    f:close()
    local chunk = load("return " .. src, "=/etc/get.cfg", "t", {})
    local ok, cfg = pcall(chunk or error)
    if ok and type(cfg) == "table" then
      for _, s in ipairs(cfg.sources or {}) do
        if type(s) == "table" and s.name and s.repo then SOURCES[#SOURCES + 1] = s end
      end
    end
  end
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

local function readState(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local src = f:read("*a")
  f:close()
  local chunk = load("return " .. src, "=state", "t", {})
  local ok, st = pcall(chunk or error)
  return ok and type(st) == "table" and st or nil
end

for _, s in ipairs(SOURCES) do
  s.dir = s.system and "/" or (s.dir or ("/home/" .. s.name)):gsub("/+$", "")
  s.statePath = s.system and "/.dwos" or (s.dir .. "/.installed")
  s.state = readState(s.statePath)
  s.installed = s.system or s.state ~= nil
  local st = s.state or {}
  -- своё (форк, другая ветка) - как записано; прежние репозитории - сюда
  if st.repo and not MOVED[st.repo] then
    s.repo, s.branch, s.sub = st.repo, st.branch or s.branch, st.dir or s.sub
  end
  s.repo = s.repo or REPO
  s.branch = s.branch or "main"
  s.sub = s.sub or ""
  if s.sub ~= "" and s.sub:sub(-1) ~= "/" then s.sub = s.sub .. "/" end
end

------------------------------------------------------------------ сеть: разом

if not component.isAvailable("internet") then die("нужна интернет-карта") end

--- Одним заходом для всех источников: сначала ветки в хэши коммитов (по
--- хэшу raw.githubusercontent не отдаёт устаревшее из кэша; у источников
--- из одного репозитория запрос один), потом манифесты.
local function prefetch(list)
  local jobs, refs = {}, {}
  for _, s in ipairs(list) do
    local key = s.repo .. "@" .. s.branch
    if not refs[key] then
      local r, parts = { ref = s.branch }, {}
      refs[key] = r
      jobs[#jobs + 1] = {
        url = ("https://api.github.com/repos/%s/commits/%s"):format(s.repo, s.branch),
        headers = { ["accept"] = "application/vnd.github.sha" },
        write = function(x) parts[#parts + 1] = x end,
        finish = function(err)
          local sha = not err and table.concat(parts):match("^%s*(%x+)%s*$")
          if sha and #sha == 40 then r.ref = sha end
        end,
      }
    end
  end
  fetch.many(jobs)
  jobs = {}
  for _, s in ipairs(list) do
    s.ref = refs[s.repo .. "@" .. s.branch].ref
    s.base = ("https://raw.githubusercontent.com/%s/%s/%s"):format(s.repo, s.ref, s.sub)
    local parts = {}
    jobs[#jobs + 1] = {
      url = s.base .. "manifest.lua",
      write = function(x) parts[#parts + 1] = x end,
      finish = function(err)
        if err then s.err = "manifest.lua: " .. err return end
        local chunk, perr = load("return " .. table.concat(parts), "=" .. s.name, "t", {})
        local ok, m = pcall(chunk or error, perr)
        if ok and type(m) == "table" and type(m.files) == "table" then s.manifest = m
        else s.err = "manifest.lua не читается: " .. tostring(ok and "не манифест" or m) end
      end,
    }
  end
  fetch.many(jobs)
end

------------------------------------------------------------------ диски

local root = fs.get("/")
local RESERVE = 65536   -- системному диску: журналы, настройки, свои файлы
local SMALL = 1048576   -- меньше - дискета: сам get её не занимает
local COST = 512        -- столько сверх размера весит каждый файл и каталог

-- Диски, куда можно писать: адрес -> { dev, path = "/" или /mnt/xxx, free }
local disks, diskAt = {}, {}
do
  local comps = component.list("filesystem")
  local tmp = computer.tmpAddress()
  for dev, path in fs.mounts() do
    local a = dev.address
    if comps[a] and a ~= tmp then
      local d = diskAt[a]
      if not d then
        local okT, total = pcall(dev.spaceTotal)
        local okU, used = pcall(dev.spaceUsed)
        local okR, ro = pcall(dev.isReadOnly)
        local okL, label = pcall(dev.getLabel)
        total = okT and tonumber(total) or 0
        d = {
          dev = dev, address = a, total = total, ro = not okR or ro,
          free = total - (okU and tonumber(used) or total),
          label = okL and label or nil,
          root = root ~= nil and a == root.address,
        }
        d.small = total < SMALL
        diskAt[a] = d
        disks[#disks + 1] = d
      end
      if d.root then d.path = "/"
      elseif not d.path or (path:match("^/mnt/[^/]+$") and not d.path:match("^/mnt/[^/]+$")) then
        d.path = path
      end
    end
  end
  table.sort(disks, function(x, y) return x.path < y.path end)
end

--- Диск, на который попадает путь.
local function diskOf(path)
  local dev = fs.get(path)
  return dev and diskAt[dev.address] or (root and diskAt[root.address])
end

--- Сколько можно занять: на системном диске - с запасом.
local function room(d) return d.free - (d.root and RESERVE or 0) end

local function mb(n)
  if n >= 1048576 then return ("%.1f МБ"):format(n / 1048576) end
  return ("%d КБ"):format(math.max(0, math.ceil(n / 1024)))
end

local DISK
if opts.disk then
  local want = opts.disk:gsub("/+$", "")
  if want == "" then want = "/" end
  for _, d in ipairs(disks) do
    if d.path == want or d.address:find(opts.disk, 1, true) == 1 or d.label == opts.disk then DISK = d end
  end
  if not DISK and want:sub(1, 1) == "/" and fs.exists(want) then DISK = diskOf(want) end
  if not DISK then die("диска " .. opts.disk .. " не видно") end
  if DISK.ro then die("на " .. DISK.path .. " писать нельзя") end
end

------------------------------------------------------------------ позиции

-- Позиция - то, что ставится и убирается целиком: игра (файлы одной pkg),
-- ролик или звук к нему, набор программ без частей, сама система. Общие
-- файлы источника (pkg = "core") ставятся с любой позицией.
local function itemsOf(s)
  local m = s.manifest
  s.items, s.core = {}, {}
  if s.system then
    local it = { src = s, key = s.name, title = "система " .. (m.version or ""), files = {}, kind = "system" }
    for _, e in ipairs(m.files) do e.lname = e[1] it.files[#it.files + 1] = e end
    s.items[1] = it
    return
  end
  local order, byPkg = {}, {}
  for _, p in ipairs(m.packages or {}) do
    local it = { src = s, key = p[1], title = p[2] .. (p[3] and (" - " .. p[3]) or ""), files = {}, kind = "game" }
    order[#order + 1] = it
    byPkg[p[1]] = it
  end
  local titles, vids = {}, {}
  local function add(e)
    e.lname = e[2] or e[1]
    if e.video then
      vids[#vids + 1] = e
    elseif e.pkg == "core" then
      s.core[#s.core + 1] = e
    elseif not m.packages or not e.pkg then
      -- набор без частей: всё - одна позиция
      if not byPkg[s.name] then
        local it = { src = s, key = s.name, title = s.title, files = {}, kind = "app" }
        order[#order + 1] = it
        byPkg[s.name] = it
      end
      local it = byPkg[s.name]
      it.files[#it.files + 1] = e
    else
      local it = byPkg[e.pkg]
      if not it then
        it = { src = s, key = e.pkg, title = e.pkg, files = {}, kind = "game" }
        order[#order + 1] = it
        byPkg[e.pkg] = it
      end
      it.files[#it.files + 1] = e
    end
  end
  for _, e in ipairs(m.files) do add(e) end
  for _, e in ipairs(m.videos or {}) do e.video = true add(e) end
  for _, e in ipairs(vids) do
    local base = e.lname:gsub("%.[^.]*$", "")
    if e.title then titles[base] = e.title end
  end
  for _, e in ipairs(vids) do
    local base, ext = e.lname:match("^(.*)%.([^.]+)$")
    local it = { src = s, key = e.lname, base = base, files = { e }, kind = "video" }
    it.title = (titles[base] or base) .. (ext == "dfpwm" and " - звук для кассеты" or "")
    if e.secs then it.title = it.title .. (" %d:%02d"):format(math.floor(e.secs / 60), e.secs % 60) end
    order[#order + 1] = it
  end
  -- ярлыки из манифеста - тоже имена позиций: get install bank
  for _, it in ipairs(order) do
    it.aliases = {}
    for _, b in ipairs(m.bin or {}) do
      for _, e in ipairs(it.files) do
        if e.lname == b[2] then it.aliases[#it.aliases + 1] = b[1] end
      end
    end
  end
  s.items = order
end

local function stateFiles(s)
  if not s.state then return {} end
  return s.state.files or {}
end

--- Где файл стоит сейчас, или nil. Путь - из записи состояния; у старых
--- установщиков его там нет - тогда рядом с состоянием. Файлы системы
--- стоят на своих местах и без записи.
local function placed(s, e)
  local rec = stateFiles(s)[e.lname]
  local path
  if rec and rec.path then path = rec.path
  elseif s.system then path = "/" .. e.lname
  elseif rec then path = s.dir .. "/" .. e.lname end
  if path and fs.exists(path) and not fs.isDirectory(path) then return path, rec end
end

--- Каталог, где позиция стоит сейчас (файл lib/x.lua в /a/lib/x.lua -
--- это /a), или nil, если не стоит ни один её файл.
local function baseOf(it)
  for _, e in ipairs(it.files) do
    local path = placed(it.src, e)
    if path and path:sub(-#e.lname - 1) == "/" .. e.lname then return path:sub(1, -#e.lname - 2) end
  end
end

--- Куда класть позицию на диске d.
local function baseOn(d, it)
  local s = it.src
  if it.kind == "video" then return d.path == "/" and "/home/videos" or (d.path .. "/videos") end
  if d == diskOf(s.dir) then return s.dir end
  return (d.path == "/" and "/home/" or (d.path .. "/")) .. s.name
end

--- Файлы, которые не обновляются: свои правки пользователя (keep в
--- манифесте) и .prop - он есть только у установочного носителя.
local function skipped(s, e)
  if not s.system then return false end
  for _, k in ipairs(s.manifest.keep or {}) do
    if k == e.lname and fs.exists("/" .. k) then return true end
  end
  return e.lname == ".prop" and not fs.exists("/.prop")
end

--- Совпадает ли стоящий файл с записью манифеста. Записанному хэшу верим,
--- если размер и время те же, что при записи, - иначе считаем.
local function hashFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local crc = 0
  while true do
    local x = f:read(16384)
    if not x then break end
    crc = fetch.crc32(crc, x)
  end
  f:close()
  return fetch.hex(crc)
end

local function fresh(s, e)
  local path, rec = placed(s, e)
  if not path then return false end
  if FORCE or not e.crc then return false, path end
  local size, mtime = fs.size(path), fs.lastModified(path)
  if e.size and size ~= e.size then return false, path end
  local crc = rec and rec.size == size and rec.mtime == mtime and rec.crc or hashFile(path)
  return crc == e.crc, path, { size = size, crc = crc, mtime = mtime }
end

local function itemPlaced(it)
  for _, e in ipairs(it.files) do if placed(it.src, e) then return true end end
  return false
end

------------------------------------------------------------------ что делать

local active = {}
for _, s in ipairs(SOURCES) do
  -- для list и install нужны все; update и remove - только стоящие
  if cmd == "list" or cmd == "install" or s.installed then active[#active + 1] = s end
end
prefetch(active)
for _, s in ipairs(active) do
  if s.manifest then itemsOf(s) else io.stderr:write(("%s: %s\n"):format(s.name, tostring(s.err))) end
end

--- Найти позиции по имени: ключ, ярлык, имя ролика без расширения,
--- имя источника (весь набор) или "источник/имя".
local function resolve(name)
  local srcName, key = name:match("^([^/]+)/(.+)$")
  key = (key or name):lower()
  local found = {}
  for _, s in ipairs(active) do
    local mine = not srcName or s.name == srcName or s.alias == srcName
    if s.items and mine then
      if not srcName and (key == s.name or key == s.alias) then
        for _, it in ipairs(s.items) do
          -- весь набор: игры и программы, ролики - только поштучно
          if it.kind ~= "video" then found[#found + 1] = it end
        end
        if #found > 0 then return found end
      end
      for _, it in ipairs(s.items) do
        local hit = it.key:lower() == key or (it.base and it.base:lower() == key)
        for _, a in ipairs(it.aliases or {}) do if a:lower() == key then hit = true end end
        if hit then found[#found + 1] = it end
      end
    end
    if #found > 0 then return found end
  end
  return found
end

local function pad(str, n)
  local w = unicode.wlen(str)
  if w >= n then
    return unicode.wtrunc(str, n) .. " "
  end
  return str .. (" "):rep(n - w)
end

if cmd == "list" then
  local W = math.min(80, (require("term").getViewport()))
  for _, s in ipairs(active) do
    if s.items then
      print(("%s  %s@%s/%s"):format(s.title, s.repo, s.branch, s.sub:gsub("/$", "")))
      for _, it in ipairs(s.items) do
        local size, stood, old = 0, false, false
        for _, e in ipairs(it.files) do
          size = size + (e.size or 0)
          if not skipped(s, e) then
            local ok, path = fresh(s, e)
            if path then stood = true end
            if path and not ok then old = true end
          end
        end
        if it.kind == "system" then stood = true end
        local mark = stood and (old and "обновить" or "стоит") or ""
        -- не на своём диске - где именно
        local base = stood and not s.system and baseOf(it)
        local d = base and diskOf(base)
        if d and d ~= diskOf(s.dir) then mark = mark .. " " .. d.path end
        local name = it.key .. (#(it.aliases or {}) > 0 and it.aliases[1] ~= it.key and ("  " .. table.concat(it.aliases, ",")) or "")
        print("  " .. pad(name, 20) .. pad(it.title or "", W - 44) .. pad(mb(size), 10) .. mark)
      end
    end
  end
  local line = {}
  for _, d in ipairs(disks) do
    if not d.ro then
      line[#line + 1] = ("%s %s%s"):format(d.path, mb(math.max(0, d.free)), d.small and " (дискета)" or "")
    end
  end
  print("Свободно: " .. table.concat(line, ", "))
  print("get install ИМЯ - поставить, get update - обновить всё, get help")
  return 0
end

-- Собрать план: какие позиции в каком источнике ставить (want) и убрать (gone).
local plan = {}
local function planOf(s)
  plan[s] = plan[s] or { want = {}, gone = {} }
  return plan[s]
end

if cmd == "install" or cmd == "remove" then
  if #args == 0 then die("get " .. cmd .. ": что именно? (get - список)") end
  for _, name in ipairs(args) do
    local found = resolve(name)
    if #found == 0 then die("не знаю, что такое " .. name .. " (get - список)") end
    for _, it in ipairs(found) do
      local p = planOf(it.src)
      if cmd == "install" then p.want[it] = true else p.gone[it] = true end
    end
  end
end
if cmd == "update" then
  local only
  if #args > 0 then
    only = {}
    for _, name in ipairs(args) do
      local found = resolve(name)
      if #found == 0 then die("не знаю, что такое " .. name) end
      for _, it in ipairs(found) do only[it] = true end
    end
  end
  for _, s in ipairs(active) do
    for _, it in ipairs(s.items or {}) do
      if (not only or only[it]) and (it.kind == "system" or itemPlaced(it)) then planOf(s).want[it] = true end
    end
  end
end

------------------------------------------------------------------ сверка

local drops = {}
local stats = { same = 0, get = 0, bytes = 0, gone = 0 }
local newState = {}
local jobs = {}          -- что качать: { it, s, need = {файлы}, all = {все файлы позиции} }

for s, p in pairs(plan) do
  local st = s.state or {}
  local ns = {
    repo = s.repo, branch = s.branch,
    dir = (s.sub ~= "" and s.sub:gsub("/+$", "")) or nil,
    files = {}, bin = {},
  }
  if s.system then ns.version = s.manifest.version end
  newState[s] = ns
  -- что ставим: файлы нужных позиций и, раз что-то ставим, общие файлы
  local want, anyWanted = {}, false
  for it in pairs(p.want) do
    anyWanted = true
    for _, e in ipairs(it.files) do want[e] = it end
  end
  local core = { src = s, key = s.name, title = s.title, files = s.core, kind = "core" }
  local all, known = {}, {}
  for _, e in ipairs(s.core) do
    all[#all + 1] = e
    if anyWanted then want[e] = core end
  end
  for _, it in ipairs(s.items) do
    for _, e in ipairs(it.files) do
      all[#all + 1] = e
      if p.gone[it] then want[e] = nil e.gone = true end
    end
  end

  local job = {}
  for _, e in ipairs(all) do
    known[e.lname] = true
    local path, rec = placed(s, e)
    if e.gone then
      if path then drops[#drops + 1] = { path = path, name = e.lname } end
    elseif want[e] == nil or skipped(s, e) then
      -- не трогаем; стоит на вынутом диске - помним, где
      local away = rec and rec.path and rec.path:match("^(/mnt/[^/]+)/")
      if rec and (path or (away and not fs.exists(away))) then ns.files[e.lname] = rec end
    else
      local it = want[e]
      local ok, _, now = fresh(s, e)
      e.src, e.cur, e.fresh = s, path, ok
      if ok then
        stats.same = stats.same + 1
        if not s.system then now.path = path end
        ns.files[e.lname] = now
      end
      if not job[it] then
        job[it] = { it = it, s = s, need = {} }
        jobs[#jobs + 1] = job[it]
      end
      if not ok then table.insert(job[it].need, e) end
    end
  end

  -- то, что стояло, а в манифесте больше нет (ролики-мегабайты не трогаем)
  if cmd ~= "remove" then
    for name, rec in pairs(stateFiles(s)) do
      if not known[name] then
        local path = rec.path or (s.system and ("/" .. name) or (s.dir .. "/" .. name))
        if fs.exists(path) and not name:match("%.bin$") and not name:match("%.dfpwm$") then
          drops[#drops + 1] = { path = path, name = name, stale = true }
        end
      end
    end
  end
end

------------------------------------------------------------------ раскладка

--- Сколько займёт на диске: большой файл качается в .part рядом со
--- старым, поэтому место под него нужно целиком; малый пишется сразу.
local function cost(e, to)
  local cur = fs.exists(to) and not fs.isDirectory(to) and fs.size(to) or nil
  if cur and (e.size or 0) <= 65536 then return (e.size or 0) - cur end
  return (e.size or 0) + COST
end

local function bytes(list, base)
  local n = 0
  for _, e in ipairs(list) do n = n + cost(e, base .. "/" .. e.lname) end
  return n
end

--- Диск для позиции в n байт: свой, если влезает, иначе где свободнее.
local function pick(n, home)
  if DISK then return room(DISK) >= n and DISK or nil end
  if home and not home.ro and room(home) >= n then return home end
  local best
  for _, d in ipairs(disks) do
    if not d.ro and not d.small and room(d) >= n and (not best or room(d) > room(best)) then best = d end
  end
  return best
end

local need, moved, homeless = {}, {}, {}
local placing = {}
for _, j in ipairs(jobs) do
  local it, s = j.it, j.s
  if it.kind == "system" or it.kind == "core" then
    -- система - на своих местах, общие файлы - в каталоге источника
    for _, e in ipairs(j.need) do
      e.to = e.cur or (s.system and ("/" .. e.lname) or (s.dir .. "/" .. e.lname))
      local d = diskOf(e.to)
      d.free = d.free - cost(e, e.to)
      if d.free < 0 then homeless[#homeless + 1] = ("%s: на %s не хватает места"):format(e.lname, d.path) end
      need[#need + 1] = e
    end
  else
    local base = baseOf(it)
    local d = base and diskOf(base)
    local move = cmd == "install" and DISK and d and d ~= DISK
    if base and not move then
      -- стоит: докачать на место, если влезает
      local n = bytes(j.need, base)
      if n <= 0 or n <= room(d) then
        d.free = d.free - n
        for _, e in ipairs(j.need) do e.to = e.cur or (base .. "/" .. e.lname) need[#need + 1] = e end
      else
        placing[#placing + 1] = j
        j.from = d
      end
    elseif #j.need > 0 or move then
      placing[#placing + 1] = j
      j.from = move and d or nil
    end
  end
end

-- Новое и переезжающее - группами: позиция, а ролик вместе со звуком к
-- нему (плеер ищет .dfpwm рядом с .bin). Каждой группе - один диск,
-- крупные раскладываются первыми.
local groups, byBase = {}, {}
for _, j in ipairs(placing) do
  j.size = COST
  for _, e in ipairs(j.it.files) do j.size = j.size + (e.size or 0) + COST end
  local key = j.it.kind == "video" and (j.s.name .. "/" .. j.it.base)
  local g = key and byBase[key]
  if not g then
    g = { jobs = {}, size = 0, it = j.it }
    groups[#groups + 1] = g
    if key then byBase[key] = g end
  end
  g.jobs[#g.jobs + 1] = j
  g.size = g.size + j.size
  g.from = g.from or j.from
end
table.sort(groups, function(a, b) return a.size > b.size end)

for _, g in ipairs(groups) do
  local it = g.it
  local home = diskOf(baseOn(diskOf(it.src.dir), it))
  -- звук к стоящему ролику (и наоборот) - к нему в каталог; там не
  -- влезает или просят другой диск - стоящий переезжает вместе с новым
  local mate
  if it.kind == "video" then
    local inGroup, mates = {}, {}
    for _, j in ipairs(g.jobs) do inGroup[j.it] = true end
    for _, x in ipairs(it.src.items) do
      local at = x.kind == "video" and x.base == it.base and not inGroup[x] and baseOf(x)
      if at then mate = at mates[#mates + 1] = x end
    end
    local md = mate and diskOf(mate)
    if md and room(md) >= g.size and (not DISK or DISK == md) then
      home = md
    elseif md then
      mate = nil
      for _, x in ipairs(mates) do
        local j = { it = x, s = x.src, need = {}, from = md, size = COST }
        for _, e in ipairs(x.files) do e.src = x.src j.size = j.size + (e.size or 0) + COST end
        g.jobs[#g.jobs + 1] = j
        g.size = g.size + j.size
        g.from = g.from or md
      end
    end
  end
  local d = pick(g.size, g.from == nil and home or (home ~= g.from and home or nil))
  local names = {}
  for _, j in ipairs(g.jobs) do names[#names + 1] = j.it.key end
  names = table.concat(names, ", ")
  if not d then
    local best
    for _, x in ipairs(disks) do
      if not x.ro and not x.small and (not best or room(x) > room(best)) then best = x end
    end
    homeless[#homeless + 1] = ("%s (%s) не влезает%s"):format(names, mb(g.size),
      DISK and (" на " .. DISK.path .. ", там свободно " .. mb(room(DISK)))
      or best and (": свободнее всего на " .. best.path .. " - " .. mb(room(best))) or "")
  else
    d.free = d.free - g.size
    for _, j in ipairs(g.jobs) do
      local base = (mate and d == diskOf(mate)) and mate or baseOn(d, j.it)
      for _, e in ipairs(j.from and j.it.files or j.need) do
        e.to = base .. "/" .. e.lname
        need[#need + 1] = e
        if e.fresh then stats.same = stats.same - 1 end
        local old = e.cur or placed(j.s, e)
        if old and old ~= e.to then drops[#drops + 1] = { path = old, name = e.lname, unless = e } end
      end
    end
    if d ~= home or g.from then
      moved[#moved + 1] = ("  %s -> %s%s"):format(names, d.path,
        g.from and (" (с " .. g.from.path .. ")") or DISK and "" or " (на своём диске не влезает)")
    end
  end
end

if #homeless > 0 then
  for _, h in ipairs(homeless) do io.stderr:write("  " .. h .. "\n") end
  die("места не хватит - освободи диск, вставь ещё один или get remove ...")
end

------------------------------------------------------------------ загрузка

for _, m in ipairs(moved) do print(m) end
local total = 0
for _, e in ipairs(need) do total = total + (e.gzsize or e.size or 0) end
if #need > 0 then
  print(("%s %d файлов, %s%s"):format(DRY and "Скачалось бы" or "Качаю", #need, mb(total),
    DRY and "" or " - по четыре разом, сжатыми"))
end
if DRY then
  for _, e in ipairs(need) do print(("  %-24s -> %s"):format(e.lname, e.to)) end
  for _, d in ipairs(drops) do print(("  %-24s удалится: %s"):format(d.name, d.path)) end
  return 0
end

local failed = {}
local function run(list, s)
  if #list == 0 then return end
  local _, bad = fetch.files{
    need = list,
    url = function(e, path) return e.src.base .. path end,
    path = function(e) return e.to end,
    -- пакет - только у системы: вся она одним сжатым файлом
    all = s and s.manifest.files, pack = s and s.manifest.pack,
    progress = function(e, n)
      if (e.size or 0) > 262144 then
        io.write(("\r  %-24s %3d%%"):format(e.lname, math.floor(n * 100 / e.size)))
      end
    end,
    done = function(e, n)
      if not n then return end
      e.got = true
      stats.get, stats.bytes = stats.get + 1, stats.bytes + n
      local ns = newState[e.src]
      local rec = { size = n, crc = e.crc, mtime = fs.lastModified(e.to) }
      if not e.src.system then rec.path = e.to end
      ns.files[e.lname] = rec
      io.write(("\r  %-24s %s\n"):format(e.lname, mb(n)))
    end,
  }
  for _, b in ipairs(bad) do
    if not (b.entry.opt and b.code == 404) then failed[#failed + 1] = b end
  end
end

-- система - отдельно (у неё пакет), всё остальное - одним заходом
local sys, rest = {}, {}
for _, e in ipairs(need) do
  if e.src.system then sys[#sys + 1] = e else rest[#rest + 1] = e end
end
local t0 = computer.uptime()
local sysSrc
for s in pairs(plan) do if s.system then sysSrc = s end end
run(sys, sysSrc)
run(rest, nil)

for _, d in ipairs(drops) do
  -- переезд: старое убираем, только если новое пришло
  if not d.unless or d.unless.got then
    fs.remove(d.path)
    stats.gone = stats.gone + 1
    if not d.unless then
      print(("  %-24s удалён%s"):format(d.name, d.stale and " - его больше нет в репозитории" or ""))
    end
    -- опустевшие каталоги позиции на другом диске не оставляем
    local dir = d.path:match("^(/mnt/[^/]+/.+)/[^/]+$")
    while dir do
      local list = fs.list(dir)
      if not list or list() ~= nil then break end
      fs.remove(dir)
      dir = dir:match("^(/mnt/[^/]+/.+)/[^/]+$")
    end
  end
end

------------------------------------------------------------------ ярлыки и состояние

local MARK = "-- ярлык на "
local function isOurs(path)
  local f = io.open(path, "rb")
  if not f then return false end
  local head = f:read(#MARK)
  f:close()
  return head == MARK
end

for s, ns in pairs(newState) do
  if not s.system then
    local m = s.manifest
    local sub = m.lib and m.lib:gsub("^/+", ""):gsub("/+$", "")
    local wanted = {}
    for _, b in ipairs(m.bin or {}) do
      local rec = ns.files[b[2]]
      local target = rec and (rec.path or (s.dir .. "/" .. b[2]))
      if target and fs.exists(target) then
        wanted[b[1]] = true
        ns.bin[#ns.bin + 1] = b[1]
        local pre = ""
        if sub and sub ~= "" and target:sub(-#b[2] - 1) == "/" .. b[2] then
          -- библиотеки - рядом с программой, на том же диске
          local lib = target:sub(1, -#b[2] - 2) .. "/" .. sub
          pre = ("package.path = %q .. package.path\n"):format(lib .. "/?.lua;")
        end
        local body = ("%s%s\nlocal a = { ... }\n%sreturn assert(loadfile(%q))(table.unpack(a))\n")
          :format(MARK, target, pre, target)
        local path = "/bin/" .. b[1] .. ".lua"
        local cur
        local fh = io.open(path, "r")
        if fh then cur = fh:read("*a") fh:close() end
        if cur ~= body and (cur == nil or isOurs(path)) then
          local f = io.open(path, "w")
          if f then f:write(body) f:close() end
        end
      end
    end
    for _, name in ipairs((s.state or {}).bin or {}) do
      local path = "/bin/" .. name .. ".lua"
      if not wanted[name] and fs.exists(path) and isOurs(path) then fs.remove(path) end
    end
  end
  -- не осталось ничего своего - и состояния не надо
  if not s.system and next(ns.files) == nil then
    fs.remove(s.statePath)
  else
    if not fs.exists(s.dir) then fs.makeDirectory(s.dir) end
    local f = io.open(s.statePath, "w")
    if f then f:write(serialize(ns), "\n") f:close() end
  end
end

if #failed > 0 then
  for _, b in ipairs(failed) do io.stderr:write(("  %s: %s\n"):format(b.entry.lname, tostring(b.err))) end
  die(("не скачалось файлов: %d"):format(#failed))
end
if stats.get == 0 and stats.gone == 0 then
  print(("Всё свежее, файлов: %d."):format(stats.same))
else
  print(("Готово за %.1f с: скачано %d (%s), без изменений %d, удалено %d.")
    :format(computer.uptime() - t0, stats.get, mb(stats.bytes), stats.same, stats.gone))
  if sysSrc and #sys > 0 then print("Система обновилась - перезагрузись: reboot") end
end
return 0
