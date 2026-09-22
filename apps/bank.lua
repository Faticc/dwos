-- bank - банкомат: снять деньги со счёта предметом и внести обратно.
--
-- Банкомат SkyDrive_, заново нарисованный под DwOS. Экран - пиксельный
-- холст gfx.new: полублок делит ячейку на две точки, так что 49x24
-- символов - это 49x48 точек. На нём скруглённые карточки с градиентом,
-- банковская карта и крупные цифры 3x5, а надписи ложатся поверх готового
-- кадра. Кадр собирается в видеопамяти, на экран уходит только
-- изменившееся. Сторонних библиотек нет: с сервером программа говорит
-- сама, через командный блок.
--
-- Это киоск: выхода нет и Ctrl+Alt+C программу не убивает - машина стоит
-- в мире и должна показывать экран банка, пока её не выключат.

local component = require("component")
local computer = require("computer")
local event = require("event")
local gfx = require("gfx")
local process = require("process")
local term = require("term")
local tty = require("tty")
local unicode = require("unicode")

--------------------Настройки--------------------
local WIDTH, HEIGHT = 49, 24 --Разрешение моника
local AUTOEXIT = 30 --Автовыход через n сек.
local TONE = 600 --Тональность звука
local MAX_OPERATION = 2000 --Максимальная операция
local MONEY_ITEM_ID = "CUSTOMNPCS_NPCMONEY" --Айдишник деняк
local SPAM = 1 --Время, в течении которого нельзя юзать комп, после выхода
-------------------------------------------------

local BG, BAR, BARLINE = 0x0B1320, 0x14213A, 0x1E3450
local FG, DIM, SOFT, ACC = 0xE8EEF5, 0x7D8BA0, 0xBFD4F5, 0x5CC8FF
local ERR, OK, GOLD, GOLD2 = 0xFF6B6B, 0x7BD88F, 0xE8C35A, 0xB8923A
local SHADOW = 0x060A12
local CARD1, CARD2 = 0x3179E0, 0x1C3F8F -- банковская карта: верх и низ
local PANEL1, PANEL2 = 0x1B2B46, 0x131F34
local MINUS1, MINUS2, MINUS_FG = 0x4A2635, 0x33192A, 0xFF9A9A
local PLUS1, PLUS2, PLUS_FG = 0x1F4A33, 0x163424, 0x9BE8A8
local TAKE1, TAKE2 = 0x7AD6FF, 0x3AA3E6
local PUT1, PUT2 = 0x86E29A, 0x3F9F5B
local EXITBG, TRACK = 0x7A2E3A, 0x2A3A55

local floor, max, min = math.floor, math.max, math.min
local wlen = unicode.wlen

------------------------------------------------------------------ сервер

-- Ответы сервера - кусок чата с кодами §, и формулировки у серверов
-- разные. Поэтому ответы разбираются не по точной фразе, а по смыслу:
-- число денег, слова успеха и отказа по-русски и по-английски. Ответ,
-- который разобрать не вышло, показывается на экране как есть.

--- Подключён ли командный блок: без него банкомат не работает.
local function linked() return component.isAvailable("opencb") end

local function com(command)
  if not linked() then return "" end
  local _, answer = component.opencb.execute(command)
  return answer or ""
end

--- Строка без цветовых кодов § и без ника: цифры в нике - не деньги.
local function plain(s, nick)
  s = s:gsub("§.", "")
  if nick then s = s:gsub(nick:gsub("%p", "%%%0"), "") end
  return s
end

--- Баланс строкой, как его печатает сервер: "1,234.00"; nil, если в
--- ответе нет числа.
local function money(nick)
  local c = plain(com("money " .. nick), nick)
  return c:match("(%-?%d[%d,]*%.%d+)") or c:match("(%-?%d[%d,]*)")
end

--- Баланс числом.
local function amount(s)
  return s and tonumber((s:gsub(",", "")))
end

--- Хватает ли денег, и если да - снять их со счёта.
local function takeMoney(nick, sum)
  local balance = amount(money(nick))
  if not balance or balance < sum then return false end
  com("money take " .. nick .. " " .. sum)
  return true
end

local function giveMoney(nick, sum) com("money give " .. nick .. " " .. sum) end

local function has(low, words)
  for _, w in ipairs(words) do
    if low:find(w, 1, true) then return true end
  end
end

