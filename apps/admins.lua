-- admins - список мод-состава: кто в какой группе и когда заходил в
-- последний раз. Список ведётся здесь же; серверу от программы нужен
-- только ответ на seen.
--
-- OpenAdmins SkyDrive_, заново нарисованный под DwOS. Экран - пиксельный
-- холст gfx.new (полублок делит ячейку на две точки): таблица на
-- скруглённой панели, цветные метки групп, окна поверх затемнённого
-- экрана, тумблеры в настройках. Надписи ложатся поверх готового кадра,
-- на экран уходит только изменившееся. Сторонних библиотек нет: с
-- сервером программа говорит сама, через командный блок.
--
--   admins [файл настроек]      по умолчанию /etc/admins.cfg
--
-- Без входа в управление это табло: список состава и время последнего
-- захода, которое обновляется само. Ctrl+Alt+C программу не убивает.

local component = require("component")
local computer = require("computer")
local event = require("event")
local gfx = require("gfx")
local process = require("process")
local serial = require("serialization")
local term = require("term")
local tty = require("tty")
local unicode = require("unicode")

local CFG = (...) or "/etc/admins.cfg"

--------------------Настройки--------------------
local UPDATE = 300 --Апдейт отображения информации в сек.
local MAX_NAME_LENGTH = 16 --Максимальная длина ника
local OWNERS = { "Fatic" } --Кто может управлять всегда
local MANAGE_TOP = 6 --Сколько верхних групп из STATUS тоже могут (от Тех.Админа до Ст.Модератора)
local IDLE = 60 --Через сколько сек. без касаний управление закрывается само
-------------------------------------------------

-- Группы хранятся в файле настроек именно этими строками, поэтому они
-- остались как были, с кодами цвета. Экран берёт из них название группы
-- и её цвет.
local STATUS = {
  "&0[&4Тех.Админ&0] - &0", "&0[&4Админ&0] - &0", "&0[&4Куратор&0] - &0",
  "&0[&9Дизайнер&0] - &3", "&0[&9Гл.Модератор&0] - &3", "&0[&3Ст.Модератор&0] - &3",
  "&0[&5Разработчик&0] - &d", "&0[&5Строитель&0] - &d", "&0[&4Модератор&0] - &6",
  "&0[&2Помощник&0] - &2", "&0[&aСтажёр&0] - &2",
}
local SEX = { "&bMale", "&dFemale" }

local config = {
  sostav = {},
  settings = {
    { mode = 3, x = 88, y = 25, label = "Разрешение экрана:" }, --[1] - Разрешение
  },
}
local MIN_W, MIN_H = 88, 25

local BG, BAR, BARLINE = 0x0B1320, 0x14213A, 0x1E3450
local FG, DIM, ACC, WARN = 0xE8EEF5, 0x7D8BA0, 0x5CC8FF, 0xFFB347
local PANEL, ZEBRA, LINE = 0x121D30, 0x16243A, 0x24344F
local SEL, SHADOW, TRACK = 0x25446E, 0x060A12, 0x2A3A55
local OK, ERR = 0x7BD88F, 0xFF6B6B
local BTN, OKBG, ERRBG, WARNBG = 0x2A4166, 0x2F6B45, 0x7A2E3A, 0xC98A2E
local POP, HEAD, FIELD = 0x1A2940, 0x24476E, 0x0B1320
local VEIL, VEIL_T = 0x03060B, 0.62 -- затемнение под окном

-- Цвета кодов &0..&f из строк групп: по смыслу как в чате, но светлее -
-- "&0" в чате чёрный, а на тёмном фоне его было бы не видно.
local CODE = {
  ["0"] = 0xA8B4C0, ["1"] = 0x5577FF, ["2"] = 0x66DD66, ["3"] = 0x33C6BA,
  ["4"] = 0xFF5555, ["5"] = 0xB070FF, ["6"] = 0xFFAA33, ["7"] = 0xBBBBBB,
  ["8"] = 0x9A9A9A, ["9"] = 0x4DA3FF, ["a"] = 0x88FF88, ["b"] = 0x55DDFF,
  ["c"] = 0xFF6666, ["d"] = 0xFF77EE, ["e"] = 0xFFFF66, ["f"] = 0xFFFFFF,
}

