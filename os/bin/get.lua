-- get: система, игры и программы из репозиториев - одной командой.
--
--   get                    что есть и что стоит
--   get install ИМЯ...     поставить (игру, ролик, программу или весь набор)
--   get update [ИМЯ...]    обновить всё поставленное (или только это)
--   get remove ИМЯ...      убрать
--   --dry  только показать   --force  качать заново   --disk=ПУТЬ  куда класть новое
--
-- Источники: сама DwOS (Faticc/dwos), игры (Faticc/ocgames) и программы
-- (Faticc/dwapps); свои дописываются в /etc/get.cfg. Состояние и ярлыки -
-- те же, что пишут их установщики (<каталог>/.installed, /.dwos, "-- ярлык
-- на" в /bin), так что games-update и dwapps-update видят поставленное
-- через get, и наоборот.
--
-- Всё, что можно, делается разом: хэши коммитов и манифесты всех
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
  get                    что есть и что стоит
  get install ИМЯ...     поставить: игру, ролик, программу или весь набор
  get update [ИМЯ...]    обновить всё поставленное (или только это)
  get remove ИМЯ...      убрать
  --dry   только показать    --force   качать заново
  --disk=ПУТЬ            куда класть новые игры и ролики (/mnt/...)]])
  return 0
end
if cmd == "ls" then cmd = "list" end
if cmd == "rm" then cmd = "remove" end
if cmd ~= "list" and cmd ~= "install" and cmd ~= "update" and cmd ~= "remove" then
  die("get: неизвестная команда " .. cmd .. " (get help)")
end

------------------------------------------------------------------ источники

local SOURCES = {
  { name = "dwos", title = "DwOS", repo = "Faticc/dwos", sub = "dist", system = true },
  { name = "games", title = "Игры и ролики", repo = "Faticc/ocgames", dir = "/home/games" },
  { name = "dwapps", title = "Программы", repo = "Faticc/dwapps", dir = "/home/dwapps" },
}
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
  s.repo = st.repo or s.repo
  s.branch = st.branch or s.branch or "main"
  s.sub = st.dir or s.sub or ""
  if s.sub ~= "" and s.sub:sub(-1) ~= "/" then s.sub = s.sub .. "/" end
end

------------------------------------------------------------------ сеть: разом

if not component.isAvailable("internet") then die("нужна интернет-карта") end