local YES = { "убрано", "удалено", "удален", "изъято", "забрано", "очищ", "cleared", "removed" }
local NO = { "не удал", "не найден", "не хватает", "недостаточно", "no items", "could not",
  "couldn't", "not found", "unknown", "неизвестн", "usage", "использование" }

--- Забрать купюры из инвентаря. Возвращает, сколько забрали на самом
--- деле (0 - ничего), и ответ сервера без кодов - для экрана.
local function takeItem(nick, count)
  local c = plain(com("clear " .. nick .. " " .. MONEY_ITEM_ID .. " " .. count), nick)
  local low = unicode.lower(c)
  if has(low, NO) or not has(low, YES) then return 0, c end
  -- сервер обычно называет, сколько убрал: если меньше, чем просили,
  -- на счёт идёт ровно столько, иначе вышло бы что-то из ничего
  local n = tonumber(c:match("%d+"))
  if n and n > 0 and n < count then return n, c end
  return count, c
end

--- Выдать купюры. Возвращает, сколько не влезло в инвентарь.
local function giveItem(nick, count)
  local c = plain(com("egive " .. nick .. " " .. MONEY_ITEM_ID .. " " .. count), nick)
  local low = unicode.lower(c)
  if not (low:find("недостаточно", 1, true) or low:find("not enough", 1, true)
          or low:find("inventory full", 1, true)) then return 0 end
  local rest = tonumber((c:match("(%d[%d,]*)") or ""):gsub(",", ""), 10)
  return rest and min(rest, count) or 0
end

------------------------------------------------------------------ холст

local gpu = tty.gpu()
local C, W, H -- холст, ширина в символах, высота в строках (точек - 2H)
local texts, tn = {}, 0 -- надписи кадра: ложатся после пикселей

local function openScreen()
  local mw, mh = gpu.maxResolution()
  local w, h = min(WIDTH, mw), min(HEIGHT, mh)
  term.clear()
  term.setCursorBlink(false)
  local cw, ch = gpu.getResolution()
  if cw ~= w or ch ~= h then gpu.setResolution(w, h) end
  C = gfx.new(gpu, w, h, { rgb = true, keepResolution = true, background = BG })
  W, H = C.w, C.h
end

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

--- Прямоугольник со срезанными углами: на полублоках это и есть скругление.
local function round(x, y, w, h, c)
  rect(x + 1, y, w - 2, h, c)
  rect(x, y + 1, 1, h - 2, c)
  rect(x + w - 1, y + 1, 1, h - 2, c)
end

--- Цвет строки row в вертикальном градиенте от c1 до c2 по строкам r1..r2.
--- Шаг градиента - целая строка: тогда у надписи ровный фон.
local function shade(c1, c2, r1, r2, row)
  if r2 <= r1 then return c1 end
  return gfx.mix(c1, c2, (row - r1) / (r2 - r1))
end

--- Скруглённая плашка с градиентом по строкам; y и h - в точках, чётные
--- края лучше: тогда плашка занимает целые строки.
local function tile(x, y, w, h, c1, c2, shadow)
  if shadow then round(x + 1, y + 1, w, h, SHADOW) end
  local r1, r2 = floor((y + 1) / 2), floor((y + h) / 2)
  for py = y, y + h - 1 do
    local c = shade(c1, c2, r1, r2, floor((py + 1) / 2))
    local inset = (py == y or py == y + h - 1) and 1 or 0
    rect(x + inset, py, w - inset * 2, 1, c)
  end
end

--- Цвет плашки в строке row - для фона надписей на ней.
local function tileAt(y, h, c1, c2, row)
  return shade(c1, c2, floor((y + 1) / 2), floor((y + h) / 2), row)
end

-- Крупные цифры 3x5 точек: все одной ширины, чтобы суммы стояли ровно.
local FONT = {
  ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "110", "010", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "011", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "001", "010", "010" },
  ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
  [","] = { "0", "0", "0", "1", "1" }, ["."] = { "0", "0", "0", "0", "1" },
  [" "] = { "0", "0", "0", "0", "0" }, ["-"] = { "000", "000", "111", "000", "000" },
}

local function bigWidth(s)
  local w = 0
  for ch in s:gmatch(".") do w = w + #(FONT[ch] or FONT[" "])[1] + 1 end
  return w - 1
end

local function big(x, y, s, c)
  for ch in s:gmatch(".") do
    local g = FONT[ch] or FONT[" "]
    for r = 1, 5 do
      local row = g[r]
      for k = 1, #row do
        if row:byte(k) == 49 then C:pixel(x + k - 1, y + r - 1, c) end
      end
    end
    x = x + #g[1] + 1
  end
  return x