-- коды клавиш LWJGL
local KEY_ESC, KEY_BACK, KEY_ENTER = 0x01, 0x0E, 0x1C

local floor, max, min = math.floor, math.max, math.min
local wlen = unicode.wlen

------------------------------------------------------------------ настройки

local function loadConfig()
  local f = io.open(CFG, "r")
  if not f then return end
  local text = f:read("*a")
  f:close()
  local ok = serial.unserialize(text or "")
  if type(ok) == "table" and ok.sostav and ok.settings then config = ok end
  -- В старых конфигах были ещё иммунитет, скорборды, honline и цвет
  -- ника: из настроек осталось только разрешение.
  for _, s in ipairs(config.settings) do
    if s.mode == 3 then
      config.settings = { s }
      break
    end
  end
end

local function saveConfig()
  local f = io.open(CFG, "w")
  if not f then return end
  f:write(serial.serialize(config) .. "\n")
  f:close()
end

------------------------------------------------------------------ сервер

--- Подключён ли командный блок: без него нет ни времени захода, ни
--- команд серверу, поэтому и управление закрыто.
local function linked() return component.isAvailable("opencb") end

local function com(command)
  if not linked() then return "" end
  local _, answer = component.opencb.execute(command)
  return answer or ""
end

--- Строка без цветовых кодов § сервера.
local function plain(s) return (s:gsub("§.", "")) end

--- Когда игрок заходил: {online = true} или {text = "5 ч. 12 мин."}.
--- Ответ разбирается по числам с единицами, по-русски и по-английски, -
--- формулировки у серверов разные. Не нашлось ни времени, ни "в сети" -
--- {err = true, raw = ответ}: его видно прямо в таблице.
local function seen(nick)
  if not linked() then return { none = true } end
  local c = plain(com("seen " .. nick))
  -- ник убрать: цифры в нём не время
  local low = unicode.lower(c):gsub(unicode.lower(nick):gsub("%p", "%%%0"), "")
  local function num(...)
    for _, p in ipairs({ ... }) do
      local n = low:match(p)
      if n then return tonumber(n) end
    end
    return 0
  end
  local year = num("(%d+)%s*лет", "(%d+)%s*год", "(%d+)%s*year")
  local month = num("(%d+)%s*мес", "(%d+)%s*month")
  local day = num("(%d+)%s*дн", "(%d+)%s*день", "(%d+)%s*day")
  local hour = num("(%d+)%s*ч", "(%d+)%s*hour")
  local minute = num("(%d+)%s*мин", "(%d+)%s*minute")
  local second = num("(%d+)%s*сек", "(%d+)%s*second")

  local off = low:find("offline") or low:find("оффлайн") or low:find("офлайн")
    or low:find("не в сети")
  local on = not off and (low:find("online") or low:find("онлайн") or low:find("в сети"))
  if on then return { online = true } end
  if year + month + day + hour + minute + second == 0 then
    return { err = true, raw = c }
  end

  -- крупные единицы вытесняют мелкие
  local s
  if year ~= 0 then
    s = year .. " лет " .. month .. " мес."
  elseif month ~= 0 then
    s = month .. " мес. " .. day .. " дн."
  elseif day ~= 0 then
    s = day .. " дн. " .. hour .. " ч."
  elseif hour + minute ~= 0 then
    s = hour .. " ч. " .. minute .. " мин."
  else
    s = "меньше минуты"
  end
  return { text = s }
end

------------------------------------------------------------------ состав

local function indexOfNick(nick)
  for i = 1, #config.sostav do
    if config.sostav[i][2] == nick then return i end
  end
end

