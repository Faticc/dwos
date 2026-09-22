-- fetch: скачивание по HTTP так быстро, как позволяет интернет-карта.
--
-- Сколько стоит сеть в моде (InternetCard, OC 1.8): request и read - не
-- прямые вызовы, по тику (50 мс) каждый, и за тик машина делает только один
-- такой; response и close бесплатны. read отдаёт не больше 2 КБ, а следующие
-- 2 КБ карта подкачивает, только когда read застал её очередь пустой, -
-- поэтому на каждые 2 КБ уходит два тика, около 20 КБ/с на поток, и это
-- потолок. Выжать можно всё остальное:
--   * сжатие: просим gzip (raw.githubusercontent его отдаёт), код на Lua
--     приходит втрое меньше, распаковка тратит процессор, а не тики;
--   * до четырёх запросов сразу (больше карта не держит): пока ждём, когда
--     сервер ответит на один, читаем другой, и ожидание тиков не стоит;
--   * конец потока: gzip кончается сам, размер без сжатия известен из
--     манифеста - два лишних read на "" и nil в конце каждого файла не нужны;
--   * код ответа виден бесплатно, через response: 404 не стоит ни одного read.
--
-- Работает и под OpenOS: веб-установщик качает этот файл и грузит через load
-- (inflate тогда кладёт в package.loaded сам).
--
--   local fetch = require("fetch")
--   local body, err, code = fetch.get(url)
--   fetch.many({ { url = ..., size = ..., write = f(s), finish = f(err, code) }, ... })

local component = require("component")
local computer = require("computer")
local inflate = require("inflate")

local fetch = {}

fetch.parallel = 4             -- столько запросов карта держит разом
fetch.timeout = 30             -- секунд ждать ответа сервера
fetch.agent = "dwos"

------------------------------------------------------------------ CRC32

--- Процессор бывает и на Lua 5.3 (операторы & ~ >>), и на 5.2 (bit32): код
--- под 5.3 в 5.2 даже не разберётся, поэтому он собирается через load.
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
    fetch.crc32 = f()
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
    fetch.crc32 = function(crc, s)
      crc = bnot(crc)
      for i = 1, #s do crc = bxor(T[band(bxor(crc, byte(s, i)), 0xFF)], rshift(crc, 8)) end
      return bnot(crc)
    end
  end
end

function fetch.hex(crc) return ("%08x"):format(crc) end

------------------------------------------------------------------ запросы

local function header(headers, name)
  if type(headers) ~= "table" then return nil end
  name = name:lower()
  for k, v in pairs(headers) do
    if type(k) == "string" and k:lower() == name then
      return type(v) == "table" and v[1] or v
    end
  end
end

