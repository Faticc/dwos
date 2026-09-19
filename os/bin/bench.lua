-- bench: замер машины. Девять проб, у каждой своя картинка на панели
-- справа. Первые четыре меряют процессор - по os.clock, то есть по
-- времени процессора самой машины, отрисовка в замер не входит. Остальные
-- упираются в бюджет тика (экран, кадры gfx, 3D, диск, сигналы) и меряются
-- по computer.uptime.
--
-- Очки: 1000 - эталонная машина (сервер и видеокарта 3 уровня на стенде
-- test/ocvm.lua), итог - среднее геометрическое проб. Прошлый и лучший
-- итоги лежат в /home/.bench. Выход - q или Ctrl+C, r - ещё раз.

local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local gfx = require("gfx")
local keys = require("keyboard").keys
local serialization = require("serialization")
local term = require("term")
local tty = require("tty")
local unicode = require("unicode")

if not term.isAvailable() then
  io.stderr:write("bench: нужен экран\n")
  return 1
end
local gpu = tty.gpu()
local W, H = gpu.getResolution()
if W < 80 or H < 25 then
  io.stderr:write("bench: нужен экран не меньше 80x25\n")
  return 1
end

local floor, min, max, random, sin, pi = math.floor, math.min, math.max, math.random, math.sin, math.pi
local clock, uptime = os.clock, computer.uptime
local wlen, usub = unicode.wlen, unicode.sub
local mix = gfx.mix

local BG, PANEL, LINE = 0x0B0E14, 0x151A24, 0x262D3D
local FG, DIM, HEAD = 0xD8DEE9, 0x6B7489, 0xFFCC66

local CPU_SECS, REAL_SECS = 2, 3
local SAVE = "/home/.bench"

-- q или Ctrl+C, пойманные где угодно (проба сигналов сама разбирает очередь)
local quit = false
local function wantQuit(e, code)
  if e == "interrupted" or (e == "key_down" and code == keys.q) then quit = true end
end

-- слева список проб, справа панель с картинкой текущей
local L = W >= 120 and 44 or 34
local VX, VR = L + 3, 6
local VW, VH = W - VX - 1, H - 7

------------------------------------------------------------------ холсты

-- Текст живёт на текстовом холсте во весь экран, картинка - на пиксельном
-- поверх панели. Цвета видеокарты общие на оба буфера, поэтому перед
-- рисованием на другом холсте его память о цветах сбрасывается.
local T = gfx.surface(gpu)
local P = gfx.new(gpu, VW, VH, { rgb = true, x = VX, y = VR, background = PANEL })
local PW, PH = P.pw, P.ph
local fb = P.fb

local function cut(s, n)
  if wlen(s) > n then return usub(s, 1, n) end
  return s
end

local function pad(s, n, right)
  s = cut(s, n)
  local sp = (" "):rep(n - wlen(s))
  return right and sp .. s or s .. sp
end

-- надпись в своём месте экрана: перерисовывается, только если изменилась
local slots = {}
local function put(x, y, w, s, fg, bg, right)
  if w <= 0 then return end
  s = pad(s, w, right)
  local key, v = x * 256 + y, s .. fg .. "/" .. bg
  if slots[key] ~= v then
    slots[key] = v
    T:set(x, y, s, fg, bg)
  end
end

--- Забыть, что показано на панели: следующий flush перерисует её всю.
local function invalidate()
  for i = 1, #P.shown do P.shown[i] = -1 end
  P:touch(1, 1, PW, PH)
  P.fg, P.bg = nil, nil
end

local function human(v)
  if v >= 1e6 then return ("%.2fM"):format(v / 1e6) end
  if v >= 1e4 then return ("%.1fK"):format(v / 1e3) end
  if v >= 100 then return tostring(floor(v + 0.5)) end
  return ("%.1f"):format(v)
end

--- Плавный переход через несколько цветов, n оттенков.
local function ramp(stops, n, cyclic)
  local out, segs = {}, #stops - 1
  for i = 0, n - 1 do
    local t = cyclic and i / n or i / max(1, n - 1)
    local k = min(segs - 1, floor(t * segs))
    out[i + 1] = mix(stops[k + 1], stops[k + 2], t * segs - k)
  end
  return out
end

------------------------------------------------------------------ пробы

-- kind "cpu": step(deadline) работает до os.clock() >= deadline и
-- возвращает, сколько сделано; draw рисует уже вне замера.
-- kind "real": step() делает порцию работы вместе с отрисовкой.