end

--- Число с пробелами между тысячами: 12 500.
local function group(n)
  local s = tostring(n)
  while true do
    local t, k = s:gsub("^(%d+)(%d%d%d)", "%1 %2")
    s = t
    if k == 0 then return s end
  end
end

--- Кадр: пиксели, потом надписи поверх, потом на экран.
local function frame(paint)
  tn = 0
  rect(1, 1, W, H * 2, BG)
  paint()
  C:flush(true)
  for i = 1, tn do
    local t = texts[i]
    C:text(t[1], t[2], t[3], t[4], t[5])
  end
  C:present()
end

local function hit(b, x, y)
  return b and x >= b[1] and x < b[1] + b[3] and y >= b[2] and y < b[2] + b[4]
end

------------------------------------------------------------------ раскладка

-- Всё стоит в колонке ширины CW посередине: на экране больше 49x24
-- колонка просто встаёт в центр. Координаты плашек - в точках, кнопок
-- для щелчка - в символах: {x, строка, ширина, строк}.
local CW = 41
local X0, R0 -- левый край колонки и сдвиг по строкам
local CHIPS = {
  { sum = -100, label = "-100" }, { sum = -10, label = "-10" }, { sum = -1, label = "-1" },
  { sum = 1, label = "+1" }, { sum = 10, label = "+10" }, { sum = 100, label = "+100" },
}
local B_LOGIN, B_EXIT, B_TAKE, B_PUT, B_SUM

local function py(row) return (row + R0) * 2 - 1 end -- верхняя точка строки

local function layout()
  X0 = floor((W - CW) / 2) + 1
  R0 = max(0, floor((H - 24) / 2))
  B_LOGIN = { floor((W - 25) / 2) + 1, 16 + R0, 25, 3 }
  B_EXIT = { W - 8, 1, 9, 1 }
  B_SUM = { X0, 10 + R0, CW, 6 }
  for i, c in ipairs(CHIPS) do c.box = { X0 + (i - 1) * 7, 17 + R0, 6, 3 } end
  B_TAKE = { X0, 21 + R0, 20, 3 }
  B_PUT = { X0 + 21, 21 + R0, 20, 3 }
end

------------------------------------------------------------------ экраны

local login, nick, summa, balance = false, nil, 0, "0.00"
local timer, timeClear, spam = 0, 0, false
local message, messageColor
local pressed -- кнопка, которую только что нажали: горит до следующего тика

local function beep() computer.beep(TONE, 0.05) end

local function header(title)
  rect(1, 1, W, 2, BAR)
  rect(1, 3, W, 1, BARLINE)
  text(3, 1, "◆", ACC, BAR)
  text(5, 1, title, FG, BAR)
end

--- Плоская кнопка на плашке: y - строка, надпись по центру средней строки.
local function button(b, label, c1, c2, fg, lit, flat)
  if lit then c1, c2 = gfx.mix(c1, 0xFFFFFF, 0.35), gfx.mix(c2, 0xFFFFFF, 0.35) end
  local y, h = b[2] * 2 - 1, b[4] * 2
  tile(b[1], y, b[3], h, c1, c2, not flat)
  local mid = b[2] + floor(b[4] / 2)
  center(b[1], b[3], mid, label, fg, tileAt(y, h, c1, c2, mid))
end

-- Банковская карта для экрана приветствия.
local DOT5 = { "01110", "11111", "11111", "11111", "01110" }

local function circle(x, y, c)
  for r = 1, 5 do
    for k = 1, 5 do
      if DOT5[r]:byte(k) == 49 then C:pixel(x + k - 1, y + r - 1, c) end
    end
  end
end

local function chipArt(x, y)
  rect(x, y, 6, 4, GOLD)
  rect(x, y + 1, 6, 1, GOLD2)
  rect(x + 2, y, 1, 4, GOLD2)
end