--- Скачать список. Каждое задание:
---   url            адрес
---   size           сколько байт ждать без сжатия (если известно): по нему
---                  видно конец, и лишние read не нужны
---   headers        свои заголовки (к ним добавляются user-agent и gzip)
---   plain          не просить сжатия
---   write(s)       очередной кусок тела, уже распакованный
---   finish(err, code)  конец: err == nil - всё пришло
--- opts.parallel - сколько запросов сразу. Возвращает число удавшихся.
function fetch.many(jobs, opts)
  opts = opts or {}
  local inet = component.internet
  local limit = math.max(1, math.min(opts.parallel or fetch.parallel, 16))
  local queue, active, okCount = {}, {}, 0
  for i = 1, #jobs do queue[i] = jobs[i] end
  local qi = 1

  local function done(a, err, code)
    for i = #active, 1, -1 do if active[i] == a then table.remove(active, i) end end
    if a.h then pcall(a.h.close) end
    a.h = nil
    if not err then okCount = okCount + 1 end
    if a.job.finish then a.job.finish(err, code) end
  end

  local function start(job)
    local hd = { ["user-agent"] = fetch.agent }
    if not job.plain then hd["accept-encoding"] = "gzip" end
    for k, v in pairs(job.headers or {}) do hd[k] = v end
    local ok, h, why = pcall(inet.request, job.url, job.post, hd)
    if not ok or not h then
      why = tostring(ok and why or h)
      if why:find("too many", 1, true) then return "wait" end
      if job.finish then job.finish(why) end
      return
    end
    active[#active + 1] = { job = job, h = h, t0 = computer.uptime(), got = 0 }
  end

  --- Ответ пришёл: код и сжатие видны бесплатно. true - можно читать.
  local function arrived(a)
    if a.code then return true end
    local code, _, headers = a.h.response()
    if not code then
      if computer.uptime() - a.t0 > (opts.timeout or fetch.timeout) then
        done(a, "сервер не ответил за " .. (opts.timeout or fetch.timeout) .. " с")
      end
      return false
    end
    a.code = code
    if code < 200 or code >= 300 then
      done(a, "HTTP " .. tostring(code), code)
      return false
    end
    local job = a.job
    if (header(headers, "content-encoding") or ""):lower():find("gzip", 1, true) then
      a.z = inflate.new(function(s)
        a.got = a.got + #s
        if job.write then job.write(s) end
      end, "gzip")
    end
    return true
  end

  local function step(a)
    local ok, chunk, why = pcall(a.h.read, 2048)
    if not ok or (chunk == nil and why) then
      return done(a, tostring(ok and why or chunk))
    end
    local job = a.job
    if chunk == nil then                   -- конец потока
      if a.z and not a.z.done then return done(a, "поток оборвался") end
      if job.size and a.got ~= job.size then
        return done(a, ("пришло %d Б, а ждали %d"):format(a.got, job.size))
      end
      return done(a, nil, a.code)
    end
    if chunk == "" then return end         -- карта подкачивает следующие 2 КБ
    if a.z then
      local zok, zerr = pcall(a.z.feed, a.z, chunk)
      if not zok then return done(a, tostring(zerr)) end
      if a.z.done then return done(a, nil, a.code) end
    else
      a.got = a.got + #chunk
      if job.write then
        local wok, werr = pcall(job.write, chunk)
        if not wok then return done(a, tostring(werr)) end
      end
      if job.size and a.got >= job.size then return done(a, nil, a.code) end
    end
  end

  while qi <= #queue or #active > 0 do
    -- в первую очередь - новые запросы: ответ сервера идёт своим чередом,
    -- пока мы читаем другие
    local started = false
    if qi <= #queue and #active < limit then
      local r = start(queue[qi])
      if r ~= "wait" then qi, started = qi + 1, true end
    end
    if not started then
      local reading
      for i = 1, #active do
        local a = active[i]
        if a and arrived(a) then reading = a break end
      end
      if reading then
        step(reading)
      elseif #active > 0 then
        os.sleep(0.05)                     -- все ждут ответа сервера
      end
    end
  end
  return okCount
end

--- Скачать один адрес целиком. Возвращает тело или nil, ошибка, код.
function fetch.get(url, opts)
  opts = opts or {}
  local parts, err, code = {}, nil, nil
  fetch.many({ {
    url = url, size = opts.size, headers = opts.headers, plain = opts.plain,
    write = function(s) parts[#parts + 1] = s end,
    finish = function(e, c) err, code = e, c end,
  } }, opts)
  if err then return nil, err, code end
  return table.concat(parts), nil, code
end

------------------------------------------------------------------ пакет

--- Разложить поток пакета по файлам. Пакет - все файлы подряд, в том
--- порядке и тех размеров, что в списке. Возвращает write для fetch и
--- функцию-итог. h.open(entry) -> файл (с write/close) или nil (пропустить);
--- h.close(entry, crc, written) - файл кончился (written - его писали, а не
--- пропускали). Итог возвращает true, если пакет пришёл до последнего байта.
function fetch.unpack(list, h)
  local i, e, f, left, crc = 0, nil, nil, 0, 0

  local function close()
    if f then f:close() end
    if h.close then h.close(e, fetch.hex(crc), f ~= nil) end
    e, f = nil, nil
  end

  -- следующий непустой файл; пустые закрываются сразу
  local function open()
    while true do
      i = i + 1
      e = list[i]
      if not e then return false end
      left, crc = e.size or 0, 0
      f = h.open(e)
      if left > 0 then return true end
      close()
    end
  end

  local function write(s)
    local pos = 1
    while pos <= #s do
      if not e and not open() then return end   -- лишнее после списка
      local piece = s:sub(pos, pos + left - 1)
      pos, left = pos + #piece, left - #piece
      if f then
        f:write(piece)
        crc = fetch.crc32(crc, piece)
      end
      if left == 0 then close() end
    end
  end

  local function finish()
    if e then                                    -- оборвался посреди файла
      if f then f:close() end
      return false
    end
    if open() then                               -- непустые остались без данных
      if f then f:close() end
      return false
    end
    return true
  end

  return write, finish
end

------------------------------------------------------------------ файлы по манифесту

-- Прикидка в тиках: запрос, первый read (он только будит подкачку) и по два
-- на каждые 2 КБ. Код на Lua gzip ужимает примерно втрое.
local function ticks(bytes) return 2 + 2 * math.ceil(bytes / 2048) end

-- Файл до стольких байт собирается в памяти и ложится на диск одним
-- open, когда хэш уже сошёлся: fs.remove и fs.rename - не прямые вызовы, по
-- тику каждый, а у .part их два на файл. Больше - через .part.
fetch.memory = 65536

--- Поставить файлы из репозитория, сверяя размер и CRC32 из манифеста.
---   o.base      адрес каталога сборки, с "/" на конце
---   o.url(e, p) или так: адрес файла p записи e (p - e[1] или e.gz)
---   o.need      записи манифеста, которые надо скачать ({ имя, size, crc });
---               e.gz - путь сжатого gzip двойника (e.gzsize - его размер):
---               тогда качается он и распаковывается на лету
---   o.all       все файлы манифеста по порядку (для пакета)
---   o.pack      запись пакета из манифеста ({ имя, size, crc }) или nil
---   o.path(e)   куда класть файл
---   o.done(e, n, err, code)  файл готов (n) или не вышел (err)
---   o.progress(e, n)  большой файл: пришло n байт (раз в 64 КБ)
--- На диск попадает только сошедшееся: небольшой файл ждёт проверки в
--- памяти, большой - в .part рядом. Что не пришло пакетом, качается
--- поштучно. Возвращает число поставленных и список несошедшихся.
function fetch.files(o)
  local fs = require("filesystem")
  local wanted, left = {}, 0
  -- записи различаются самой таблицей, а не именем: у двух источников
  -- может быть по своему install.lua
  for _, e in ipairs(o.need) do wanted[e] = true left = left + 1 end
  local placed, failed = 0, {}
  local function url(e, p) return o.url and o.url(e, p) or (o.base .. p) end

  local function mkdir(path)
    local dir = path:match("^(.*)/[^/]*$")
    if dir and dir ~= "" and not fs.exists(dir) then fs.makeDirectory(dir) end
  end

  --- Приёмник одного файла: write(s), finish() -> ошибка или nil, drop().
  local function sink(e)
    local to = o.path(e)
    mkdir(to)
    local n, crc = 0, 0
    local size = e.size or 0
    local parts, tmp, f, werr
    if size <= fetch.memory and computer.freeMemory() > size * 4 + 32768 then
      parts = {}
    else
      tmp = fs.exists(to) and (to .. ".part") or to
    end
    local sk = {}
    function sk.write(s)
      if o.progress and math.floor((n + #s) / 65536) > math.floor(n / 65536) then o.progress(e, n + #s) end
      n, crc = n + #s, fetch.crc32(crc, s)
      if parts then
        parts[#parts + 1] = s
      else
        if not f and not werr then f, werr = io.open(tmp, "wb") end
        if f then f:write(s) end
      end
    end
    function sk.drop()
      if f then f:close() f = nil end
      if tmp then fs.remove(tmp) end
      parts = nil
    end
    function sk.finish()
      local h = fetch.hex(crc)
      local err
      if werr then
        err = tostring(werr)
      elseif (e.size and n ~= e.size) or (e.crc and h ~= e.crc) then
        err = ("пришло %d Б с хэшем %s, а ждали %s Б с хэшем %s")
          :format(n, h, tostring(e.size), tostring(e.crc))
      elseif parts then
        local out, why = io.open(to, "wb")
        if not out then
          err = tostring(why)
        else
          for i = 1, #parts do out:write(parts[i]) end
          out:close()
        end
      else
        if not f then f, werr = io.open(tmp, "wb") end   -- пустой файл
        if f then f:close() f = nil end
        if tmp ~= to then
          fs.remove(to)
          local ok, rerr = fs.rename(tmp, to)
          if not ok then err = "не переименовать .part: " .. tostring(rerr) end
        end
      end
      if err then
        sk.drop()
        return err
      end
      parts = nil
      wanted[e] = nil
      placed = placed + 1
      if o.done then o.done(e, n) end
    end
    return sk
  end

  -- пакетом, если так выходит дешевле, чем по файлу
  if o.pack and o.all and left > 0 then
    local single = 0
    for _, e in ipairs(o.need) do single = single + ticks((e.size or 0) / 3) end
    if ticks(o.pack.size or math.huge) < single then
      local cur
      local write, finish = fetch.unpack(o.all, {
        open = function(e)
          if not wanted[e] then return nil end
          cur = sink(e)
          local sk = cur
          return { write = function(_, s) sk.write(s) end, close = function() end }
        end,
        close = function(e, _, written)
          if written and cur then cur.finish() end
          cur = nil
        end,
      })
      local z = inflate.new(write, "gzip")
      local err
      fetch.many({ {
        url = url(o.pack, o.pack[1]), size = o.pack.size, plain = true,
        write = function(s) z:feed(s) end,
        finish = function(e) err = e end,
      } })
      if not err and z.done then finish() end
      -- недописанное пакетом не оставляем: докачается ниже по файлу
      if cur then cur.drop() cur = nil end
    end
  end

  -- поштучно: всё, что осталось, по четыре запроса разом, с одним повтором
  for _ = 1, 2 do
    local jobs = {}
    for _, e in ipairs(o.need) do
      if wanted[e] then
        local sk = sink(e)
        local job = {
          url = url(e, e[1]), size = e.size,
          write = sk.write,
          finish = function(err, code)
            if err then sk.drop() else err = sk.finish() end
            failed[e] = err and { err = err, code = code } or nil
          end,
        }
        if e.gz then
          -- сжатый двойник: GitHub двоичное сам не сжимает, а ролик
          -- втрое-вполовину легче - столько же меньше тиков
          local z = inflate.new(sk.write, "gzip")
          job.url, job.size, job.plain = url(e, e.gz), e.gzsize, true
          job.write = function(s) z:feed(s) end
          local fin = job.finish
          job.finish = function(err, code)
            if not err and not z.done then err = "сжатый поток оборвался" end
            fin(err, code)
          end
        end
        jobs[#jobs + 1] = job
      end
    end
    if #jobs == 0 then break end
    fetch.many(jobs)
    -- 404 повтор не лечит
    local again = false
    for e, f in pairs(failed) do if f.code ~= 404 and wanted[e] then again = true end end
    if not again then break end
  end

  local bad = {}
  for _, e in ipairs(o.need) do
    if wanted[e] then
      local f = failed[e] or { err = "не скачался" }
      bad[#bad + 1] = { entry = e, err = f.err, code = f.code }
      if o.done then o.done(e, nil, f.err, f.code) end
    end
  end
  return placed, bad
end

return fetch