local life = { name = "Целые", unit = "кл/с", color = 0x7BD88F, ref = 2.4e6,
  title = "«Жизнь» Конвея", about = "клеток поля за секунду процессора" }
do
  local cur, nxt, age, xl, xr, up, dn, fade
  function life.init()
    cur, nxt, age, xl, xr, up, dn = {}, {}, {}, {}, {}, {}, {}
    for x = 1, PW do
      xl[x] = x == 1 and PW or x - 1
      xr[x] = x == PW and 1 or x + 1
    end
    for y = 1, PH do
      up[y] = ((y == 1 and PH or y - 1) - 1) * PW
      dn[y] = ((y == PH and 1 or y + 1) - 1) * PW
    end
    for i = 1, PW * PH do
      cur[i] = random() < 0.3 and 1 or 0
      nxt[i], age[i] = 0, 5
    end
    -- следы умерших клеток гаснут за пять кадров
    fade = { [0] = 0xE8FFE0 }
    for a = 1, 5 do fade[a] = mix(life.color, PANEL, (a - 1) / 4) end
    life.gen, life.seeded = 0, 0
  end

  function life.step(deadline)
    local n, cells = 0, PW * PH
    repeat
      local c, nx = cur, nxt
      for y = 1, PH do
        local o, ou, od = (y - 1) * PW, up[y], dn[y]
        for x = 1, PW do
          local l, r = xl[x], xr[x]
          local s = c[ou + l] + c[ou + x] + c[ou + r] + c[o + l] + c[o + r]
            + c[od + l] + c[od + x] + c[od + r]
          if s == 3 or (s == 2 and c[o + x] == 1) then nx[o + x] = 1 else nx[o + x] = 0 end
        end
      end
      cur, nxt = nx, c
      n = n + cells
      life.gen = life.gen + 1
    until clock() >= deadline
    return n
  end

  function life.draw()
    -- поле на торе со временем затихает: подсыпаем жизни
    if life.gen - life.seeded >= 40 then
      life.seeded = life.gen
      local sx, sy = random(1, PW - 12), random(1, PH - 12)
      for y = sy, sy + 11 do
        for x = sx, sx + 11 do cur[(y - 1) * PW + x] = random() < 0.45 and 1 or 0 end
      end
    end
    for i = 1, PW * PH do
      if cur[i] == 1 then
        fb[i] = age[i] > 0 and fade[0] or fade[1]
        age[i] = 0
      else
        local a = age[i]
        if a < 5 then a = a + 1 age[i] = a end
        fb[i] = fade[a]
      end
    end
    P:touch(1, 1, PW, PH)
  end
end

local mand = { name = "Дробные", unit = "ит/с", color = 0xFC9867, ref = 5.4e6,
  title = "Множество Мандельброта", about = "итераций z² + c за секунду процессора" }
do
  -- центр, ширина кадра, предел итераций
  local VIEWS = {
    { -0.65, 0, 3.1, 48 },
    { -0.7453, 0.1127, 0.014, 160 },
    { -0.235125, 0.827215, 0.006, 200 },
    { -1.2539, 0.3845, 0.04, 150 },
    { -0.1592, 1.0317, 0.035, 120 },
  }
  local PAL = ramp({ 0x07104A, 0x206BCB, 0xEDFFFF, 0xFFAA00, 0x7A1E00, 0x07104A }, 48, true)
  local cx, cy, sc, it

  local function nextView()
    mand.view = mand.view % #VIEWS + 1
    local v = VIEWS[mand.view]
    sc = v[3] / PW
    cx, cy, it = v[1] - sc * PW / 2, v[2] - sc * PH / 2, v[4]
    mand.row = 1
  end

  function mand.init() mand.view, mand.row = 0, PH + 1 end

  function mand.step(deadline)
    local n, np = 0, #PAL
    repeat
      if mand.row > PH then nextView() end
      local y = mand.row
      local ci, o = cy + (y - 1) * sc, (y - 1) * PW
      for x = 1, PW do
        local cr = cx + (x - 1) * sc
        local zr, zi, zr2, zi2, k = 0, 0, 0, 0, 0
        while k < it and zr2 + zi2 < 4 do
          zi = 2 * zr * zi + ci
          zr = zr2 - zi2 + cr
          zr2, zi2 = zr * zr, zi * zi
          k = k + 1
        end
        n = n + k
        fb[o + x] = k >= it and 0 or PAL[k % np + 1]
      end
      mand.row = y + 1
    until clock() >= deadline
    return n
  end

  function mand.draw() P:touch(1, 1, PW, PH) end