local function paintWelcome()
  header("Банк")
  text(W - 5, 1, "DwOS", DIM, BAR)

  local cx, cy = floor((W - 27) / 2) + 1, py(4)
  tile(cx, cy, 27, 16, CARD1, CARD2, true)
  chipArt(cx + 3, cy + 4)
  for g = 0, 2 do
    for d = 0, 2 do C:pixel(cx + 3 + g * 6 + d * 2, cy + 11, SOFT) end
  end
  circle(cx + 17, cy + 2, 0xE0463C)
  circle(cx + 20, cy + 2, 0xF2A33A)

  center(1, W, 13 + R0, "Банкомат", FG, BG)
  center(1, W, 14 + R0, "снятие и пополнение счёта", DIM, BG)
  if linked() then
    button(B_LOGIN, "Войти  →", TAKE1, TAKE2, BG)
    center(1, W, 20 + R0, "счёт откроется на того, кто нажал", DIM, BG)
  else
    button(B_LOGIN, "Банкомат не работает", MINUS1, MINUS2, MINUS_FG, false, true)
    center(1, W, 20 + R0, "командный блок не подключен", ERR, BG)
  end

  rect(1, H * 2 - 1, W, 2, BAR)
  text(3, H, "до " .. group(MAX_OPERATION) .. " $ за операцию", DIM, BAR)
  text(W - 5, H, "24/7", DIM, BAR)
end

local function paintAccount()
  header("Банк")
  local bx = B_EXIT
  rect(bx[1], 1, bx[3], 2, EXITBG)
  center(bx[1], bx[3], 1, "Выход", FG, EXITBG)

  -- карта с балансом
  local y, h = py(3), 14
  tile(X0, y, CW, h, CARD1, CARD2, true)
  text(X0 + 3, 4 + R0, "БАЛАНС", SOFT, tileAt(y, h, CARD1, CARD2, 4 + R0))
  chipArt(X0 + CW - 9, y + 2)
  if not balance:find("%d") then
    text(X0 + 3, 6 + R0, "баланс недоступен", ERR, tileAt(y, h, CARD1, CARD2, 6 + R0))
  elseif bigWidth(balance) <= CW - 14 then
    -- знак валюты обычным шрифтом у середины цифр: в 3x5 "$" не читается
    big(X0 + 3, y + 6, balance, 0xFFFFFF)
    text(X0 + 5 + bigWidth(balance), 7 + R0, "$", SOFT, tileAt(y, h, CARD1, CARD2, 7 + R0))
  else
    text(X0 + 3, 6 + R0, balance .. " $", 0xFFFFFF, tileAt(y, h, CARD1, CARD2, 6 + R0), CW - 6)
  end
  text(X0 + 3, 9 + R0, fit(unicode.upper(nick), CW - 6), SOFT, tileAt(y, h, CARD1, CARD2, 9 + R0))

  -- сумма операции
  y, h = py(10) + 1, 11
  tile(X0, y, CW, h, PANEL1, PANEL2, true)
  local lbg = tileAt(y, h, PANEL1, PANEL2, 11 + R0)
  text(X0 + 3, 11 + R0, "СУММА", DIM, lbg)
  local hint = summa > 0 and "коснитесь — сброс" or "наберите кнопками"
  text(X0 + CW - 3 - wlen(hint), 11 + R0, hint, DIM, lbg)
  local sum = group(summa)
  big(X0 + 3, y + 3, sum, summa > 0 and FG or DIM)
  text(X0 + 5 + bigWidth(sum), 13 + R0, "$", DIM, tileAt(y, h, PANEL1, PANEL2, 13 + R0))
  local lim = "из " .. group(MAX_OPERATION)
  text(X0 + CW - 3 - wlen(lim), 13 + R0, lim, DIM, tileAt(y, h, PANEL1, PANEL2, 13 + R0))
  local tw = CW - 6
  local n = floor(tw * summa / MAX_OPERATION + 0.5)
  rect(X0 + 3, y + 9, tw, 1, TRACK)
  if n > 0 then rect(X0 + 3, y + 9, n, 1, ACC) end

  for i, c in ipairs(CHIPS) do
    if c.sum < 0 then button(c.box, c.label, MINUS1, MINUS2, MINUS_FG, pressed == c, true)
    else button(c.box, c.label, PLUS1, PLUS2, PLUS_FG, pressed == c, true) end
  end
  button(B_TAKE, "↑ Снять", TAKE1, TAKE2, BG, pressed == B_TAKE)
  button(B_PUT, "↓ Внести", PUT1, PUT2, BG, pressed == B_PUT)

  if message then center(1, W, 20 + R0, message, messageColor, BG) end

  -- подвал: обратный отсчёт до автовыхода
  rect(1, H * 2 - 1, W, 2, BAR)
  local tc = timer <= 10 and ERR or FG
  text(3, H, "Автовыход", DIM, BAR)
  text(13, H, string.format("%2d с", timer), tc, BAR)
  local bw = W - 22
  local fill = floor(bw * timer / AUTOEXIT + 0.5)
  rect(20, H * 2, bw, 1, TRACK)
  if fill > 0 then rect(20, H * 2, fill, 1, gfx.mix(ERR, ACC, timer / AUTOEXIT)) end