--- Разложить состав по старшинству групп.
local function sort()
  local buffer = {}
  for i = 1, #STATUS do
    for j = 1, #config.sostav do
      if STATUS[i] == config.sostav[j][1] then buffer[#buffer + 1] = config.sostav[j] end
    end
  end
  config.sostav = buffer
end

--- Название группы и её цвет - из строки группы.
local function groupOf(stat)
  local code, name = stat:match("%[&(%w)(.-)&%w%]")
  return name or stat, CODE[code] or FG
end

local function sexOf(s)
  if s and s:find("Female") then return "жен.", CODE.d end
  return "муж.", CODE.b
end

------------------------------------------------------------------ холст

local gpu = tty.gpu()
local C, W, H -- холст, ширина в символах, высота в строках (точек - 2H)
local texts, tn = {}, 0 -- надписи кадра: ложатся после пикселей

local function openScreen()
  local mw, mh = gpu.maxResolution()
  local r = config.settings[1]
  local w, h = min(r.x, mw), min(r.y, mh)
  if C then C:close() end
  term.clear()
  term.setCursorBlink(false)
  local cw, ch = gpu.getResolution()
  if cw ~= w or ch ~= h then gpu.setResolution(w, h) end
  C = gfx.new(gpu, w, h, { rgb = true, keepResolution = true, background = BG })
  W, H = C.w, C.h
end

local function py(row) return row * 2 - 1 end -- верхняя точка строки

local function fit(s, n)
  if n <= 0 then return "" end
  if wlen(s) > n then s = unicode.wtrunc(s, n + 1) end
  return s
end

--- Надпись в строке row. Фон должен совпадать с тем, что под ней
--- нарисовано: обе точки ячейки этой строки - одного цвета.
local function text(x, row, s, fg, bg, room)
  if room then s = fit(s, room) end
  if s == "" then return end
  tn = tn + 1
  texts[tn] = { floor(x), row, s, fg, bg }
end

local function center(x, w, row, s, fg, bg)
  s = fit(s, w)
  text(x + floor((w - wlen(s)) / 2), row, s, fg, bg)
end

local function rect(x, y, w, h, c) C:rect(x, y, w, h, c) end

--- Плашка со срезанными углами - на полублоках это и есть скругление.
--- y и h - в точках.
local function tile(x, y, w, h, c, shadow)
  if shadow then
    rect(x + 2, y + 1, w - 2, h, SHADOW)
    rect(x + 1, y + 2, w, h - 2, SHADOW)
  end
  rect(x + 1, y, w - 2, h, c)
  rect(x, y + 1, w, h - 2, c)
end

--- Кнопка в строку: залитые ячейки с надписью, по пробелу с боков.
local function chip(x, row, label, fg, bg)
  local w = wlen(label) + 2
  rect(x, py(row), w, 2, bg)
  text(x + 1, row, label, fg, bg)
  return { x, row, w, 1 }
end

local function hit(b, x, y)
  return b and x >= b[1] and x < b[1] + b[3] and y >= b[2] and y < b[2] + b[4]
end

-- Затемнение под окном: каждый цвет смешивается с чёрным один раз.
local veil = {}
local function dim(c)
  local d = veil[c]
  if not d then d = gfx.mix(c, VEIL, VEIL_T) veil[c] = d end
  return d
end

-- Области окон этого кадра {x1, строка1, x2, строка2}: надписи главного
-- экрана под ними не рисуются, иначе они легли бы поверх окна.
local covers = {}

local function covered(x, row)
  for _, c in ipairs(covers) do
    if row >= c[2] and row <= c[4] and x >= c[1] and x <= c[3] then return c end
  end
end

--- Вывести надпись главного экрана, пропустив то, что закрыто окном.
local function clipped(t)
  local x, row, s = t[1], t[2], t[3]
  local n = unicode.len(s)
  local i = 1
  while i <= n do
    local c = covered(x + i - 1, row)
    if c then
      i = c[3] - x + 2 -- перепрыгнуть окно
    else
      local j = i
      while j < n and not covered(x + j, row) do j = j + 1 end
      C:text(x + i - 1, row, unicode.sub(s, i, j), t[4], t[5])
      i = j + 1
    end
  end
end

--- Кадр: главный экран, при открытом окне - затемнённый, окно поверх,
--- надписи поверх пикселей, и на экран.
local function frame(paint, modal)
  tn = 0
  covers = {}
  rect(1, 1, W, H * 2, BG)
  paint()
  local base = tn
  if modal then
    local fb = C.fb
    for i = 1, W * H * 2 do fb[i] = dim(fb[i]) end
    for i = 1, tn do
      local t = texts[i]
      t[4], t[5] = dim(t[4]), dim(t[5])
    end
    modal()
  end
  C:flush(true)
  for i = 1, tn do
    local t = texts[i]
    if i <= base and covers[1] then clipped(t)
    else C:text(t[1], t[2], t[3], t[4], t[5]) end
  end
  C:present()
end

------------------------------------------------------------------ главный экран

local login, sel, top = false, nil, 0
local manager -- кто сейчас управляет: только его касания и клавиши и слушаем
local seenCache = {}
local btns = {} -- кнопки этого кадра: {box, действие}
local note, noteColor, noteUntil -- короткое сообщение над нижней панелью

local function toast(s, color)
  note, noteColor, noteUntil = s, color or OK, computer.uptime() + 4
end

--- Может ли игрок управлять составом: он в OWNERS или состоит в одной из
--- MANAGE_TOP старших групп списка.
local function canManage(nick)
  for _, n in ipairs(OWNERS) do
    if n == nick then return true end
  end
  for _, m in ipairs(config.sostav) do
    if m[2] == nick then
      for i = 1, MANAGE_TOP do
        if STATUS[i] == m[1] then return true end
      end
    end
  end
  return false
end

local LIST_Y = 5 -- первая строка списка
local function listRoom() return H - LIST_Y - 3 end

-- столбцы таблицы; последний забирает всё, что осталось справа
local C_MARK, C_GROUP, C_NICK, C_SEX, C_SEEN = 4, 6, 22, 42, 50

local function refreshSeen()
  seenCache = {}
  for _, row in ipairs(config.sostav) do seenCache[row[2]] = seen(row[2]) end
end

local function clampTop()
  top = max(0, min(top, #config.sostav - listRoom()))
end

local function drawRow(i, row)
  local m = config.sostav[i]
  local picked = m[2] == sel
  local bg = picked and SEL or (i % 2 == 0 and ZEBRA or PANEL)
  local right = W - 4
  rect(3, py(row), right - 2, 2, bg)
  local name, gcol = groupOf(m[1])
  rect(C_MARK, py(row), 1, 2, gcol) -- метка группы
  if picked then rect(3, py(row), 1, 2, ACC) end
  text(C_GROUP, row, name, gcol, bg, C_NICK - C_GROUP - 1)
  text(C_NICK, row, m[2], picked and 0xFFFFFF or FG, bg, C_SEX - C_NICK - 1)
  local sx, scol = sexOf(m[3])
  text(C_SEX, row, sx, scol, bg)
  local s, room = seenCache[m[2]], right - C_SEEN
  if not s then
    text(C_SEEN, row, "…", DIM, bg)
  elseif s.err then
    -- непонятный ответ показываем как есть: по нему видно, что не так
    local raw = s.raw:gsub("%s+", " "):gsub("^ ", "")
    text(C_SEEN, row, "? " .. (raw ~= "" and raw or "нет данных"), ERR, bg, room)
  elseif s.none then
    text(C_SEEN, row, "—", DIM, bg)
  elseif s.online then
    text(C_SEEN, row, "● в сети", OK, bg, room)
  else
    text(C_SEEN, row, "○ " .. s.text .. " назад", DIM, bg, room)
  end
end

local function button(label, fg, bg, x, row, action)
  local b = chip(x, row, label, fg, bg)
  btns[#btns + 1] = { b, action }
  return b[1] + b[3] + 1
end

local actions -- что делает каждая кнопка; заполняется ниже

local function paintMain()
  btns = {}
  clampTop()

  -- шапка
  rect(1, 1, W, 2, BAR)
  rect(1, 3, W, 1, BARLINE)
  text(3, 1, "◆", ACC, BAR)
  text(5, 1, "Администрация", FG, BAR)
  if login then chip(20, 1, "УПРАВЛЕНИЕ", BG, WARNBG) end
  if not linked() then chip(login and 34 or 20, 1, "НЕТ КОМАНДНОГО БЛОКА", FG, ERRBG) end
  local online = 0
  for _, m in ipairs(config.sostav) do
    local s = seenCache[m[2]]
    if s and s.online then online = online + 1 end
  end
  local count = #config.sostav .. " в составе"
  local x = W - wlen(count) - 1
  text(x, 1, count, DIM, BAR)
  local on = "● " .. online .. " в сети"
  text(x - wlen(on) - 3, 1, on, online > 0 and OK or DIM, BAR)

  -- таблица на панели
  local room = listRoom()
  -- панель до строки под списком и ещё на точку: тень не лезет на кнопки
  tile(2, py(3), W - 2, (room + 3) * 2 - 1, PANEL, true)
  text(C_GROUP, 3, "ГРУППА", DIM, PANEL)
  text(C_NICK, 3, "НИК", DIM, PANEL)
  text(C_SEX, 3, "ПОЛ", DIM, PANEL)
  text(C_SEEN, 3, "ПОСЛЕДНИЙ ЗАХОД", DIM, PANEL)
  rect(3, py(4), W - 4, 1, LINE)
  if #config.sostav == 0 then
    center(2, W - 2, LIST_Y + 2, "Состав пуст", DIM, PANEL)
    if login then center(2, W - 2, LIST_Y + 3, "добавьте первого кнопкой внизу", DIM, PANEL) end
  end
  for r = 1, room do
    if config.sostav[top + r] then drawRow(top + r, LIST_Y + r - 1) end
  end
  -- полоса прокрутки, если все не влезли
  if #config.sostav > room then
    local th = max(2, floor(room * 2 * room / #config.sostav))
    local ty = floor((room * 2 - th) * top / (#config.sostav - room) + 0.5)
    rect(W - 2, py(LIST_Y), 1, room * 2, TRACK)
    rect(W - 2, py(LIST_Y) + ty, 1, th, ACC)
  end

  -- что можно сделать с выбранным
  local ar = H - 2
  if note and computer.uptime() < noteUntil then
    text(3, ar, note, noteColor, BG, W - 4)
  elseif not linked() then
    text(3, ar, "Командный блок не подключен: время захода не обновляется, управление закрыто",
         ERR, BG, W - 4)
  elseif login and sel then
    text(3, ar, "▸", ACC, BG)
    text(5, ar, sel, FG, BG)
    x = 6 + wlen(sel) + 1
    x = button("Группа", FG, BTN, x, ar, actions.group)
    x = button("Ник", FG, BTN, x, ar, actions.rename)
    x = button("Пол", FG, BTN, x, ar, actions.sex)
    button("✕ Удалить", FG, ERRBG, x + 1, ar, actions.remove)
  elseif login then
    text(3, ar, "Коснитесь строки, чтобы изменить человека", DIM, BG)
  end

  -- нижняя панель
  rect(1, py(H) - 1, W, 1, BARLINE)
  rect(1, py(H), W, 2, BAR)
  if login then
    x = button("+ Добавить", FG, OKBG, 3, H, actions.add)
    button("⚙ Настройки", FG, BTN, x, H, actions.settings)
    local who = "управляет " .. manager
    text(W - 10 - wlen(who), H, who, DIM, BAR)
    button("Выход", FG, ERRBG, W - 8, H, actions.logout)
  else
    text(3, H, "Обновляется раз в " .. floor(UPDATE / 60 + 0.5) .. " мин", DIM, BAR)
    button("Управление", BG, ACC, W - 13, H, actions.login)
  end
end

local function render(modal) frame(paintMain, modal) end

------------------------------------------------------------------ окна

--- Рамка окна по центру: w символов на h строк, шапка с названием.
--- Возвращает левый край и первую строку.
local function panel(w, h, title)
  local x = floor((W - w) / 2) + 1
  local r = floor((H - h) / 2) + 1
  tile(x, py(r), w, h * 2, POP, true)
  covers[#covers + 1] = { x, r, x + w, r + h } -- с тенью
  rect(x + 1, py(r), w - 2, 1, HEAD)
  rect(x, py(r) + 1, w, 1, HEAD)
  text(x + 2, r, title, FG, HEAD, w - 4)
  return x, r
end

--- event.pull, который во время управления слышит только управляющего:
--- чужие касания и клавиши пропускаются, пока окно открыто.
local function input(timeout)
  while true do
    local ev = table.pack(event.pull(timeout))
    local e = ev[1]
    local who
    if e == "touch" or e == "scroll" then who = ev[6]
    elseif e == "key_down" or e == "clipboard" then who = ev[5] end
    if not e or not manager or who == nil or who == manager then
      return table.unpack(ev, 1, ev.n)
    end
  end
end

--- Поле ввода внутри окна. paint рисует окно, (x, row, w) - где поле.
--- Возвращает текст и то, чем кончили: "enter", "esc" или "touch" (тогда
--- ещё координаты щелчка).
local function field(paint, x, row, w, s, maxLen, accept)
  local blink = true
  while true do
    render(function()
      paint()
      rect(x, py(row), w, 2, FIELD)
      local shown = s
      if wlen(shown) > w - 3 then shown = unicode.sub(shown, -(w - 3)) end
      text(x + 1, row, shown, FG, FIELD)
      if blink then rect(x + 1 + wlen(shown), py(row), 1, 2, ACC) end
    end)
    local e, _, a, b = input(0.5)
    if e == "key_down" then
      blink = true
      if b == KEY_ENTER then return s, "enter"
      elseif b == KEY_ESC then return s, "esc"
      elseif b == KEY_BACK then s = unicode.sub(s, 1, -2)
      elseif a and a ~= 0 then
        local c = unicode.char(a)
        if c:find(accept) and unicode.len(s) < maxLen then s = s .. c end
      end
    elseif e == "clipboard" then
      for c in a:gmatch(".") do
        if c:find(accept) and unicode.len(s) < maxLen then s = s .. c end
      end
    elseif e == "touch" then
      return s, "touch", a, b
    elseif e == nil then
      blink = not blink
    end
  end
end

--- Окно с полем ввода ника. Возвращает ник или nil, если отменили.
local function ask(title, s)
  local w, h = 42, 8
  local bOk, bNo, fx, fr
  local function paint()
    local x, r = panel(w, h, title)
    text(x + 2, r + 2, "Ник игрока", DIM, POP)
    text(x + 2, r + 4, "латиница, цифры и _, до " .. MAX_NAME_LENGTH .. " знаков", DIM, POP, w - 4)
    bOk = chip(x + 2, r + 6, "Готово", FG, OKBG)
    bNo = chip(bOk[1] + bOk[3] + 1, r + 6, "Отмена", FG, BTN)
    text(x + w - 13, r + 6, "Enter / Esc", DIM, POP)
    fx, fr = x + 2, r + 3
  end
  paint()
  s = s or ""
  while true do
    local how, tx, ty
    s, how, tx, ty = field(paint, fx, fr, w - 4, s, MAX_NAME_LENGTH, "[0-9a-zA-Z_]")
    if how == "enter" or (how == "touch" and hit(bOk, tx, ty)) then
      return s ~= "" and s or nil
    elseif how == "esc" or (how == "touch" and hit(bNo, tx, ty)) then
      return nil
    end
  end
end

--- Окно выбора из списка. items - {подпись, цвет, значение}; щелчок мимо
--- окна - отмена.
local function pick(title, items, current)
  local w = wlen(title) + 6
  for _, it in ipairs(items) do w = max(w, wlen(it[1]) + 12) end
  local h = #items + 3
  local x, r
  render(function()
    x, r = panel(w, h, title)
    for i, it in ipairs(items) do
      local row = r + 1 + i
      local cur = it[3] == current
      local bg = cur and SEL or POP
      if cur then rect(x + 1, py(row), w - 2, 2, SEL) end
      rect(x + 2, py(row), 1, 2, it[2])
      text(x + 4, row, it[1], cur and 0xFFFFFF or it[2], bg, w - 8)
      if cur then text(x + w - 3, row, "✓", ACC, bg) end
    end
  end)
  while true do
    local e, _, tx, ty = input()
    local code = ty -- у key_down код клавиши на месте y
    if e == "touch" then
      if tx >= x and tx < x + w and ty > r + 1 and ty <= r + 1 + #items then
        return items[ty - r - 1][3]
      elseif not hit({ x, r, w, h }, tx, ty) then
        return nil
      end
    elseif e == "key_down" and code == KEY_ESC then
      return nil
    end
  end
end

--- Да или нет.
local function confirm(title, question, yes)
  local w = max(wlen(question) + 6, 38)
  local h = 6
  local x, r, bYes, bNo
  render(function()
    x, r = panel(w, h, title)
    text(x + 2, r + 2, question, FG, POP, w - 4)
    bYes = chip(x + 2, r + 4, yes, FG, ERRBG)
    bNo = chip(bYes[1] + bYes[3] + 1, r + 4, "Отмена", FG, BTN)
  end)
  while true do
    local e, _, tx, ty = input()
    local code = ty -- у key_down код клавиши на месте y
    if e == "touch" then
      if hit(bYes, tx, ty) then return true end
      if hit(bNo, tx, ty) or not hit({ x, r, w, h }, tx, ty) then return false end
    elseif e == "key_down" then
      if code == KEY_ENTER then return true end
      if code == KEY_ESC then return false end
    end
  end
end

--- Тумблер на пять ячеек: светлая ручка справа - включено.
local function switch(x, row, on)
  rect(x, py(row), 5, 2, on and OKBG or TRACK)
  rect(on and x + 3 or x, py(row), 2, 2, on and 0xFFFFFF or DIM)
  return { x, row, 5, 1 }
end

--- Окно настроек: тумблеры и разрешение. Возвращает, поменялось ли
--- разрешение.
local function settings()
  local list = config.settings
  local r1 = list[1]
  local wasX, wasY = r1.x, r1.y
  local mw, mh = gpu.maxResolution()
  local maxW, maxH = min(160, mw), min(50, mh)
  local w = 0
  for _, s in ipairs(list) do w = max(w, wlen(s.label or "") + 24) end
  w = max(w, 52) -- под подсказку о размере экрана внизу
  local h = #list * 2 + 5

  local x, r, boxes, bSave
  local function paint()
    x, r = panel(w, h, "⚙ Настройки")
    boxes = {}
    local right = x + w - 3
    for i, s in ipairs(list) do
      local row = r + i * 2
      text(x + 2, row, s.label or "", FG, POP, w - 16)
      if s.mode == 2 then
        boxes[#boxes + 1] = { switch(right - 4, row, s.value), i }
      elseif s.mode == 3 then
        local sy = tostring(s.y)
        local by = chip(right - wlen(sy) - 1, row, sy, FG, FIELD)
        text(by[1] - 2, row, "×", DIM, POP)
        local sx = tostring(s.x)
        local bx = chip(by[1] - 4 - wlen(sx), row, sx, FG, FIELD)
        boxes[#boxes + 1] = { bx, i, "x" }
        boxes[#boxes + 1] = { by, i, "y" }
      end
    end
    bSave = chip(x + 2, r + h - 2, "Сохранить", BG, ACC)
    text(bSave[1] + bSave[3] + 2, r + h - 2,
         "экран от " .. MIN_W .. "×" .. MIN_H .. " до " .. maxW .. "×" .. maxH, DIM, POP)
  end

  while true do
    render(paint)
    local e, _, tx, ty = input()
    local code = ty -- у key_down код клавиши на месте y
    if e == "key_down" and (code == KEY_ESC or code == KEY_ENTER) then break end
    if e == "touch" then
      if hit(bSave, tx, ty) then break end
      for _, bx in ipairs(boxes) do
        if hit(bx[1], tx, ty) then
          local s = list[bx[2]]
          if s.mode == 2 then
            s.value = not s.value
          else
            local b = bx[1]
            local v = tonumber((field(paint, b[1], b[2], 5, tostring(s[bx[3]]), 3, "[0-9]")))
            if v and bx[3] == "x" then s.x = max(MIN_W, min(maxW, v)) end
            if v and bx[3] == "y" then s.y = max(MIN_H, min(maxH, v)) end
          end
          break
        end
      end
    end
  end
  return r1.x ~= wasX or r1.y ~= wasY
end

------------------------------------------------------------------ действия

local owner -- кто нажал последнюю кнопку

actions = {}

local lastTouch = 0

function actions.login()
  if not linked() then
    toast("Командный блок не подключен — управление недоступно", ERR)
    return
  end
  login, manager, sel = true, owner, nil
  lastTouch = computer.uptime()
end

function actions.logout()
  login, manager, sel = false, nil, nil
end

function actions.add()
  local nick = ask("+ Новый участник")
  if not nick then return end
  if not indexOfNick(nick) then
    config.sostav[#config.sostav + 1] = { STATUS[#STATUS], nick, SEX[1] }
    seenCache[nick] = seen(nick)
    saveConfig()
  end
  sel = nick
  top = indexOfNick(nick) -- прокрутить к нему; clampTop поправит край
end

function actions.group()
  local i = indexOfNick(sel)
  local items = {}
  for _, st in ipairs(STATUS) do
    local name, col = groupOf(st)
    items[#items + 1] = { name, col, st }
  end
  local stat = pick("Группа · " .. sel, items, config.sostav[i][1])
  if stat and config.sostav[i][1] ~= stat then
    config.sostav[i][1] = stat
    sort()
    saveConfig()
  end
end

function actions.rename()
  local i = indexOfNick(sel)
  local nick = ask("Новый ник · " .. sel, sel)
  if nick and nick ~= sel and not indexOfNick(nick) then
    config.sostav[i][2] = nick
    seenCache[nick] = seen(nick)
    sel = nick
    saveConfig()
  end
end

function actions.sex()
  local i = indexOfNick(sel)
  local sex = pick("Пол · " .. sel, {
    { "Мужской", CODE.b, SEX[1] }, { "Женский", CODE.d, SEX[2] },
  }, config.sostav[i][3])
  if sex then
    config.sostav[i][3] = sex
    saveConfig()
  end
end

function actions.remove()
  if not confirm("✕ Удаление", "Убрать " .. sel .. " из состава?", "Удалить") then return end
  table.remove(config.sostav, indexOfNick(sel))
  sel = nil
  saveConfig()
end

function actions.settings()
  if settings() then openScreen() end
  saveConfig()
end

local function click(x, y, who)
  owner = who
  for _, b in ipairs(btns) do
    if hit(b[1], x, y) then
      b[2]()
      return
    end
  end
  local r = y - LIST_Y + 1
  local m = config.sostav[top + r]
  if login and r >= 1 and r <= listRoom() and m then
    sel = m[2] ~= sel and m[2] or nil
  elseif y ~= H then
    sel = nil
  end
end

------------------------------------------------------------------ работа

local function loop()
  process.killable(false) -- табло: Ctrl+Alt+C не выкидывает в оболочку
  loadConfig()
  openScreen()
  render()
  refreshSeen()
  render()
  local last = computer.uptime()
  local wasUp = linked()
  while true do
    -- пока идёт управление или висит сообщение - просыпаться каждую секунду
    local busy = login or (note and computer.uptime() < noteUntil)
    local e, _, x, y, d, who = event.pull(busy and 1 or max(1, UPDATE - (computer.uptime() - last)))
    local now = computer.uptime()
    -- Касания игроков без прав не значат ничего: ни кнопок, ни выбора
    -- строки, ни прокрутки. Пока идёт управление - слушаем только того,
    -- кто его открыл.
    if (e == "touch" or e == "scroll") and not (login and who == manager or not login and canManage(who)) then
      e = "ignored"
    end
    if e == "touch" then
      lastTouch = now
      click(x, y, who)
    elseif e == "scroll" then
      lastTouch = now
      top = top - d
    end
    -- командный блок отключили посреди управления - закрыть его; включили
    -- обратно - сразу обновить время захода
    local up = linked()
    if login and not up then actions.logout() end
    if wasUp and not up then refreshSeen() end -- старое "в сети" уже неправда
    if up and not wasUp then last = now - UPDATE end
    wasUp = up
    if login and now - lastTouch >= IDLE then
      actions.logout()
      toast("Управление закрыто: " .. IDLE .. " с без касаний", DIM)
    end
    if not login and now - last >= UPDATE then
      refreshSeen()
      last = now
    end
    render()
  end
end

local ok, err = xpcall(loop, debug.traceback)
if C then C:close() end
term.setCursorBlink(true)
term.clear()
if not ok then error(err, 0) end