end

local str = { name = "Строки", unit = "оп/с", color = 0x78DCE8, ref = 1.8e5,
  title = "Строки и юникод", about = "format, gsub, find, upper, concat за секунду процессора" }
do
  local WORDS = { "альфа", "beta", "гамма", "delta", "эпсилон", "zeta", "омега", "lua", "dwos", "тик" }
  local lines, seq, i
  function str.init() lines, seq, i = {}, 0, 0 end

  function str.step(deadline)
    local n, parts = 0, {}
    repeat
      for _ = 1, 32 do
        i = i + 1
        local w = WORDS[i % #WORDS + 1]
        local s = ("%06d  %s  %04X"):format(i, w, i * 7919 % 65536):gsub("0", "·")
        local u = unicode.upper(w)
        local h = 0
        for k = 1, #u, 2 do h = (h * 31 + u:byte(k)) % 65521 end
        parts[1], parts[2], parts[3] = s, u, ("#%05d"):format(h)
        s = table.concat(parts, "  ")
        if s:find(u, 1, true) then n = n + 1 end
        if i % 24 == 0 then
          seq = seq + 1
          lines[(seq - 1) % VH + 1] = s
        end
      end
    until clock() >= deadline
    return n
  end

  function str.draw() P:clear(PANEL) end

  -- надписи ложатся поверх готового кадра: flush после них стёр бы их
  function str.overlay()
    for r = 1, VH do
      local k = seq - VH + r
      if k >= 1 then
        local c = r == VH and 0xFFFFFF or mix(PANEL, str.color, (r / VH) ^ 1.5)
        P:text(2, r, cut(lines[(k - 1) % VH + 1], VW - 2), c, PANEL)
      end
    end
  end
end

local tab = { name = "Таблицы", unit = "табл/с", color = 0xAB9DF2, ref = 8.0e5,
  title = "Сортировка и сборка мусора", about = "созданных таблиц за секунду; внизу - занятая память" }
do
  local function byId(a, b) return a.id < b.id end
  local mem, seed
  function tab.init() mem, seed = {}, 1 end

  function tab.step(deadline)
    local n = 0
    repeat
      for _ = 1, 8 do
        local arr, idx = {}, {}
        for j = 1, 32 do
          seed = seed * 16807 % 2147483647
          arr[j] = { id = seed % 1000, n = j }
        end
        table.sort(arr, byId)
        for j = 1, 32 do idx[arr[j].n] = arr[j].id end
        table.insert(arr, 1, table.remove(arr))
        n = n + 34
      end
    until clock() >= deadline
    return n
  end

  function tab.draw()
    local total = computer.totalMemory()
    mem[#mem + 1] = (total - computer.freeMemory()) / total
    local cols = floor(PW / 2)
    while #mem > cols do table.remove(mem, 1) end
    P:rect(1, 1, PW, PH, PANEL)
    for y = PH, 1, -8 do P:rect(1, y, PW, 1, LINE) end
    local body = mix(tab.color, PANEL, 0.6)
    for i = 1, #mem do
      local x = PW - (#mem - i + 1) * 2 + 1
      local hg = max(1, floor(mem[i] * PH + 0.5))
      P:rect(x, PH - hg + 1, 2, hg, body)
      P:rect(x, PH - hg + 1, 2, 1, tab.color)
    end
  end
end

local scr = { name = "Экран", unit = "выз/с", color = 0xFF6188, ref = 3800, kind = "real",
  title = "Прямой вывод на экран", about = "вызовов gpu за секунду: упирается в бюджет тика" }
do
  local CONF = { 0xFF6188, 0xFC9867, 0xFFD866, 0xA9DC76, 0x78DCE8, 0xAB9DF2 }
  function scr.init() if gpu.setActiveBuffer then gpu.setActiveBuffer(0) end end

  function scr.step()
    for _ = 1, 16 do
      local w, h = random(2, 12), random(1, 4)
      local x, y = VX + random(0, VW - w), VR + random(0, VH - h)
      gpu.setBackground(CONF[random(#CONF)])
      gpu.fill(x, y, w, h, " ")
    end
    return 32
  end

  -- рисовали мимо холстов: пусть оба забудут, что на экране
  function scr.finish()
    T.fg, T.bg = nil, nil
    invalidate()
  end
end

local fps = { name = "Кадры", unit = "к/с", color = 0xFFD866, ref = 20, kind = "real",
  title = "Плазма через gfx", about = "полных кадров в секунду: расчёт, буфер, вывод" }
do
  local PL, SX, SY, SD, NX, NY, ND, t
  local function wave(n, amp)
    local w = {}
    for i = 0, n - 1 do w[i] = floor((sin(i / n * 2 * pi) + 1) * amp) end
    return w
  end
  function fps.init()
    PL = ramp({ 0x1B0B3B, 0xAB2F6F, 0xFFD866, 0x2BB3C0, 0x1B0B3B }, 64, true)
    NX, NY, ND = floor(PW * 0.9), floor(PH * 1.3), floor((PW + PH) * 0.6)
    SX, SY, SD = wave(NX, 10.5), wave(NY, 10.5), wave(ND, 10.5)
    t = 0
  end

  function fps.step()
    t = t + 1
    local a, b, c = t * 3, t * 2, t * 5
    for y = 1, PH do
      local o, sy, yc = (y - 1) * PW, SY[(y + b) % NY], y + c
      for x = 1, PW do
        fb[o + x] = PL[(SX[(x + a) % NX] + sy + SD[(x + yc) % ND]) % 64 + 1]
      end
    end
    P:touch(1, 1, PW, PH)
    P.fg, P.bg = nil, nil
    P:flush()
    return 1
  end
end

local fig = { name = "Фигура", unit = "к/с", color = 0xE879F9, ref = 20, kind = "real",
  title = "Тор в 3D", about = "поворот, свет, отсечение и заливка граней за кадр" }
do
  -- тор: U отрезков по кругу, V - по сечению трубки
  local U, V, R, r = 22, 11, 1, 0.42
  local vx, vy, vz, nx, ny, nz = {}, {}, {}, {}, {}, {}
  local px, py, pz, faces, order = {}, {}, {}, {}, {}
  local SH, f, cx, cy, ax, ay
  local LX, LY, LZ = -0.45, 0.6, -0.66 -- свет сверху слева, со стороны зрителя
  local D = 4                           -- камера в (0, 0, -D), смотрит вдоль +z

  local function id(i, j) return (i % U) * V + (j % V) + 1 end

  function fig.init()
    for i = 0, U - 1 do
      local a = i / U * 2 * pi
      local ca, sa = math.cos(a), sin(a)
      for j = 0, V - 1 do
        local b = j / V * 2 * pi
        local cb, sb = math.cos(b), sin(b)
        local k = id(i, j)
        vx[k], vy[k], vz[k] = (R + r * cb) * ca, r * sb, (R + r * cb) * sa
        nx[k], ny[k], nz[k] = cb * ca, sb, cb * sa
      end
    end
    for i = 0, U - 1 do
      for j = 0, V - 1 do
        faces[#faces + 1] = { id(i, j), id(i + 1, j), id(i + 1, j + 1), id(i, j + 1) }
      end
    end
    SH = ramp({ mix(fig.color, PANEL, 0.88), mix(fig.color, PANEL, 0.35), fig.color, 0xFFF4FF }, 40)
    f = min(PW, PH * 1.2) * 1.05
    cx, cy = PW / 2 + 0.5, PH / 2 + 0.5
    ax, ay = 0.5, 0
  end

  -- треугольник сплошным цветом, строками сверху вниз
  local function tri(x1, y1, x2, y2, x3, y3, c)
    if y1 > y2 then x1, y1, x2, y2 = x2, y2, x1, y1 end
    if y2 > y3 then x2, y2, x3, y3 = x3, y3, x2, y2 end
    if y1 > y2 then x1, y1, x2, y2 = x2, y2, x1, y1 end
    if y3 - y1 < 0.001 then return end
    local ys, ye = max(1, math.ceil(y1 - 0.5)), min(PH, floor(y3 + 0.5))
    for y = ys, ye do
      local t = min(max(y, y1), y3)
      local xa = x1 + (x3 - x1) * (t - y1) / (y3 - y1)
      local xb
      if t < y2 then xb = x1 + (x2 - x1) * (t - y1) / (y2 - y1)
      elseif y3 > y2 then xb = x2 + (x3 - x2) * (t - y2) / (y3 - y2)
      else xb = x2 end
      if xa > xb then xa, xb = xb, xa end
      local o = (y - 1) * PW
      for x = max(1, floor(xa + 0.5)), min(PW, floor(xb + 0.5)) do fb[o + x] = c end
    end
  end

  function fig.step()
    ax, ay = ax + 0.045, ay + 0.07
    local sx, cxa, sy, cya = sin(ax), math.cos(ax), sin(ay), math.cos(ay)
    -- поворот вокруг y, затем вокруг x; нормали - так же
    local rnx, rny, rnz = {}, {}, {}
    for k = 1, U * V do
      local x, z = vx[k] * cya + vz[k] * sy, -vx[k] * sy + vz[k] * cya
      local y = vy[k]
      y, z = y * cxa - z * sx, y * sx + z * cxa
      local w = f / (z + D)
      px[k], py[k], pz[k] = cx + x * w, cy - y * w, z
      local a, c = nx[k] * cya + nz[k] * sy, -nx[k] * sy + nz[k] * cya
      local b = ny[k]
      rnx[k], rny[k], rnz[k] = a, b * cxa - c * sx, b * sx + c * cxa
    end
    for i = 1, PW * PH do fb[i] = PANEL end
    -- видимые грани, дальние первыми
    local n = 0
    for fi = 1, #faces do
      local q = faces[fi]
      local a, b, c, d = q[1], q[2], q[3], q[4]
      -- ориентация на экране: грань к нам лицом, если обход по часовой
      local cross = (px[b] - px[a]) * (py[d] - py[a]) - (py[b] - py[a]) * (px[d] - px[a])
      if cross < 0 then
        n = n + 1
        order[n] = fi
        q.z = pz[a] + pz[b] + pz[c] + pz[d]
      end
    end
    for i = n + 1, #order do order[i] = nil end
    table.sort(order, function(i, j) return faces[i].z > faces[j].z end)
    for i = 1, n do
      local q = faces[order[i]]
      local a, b, c, d = q[1], q[2], q[3], q[4]
      local lx = rnx[a] + rnx[b] + rnx[c] + rnx[d]
      local ly = rny[a] + rny[b] + rny[c] + rny[d]
      local lz = rnz[a] + rnz[b] + rnz[c] + rnz[d]
      local l = (lx * LX + ly * LY + lz * LZ) / math.sqrt(lx * lx + ly * ly + lz * lz)
      local col = SH[max(1, min(#SH, floor((0.12 + 0.88 * max(0, l)) ^ 1.4 * #SH + 0.5)))]
      tri(px[a], py[a], px[b], py[b], px[c], py[c], col)
      tri(px[a], py[a], px[c], py[c], px[d], py[d], col)
    end
    P:touch(1, 1, PW, PH)
    P.fg, P.bg = nil, nil
    P:flush()
    return 1
  end
end

local disk = { name = "Диск", unit = "КБ/с", color = 0x5AB0F6, ref = 1000, kind = "real",
  title = "Файл туда и обратно", about = "запись и чтение кусками по 2 КБ" }
do
  local CHUNK = ("DwOS"):rep(512)
  local path, n, h, phase, done, cols, cw, chh, gx, gy
  local wb, wt, rb, rt, t0

  local function block(i, c)
    local col, row = (i - 1) % cols, floor((i - 1) / cols)
    P:rect(gx + col * cw, gy + row * chh, cw - 1, chh - 1, c)
  end

  function disk.init()
    path, h = nil, nil
    for _, dir in ipairs({ "/home", "/tmp" }) do
      local px = fs.get(dir)
      if px and not px.isReadOnly() then
        local free = px.spaceTotal() - px.spaceUsed()
        if free >= 24 * 1024 then
          path, n = dir .. "/.bench.tmp", min(64, floor(free / 2048 / 2))
          break
        end
      end
    end
    wb, wt, rb, rt = 0, 0, 0, 0
    phase, done = "w", 0
    if not path then disk.about = "нет диска, куда можно писать" return end
    -- сетка блоков, как у дефрагментатора
    cols = 16
    cw = max(2, floor((PW - 2) / cols))
    chh = max(2, min(cw, floor((PH - 2) / math.ceil(n / cols))))
    gx = floor((PW - cols * cw) / 2) + 1
    gy = floor((PH - math.ceil(n / cols) * chh) / 2) + 1
    for i = 1, n do block(i, LINE) end
    t0 = uptime()
  end

  function disk.step()
    if not path then return 0 end
    local moved = 0
    for _ = 1, 4 do
      if phase == "w" then
        if not h then
          for i = 1, n do block(i, LINE) end
          h = fs.open(path, "wb")
          if not h then path = nil return 0 end
        end
        h:write(CHUNK)
        done = done + 1
        moved = moved + #CHUNK
        wb = wb + #CHUNK
        block(done, mix(disk.color, PANEL, 0.55))
        if done >= n then
          h:close()
          h, phase, done = nil, "r", 0
          local now = uptime()
          wt, t0 = wt + now - t0, now
        end
      else
        if not h then h = fs.open(path, "rb") end
        local s = h and h:read(2048)
        if s then
          done = done + 1
          moved = moved + #s
          rb = rb + #s
          block(done, disk.color)
        end
        if not s or done >= n then
          if h then h:close() end
          h, phase, done = nil, "w", 0
          local now = uptime()
          rt, t0 = rt + now - t0, now
        end
      end
    end
    local parts = {}
    if wt > 0 then parts[#parts + 1] = ("запись %s КБ/с"):format(human(wb / 1024 / wt)) end
    if rt > 0 then parts[#parts + 1] = ("чтение %s КБ/с"):format(human(rb / 1024 / rt)) end
    parts[#parts + 1] = path
    disk.about = table.concat(parts, " · ")
    P.fg, P.bg = nil, nil
    P:flush()
    return moved / 1024
  end

  function disk.finish()
    if h then pcall(h.close, h) h = nil end
    if path then fs.remove(path) end
  end
end

local sig = { name = "Сигналы", unit = "сиг/с", color = 0xA9DC76, ref = 20, kind = "real",
  title = "Очередь сигналов", about = "pushSignal и pullSignal за секунду" }
do
  local N, K = 32, 16
  local dots, heat, k, cx, cy, rad
  local shade = {}
  function sig.init()
    cx, cy = floor(PW / 2), floor(PH / 2)
    rad = floor(min(PW, PH) / 2) - 4
    dots, heat, k = {}, {}, 0
    for i = 1, N do
      local a = (i - 1) / N * 2 * pi
      dots[i] = { floor(cx + rad * math.cos(a) + 0.5), floor(cy + rad * sin(a) + 0.5) }
      heat[i] = 0
    end
    for j = 0, 6 do shade[j] = mix(LINE, sig.color, j / 6) end
    shade[7] = 0xF0FFE0
  end

  function sig.step()
    for i = 1, K do computer.pushSignal("bench_ping", i) end
    local got, miss = 0, 0
    -- event.pull(0) не уступает машину вовсе: при нулевом ожидании он
    -- выходит, не спросив очередь. pullSignal(0) спрашивает.
    while got < K and miss < 4 do
      local e, _, _, code = computer.pullSignal(0)
      if e == "bench_ping" then
        got = got + 1
        k = k % N + 1
        heat[k] = 7
      elseif e then
        wantQuit(e, code)
      else
        miss = miss + 1
      end
    end
    for i = 1, N do
      local d = dots[i]
      P:rect(d[1] - 1, d[2] - 1, 3, 3, shade[heat[i]])
      if heat[i] > 0 then heat[i] = heat[i] - 1 end
    end
    P.fg, P.bg = nil, nil
    P:flush()
    return got
  end
end

local TESTS = { life, mand, str, tab, scr, fps, fig, disk, sig }

------------------------------------------------------------------ экран

local function row(i) return 3 + (i - 1) * 2 end
local SUM = row(#TESTS) + 2
local SPIN = { "◐", "◓", "◑", "◒" }
local BAR = L - 20

local info = ("%s · ОЗУ %dK · %d×%d"):format(
  computer.getArchitecture and computer.getArchitecture() or _VERSION,
  floor(computer.totalMemory() / 1024), W, H)

local saved = {}
do
  local f = io.open(SAVE)
  if f then
    saved = serialization.unserialize(f:read("*a") or "") or {}
    f:close()
  end
end

local started, current, spin = 0, 0, 0
local bars = {}

local function layout()
  slots, bars = {}, {}
  T:fill(1, 1, W, H, " ", FG, BG)
  T:fill(1, 1, W, 1, " ", FG, LINE)
  T:fill(L + 1, 3, W - L, H - 3, " ", FG, PANEL)
  T:set(2, 1, "DwOS · бенчмарк", HEAD, LINE)
  T:set(W - wlen(info) - 1, 1, info, DIM, LINE)
end

local function drawList()
  for i, t in ipairs(TESTS) do
    local y = row(i)
    local on = i == current and not t.score
    local icon, ic = "○", DIM
    if t.score then icon, ic = "●", t.color elseif on then icon, ic = SPIN[spin % 4 + 1], t.color end
    put(2, y, 1, icon, ic, BG)
    put(4, y, L - 14, t.name, (t.score or on) and FG or DIM, BG)
    put(L - 9, y, 8, t.score and tostring(t.score) or "", t.color, BG, true)
    -- полоска: пока проба идёт - сколько прошло, потом - очки (2000 во всю длину)
    local frac = t.score and min(1, t.score / 2000) or on and (t.progress or 0) or 0
    local full = floor(min(1, frac) * BAR + 0.5)
    if bars[i] ~= full then
      bars[i] = full
      if full > 0 then T:set(4, y + 1, ("━"):rep(full), t.score and t.color or mix(t.color, BG, 0.4), BG) end
      if full < BAR then T:set(4 + full, y + 1, ("─"):rep(BAR - full), LINE, BG) end
    end
    put(L - 15, y + 1, 14, t.value and (human(t.value) .. " " .. t.unit) or "", DIM, BG, true)
  end
end

local function drawFrame(total)
  T.fg, T.bg = nil, nil
  drawList()
  local t = TESTS[current]
  if t then
    put(VX, 3, VW, t.name .. " · " .. t.title, t.color, PANEL)
    put(VX, 4, VW, t.about, DIM, PANEL)
  end
  put(2, SUM, L - 3, "Итог", HEAD, BG)
  put(2, SUM + 1, L - 3, total and ("%d очков"):format(total) or "идёт замер…", total and HEAD or DIM, BG)
  local prev = ""
  if saved.last then
    prev = ("прошлый %d · лучший %d"):format(saved.last, saved.best or saved.last)
  end
  put(2, SUM + 2, L - 3, prev, DIM, BG)
  if total then
    put(2, H, W - 2, "r — ещё раз · q — выход", DIM, BG)
  else
    put(2, H, W - 2, ("q — выход · проба %d из %d · %.1f с"):format(current, #TESTS, uptime() - started), DIM, BG)
  end
  T:present("replay")
  P.fg, P.bg = nil, nil
end

------------------------------------------------------------------ прогон

local function aborted()
  local e, _, _, code = computer.pullSignal(0)
  wantQuit(e, code)
  return quit
end

local function runTest(i)
  local t = TESTS[i]
  current, t.progress, t.value, t.score = i, 0, nil, nil
  P:clear(PANEL)
  t.init()
  if t.kind == "real" then
    drawFrame()
    local t0, units, ui = uptime(), 0, 0
    repeat
      units = units + t.step()
      local el = uptime() - t0
      t.value, t.progress = units / max(el, 0.05), el / REAL_SECS
      -- список и часы - раз в четверть секунды: это тоже вызовы к экрану
      if el - ui >= 0.25 then
        ui, spin = el, spin + 1
        drawFrame()
      end
    until el >= REAL_SECS
    if t.finish then t.finish() end
  else
    local cpu, units = 0, 0
    while cpu < CPU_SECS do
      local c0 = clock()
      units = units + t.step(c0 + 0.05)
      cpu = cpu + (clock() - c0)
      t.value, t.progress = units / cpu, cpu / CPU_SECS
      t.draw()
      spin = spin + 1
      drawFrame()
      P:flush(t.overlay ~= nil)
      if t.overlay then
        t.overlay()
        P:present()
      end
      if aborted() then return false end
    end
  end
  t.score = t.value and t.value > 0 and floor(1000 * t.value / t.ref + 0.5) or nil
  drawFrame()
  return not aborted()
end

------------------------------------------------------------------ итог

-- цифры 3x5 для большого числа
local FONT = {
  ["0"] = "111101101101111", ["1"] = "010110010010111", ["2"] = "111001111100111",
  ["3"] = "111001111001111", ["4"] = "101101111001001", ["5"] = "111100111001111",
  ["6"] = "111100111101111", ["7"] = "111001010010010", ["8"] = "111101111101111",
  ["9"] = "111101111001111",
}

local function summary(total)
  current = 0
  P:clear(PANEL)
  local digits = tostring(total)
  local s = max(1, min(floor(PW * 0.8 / (#digits * 4)), floor(PH * 0.3 / 5)))
  local x0 = floor((PW - (#digits * 4 - 1) * s) / 2) + 1
  local y0 = 3
  for d = 1, #digits do
    local g = FONT[digits:sub(d, d)]
    for fy = 0, 4 do
      local c = mix(HEAD, 0xFC9867, fy / 4)
      for fx = 0, 2 do
        local k = fy * 3 + fx + 1
        if g:sub(k, k) == "1" then
          P:rect(x0 + ((d - 1) * 4 + fx) * s, y0 + fy * s, s, s, c)
        end
      end
    end
  end
  local textRow = floor((y0 + 5 * s) / 2) + 2
  -- полоски проб: 1000 - отметка эталона, серая черта - прошлый раз
  local top = textRow + 2
  local bx, bw = 12, PW - 19
  local scale = 2000
  for _, t in ipairs(TESTS) do scale = max(scale, t.score or 0) end
  local mark = bx + floor(1000 / scale * bw)
  local last = saved.scores or {}
  P:rect(mark, (top - 1) * 2 + 1, 1, #TESTS * 2 - 1, mix(HEAD, PANEL, 0.4))
  for i, t in ipairs(TESTS) do
    local py = (top + i - 2) * 2 + 1
    P:rect(bx, py, bw, 1, LINE)
    if t.score then P:rect(bx, py, max(1, floor(t.score / scale * bw)), 1, t.color) end
    if last[i] then P:rect(bx + floor(min(last[i], scale) / scale * bw), py, 1, 2, FG) end
  end
  P:flush(true)
  local label = "DwMark · 1000 — эталонная машина"
  P:text(floor((VW - wlen(label)) / 2) + 1, textRow, label, DIM, PANEL)
  for i, t in ipairs(TESTS) do
    P:text(2, top + i - 1, pad(t.name, 9), t.color, PANEL)
    P:text(VW - 6, top + i - 1, pad(t.score and tostring(t.score) or "—", 6, true), FG, PANEL)
  end
  if saved.last and top + #TESTS + 1 <= VH then
    local d = (total - saved.last) / saved.last * 100
    local msg = ("%+.1f%% к прошлому"):format(d)
    if total > (saved.best or 0) then msg = msg .. " · новый рекорд!" end
    P:text(floor((VW - wlen(msg)) / 2) + 1, top + #TESTS + 1, msg, d >= 0 and 0xA9DC76 or 0xFF6188, PANEL)
  end
  P:present()
  put(VX, 3, VW, "Итог", HEAD, PANEL)
  put(VX, 4, VW, ("среднее геометрическое %d проб"):format(#TESTS), DIM, PANEL)
end

local function save(total)
  local scores = {}
  for i, t in ipairs(TESTS) do scores[i] = t.score end
  local rec = { last = total, best = max(total, saved.best or 0), scores = scores, runs = (saved.runs or 0) + 1 }
  pcall(function()
    local f = io.open(SAVE, "w")
    if f then f:write(serialization.serialize(rec)) f:close() end
  end)
  return rec
end

local function run()
  while true do
    quit = false
    for _, t in ipairs(TESTS) do t.score, t.value, t.progress = nil, nil, 0 end
    layout()
    invalidate()
    started, spin = uptime(), 0
    for i = 1, #TESTS do
      if not runTest(i) then return end
    end
    local sum, cnt = 0, 0
    for _, t in ipairs(TESTS) do
      if t.score and t.score > 0 then sum, cnt = sum + math.log(t.score), cnt + 1 end
    end
    local total = cnt > 0 and floor(math.exp(sum / cnt) + 0.5) or 0
    summary(total)
    drawFrame(total)
    saved = save(total)
    while true do
      local e, _, _, code = event.pull()
      if e == "interrupted" then return end
      if e == "key_down" then
        if code == keys.q or code == keys.enter then return end
        if code == keys.r then break end
      end
    end
  end
end

term.setCursorBlink(false)
local ok, err = xpcall(run, debug.traceback)
pcall(disk.finish)
P:close()
T:close()
term.setCursorBlink(true)
term.clear()
if not ok then error(err, 0) end