end

local function render()
  frame(login and paintAccount or paintWelcome)
end

------------------------------------------------------------------ действия

--- Сообщение под кнопками; само гаснет через hold секунд.
local function say(s, hold, color)
  message, messageColor, timeClear = s, color or OK, hold or 0
end

--- Выйти из счёта: экран приветствия и никого за машиной.
local function logout()
  login, nick, summa, message, pressed = false, nil, 0, nil, nil
  local users = { computer.users() }
  for i = 1, #users do computer.removeUser(users[i]) end
  spam = true
end

local function enter(who)
  computer.addUser(who)
  login, nick, summa = true, who, 0
  balance = money(nick) or "?"
  say(nil)
  beep()
end

--- Снять со счёта: деньги уходят со счёта, в инвентарь падают купюры.
local function withdraw()
  if summa == 0 then
    say("Сначала наберите сумму", 3, ERR)
  elseif takeMoney(nick, summa) then
    local rest = giveItem(nick, summa)
    if rest == 0 then
      say("✔ Выдано " .. group(summa) .. " $", 3)
    else
      -- что не влезло в инвентарь - обратно на счёт, игрок не в убытке
      giveMoney(nick, rest)
      say("Инвентарь полон: " .. group(rest) .. " $ на счёт", 5, ERR)
    end
    summa = 0
  else
    say("Недостаточно средств", 3, ERR)
  end
end

--- Внести на счёт: купюры из инвентаря превращаются в деньги.
local function deposit()
  if summa == 0 then
    say("Сначала наберите сумму", 3, ERR)
  else
    local got, answer = takeItem(nick, summa)
    if got == summa then
      giveMoney(nick, got)
      say("✔ Зачислено " .. group(got) .. " $", 3)
      summa = 0
    elseif got > 0 then
      giveMoney(nick, got)
      say("Нашлось только " .. group(got) .. " $ — зачислено", 5, ERR)
      summa = 0
    else
      say("В инвентаре нет столько купюр", 3, ERR)
    end
  end
end

local function touch(x, y, who)
  if not login then
    if hit(B_LOGIN, x, y) and linked() then enter(who) end
    return
  end
  if not linked() and not hit(B_EXIT, x, y) then
    say("Командный блок не подключен", 3, ERR)
    return
  end
  if hit(B_EXIT, x, y) then
    beep()
    logout()
    return
  end
  for _, c in ipairs(CHIPS) do
    if hit(c.box, x, y) then
      summa = max(0, min(MAX_OPERATION, summa + c.sum))
      pressed = c
      beep()
      return
    end
  end
  if hit(B_SUM, x, y) and summa > 0 then
    summa = 0
    beep()
  elseif hit(B_TAKE, x, y) or hit(B_PUT, x, y) then
    pressed = hit(B_TAKE, x, y) and B_TAKE or B_PUT
    if pressed == B_TAKE then withdraw() else deposit() end
    balance = money(nick) or "?"
    beep()
  end
end

--- Раз в секунду: обратный отсчёт до автовыхода и гашение сообщения.
local function tick()
  timer = timer - 1
  if timer <= 0 then
    logout()
    return
  end
  if timeClear > 0 then
    timeClear = timeClear - 1
    if timeClear == 0 then message = nil end
  end
end

------------------------------------------------------------------ работа

local function loop()
  process.killable(false) -- киоск: Ctrl+Alt+C не выкидывает в оболочку
  openScreen()
  layout()
  logout()
  render()
  while true do
    if spam then
      -- после выхода машина секунду не слушает: чтобы следующий игрок не
      -- попал в чужой счёт хвостом чужого щелчка
      os.sleep(SPAM)
      spam = false
    else
      local e, _, x, y, _, who = event.pull(1, "touch")
      if e == "touch" then
        touch(x, y, who)
        timer = AUTOEXIT
      end
      if login then tick() end
      render()
      pressed = nil -- нажатая кнопка горит один кадр, до следующего тика
    end
  end
end

local ok, err = xpcall(loop, debug.traceback)
if C then C:close() end
term.setCursorBlink(true)
term.clear()
if not ok then error(err, 0) end