--- Одним заходом для всех источников: сначала ветки в хэши коммитов (по
--- хэшу raw.githubusercontent не отдаёт устаревшее из кэша), потом манифесты.
local function prefetch(list)
  local jobs = {}
  for _, s in ipairs(list) do
    s.ref = s.branch
    local parts = {}
    jobs[#jobs + 1] = {
      url = ("https://api.github.com/repos/%s/commits/%s"):format(s.repo, s.branch),
      headers = { ["accept"] = "application/vnd.github.sha" },
      write = function(x) parts[#parts + 1] = x end,
      finish = function(err)
        local sha = not err and table.concat(parts):match("^%s*(%x+)%s*$")
        if sha and #sha == 40 then s.ref = sha end
      end,
    }
  end
  fetch.many(jobs)
  jobs = {}
  for _, s in ipairs(list) do
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

--- Каталог, куда смонтирован диск пути: "/" или "/mnt/xxx".
local function mountOf(path)
  local dev = fs.get(path)
  if not dev or (root and dev.address == root.address) then return "/" end
  for d, p in fs.mounts() do
    if d.address == dev.address and p:match("^/mnt/[^/]+$") then return p end
  end
  return "/"
end

local DISK
if opts.disk then
  for d, p in fs.mounts() do
    if p == opts.disk:gsub("/+$", "") or d.address:find(opts.disk, 1, true) == 1 then
      DISK = p
    end
  end
  if not DISK then die("диска " .. opts.disk .. " не видно") end
end

local function mb(n)
  if n >= 1048576 then return ("%.1f МБ"):format(n / 1048576) end
  return ("%d КБ"):format(math.ceil(n / 1024))
end

------------------------------------------------------------------ позиции

-- Позиция - то, что ставится и убирается целиком: игра (файлы одной pkg),
-- ролик или звук к нему, набор программ без частей, сама система. Общие
-- файлы источника (установщик, pkg = "core") ставятся с любой позицией.
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
    elseif not m.packages or e.pkg == "core" or not e.pkg then
      if m.packages then s.core[#s.core + 1] = e
      else
        if not byPkg[s.name] then
          local it = { src = s, key = s.name, title = s.title, files = {}, kind = "app" }
          order[#order + 1] = it
          byPkg[s.name] = it
        end
        local it = byPkg[s.name]
        -- установщик набора - общий файл, остальное - сам набор
        if e.lname == "install.lua" then s.core[#s.core + 1] = e else it.files[#it.files + 1] = e end
      end
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
        if e.lname == b[2] and b[2] ~= "install.lua" then it.aliases[#it.aliases + 1] = b[1] end
      end
    end
  end
  s.items = order
end

local function stateFiles(s)
  if not s.state then return {} end
  return s.state.files or {}
end

--- Где файл стоит сейчас, или nil. Путь - из записи состояния; у
--- программ и старых установщиков его там нет - тогда рядом с состоянием.
--- Файлы системы стоят на своих местах и без записи.
local function placed(s, e)
  local rec = stateFiles(s)[e.lname]
  local path
  if rec and rec.path then path = rec.path
  elseif s.system then path = "/" .. e.lname
  elseif rec then path = s.dir .. "/" .. e.lname end
  if path and fs.exists(path) and not fs.isDirectory(path) then return path, rec end
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

--- Куда класть файл, которого ещё нет.
local function home(s, it, e)
  if s.system then return "/" .. e.lname end
  if it and it.kind == "video" then
    local m = DISK or mountOf(s.dir)
    return (m == "/" and "/home/videos" or (m .. "/videos")) .. "/" .. e.lname
  end
  if it and it.kind == "game" and DISK then return DISK .. "/games/" .. e.lname end
  return s.dir .. "/" .. e.lname
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
    if s.items and (not srcName or s.name == srcName) then
      if not srcName and key == s.name then
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
  if w > n then
    return unicode.wtrunc(str, n) .. " "
  end
  return str .. (" "):rep(n - w)
end

if cmd == "list" then
  local W = math.min(80, (require("term").getViewport()))
  for _, s in ipairs(active) do
    if s.items then
      print(("%s  %s@%s"):format(s.title, s.repo, s.branch))
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
        local name = it.key .. (#(it.aliases or {}) > 0 and it.aliases[1] ~= it.key and ("  " .. table.concat(it.aliases, ",")) or "")
        print("  " .. pad(name, 20) .. pad(it.title or "", W - 44) .. pad(mb(size), 10) .. mark)
      end
    end
  end
  print("get install ИМЯ - поставить, get update - обновить всё, get help")
  return 0
end

-- Собрать план: что качать (need), что стереть (drop), какие позиции
-- в каком источнике будут стоять после.
local plan = {}         -- источник -> { want = {позиция = true}, gone = {} }
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

local need, drops = {}, {}
local stats = { same = 0, get = 0, bytes = 0, gone = 0 }
local newState = {}

for s, p in pairs(plan) do
  local st = s.state or {}
  local ns = {
    repo = s.repo, branch = s.branch,
    dir = (s.sub ~= "" and s.sub:gsub("/+$", "")) or nil,
    files = {}, bin = {}, seen = st.seen,
  }
  if s.system then ns.version = s.manifest.version end
  newState[s] = ns
  -- что ставим: файлы нужных позиций и, раз что-то ставим, общие файлы
  local want, anyWanted = {}, false
  for it in pairs(p.want) do
    anyWanted = true
    for _, e in ipairs(it.files) do want[e] = it end
  end
  -- seen у установщика игр - "уже предлагали": чего там нет, games-update
  -- считает новым и ставит сам. get показывает весь список, так что
  -- предложено всё, что есть в манифесте
  if not s.system then
    ns.seen = ns.seen or {}
    for _, it in ipairs(s.items) do ns.seen[it.key] = true end
  end
  local all, known = {}, {}
  for _, e in ipairs(s.core) do
    all[#all + 1] = e
    if anyWanted then want[e] = want[e] or false end
  end
  for _, it in ipairs(s.items) do
    for _, e in ipairs(it.files) do
      all[#all + 1] = e
      if p.gone[it] then want[e] = nil e.gone = true end
    end
  end

  for _, e in ipairs(all) do
    known[e.lname] = true
    local path, rec = placed(s, e)
    if e.gone then
      if path then drops[#drops + 1] = { path = path, name = e.lname } end
    elseif want[e] == nil or skipped(s, e) then
      if rec and path then ns.files[e.lname] = rec end   -- не трогаем
    else
      local ok, _, now = fresh(s, e)
      if ok then
        stats.same = stats.same + 1
        if not s.system then now.path = path end
        ns.files[e.lname] = now
      else
        e.src = s
        e.to = path or home(s, want[e] or nil, e)
        need[#need + 1] = e
      end
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

-- места хватит? считаем по дискам
do
  local byDisk = {}
  for _, e in ipairs(need) do
    local dev = fs.get(e.to:match("^(.*)/[^/]*$") ~= "" and e.to or "/") or root
    local cur = fs.exists(e.to) and fs.size(e.to) or 0
    byDisk[dev] = (byDisk[dev] or 0) + (e.size or 0) - cur + 512
  end
  for dev, n in pairs(byDisk) do
    local free = (dev.spaceTotal() or 0) - (dev.spaceUsed() or 0)
    if n > free then
      die(("на диске %s не хватит места: нужно %s, свободно %s (--disk=/mnt/...)")
        :format(dev.getLabel() or dev.address:sub(1, 8), mb(n), mb(free)))
    end
  end
end

------------------------------------------------------------------ загрузка

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
  fs.remove(d.path)
  stats.gone = stats.gone + 1
  print(("  %-24s удалён%s"):format(d.name, d.stale and " - его больше нет в репозитории" or ""))
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
    local lib
    if m.lib then
      local sub = m.lib:gsub("^/+", ""):gsub("/+$", "")
      if sub ~= "" then lib = s.dir .. "/" .. sub end
    end
    local wanted = {}
    for _, b in ipairs(m.bin or {}) do
      local rec = ns.files[b[2]]
      local target = rec and (rec.path or (s.dir .. "/" .. b[2]))
      if target and fs.exists(target) then
        wanted[b[1]] = true
        ns.bin[#ns.bin + 1] = b[1]
        local pre = ""
        if b[2] == "install.lua" then
          pre = ("table.insert(a, 1, %q)\n"):format("--to=" .. s.dir)
        elseif lib then
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
