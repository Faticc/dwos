-- edit: редактор текста. Экран собирается в видеопамяти (gfx.surface),
-- поэтому правка строки стоит десяток вызовов gpu, а не перерисовки всего.
--
-- Что умеет сверх оригинала OpenOS:
--   подсветка Lua, выделение (Shift+стрелки, Ctrl+A) со своим буфером
--   обмена, отмена и повтор, автодополнение по Tab, автоотступ и парные
--   скобки, переход к строке по номеру, колонка с номерами строк;
--   проверка синтаксиса и подозрительных имён на лету, переход к ошибке
--   после запуска, поиск с заменой, несколько файлов, список функций,
--   переход к определению, переименование, свёртка блоков и отладчик с
--   точками останова, шагами и значениями переменных. Полный список
--   клавиш - по F1.
--
-- Раскладка клавиш читается из /etc/edit.cfg, как в OpenOS; чего в файле
-- нет, берётся из значений по умолчанию, так что старый конфиг не мешает.

local fs = require("filesystem")
local keyboard = require("keyboard")
local keys = keyboard.keys
local shell = require("shell")
local term = require("term")
local text = require("text")
local unicode = require("unicode")
local event = require("event")
local computer = require("computer")
local component = require("component")
local gfx = require("gfx")
local tty = require("tty")
local luascan = require("luascan")

if not term.isAvailable() then return end

local args, options = shell.parse(...)
if #args == 0 then
  io.write("Usage: edit [-r] <filename>\n")
  return
end

local filename = shell.resolve(args[1])
local parent = fs.path(filename)

if fs.exists(parent) and not fs.isDirectory(parent) then
  io.stderr:write(string.format("Not a directory: %s\n", parent))
  return 1
end
if fs.isDirectory(filename) then
  io.stderr:write("file is a directory\n")
  return 1
end

local readonly = options.r or fs.get(filename) == nil or fs.get(filename).isReadOnly()
if not fs.exists(filename) and readonly then
  io.stderr:write("file system is read only\n")
  return 1
end

------------------------------------------------------------------ настройки

local DEFAULTS = {
  left = { { "left" } },
  right = { { "right" } },
  up = { { "up" } },
  down = { { "down" } },
  home = { { "home" } },
  eol = { { "end" } },
  pageUp = { { "pageUp" } },
  pageDown = { { "pageDown" } },

  backspace = { { "back" }, { "shift", "back" } },
  delete = { { "delete" } },
  deleteLine = { { "control", "delete" }, { "shift", "delete" } },
  newline = { { "enter" } },

  save = { { "control", "s" } },
  close = { { "control", "w" } },
  find = { { "control", "f" } },
  findnext = { { "control", "g" }, { "control", "n" }, { "f3" } },
  cut = { { "control", "k" } },
  uncut = { { "control", "u" } },
  goto_line = { { "control", "l" } },

  copy = { { "control", "c" } },
  cutSelection = { { "control", "x" } },
  selectAll = { { "control", "a" } },
  undo = { { "control", "z" } },
  redo = { { "control", "y" } },
  complete = { { "tab" } },
  completeList = { { "control", "space" } },
  unindent = { { "shift", "tab" } },
  run = { { "f5" }, { "control", "r" } },
  shell = { { "control", "e" } },
  panel = { { "control", "o" } },

  replace = { { "control", "h" } },
  findprev = { { "shift", "f3" } },
  open = { { "control", "p" } },
  nextDoc = { { "control", "pageDown" } },
  prevDoc = { { "control", "pageUp" } },
  outline = { { "control", "t" } },
  definition = { { "f12" } },
  usages = { { "shift", "f12" } },
  back = { { "control", "b" } },
  rename = { { "f2" } },
  problem = { { "f8" } },
  problemPrev = { { "shift", "f8" } },
  comment = { { "control", "slash" } },
  duplicate = { { "control", "d" } },
  moveUp = { { "alt", "up" }, { "control", "shift", "up" } },
  moveDown = { { "alt", "down" }, { "control", "shift", "down" } },
  fold = { { "control", "lbracket" } },
  debug = { { "f6" } },
  breakpoint = { { "f9" } },
  help = { { "f1" } },
}

local function loadConfig()
  local env = {}
  local config = loadfile("/etc/edit.cfg", nil, env)
  if config then pcall(config) end
  if type(env.keybinds) ~= "table" then env.keybinds = {} end
  -- чего в файле нет, берём своё: старый конфиг не должен лишать новых клавиш
  local fresh = false
  for command, bind in pairs(DEFAULTS) do
    if env.keybinds[command] == nil then
      env.keybinds[command] = bind
      fresh = true
    end
  end
  if fresh then
    local root = fs.get("/")
    if root and not root.isReadOnly() then
      fs.makeDirectory("/etc")
      local f = io.open("/etc/edit.cfg", "w")
      if f then
        local serialization = require("serialization")
        for k, v in pairs(env) do
          f:write(k .. "=" .. tostring(serialization.serialize(v, math.huge)) .. "\n")
        end
        f:close()
      end
    end
  end
  return env
end

local config = loadConfig()

------------------------------------------------------------------ цвета

local P = {
  FG = 0xD0D0D0, BG = 0x000000,
  C_KW = 0x66CCFF, C_STR = 0x88DD88, C_NUM = 0xFFAA00, C_CMT = 0x707070, C_BLT = 0xFF9966, C_OP = 0xBBBBBB,
  BAR_BG = 0x1B2A3A, BAR_FG = 0x7A8A98, BAR_NAME = 0xE1E1E1,
  BAR_POS = 0x66CCFF, BAR_MARK = 0xFFAA00, BAR_MSG = 0x88DD88,
  GUT = 0x4E5D6B, GUT_CUR = 0x9AA8B4, CUR = 0xFFFFFF,
  SEL = 0x2D4A66, FIND = 0xFFAA00, PAIR = 0x4E7A2D,
  ERR = 0xFF6666, WARN = 0xE0C050,
  BP_BG = 0x8A2020, DBG_BG = 0x3C3A12, FIND_ALL = 0x5A4210,
  POP_BG = 0x22323F, POP_FG = 0xC8D2DA, POP_SEL = 0x2D4A66,
}

------------------------------------------------------------------ подсветка

local KEYWORD = {}
for w in ("and break do else elseif end for function goto if in local not or " ..
          "repeat return then until while"):gmatch("%S+") do KEYWORD[w] = true end
local BUILTIN = {}
for w in ("nil true false self _G _ENV require print pairs ipairs type tostring tonumber " ..
          "string table math os io coroutine error assert pcall xpcall select setmetatable " ..
          "getmetatable rawget rawset rawequal rawlen next load dofile loadfile unpack " ..
          "component computer unicode checkArg"):gmatch("%S+") do
  BUILTIN[w] = true
end

local function isLua(name) return name:sub(-4) == ".lua" or name:sub(-4) == ".cfg" end
local lua = isLua(filename)

-- Разобрать строку на куски {текст, цвет}. state - "мы внутри длинной
-- скобки" ({level = число =, comment = строка это комментарий}).
local function tokenize(s, state)
  local out, i, n = {}, 1, #s
  local function push(t, c) if t ~= "" then out[#out + 1] = { t, c } end end
  while i <= n do
    if state then
      local close = "]" .. ("="):rep(state.level) .. "]"
      local a = s:find(close, i, true)
      local col = state.comment and P.C_CMT or P.C_STR
      if a then
        push(s:sub(i, a + #close - 1), col)
        i = a + #close
        state = nil
      else
        push(s:sub(i), col)
        i = n + 1
      end
    else
      local c = s:sub(i, i)
      if c:match("%s") then
        local a, b = s:find("%s+", i)
        push(s:sub(a, b), P.FG)
        i = b + 1
      elseif s:find("^%-%-", i) then
        local eq = s:match("^%-%-%[(=*)%[", i)
        if eq then
          state = { level = #eq, comment = true }
          push(s:sub(i, i + #eq + 3), P.C_CMT)
          i = i + #eq + 4
        else
          push(s:sub(i), P.C_CMT)
          i = n + 1
        end
      elseif s:find("^%[=*%[", i) then
        local eq = s:match("^%[(=*)%[", i)
        state = { level = #eq, comment = false }
        push(s:sub(i, i + #eq + 1), P.C_STR)
        i = i + #eq + 2
      elseif c == '"' or c == "'" then
        local j = i + 1
        while j <= n do
          local d = s:sub(j, j)
          if d == "\\" then
            j = j + 2
          elseif d == c then
            j = j + 1
            break
          else
            j = j + 1
          end
        end
        push(s:sub(i, j - 1), P.C_STR)
        i = j
      elseif c:match("%d") or (c == "." and s:sub(i + 1, i + 1):match("%d")) then
        local a, b = s:find("^0[xX]%x+", i)
        if not a then a, b = s:find("^%d+%.?%d*[eE][-+]?%d+", i) end
        if not a then a, b = s:find("^%d*%.?%d+", i) end
        if not a then a, b = i, i end
        push(s:sub(a, b), P.C_NUM)
        i = b + 1
      elseif c:match("[%a_\128-\255]") then
        -- байты старше 127 - это UTF-8: русская буква в два байта, и по
        -- одному их рисовать нельзя (на экране выйдут знаки вопроса)
        local a, b = s:find("^[%w_\128-\255]+", i)
        local word = s:sub(a, b)
        push(word, KEYWORD[word] and P.C_KW or BUILTIN[word] and P.C_BLT or P.FG)
        i = b + 1
      else
        push(c, P.C_OP)
        i = i + 1
      end
    end
  end
  return out, state
end

------------------------------------------------------------------ окно

local gpu = tty.gpu()
term.clear()
term.setCursorBlink(false)
local SW, SH = gpu.getResolution()
local panelH = 0                  -- панель оболочки внизу; 0 - закрыта
local S = gfx.surface(gpu, { h = SH })
local W, H = S.w, S.h             -- холст редактора, H - его служебная строка
local rows = H - 1

local buffer = {}
local carry, carryTop = {}, 1     -- состояние подсветки на входе в строку
local cx, cy = 1, 1               -- курсор: символ в строке и номер строки
local scrollX, scrollY = 0, 0
local running = true
local anchor = nil                -- начало выделения: { символ, строка }
local clip = {}                   -- свой буфер обмена, строками
local cutting = false             -- Ctrl+K подряд складывает строки в один кусок
local rev = 0                     -- счётчик правок: по нему стареет словарь
local ghost = nil                 -- подсказка при наборе: { text, more }
local status, dirty = nil, {}
local fullRedraw, modified = true, false
local match, pair = nil, nil      -- найденное и парная скобка
local GW = 2                      -- ширина колонки с номерами строк
local sigHelp = nil               -- сигнатура вызова под курсором: куски { текст, цвет }
local lineProblem                 -- (i) -> что не заполнено в вызовах строки; ниже
local bps, folds = {}, {}         -- точки останова: строка -> true; свёрнутое: первая -> последняя
local diag = {}                   -- строка -> { err = текст, warn = текст, marks = { {байт, длина} } }
local syntaxErr, runErr = nil, nil -- { l, msg }: синтаксис и падение при запуске
local scan, scanRev = nil, -1     -- разбор luascan и номер правки, к которой он относится
local checkDue = nil              -- когда проверить файл: после паузы в наборе
local savedId = 0                 -- шаг отмены, на котором файл совпадает с диском
local stamp = nil                 -- lastModified файла при чтении или записи
local dbgLine = nil               -- строка, на которой стоит отладчик
local view, rowOf = {}, {}        -- экранная строка -> строка файла и обратно (свёртка)

local function curLine() return buffer[cy] or "" end
local function textW() return W - GW end

--- Сколько экранных колонок занимают первые (i-1) символов строки.
local function dispCol(line, i)
  return unicode.wlen(unicode.sub(line, 1, i - 1)) + 1
end

--- Номер символа, попадающего в экранную колонку col.
local function charAt(line, col)
  if col > unicode.wlen(line) then return unicode.len(line) + 1 end
  return unicode.len(unicode.wtrunc(line, col)) + 1
end

--- Убрать слева length экранных колонок (широкий символ на срезе - пробел).
local function removePrefix(line, length)
  if length >= unicode.wlen(line) then return "" end
  local prefix = unicode.wtrunc(line, length + 1)
  local suffix = unicode.sub(line, unicode.len(prefix) + 1)
  length = length - unicode.wlen(prefix)
  if length > 0 then
    suffix = (" "):rep(unicode.charWidth(suffix) - length) .. unicode.sub(suffix, 2)
  end
  return suffix
end

--- Обрезать по ширине. unicode.wtrunc падает, если строка уже короче
--- запрошенного, поэтому сначала сравниваем.
local function fit(s, w)
  if w < 1 then return "" end
  return unicode.wlen(s) > w and unicode.wtrunc(s, w + 1) or s
end

local function invalidate(from)
  if carryTop > from then carryTop = from end
end

local function ensureCarry(upto)
  upto = math.min(upto, #buffer)
  while carryTop <= upto do
    local _, st = tokenize(buffer[carryTop] or "", carry[carryTop])
    carry[carryTop + 1] = st
    carryTop = carryTop + 1
  end
end

local function tokensFor(i)
  if not lua then return { { buffer[i] or "", P.FG } } end
  ensureCarry(i - 1)
  return (tokenize(buffer[i] or "", carry[i]))
end

local function markDirty(i) dirty[i] = true end

------------------------------------------------------------------ выделение

--- Границы выделения, упорядоченные: строка1, символ1, строка2, символ2.
local function selection()
  if not anchor then return nil end
  local l1, c1, l2, c2 = anchor[2], anchor[1], cy, cx
  if l1 > l2 or (l1 == l2 and c1 > c2) then
    l1, c1, l2, c2 = l2, c2, l1, c1
  end
  if l1 == l2 and c1 == c2 then return nil end
  return l1, c1, l2, c2
end

--- Что выделено, строками (первая и последняя могут быть кусками).
local function selectedText()
  local l1, c1, l2, c2 = selection()
  if not l1 then return nil end
  if l1 == l2 then
    return { unicode.sub(buffer[l1], c1, c2 - 1) }
  end
  local out = { unicode.sub(buffer[l1], c1) }
  for i = l1 + 1, l2 - 1 do out[#out + 1] = buffer[i] end
  out[#out + 1] = unicode.sub(buffer[l2], 1, c2 - 1)
  return out
end

local function dropSelection()
  if anchor then
    fullRedraw = true
    anchor = nil
  end
end

------------------------------------------------------------------ отмена

local undoStack, redoStack = {}, {}
local pending = nil
local UNDO_MAX = 120
local undoSeq = 0

--- Шаг отмены, на котором стоит файл: по нему видно, совпадает ли с диском.
local function topId()
  local e = undoStack[#undoStack]
  return e and e.id or 0
end

--- Строки [at, last] заменили n новыми: точки останова и свёрнутое
--- едут вместе с текстом. Таблицы правим на месте - на них смотрит отладчик.
local function shiftMarks(at, count, n)
  local last, d = at + count - 1, n - count
  local keep = {}
  for l in pairs(bps) do
    if l < at then keep[#keep + 1] = l
    elseif l > last then keep[#keep + 1] = l + d
    elseif l - at < n then keep[#keep + 1] = l end
  end
  for l in pairs(bps) do bps[l] = nil end
  for _, l in ipairs(keep) do bps[l] = true end
  local fk = {}
  for s0, e0 in pairs(folds) do
    if last < s0 then fk[s0 + d] = e0 + d
    elseif at > e0 then fk[s0] = e0
    elseif at == s0 and last == s0 and n > 0 then fk[s0] = e0 + d end
  end
  for k in pairs(folds) do folds[k] = nil end
  for k, v in pairs(fk) do if v > k then folds[k] = v end end
end

--- Заменить строки [at, at+count-1] на new.
local function apply(at, count, new)
  shiftMarks(at, count, #new)
  local tail = {}
  for i = at + count, #buffer do tail[#tail + 1] = buffer[i] end
  for i = #buffer, at, -1 do buffer[i] = nil end
  for i = 1, #new do buffer[at + i - 1] = new[i] end
  for i = 1, #tail do buffer[at + #new + i - 1] = tail[i] end
  if #buffer == 0 then buffer[1] = "" end
end

local function commit() pending = nil end

local function setCursor(nx, ny)
  cy = math.max(1, math.min(#buffer, math.floor(ny)))
  cx = math.max(1, math.min(unicode.len(buffer[cy] or "") + 1, math.floor(nx)))
end

--- Правка с записью в историю. kind склеивает подряд идущие правки одной
--- строки в один шаг отмены: набранное слово откатывается целиком.
local function splice(at, count, new, kind)
  local old = {}
  for i = at, at + count - 1 do old[#old + 1] = buffer[i] or "" end
  local merge = pending and kind and pending.kind == kind and pending.at == at
    and #pending.new == 1 and count == 1 and #new == 1
  if merge then
    pending.new = new
  else
    undoSeq = undoSeq + 1
    pending = { at = at, old = old, new = new, kind = kind, cx = cx, cy = cy, id = undoSeq }
    undoStack[#undoStack + 1] = pending
    if #undoStack > UNDO_MAX then table.remove(undoStack, 1) end
    redoStack = {}
  end
  apply(at, count, new)
  rev = rev + 1
  modified = topId() ~= savedId
  checkDue = computer.uptime() + 0.5
  if runErr then runErr = nil fullRedraw = true end
  status = nil
  if match then markDirty(match.line) match = nil end
  invalidate(at)
  if count ~= #new then fullRedraw = true else markDirty(at) end
end

local function undoStep(from, to)
  local entry = table.remove(from)
  if not entry then
    status = "нечего отменять"
    return
  end
  -- шаг наружу: то, что было, становится тем, что стало
  apply(entry.at, #entry.new, entry.old)
  entry.old, entry.new = entry.new, entry.old
  local wasX, wasY = entry.cx, entry.cy
  entry.cx, entry.cy = cx, cy
  to[#to + 1] = entry
  commit()
  anchor = nil
  setCursor(wasX, wasY)
  invalidate(entry.at)
  rev = rev + 1
  modified = topId() ~= savedId
  checkDue = computer.uptime() + 0.5
  fullRedraw = true
end

------------------------------------------------------------------ рисование

-- Каждая клетка за кадр пишется один раз. Раньше строка сперва заливалась
-- пустотой, а потом поверх ложился текст, подсказка и курсор; когда кадр
-- уходит на экран повтором журнала, между заливкой и текстом бывает
-- видна пустая строка - подсказка и список вариантов моргали. Теперь строка
-- идёт слева направо кусками, а хвост добивается пробелами.

-- Прямоугольники, которые занимает список вариантов и справка к нему:
-- текст их обходит, чтобы не рисоваться под ними.
local holes = {}

--- Положить кусок на экран с колонки sx, обойдя дыры.
local function put(sx, y, s, fg, bg)
  if s == "" then return end
  local w = unicode.wlen(s)
  for _, r in ipairs(holes) do
    if y >= r.y1 and y <= r.y2 and sx <= r.x2 and sx + w - 1 >= r.x1 then
      if sx < r.x1 then put(sx, y, fit(s, r.x1 - sx), fg, bg) end
      if sx + w - 1 > r.x2 then put(r.x2 + 1, y, removePrefix(s, r.x2 - sx + 1), fg, bg) end
      return
    end
  end
  S:set(sx, y, s, fg, bg)
end

local findText = ""               -- что искали; ниже - поиск
local findAt                      -- (строка, с байта) -> начало, конец совпадения

--- Где в строке все совпадения с искомым: пары символов { с, до }.
local function matchesIn(line)
  local out, from = {}, 1
  while findAt and #out < 40 do
    local a, b = findAt(line, from)
    if not a or b < a then break end
    out[#out + 1] = { unicode.len(line:sub(1, a - 1)) + 1, unicode.len(line:sub(1, b)) + 1 }
    from = b + 1
  end
  return out
end

local function drawRow(i)
  local y = rowOf[i]
  if not y then return end
  local line = buffer[i]
  if not line then
    put(1, y, (" "):rep(W), P.FG, P.BG)
    return
  end

  local n = tostring(i)
  local dg = diag[i]
  local gfg, gbg = P.GUT, P.BG
  if (dg and dg.err) or (runErr and runErr.l == i) or lineProblem(i) then gfg = P.ERR
  elseif dg and dg.warn then gfg = P.WARN
  elseif i == cy then gfg = P.GUT_CUR end
  if bps[i] then gfg, gbg = 0xFFFFFF, P.BP_BG end
  if dbgLine == i then gfg, gbg = 0x000000, P.WARN end
  put(1, y, (" "):rep(GW - 1 - #n) .. n .. " ", gfg, gbg)
  local rowBg = dbgLine == i and P.DBG_BG or P.BG

  -- где у строки меняется оформление: выделение, найденное, пара, курсор
  local cuts = {}
  local sl1, sc1, sl2, sc2 = selection()
  local from, to
  if sl1 and i >= sl1 and i <= sl2 then
    from = (i == sl1) and sc1 or 1
    to = (i == sl2) and sc2 or math.huge
    cuts[#cuts + 1], cuts[#cuts + 2] = from, to
  end
  local mf, mt
  if match and match.line == i then
    mf, mt = match.from, match.from + match.len
    cuts[#cuts + 1], cuts[#cuts + 2] = mf, mt
  end
  -- пока найденное на экране, видны и остальные совпадения
  local all = match and matchesIn(line) or {}
  for _, m in ipairs(all) do cuts[#cuts + 1], cuts[#cuts + 2] = m[1], m[2] end
  -- подозрительные имена - своим цветом прямо в тексте
  local marks = {}
  if dg and dg.marks then
    for _, m in ipairs(dg.marks) do
      local a = unicode.len(line:sub(1, m[1] - 1)) + 1
      local b = a + unicode.len(line:sub(m[1], m[1] + m[2] - 1))
      marks[#marks + 1] = { a, b }
      cuts[#cuts + 1], cuts[#cuts + 2] = a, b
    end
  end
  local pairAt = {}
  if pair then
    for _, p in ipairs(pair) do
      if p[2] == i then
        pairAt[p[1]] = true
        cuts[#cuts + 1], cuts[#cuts + 2] = p[1], p[1] + 1
      end
    end
  end
  local cur = (i == cy) and cx or nil
  if cur then cuts[#cuts + 1], cuts[#cuts + 2] = cx, cx + 1 end
  table.sort(cuts)

  local function style(pos, fg)
    if pos == cur then return P.BG, readonly and 0x88AAFF or P.CUR end
    if pairAt[pos] then return 0xFFFFFF, P.PAIR end
    if mf and pos >= mf and pos < mt then return P.BG, P.FIND end
    for _, m in ipairs(marks) do
      if pos >= m[1] and pos < m[2] then fg = dg.err and P.ERR or P.WARN end
    end
    if from and pos >= from and pos < to then return fg, P.SEL end
    for _, m in ipairs(all) do
      if pos >= m[1] and pos < m[2] then return fg, P.FIND_ALL end
    end
    return fg, rowBg
  end

  local TW, col, drawnTo = textW(), 1, GW
  local function emit(s, fg, bg)
    local wl = unicode.wlen(s)
    if col + wl - 1 > scrollX and col <= scrollX + TW then
      local x = col - scrollX
      if x < 1 then
        s = removePrefix(s, scrollX - col + 1)
        x = 1
      end
      s = fit(s, TW - x + 1)
      if s ~= "" then
        put(GW + x, y, s, fg, bg)
        drawnTo = GW + x + unicode.wlen(s) - 1
      end
    end
    col = col + wl
  end

  local at, ci = 1, 1
  for _, t in ipairs(tokensFor(i)) do
    local rest, color = t[1], t[2]
    local pos = at
    while rest ~= "" do
      while cuts[ci] and cuts[ci] <= pos do ci = ci + 1 end
      local k = cuts[ci] and (cuts[ci] - pos) or math.huge
      local part = rest
      if k < unicode.len(rest) then
        part = unicode.sub(rest, 1, k)
        rest = unicode.sub(rest, k + 1)
      else
        rest = ""
      end
      local fg, bg = style(pos, color)
      if part == "\t" and pos == cur then part = " " end
      emit(part, fg, bg)
      pos = pos + unicode.len(part)
    end
    at = pos
  end

  -- в конце строки курсор садится на первую букву серой подсказки
  if cur and cx > unicode.len(line) then
    local g = ghost and ghost.text or ""
    local first = unicode.sub(g, 1, 1)
    emit(first ~= "" and first or " ", style(cx, P.FG))
    if unicode.len(g) > 1 then emit(unicode.sub(g, 2), P.GUT, P.BG) end
  end
  if folds[i] then emit(" ... ещё " .. (folds[i] - i) .. " стр.", P.GUT, rowBg) end

  if drawnTo < W then put(drawnTo + 1, y, (" "):rep(W - drawnTo), P.FG, rowBg) end
end

-- Подсказки короткие: "^S сохранить". Ctrl обозначаем крышкой, как принято
-- в терминальных редакторах, - иначе строка не влезает даже на 80 колонок.
local function helpText()
  local out = {}
  local function pretty(label, command)
    local kb = type(config.keybinds) == "table" and config.keybinds[command]
    if type(kb) ~= "table" or type(kb[1]) ~= "table" then return end
    local alt, control, shift, key
    for _, v in ipairs(kb[1]) do
      if v == "alt" then alt = true
      elseif v == "control" then control = true
      elseif v == "shift" then shift = true
      else key = v end
    end
    if not key then return end
    out[#out + 1] = (control and "^" or alt and "M-" or shift and "S-" or "") ..
      unicode.upper(key) .. " " .. label
  end
  pretty("сохранить", "save")
  pretty("выход", "close")
  pretty("запуск", "run")
  pretty("оболочка", "shell")
  pretty("отладка", "debug")
  pretty("поиск", "find")
  pretty("клавиши", "help")
  return table.concat(out, "  ")
end

local HELP = helpText()

--- Служебная строка кусками слева направо, без заливки под ними.
local function bar(parts)
  local x = 1
  for _, p in ipairs(parts) do
    local s = p[1]
    if s ~= "" and x <= W then
      s = fit(s, W - x + 1)
      S:set(x, H, s, p[2], p[3] or P.BAR_BG)
      x = x + unicode.wlen(s)
    end
  end
  if x <= W then S:set(x, H, (" "):rep(W - x + 1), P.BAR_FG, P.BAR_BG) end
end

local docs, docIndex = {}, 1      -- открытые файлы; текущий - в переменных выше

--- Сообщение проверки для строки: ошибка важнее предупреждения.
local function diagText(i)
  if runErr and runErr.l == i then return runErr.msg, P.ERR end
  local d = diag[i]
  if d and d.err then return d.err, P.ERR end
  local miss = lineProblem(i)
  if miss then return "не заполнено: " .. table.concat(miss, "; "), P.ERR end
  if d and d.warn then return d.warn, P.WARN end
end

local function drawStatus()
  local right = string.format("%d,%d", cy, cx)
  local ne, nw = 0, 0
  for _, d in pairs(diag) do
    if d.err then ne = ne + 1 elseif d.warn then nw = nw + 1 end
  end
  if runErr then ne = ne + 1 end
  if ne + nw > 0 then
    right = (ne > 0 and (ne .. " ош ") or "") .. (nw > 0 and (nw .. " пред ") or "") .. " " .. right
  end
  local l1, _, l2 = selection()
  if l1 then
    right = string.format("выд %d  %s", l2 - l1 + 1, right)
  elseif #clip > 0 then
    right = string.format("#%d  %s", #clip, right)
  end
  right = right .. " "
  local rw = unicode.wlen(right)

  local name = fs.name(filename) .. (#docs > 1 and string.format(" [%d/%d]", docIndex, #docs) or "")
  name = fit(name, math.max(1, W - rw - 4))
  local mark = readonly and " [чтение]" or modified and " *" or ""
  local mid
  if status then
    mid = { { status, P.BAR_MSG } }
  elseif sigHelp then
    mid = sigHelp
  elseif ghost then
    mid = { { "Tab → " .. ghost.word .. (ghost.more > 0 and ("   ещё " .. ghost.more) or ""), P.BAR_POS } }
  else
    local text, colour = diagText(cy)
    mid = text and { { text, colour } } or { { HELP, P.BAR_FG } }
  end
  local at = 1 + unicode.wlen(name) + unicode.wlen(mark)
  local room = W - rw - at - 2
  local parts = { { " ", P.BAR_FG }, { name, P.BAR_NAME }, { mark, P.BAR_MARK } }
  if room > 0 then
    parts[#parts + 1] = { "  ", P.BAR_FG }
    for _, m in ipairs(mid) do
      if room <= 0 then break end
      local piece = fit(m[1], room)
      parts[#parts + 1] = { piece, m[2] }
      room = room - unicode.wlen(piece)
    end
    parts[#parts + 1] = { (" "):rep(math.max(0, room)), P.BAR_FG }
  else
    parts[#parts + 1] = { (" "):rep(math.max(0, W - rw - at)), P.BAR_FG }
  end
  parts[#parts + 1] = { right, P.BAR_POS }
  bar(parts)
end

local lastCursorRow

local function syncGutter()
  local w = #tostring(math.max(#buffer, 1)) + 1
  if w ~= GW then
    GW = w
    fullRedraw = true
  end
end

--- Парная скобка к той, что под курсором.
local OPEN = { ["("] = ")", ["["] = "]", ["{"] = "}" }
local CLOSE = { [")"] = "(", ["]"] = "[", ["}"] = "{" }

local function findPair()
  local had = pair
  pair = nil
  local ch = unicode.sub(curLine(), cx, cx)
  local dir, want
  if OPEN[ch] then dir, want = 1, OPEN[ch]
  elseif CLOSE[ch] then dir, want = -1, CLOSE[ch]
  else
    if had then fullRedraw = true end
    return
  end
  local depth, i, j = 0, cy, cx
  while buffer[i] do
    local line = buffer[i]
    while j >= 1 and j <= unicode.len(line) do
      local c = unicode.sub(line, j, j)
      if c == ch then depth = depth + 1
      elseif c == want then
        depth = depth - 1
        if depth == 0 then
          pair = { { cx, cy }, { j, i } }
          fullRedraw = true
          return
        end
      end
      j = j + dir
    end
    i = i + dir
    if math.abs(i - cy) > 400 then break end
    j = dir > 0 and 1 or unicode.len(buffer[i] or "")
  end
  if had then fullRedraw = true end
end

--- Первая строка свёртки, которая прячет строку i.
local function hiddenBy(i)
  for s0, e0 in pairs(folds) do
    if i > s0 and i <= e0 then return s0 end
  end
end

--- Ближайшая видимая строка от i в сторону dir; nil - дальше некуда.
local function stepLine(i, dir)
  i = i + dir
  while i >= 1 and i <= #buffer do
    local s0 = hiddenBy(i)
    if not s0 then return i end
    i = dir > 0 and folds[s0] + 1 or s0
  end
end

--- На n видимых строк от i, сколько получится.
local function stepLines(i, n)
  local dir = n < 0 and -1 or 1
  for _ = 1, math.abs(n) do i = stepLine(i, dir) or i end
  return i
end

local function clampScroll()
  local before = scrollX .. ":" .. scrollY
  -- курсор попал в свёрнутое (переход к строке, поиск) - раскрываем
  local s0 = hiddenBy(cy)
  while s0 do
    folds[s0] = nil
    fullRedraw = true
    s0 = hiddenBy(cy)
  end
  if cy <= scrollY then scrollY = cy - 1 end
  local top = scrollY + 1
  if hiddenBy(top) then top = hiddenBy(top) end
  -- курсор ниже экрана: ставим его на нижнюю строку
  local i, n = cy, 1
  while i > top and n <= rows do
    i = stepLine(i, -1) or top
    n = n + 1
  end
  if n > rows then top = stepLines(cy, -(rows - 1)) end
  scrollY = math.max(0, top - 1)
  local col, TW = dispCol(curLine(), cx), textW()
  if col - scrollX < 1 then scrollX = col - 1 end
  if col - scrollX > TW then scrollX = col - TW end
  if scrollX < 0 then scrollX = 0 end
  if before ~= (scrollX .. ":" .. scrollY) then fullRedraw = true end
  -- что где на экране; за концом файла - несуществующие строки, пустые
  view, rowOf = {}, {}
  i = scrollY + 1
  for y = 1, rows do
    view[y], rowOf[i] = i, y
    i = i < #buffer and (stepLine(i, 1) or #buffer + 1) or i + 1
  end
end

local popupDraw = nil     -- рисует список вариантов поверх кадра

local function redraw()
  syncGutter()
  clampScroll()
  if fullRedraw or anchor then
    for y = 1, rows do drawRow(view[y]) end
    fullRedraw = false
    dirty = {}
  else
    if lastCursorRow then dirty[lastCursorRow] = true end
    dirty[cy] = true
    for i in pairs(dirty) do drawRow(i) end
    dirty = {}
  end
  lastCursorRow = cy
  drawStatus()
  if popupDraw then popupDraw() end
  S:present()
end

------------------------------------------------------------------ движение

local function move(nx, ny, keep)
  if not keep then dropSelection() end
  setCursor(nx, ny)
  if anchor then fullRedraw = true end
  commit()
end

local function home(keep) move(1, cy, keep) end
local function ende(keep) move(unicode.len(curLine()) + 1, cy, keep) end

local function left(keep)
  if cx > 1 then
    move(cx - 1, cy, keep)
    return true
  elseif stepLine(cy, -1) then
    move(math.huge, stepLine(cy, -1), keep)
    return true
  end
end

local function right(keep)
  if cx <= unicode.len(curLine()) then move(cx + 1, cy, keep)
  elseif stepLine(cy, 1) then move(1, stepLine(cy, 1), keep) end
end

------------------------------------------------------------------ правка

local function deleteSelection()
  local l1, c1, l2, c2 = selection()
  if not l1 then return false end
  local head = unicode.sub(buffer[l1], 1, c1 - 1)
  local tail = unicode.sub(buffer[l2], c2)
  anchor = nil
  cx, cy = c1, l1
  splice(l1, l2 - l1 + 1, { head .. tail })
  setCursor(c1, l1)
  fullRedraw = true
  return true
end

local function insert(value, kind)
  if not value or value == "" then return end
  deleteSelection()
  local line = curLine()
  splice(cy, 1, { unicode.sub(line, 1, cx - 1) .. value .. unicode.sub(line, cx) }, kind or "type")
  setCursor(cx + unicode.len(value), cy)
end

--- Отступ новой строки: как у текущей, плюс уровень после открытия блока.
local function indentFor(head)
  local ws = head:match("^[ \t]*") or ""
  local body = head:gsub("%-%-[^%[].*$", ""):gsub("%s+$", "")
  if body:match("[%({]$") or body:match("[%w_%)\"']%s*then$") or body:sub(-4) == "then"
     or body:sub(-2) == "do" or body:sub(-4) == "else" or body:sub(-6) == "repeat" then
    ws = ws .. "  "
  end
  return ws
end

local function enter()
  deleteSelection()
  local line = curLine()
  local head = unicode.sub(line, 1, cx - 1)
  local tail = unicode.sub(line, cx)
  local ws = lua and indentFor(head) or (head:match("^[ \t]*") or "")
  splice(cy, 1, { head, ws .. tail })
  setCursor(unicode.len(ws) + 1, cy + 1)
  commit()
end

local function delete(fullLine)
  if deleteSelection() then return end
  if fullLine then
    if #buffer > 1 then splice(cy, 1, {}) else splice(1, 1, { "" }) end
    setCursor(1, cy)
    return
  end
  local line = curLine()
  if cx <= unicode.len(line) then
    splice(cy, 1, { unicode.sub(line, 1, cx - 1) .. unicode.sub(line, cx + 1) }, "erase")
  elseif cy < #buffer then
    splice(cy, 2, { line .. buffer[cy + 1] })
  end
end

------------------------------------------------------------------ строка снизу

--- Прочитать строку в служебной строке экрана. Возвращает nil при отмене.
--- init - что уже набрано; complete(buf) -> buf - что делать по Tab.
local function readLine(label, init, complete)
  local buf = init or ""
  while true do
    local room = W - unicode.wlen(label) - 3
    local shown = buf
    while room > 0 and unicode.wlen(shown) > room do shown = unicode.sub(shown, 2) end
    bar({ { " ", P.BAR_FG }, { label, P.BAR_MARK }, { shown, P.BAR_NAME }, { " ", P.BAR_BG, P.BAR_POS } })
    S:present()
    local e, addr, char, code = event.pull()
    if e == "key_down" and addr == term.keyboard() then
      if code == keys.enter or code == keys.numpadenter then
        status = nil
        return buf
      elseif code == 1 then
        status = nil
        return nil
      elseif code == keys.back then
        -- Esc забирает себе Minecraft, так что выйти можно Backspace'ом
        if buf == "" then
          status = nil
          return nil
        end
        buf = unicode.sub(buf, 1, -2)
      elseif code == keys.tab and complete then
        buf = complete(buf) or buf
      elseif char and not keyboard.isControl(char) then
        buf = buf .. unicode.char(char)
      end
    elseif e == "clipboard" then
      buf = buf .. tostring(char):gsub("\n.*", "")
    end
  end
end

--- Вопрос в служебной строке; ответ - одна из букв letters или nil
--- (C и Backspace). Esc до машины не доходит - Minecraft закрывает им окно
--- экрана, - поэтому отмена на C.
local function choice(question, letters)
  bar({ { " ", P.BAR_FG }, { question, P.BAR_MARK } })
  S:present()
  while true do
    local e, addr, char, code = event.pull()
    if e == "key_down" and addr == term.keyboard() then
      for l in letters:gmatch(".") do
        if code == keys[l] or char == l:byte() then return l end
      end
      if code == keys.c or code == keys.back or code == 1 then return nil end
    end
  end
end

--- Да, нет или отмена.
local function ask(question)
  local a = choice(question, "yn")
  if a then return a == "y" end
end

------------------------------------------------------------------ поиск

local find, replace
do
-- Регистр не важен, пока в запросе нет заглавных. Запрос с "/" в начале -
-- шаблон Lua: "/^local", "/%f[%w_]x%f[^%w_]" - слово целиком.
local findPat

local function setFind(q)
  findText, findPat = q, q:match("^/(.+)$")
  if findPat then
    if not pcall(string.find, "", findPat) then
      findAt = nil
      status = "плохой шаблон: " .. findPat
      return false
    end
    findAt = function(line, from) return line:find(findPat, from) end
  elseif unicode.lower(q) ~= q then
    findAt = function(line, from) return line:find(q, from, true) end
  else
    findAt = function(line, from) return unicode.lower(line):find(q, from, true) end
  end
  return true
end

local function showMatch(i, a, b)
  setCursor(unicode.len(buffer[i]:sub(1, a - 1)) + 1, i)
  match = { line = i, from = cx, len = unicode.len(buffer[i]:sub(a, b)) }
  fullRedraw = true
end

--- Следующее совпадение от символа bx строки by (назад - до него), по кругу.
local function searchFrom(bx, by, back)
  if not findAt then return end
  local n = #buffer
  for step = 0, n do
    local i = back and ((by - 1 - step) % n + 1) or ((by - 1 + step) % n + 1)
    local line = buffer[i]
    -- find работает по байтам, а курсор считает символы
    local limit = #unicode.sub(line, 1, bx - 1)
    local from, best = (not back and step == 0) and limit + 1 or 1, nil
    while true do
      local a, b = findAt(line, from)
      if not a or b < a then break end
      if not back then
        showMatch(i, a, b)
        return true
      end
      if step == 0 and a > limit then break end
      best = { a, b }
      from = a + 1
    end
    if best then
      showMatch(i, best[1], best[2])
      return true
    end
  end
  status = "не найдено: " .. findText
end

function find(again, back)
  if match then
    markDirty(match.line)
    match = nil
    fullRedraw = true
  end
  if again and findText ~= "" then
    if back then searchFrom(cx, cy, true) else searchFrom(cx + 1, cy) end
    return
  end
  local q = readLine("Поиск: ")
  if q and q ~= "" and setFind(q) then searchFrom(cx, cy) end
end

--- Чем заменить найденный кусок: у шаблона работают %1 и прочее.
local function replacement(piece, rep)
  if findPat then return (piece:gsub(findPat, rep, 1)) end
  return rep
end

--- Заменить всё в файле одной правкой; вернуть, сколько раз.
local function replaceAll(rep)
  local first, last, count, new = nil, nil, 0, {}
  for i, line in ipairs(buffer) do
    local out, from = {}, 1
    while true do
      local a, b = findAt(line, from)
      if not a or b < a then break end
      out[#out + 1] = line:sub(from, a - 1)
      out[#out + 1] = replacement(line:sub(a, b), rep)
      from = b + 1
      count = count + 1
    end
    if from > 1 then
      out[#out + 1] = line:sub(from)
      new[i] = table.concat(out)
      first, last = first or i, i
    end
  end
  if count > 0 then
    local lines = {}
    for i = first, last do lines[#lines + 1] = new[i] or buffer[i] end
    splice(first, last - first + 1, lines)
    commit()
  end
  return count
end

--- Ctrl+H: найти и заменить, на каждое совпадение - вопрос.
function replace()
  if readonly then return end
  local q = readLine("Заменить: ")
  if not q or q == "" or not setFind(q) then return end
  local rep = readLine("Заменить \"" .. q .. "\" на: ")
  if not rep then return end
  local count, startY, startX, wrapped = 0, cy, cx, false
  local lastY, lastX = cy, cx
  searchFrom(cx, cy)
  while match do
    -- обошли файл по кругу и вернулись к началу - хватит
    if match.line < lastY or (match.line == lastY and match.from < lastX) then wrapped = true end
    if wrapped and (match.line > startY or (match.line == startY and match.from >= startX)) then break end
    lastY, lastX = match.line, match.from
    redraw()
    local answer = choice("Заменить? Y - да, N - дальше, A - все в файле, C - хватит", "yna")
    local i = match.line
    if answer == "a" then
      match = nil
      count = count + replaceAll(rep)
      break
    elseif answer == "y" then
      local line = buffer[i]
      local at = #unicode.sub(line, 1, match.from - 1) + 1
      local a, b = findAt(line, at)
      if a ~= at then break end
      local piece = replacement(line:sub(a, b), rep)
      match = nil
      splice(i, 1, { line:sub(1, a - 1) .. piece .. line:sub(b + 1) })
      commit()
      count = count + 1
      setCursor(unicode.len(line:sub(1, a - 1) .. piece) + 1, i)
      if i == startY and a < #unicode.sub(line, 1, startX - 1) then
        startX = startX + unicode.len(piece) - unicode.len(line:sub(a, b))
      end
      lastX = cx
      if not searchFrom(cx, cy) then break end
    elseif answer == "n" then
      if not searchFrom(match.from + 1, i) then break end
    else
      break
    end
  end
  if match then markDirty(match.line) match = nil end
  fullRedraw = true
  status = "заменено: " .. count
end
end

------------------------------------------------------------------ дополнение

local chainBefore, aliases, updateGhost, updateSig, complete, autoPopup, wrapInto, pad, splitChain, resolve, popup, forgetCaches
-- Событие, которое список закрыл собой (ниже, у popup).
local replay = nil
do

--- Слово или цепочка a.b.c перед курсором.
function chainBefore()
  local upto = unicode.sub(curLine(), 1, cx - 1)
  return upto:match("[%a_][%w_%.:]*$")
end

--- Локальные имена файла, за которыми стоит что-то живое:
---   local gpu = component.gpu            -> { "component", "gpu" }
---   local c = require("component")       -> { "component" }
---   local g = component.proxy(component.list("gpu")())  -> { "component", "gpu" }
--- Без этого подсказки и справка работали бы только с полным путём.
local aliasCache, aliasRev, aliasAt, aliasSig = nil, -1, -2, ""

-- Разбор вызовов в строке дорогой (подсветка, поиск по таблицам), а
-- рисуется строка часто, поэтому ответ помним по её тексту. Забываем, когда
-- в файле поменялись свои имена: gpu.set могло начать что-то значить.
local problemCache = {}

function aliases()
  if aliasCache and (aliasRev == rev or computer.uptime() - aliasAt < 1) then
    return aliasCache
  end
  local map = {}
  for _, line in ipairs(buffer) do
    if line:find("local", 1, true) then
      line = line:gsub("%-%-.*$", "")
      local name, mod = line:match("local%s+([%a_][%w_]*)%s*=%s*require%s*%(?%s*[\"']([%w_%.]+)[\"']")
      if name then
        map[name] = { mod }
      else
        name, mod = line:match("local%s+([%a_][%w_]*)%s*=%s*component%.proxy%s*%(%s*component%.list%s*%(%s*[\"']([%w_]+)[\"']")
        if name then
          map[name] = { "component", mod }
        else
          local chain
          name, chain = line:match("local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_%.]*)%s*;?%s*$")
          if name and chain ~= name then
            local p = {}
            for part in chain:gmatch("[^%.]+") do p[#p + 1] = part end
            map[name] = p
          end
        end
      end
    end
  end
  local names = {}
  for k, v in pairs(map) do names[#names + 1] = k .. "=" .. table.concat(v, ".") end
  table.sort(names)
  local sig = table.concat(names, " ")
  if sig ~= aliasSig then
    aliasSig = sig
    problemCache = {}
  end
  aliasCache, aliasRev, aliasAt = map, rev, computer.uptime()
  return map
end

--- Пройти по цепочке имён от глобального окружения. Библиотеку из /lib
--- подгружаем, если её ещё не требовали, - иначе дополнять нечем.
function resolve(path, depth)
  local cur
  for i, name in ipairs(path) do
    if i == 1 then
      cur = rawget(_G, name) or package.loaded[name]
      -- своё имя файла: local gpu = component.gpu и подобное
      if cur == nil and (depth or 0) < 3 then
        local a = aliases()[name]
        if a then cur = resolve(a, (depth or 0) + 1) end
      end
      if cur == nil and fs.exists("/lib/" .. name .. ".lua") then
        local ok, libtab = pcall(require, name)
        cur = ok and libtab or nil
      end
    else
      if type(cur) ~= "table" then return nil end
      local ok, v = pcall(function() return cur[name] end)
      cur = ok and v or nil
    end
    if cur == nil then return nil end
  end
  return cur
end

local function keysOf(t, out, seen)
  pcall(function()
    for k in pairs(t) do
      if type(k) == "string" and not seen[k] then
        seen[k] = true
        out[#out + 1] = k
      end
    end
  end)
end

-- Словарь слов файла собирается не на каждую букву: перебрать тысячу строк
-- в песочнице мода быстрее, чем кажется, но не двадцать раз в секунду.
-- Список держим отсортированным - тогда подходящие под приставку лежат
-- подряд, и найти их можно двоичным поиском, не читая весь словарь.
local wordCache, wordCacheRev, wordCacheAt = nil, -1, -2
local memberCache = {}

local function wordList()
  if wordCache and (wordCacheRev == rev or computer.uptime() - wordCacheAt < 1) then
    return wordCache
  end
  local all, seen = {}, {}
  for _, line in ipairs(buffer) do
    for word in line:gmatch("[%a_][%w_]*") do
      if not seen[word] then seen[word] = true all[#all + 1] = word end
    end
  end
  for w in pairs(KEYWORD) do if not seen[w] then seen[w] = true all[#all + 1] = w end end
  for w in pairs(BUILTIN) do if not seen[w] then seen[w] = true all[#all + 1] = w end end
  keysOf(_G, all, seen)
  keysOf(package.loaded, all, seen)
  table.sort(all, function(a, b) return a:lower() < b:lower() end)
  wordCache, wordCacheRev, wordCacheAt = all, rev, computer.uptime()
  return all
end

--- Разобрать набранное на путь по таблицам и последний кусок.
function splitChain(chain)
  local path, frag = {}, chain
  local dot = chain:match("^(.*)[%.:][%w_]*$")
  if dot then
    frag = chain:match("[%.:]([%w_]*)$") or ""
    for name in dot:gmatch("[^%.:]+") do path[#path + 1] = name end
  end
  return path, frag
end

--- Отсортированный словарь, по которому ищем: поля таблицы или слова файла.
--- Всё, что под component, живёт недолго: устройство могут подключить или
--- снять, пока файл открыт, - и сундук, которого не было, должен появиться.
local function dictionary(path)
  if #path == 0 then return wordList() end
  local key = table.concat(path, ".")
  local live = path[1] == "component"
  local cached = memberCache[key]
  if cached ~= nil and computer.uptime() - cached.at < (live and 1 or 3) then
    return cached.list or nil
  end
  local t = resolve(path)
  local all, seen = {}, {}
  if type(t) == "table" then
    keysOf(t, all, seen)
    -- component.<тип>: подключённые устройства, а не только уже основные
    if live and #path == 1 then
      pcall(function()
        for _, kind in component.list() do
          if not seen[kind] then seen[kind] = true all[#all + 1] = kind end
        end
      end)
    end
    table.sort(all, function(a, b) return a:lower() < b:lower() end)
  else
    all = false
  end
  memberCache[key] = { list = all, at = computer.uptime() }
  return all or nil
end

--- Первый индекс, с которого слова не меньше приставки.
local function lowerBound(list, low)
  local a, b = 1, #list + 1
  while a < b do
    local mid = math.floor((a + b) / 2)
    if list[mid]:lower() < low then a = mid + 1 else b = mid end
  end
  return a
end

--- Что можно подставить вместо набранного куска.
local function candidates(chain)
  local path, frag = splitChain(chain)
  local list = dictionary(path)
  if not list then return nil end

  local low = frag:lower()
  local out = {}
  for i = lowerBound(list, low), #list do
    local w = list[i]
    if w:lower():sub(1, #low) ~= low then break end
    if w ~= frag then out[#out + 1] = w end
    if #out > 300 then break end
  end
  table.sort(out, function(a, b)
    if #a ~= #b then return #a < #b end
    return a < b
  end)
  return out, frag
end

--- Подсказка при наборе: что подставит Tab. Показываем только в конце
--- строки - иначе она закрыла бы настоящий текст - и не раньше двух букв:
--- на одну их сотни, подсказывать нечего. Стоит это одного вызова gpu,
--- поэтому кадр остаётся дешёвым и на каждую букву не уходит bitblt.
function updateGhost()
  local was = ghost
  ghost = nil
  repeat
    if readonly or anchor then break end
    if cx <= unicode.len(curLine()) then break end
    local chain = chainBefore()
    if not chain then break end
    local path, frag = splitChain(chain)
    if #path == 0 and unicode.len(frag) < 2 then break end
    local list = candidates(chain)
    if not list or #list == 0 then break end
    local pick = list[1]
    if unicode.len(pick) <= unicode.len(frag) then break end
    ghost = {
      word = pick,
      text = unicode.sub(pick, unicode.len(frag) + 1),
      more = #list - 1,
    }
  until true
  if was or ghost then markDirty(cy) end
end

--- Заменить набранный кусок (n символов перед курсором) на слово.
local function replaceFrag(n, word)
  if n > 0 then
    local line = curLine()
    splice(cy, 1, { unicode.sub(line, 1, cx - n - 1) .. unicode.sub(line, cx) })
    setCursor(cx - n, cy)
  end
  insert(word)
  commit()
end

-- Событие, которое список закрыл собой: его отдадут обычной обработке,
-- чтобы нажатая клавиша не пропала (набрал "(" - список закрылся, а скобка
-- встала).

local MODS = {}
for _, k in ipairs({ "lshift", "rshift", "lcontrol", "rcontrol", "lmenu", "rmenu" }) do
  if keys[k] then MODS[keys[k]] = true end
end

--- Справка к полю под рамкой списка. У методов устройств она своя
--- (component.doc: "function(x:number...):boolean -- что делает"), у
--- остального показываем, что это за значение.
local docCache = {}

local function docFor(owner, path, name)
  local key = table.concat(path, ".") .. "." .. name
  if docCache[key] ~= nil then return docCache[key] or nil end
  local doc
  pcall(function()
    local root = path[1] == "component" and #path == 1
    if type(owner) == "table" and type(rawget(owner, "address")) == "string" then
      doc = component.doc(owner.address, name)
    end
    if not doc and root then
      local addr = component.list(name, true)()
      if addr then doc = "устройство " .. name .. " -- адрес " .. addr end
    end
    if doc then return end
    local v
    if #path == 0 then
      v = rawget(_G, name)
      if v == nil then v = package.loaded[name] end
    elseif type(owner) == "table" then
      -- component.<тип> через __index сделал бы устройство основным
      if root then v = rawget(owner, name) else v = owner[name] end
    end
    local t = type(v)
    if t == "function" then
      doc = "функция"
    elseif t == "table" then
      local n = 0
      for _ in pairs(v) do n = n + 1 end
      doc = "таблица, полей " .. n
    elseif t == "string" then
      doc = "строка " .. string.format("%q", v)
    elseif t == "number" or t == "boolean" then
      doc = (t == "number" and "число " or "") .. tostring(v)
    end
  end)
  docCache[key] = doc or false
  return doc
end

--- Разложить текст по строкам ширины width (слова длиннее - режем).
function wrapInto(out, s, width, colour)
  local line = nil
  for word in s:gmatch("%S+") do
    while unicode.wlen(word) > width do
      if line then out[#out + 1] = { line, colour } line = nil end
      out[#out + 1] = { fit(word, width), colour }
      word = removePrefix(word, width)
    end
    if line and unicode.wlen(line) + 1 + unicode.wlen(word) <= width then
      line = line .. " " .. word
    else
      if line then out[#out + 1] = { line, colour } end
      line = word
    end
  end
  if line then out[#out + 1] = { line, colour } end
end

function pad(s, width)
  s = fit(s, width)
  return s .. (" "):rep(width - unicode.wlen(s))
end

------------------------------------------------------------------ сигнатуры

-- У методов устройств справка начинается с сигнатуры:
--   function(x:number, y:number, value:string[, vertical:boolean]):boolean
-- По ней видно, сколько аргументов обязательно. Пока вызов не заполнен,
-- номер строки красный, а в служебной строке - что ещё не хватает.

local sigCache = {}

--- Разобрать сигнатуру: { params = { {text, name, optional} }, ret = ":тип" }.
local function sigOf(doc)
  if sigCache[doc] ~= nil then return sigCache[doc] or nil end
  local inner, rest = doc:match("^function%((.-)%)(.*)$")
  local sig = false
  if inner then
    local ret = (rest:match("^(.-)%s*%-%-") or rest):gsub("%s+$", "")
    sig = { params = {}, ret = ret }
    local depth, cur, optional = 0, "", false
    local function push()
      local t = cur:gsub("^%s+", ""):gsub("%s+$", "")
      if t ~= "" then
        sig.params[#sig.params + 1] = {
          text = t, name = t:match("^[^:]+"),
          optional = optional or t:sub(1, 3) == "...",
        }
      end
      cur, optional = "", false
    end
    for ch in inner:gmatch(".") do
      if ch == "[" then depth = depth + 1
      elseif ch == "]" then depth = depth - 1
      elseif ch == "," then push()
      else
        if cur:find("^%s*$") and ch:find("%S") then optional = depth > 0 end
        cur = cur .. ch
      end
    end
    push()
  end
  sigCache[doc] = sig
  return sig or nil
end

--- Строка как код: строки заменены нулями, комментарии пробелами, чтобы
--- скобки и запятые внутри них не мешали считать. Длина в байтах та же.
local function codeOf(i)
  local out = {}
  for _, t in ipairs(tokensFor(i)) do
    if t[2] == P.C_STR then out[#out + 1] = ("0"):rep(#t[1])
    elseif t[2] == P.C_CMT then out[#out + 1] = (" "):rep(#t[1])
    else out[#out + 1] = t[1] end
  end
  return table.concat(out)
end

--- Вызов, открытый скобкой на байте open: чей он и какие аргументы.
local function callAt(code, open)
  local chain = code:sub(1, open - 1):match("([%a_][%w_%.]*)%s*$")
  if not chain or chain:sub(-1) == "." then return nil end
  local path = {}
  for part in chain:gmatch("[^%.]+") do path[#path + 1] = part end
  if #path < 2 then return nil end
  local name = table.remove(path)
  local owner = resolve(path)
  if type(owner) ~= "table" then return nil end
  local doc = docFor(owner, path, name)
  local sig = doc and sigOf(doc)
  if not sig then return nil end
  local args, depth, start, close = {}, 0, open + 1, nil
  for j = open + 1, #code do
    local c = code:sub(j, j)
    if c == "(" or c == "[" or c == "{" then
      depth = depth + 1
    elseif c == ")" or c == "]" or c == "}" then
      if depth == 0 then close = j break end
      depth = depth - 1
    elseif c == "," and depth == 0 then
      args[#args + 1] = { start, j - 1 }
      start = j + 1
    end
  end
  args[#args + 1] = { start, (close or #code + 1) - 1 }
  return { name = name, sig = sig, args = args, close = close, code = code }
end

local function filled(call, k)
  local a = call.args[k]
  return a and call.code:sub(a[1], a[2]):find("%S") ~= nil
end

--- Обязательные параметры, для которых аргумента нет.
local function missingOf(call)
  local out = {}
  for k, p in ipairs(call.sig.params) do
    if not p.optional and not filled(call, k) then out[#out + 1] = p.name end
  end
  return out
end

lineProblem = function(i)
  local line = buffer[i]
  if not lua or not line or not line:find("(", 1, true) then return nil end
  local known = problemCache[line]
  if known ~= nil then return known or nil end
  local code = codeOf(i)
  local miss
  for open in code:gmatch("()%(") do
    local call = callAt(code, open)
    -- незакрытый вызов может продолжаться на следующих строках
    if call and call.close then
      local m = missingOf(call)
      if #m > 0 then
        miss = miss or {}
        miss[#miss + 1] = call.name .. ": " .. table.concat(m, ", ")
      end
    end
  end
  problemCache[line] = miss or false
  return miss
end

--- Ближайший вызов с сигнатурой, внутри которого стоит курсор.
local function callAround()
  if not lua then return nil end
  local code = codeOf(cy)
  local pos = #unicode.sub(curLine(), 1, cx - 1)
  local depth = 0
  for j = pos, 1, -1 do
    local c = code:sub(j, j)
    if c == ")" or c == "]" or c == "}" then
      depth = depth + 1
    elseif c == "(" or c == "[" or c == "{" then
      if depth > 0 then
        depth = depth - 1
      elseif c == "(" then
        -- tostring( внутри gpu.set( - смотрим дальше наружу
        local call = callAt(code, j)
        if call then return call, pos + 1 end
      end
    end
  end
end

--- Собрать подсказку к вызову под курсором: текущий параметр выделен,
--- незаполненные обязательные - красным, и отдельно что не хватает.
function updateSig()
  sigHelp = nil
  local call, at = callAround()
  if not call then return end
  local k = #call.args
  for i, a in ipairs(call.args) do
    if at <= a[2] + 1 then k = i break end
  end
  local out = { { call.name .. "(", P.BAR_NAME } }
  for i, p in ipairs(call.sig.params) do
    if i > 1 then out[#out + 1] = { ", ", P.BAR_FG } end
    local colour = P.BAR_FG
    if i == k then colour = P.BAR_MARK
    elseif not p.optional and not filled(call, i) then colour = P.ERR end
    out[#out + 1] = { p.optional and ("[" .. p.text .. "]") or p.text, colour }
  end
  out[#out + 1] = { ")" .. call.sig.ret, P.BAR_NAME }
  local miss = missingOf(call)
  if #miss > 0 then
    out[#out + 1] = { "   не хватает: " .. table.concat(miss, ", "), P.ERR }
  end
  sigHelp = out
end

--- Список вариантов у курсора: поля таблицы после точки или слова.
--- Буквы идут прямо в текст и сужают список, стрелки выбирают, Enter и
--- Tab подставляют. Любая другая клавиша закрывает список и срабатывает
--- как обычно, так что печатать дальше он не мешает. Рядом со списком -
--- справка к выбранному.
function popup(path)
  local list = dictionary(path)
  if not list or #list == 0 then return false end
  local key = table.concat(path, ".")
  local owner = #path > 0 and resolve(path) or nil
  local sel, top = 1, 1
  ghost = nil
  local function close()
    popupDraw = nil
    holes = {}
    status = nil
    fullRedraw = true
  end
  while true do
    local chain = chainBefore() or ""
    local p, frag = splitChain(chain)
    if chain == "" then p, frag = {}, "" end
    if table.concat(p, ".") ~= key then return close() end
    local low = frag:lower()
    local shown = {}
    for i = lowerBound(list, low), #list do
      local w = list[i]
      if w:lower():sub(1, #low) ~= low then break end
      shown[#shown + 1] = w
    end
    if #shown == 0 then return close() end
    if sel > #shown then sel = #shown end
    local h = math.min(10, #shown, rows - 1)
    if sel < top then top = sel end
    if sel > top + h - 1 then top = sel - h + 1 end

    -- рамка списка: под курсором, а если внизу тесно - над ним
    local width = 0
    for i = 1, #shown do width = math.max(width, unicode.wlen(shown[i])) end
    width = math.min(width + 3, W - 4)
    local x = GW + dispCol(curLine(), cx - unicode.len(frag)) - scrollX
    x = math.max(1, math.min(x, W - width))
    local below = cy - scrollY + h <= rows
    local y = below and (cy - scrollY + 1) or math.max(1, cy - scrollY - h)

    -- справка: справа от списка, если не влезает - слева, иначе внизу
    local doc = docFor(owner, path, shown[sel])
    local dlines, dx, dw = {}, nil, nil
    if doc then
      local space = W - (x + width)
      if space >= 24 then
        dx, dw = x + width, math.min(52, space)
      elseif x - 1 >= 24 then
        dw = math.min(52, x - 1)
        dx = x - dw
      end
      if dx then
        local sig, desc = doc:match("^(.-)%s*%-%-%s*(.*)$")
        wrapInto(dlines, sig or doc, dw - 2, P.BAR_POS)
        if desc and desc ~= "" then wrapInto(dlines, desc, dw - 2, P.POP_FG) end
      end
    end
    local dh = math.min(#dlines, math.max(h, 6), rows - 1)
    local dy = below and y or (y + h - dh)
    if below and dy + dh - 1 > rows then dy = rows - dh + 1 end
    if dy < 1 then dy = 1 end

    -- куда список лёг в прошлый раз и куда ляжет сейчас: эти строки текста
    -- рисуем заново, остальные не трогаем
    for _, r in ipairs(holes) do
      for row = r.y1, r.y2 do markDirty(row + scrollY) end
    end
    holes = { { x1 = x, y1 = y, x2 = x + width - 1, y2 = y + h - 1 } }
    if dh > 0 then holes[2] = { x1 = dx, y1 = dy, x2 = dx + dw - 1, y2 = dy + dh - 1 } end
    for _, r in ipairs(holes) do
      for row = r.y1, r.y2 do markDirty(row + scrollY) end
    end

    popupDraw = function()
      for i = 0, h - 1 do
        local mark = (i == 0 and top > 1) and "^" or (i == h - 1 and top + h - 1 < #shown) and "v" or " "
        S:set(x, y + i, " " .. pad(shown[top + i], width - 2) .. mark, P.POP_FG,
          (top + i == sel) and P.POP_SEL or P.POP_BG)
      end
      for i = 1, dh do
        local l = dlines[i]
        S:set(dx, dy + i - 1, " " .. pad(l[1], dw - 1), l[2], P.BAR_BG)
      end
    end
    status = string.format("%s%s: %d из %d   Enter - вставить", key, key ~= "" and "." or "",
      sel, #shown)
    if doc and not dx then status = doc end
    redraw()

    local ev = table.pack(event.pull())
    local e, addr, char, code = ev[1], ev[2], ev[3], ev[4]
    if e == "key_down" and addr == term.keyboard() then
      if code == keys.up then
        sel = sel > 1 and sel - 1 or #shown
      elseif code == keys.down then
        sel = sel < #shown and sel + 1 or 1
      elseif code == keys.pageUp then
        sel = math.max(1, sel - h)
      elseif code == keys.pageDown then
        sel = math.min(#shown, sel + h)
      elseif code == keys.enter or code == keys.numpadenter or code == keys.tab then
        close()
        replaceFrag(unicode.len(frag), shown[sel])
        -- метод устройства: сразу скобки, курсор внутри - и видна сигнатура
        local sig = doc and doc:find("^function%(") and sigOf(doc)
        if sig and unicode.sub(curLine(), cx, cx) ~= "(" then
          insert("()")
          if #sig.params > 0 then setCursor(cx - 1, cy) end
          commit()
        end
        return true
      elseif code == keys.back and frag ~= "" then
        local line = curLine()
        splice(cy, 1, { unicode.sub(line, 1, cx - 2) .. unicode.sub(line, cx) }, "erase")
        setCursor(cx - 1, cy)
        sel, top = 1, 1
      elseif char and char > 32 and not keyboard.isControl(char) and unicode.char(char):match("[%w_]")
             and not keyboard.isControlDown(term.keyboard()) then
        insert(unicode.char(char))
        sel, top = 1, 1
      elseif not MODS[code] then
        close()
        replay = ev
        return true
      end
    elseif e ~= "key_up" and e ~= "interrupted" then
      close()
      replay = ev
      return true
    end
  end
end

--- Tab без подсказки и Ctrl+Space: вариант один - подставить, иначе список.
function complete()
  local chain = chainBefore()
  if not chain then return false end
  local list, frag = candidates(chain)
  if not list or #list == 0 then
    status = "нечем дополнить"
    return true
  end
  if #list == 1 then
    replaceFrag(unicode.len(frag), list[1])
  else
    popup((splitChain(chain)))
  end
  return true
end

--- Курсор в коде, а не в строке или комментарии: там точка - просто точка.
local function inCode()
  if not lua then return false end
  local at, pos = 1, cx - 1
  for _, t in ipairs(tokensFor(cy)) do
    local len = unicode.len(t[1])
    if pos >= at and pos < at + len then return t[2] ~= P.C_CMT and t[2] ~= P.C_STR end
    at = at + len
  end
  return true
end

--- После точки за именем живой таблицы список открывается сам:
--- component. - устройства, component.gpu. - методы видеокарты.
function autoPopup()
  local chain = chainBefore()
  if not chain or chain:sub(-1) ~= "." or chain:find("..", 1, true) or not inCode() then return end
  popup((splitChain(chain)))
end

--- Забыть всё, что помнилось про файл: он сменился или его поменяли снаружи.
function forgetCaches()
  aliasCache, wordCache = nil, nil
  memberCache, problemCache = {}, {}
end
end

------------------------------------------------------------------ отступы

local function indentSelection(back)
  local l1, _, l2 = selection()
  if not l1 then
    if back then
      local line = curLine()
      local ws = line:match("^  ") and 2 or (line:match("^ ") and 1 or 0)
      if ws > 0 then
        splice(cy, 1, { unicode.sub(line, ws + 1) })
        setCursor(math.max(1, cx - ws), cy)
      end
    else
      insert("  ")
    end
    return
  end
  local new = {}
  for i = l1, l2 do
    local line = buffer[i]
    if back then
      local ws = line:match("^  ") and 2 or (line:match("^ ") and 1 or 0)
      new[#new + 1] = unicode.sub(line, ws + 1)
    else
      new[#new + 1] = "  " .. line
    end
  end
  local keep = anchor
  splice(l1, l2 - l1 + 1, new)
  anchor = keep
  fullRedraw = true
end

------------------------------------------------------------------ файл

local function save()
  if readonly then return true end
  local new = not fs.exists(filename)
  -- файл поменяли снаружи, пока он был открыт: молча не затираем
  if not new and stamp and fs.lastModified(filename) ~= stamp then
    if not ask(fs.name(filename) .. " изменён на диске. Записать поверх? [Y/n, C - отмена]") then
      status = nil
      return false
    end
  end
  local backup
  if not new then
    backup = filename .. "~"
    for i = 1, math.huge do
      if not fs.exists(backup) then break end
      backup = filename .. "~" .. i
    end
    fs.copy(filename, backup)
  end
  if not fs.exists(parent) then fs.makeDirectory(parent) end
  local f, reason = io.open(filename, "w")
  if not f then
    status = tostring(reason)
    return false
  end
  local chars = 0
  for i, line in ipairs(buffer) do
    f:write(i == 1 and line or ("\n" .. line))
    chars = chars + unicode.len(line)
  end
  f:write("\n")
  f:close()
  commit()
  savedId = topId()
  modified = false
  stamp = fs.lastModified(filename)
  status = string.format(new and [["%s" [новый] %dL,%dC записано]] or [["%s" %dL,%dC записано]],
    fs.name(filename), #buffer, chars)
  if not new then fs.remove(backup) end
  return true
end

------------------------------------------------------------------ файлы

-- Открытых файлов может быть несколько. Редактор работает с переменными
-- текущего, а остальные лежат в docs; при переключении они меняются местами.
local stash, openDoc, switchDoc, closeDoc, checkDisk
do
  function stash()
    docs[docIndex] = {
      filename = filename, parent = parent, readonly = readonly, lua = lua,
      buffer = buffer, cx = cx, cy = cy, scrollX = scrollX, scrollY = scrollY,
      modified = modified, undoStack = undoStack, redoStack = redoStack,
      savedId = savedId, stamp = stamp, bps = bps, folds = folds, diag = diag,
      syntaxErr = syntaxErr, runErr = runErr,
    }
  end

  --- Общее для открытия и переключения: то, что про прошлый файл, забыть.
  local function fresh()
    carry, carryTop = {}, 1
    anchor, ghost, match, pair, sigHelp, pending = nil, nil, nil, nil, nil, nil
    scan, scanRev = nil, -1
    rev = rev + 1
    forgetCaches()
    lastCursorRow = nil
    fullRedraw = true
    status = nil
    checkDue = computer.uptime() + 0.1
  end

  local function restore(i)
    local d = docs[i]
    docIndex = i
    filename, parent, readonly, lua = d.filename, d.parent, d.readonly, d.lua
    buffer, cx, cy, scrollX, scrollY = d.buffer, d.cx, d.cy, d.scrollX, d.scrollY
    modified, undoStack, redoStack, savedId, stamp = d.modified, d.undoStack, d.redoStack, d.savedId, d.stamp
    bps, folds, diag, syntaxErr, runErr = d.bps, d.folds, d.diag, d.syntaxErr, d.runErr
    fresh()
  end

  local function readFile(path)
    local lines, chars = {}, 0
    local f = io.open(path)
    if f then
      for line in f:lines() do
        lines[#lines + 1] = line
        chars = chars + unicode.len(line)
      end
      f:close()
    end
    if #lines == 0 then lines[1] = "" end
    return lines, chars, f ~= nil
  end

  --- Файл поменяли снаружи (оболочка, запущенная программа): перечитать.
  --- Перечитывание - обычная правка, её можно отменить.
  function checkDisk()
    if not stamp or not fs.exists(filename) or fs.lastModified(filename) == stamp then return end
    local now = fs.lastModified(filename)
    if modified and not ask(fs.name(filename) .. " изменён на диске. Перечитать, потеряв правки? [Y/n]") then
      stamp = now
      status = nil
      return
    end
    local lines = readFile(filename)
    splice(1, #buffer, lines)
    commit()
    setCursor(cx, cy)
    savedId, modified, stamp = topId(), false, now
    fullRedraw = true
    status = "перечитан с диска"
  end

  --- Открыть файл (или перейти к нему, если уже открыт).
  function openDoc(path, ro)
    for i, d in ipairs(docs) do
      if (i == docIndex and filename or d.filename) == path then
        switchDoc(i)
        return true
      end
    end
    if fs.isDirectory(path) then
      status = "это каталог: " .. path
      return false
    end
    local node = fs.get(path)
    local r = ro or node == nil or node.isReadOnly()
    if r and not fs.exists(path) then
      status = "нет файла, а записать некуда: " .. path
      return false
    end
    if #docs > 0 then stash() end
    local lines, chars, exists = readFile(path)
    docIndex = #docs + 1
    filename, parent, readonly, lua = path, fs.path(path), r, isLua(path)
    buffer, cx, cy, scrollX, scrollY = lines, 1, 1, 0, 0
    modified, undoStack, redoStack, savedId = false, {}, {}, 0
    stamp = exists and fs.lastModified(path) or nil
    bps, folds, diag, syntaxErr, runErr = {}, {}, {}, nil, nil
    fresh()
    stash()
    if exists then
      status = string.format(readonly and [["%s" [только чтение] %dL,%dC]] or [["%s" %dL,%dC]],
        fs.name(path), #buffer, chars)
    else
      status = string.format([==["%s" [новый файл]]==], fs.name(path))
    end
    return true
  end

  function switchDoc(i)
    if i == docIndex or not docs[i] then return end
    stash()
    restore(i)
    checkDisk()
  end

  --- Закрыть текущий файл; последний - закрыть и редактор.
  function closeDoc()
    if modified and not readonly then
      local answer = ask(fs.name(filename) .. " изменён. Сохранить перед закрытием? [Y/n, C - остаться]")
      if answer == nil then
        status = nil
        return
      end
      if answer and not save() then return end
    end
    table.remove(docs, docIndex)
    if #docs == 0 then
      running = false
      return
    end
    restore(math.min(docIndex, #docs))
    checkDisk()
  end
end

------------------------------------------------------------------ проверка

-- Пока набирают, проверять нечего: через полсекунды тишины файл
-- компилируется (синтаксис) и разбирается luascan (подозрительные имена).
-- Номер строки с ошибкой краснеет, с предупреждением - желтеет, а сам
-- текст сообщения виден внизу, когда курсор на этой строке.
local ensureScan, runChecks
do
  local function known(name) return _ENV[name] ~= nil end

  --- Разбор файла; name - имя, чьи упоминания нужны (переход, переименование).
  --- Разбор идёт потоком, но на большом файле всё равно ест память: если её
  --- мало, лучше обойтись без подсказок, чем уронить редактор с правками.
  function ensureScan(name)
    if not lua then return nil end
    if scanRev ~= rev or not scan or (name and scan.name ~= name) then
      local src = table.concat(buffer, "\n")
      scan, scanRev = nil, rev
      if computer.freeMemory() > #src * 3 + 65536 then
        local ok, r = pcall(luascan.analyze, src, { known = known, name = name })
        if ok then
          scan = r
          r.name = name
        end
      end
    end
    return scan
  end

  function runChecks()
    checkDue = nil
    diag, syntaxErr = {}, nil
    if lua then
      local fn, err = load(table.concat(buffer, "\n"), "=" .. fs.name(filename), "t", {})
      if not fn then
        err = tostring(err)
        local l, msg = err:match(":(%d+): (.*)$")
        l = math.min(tonumber(l) or #buffer, #buffer)
        syntaxErr = { l = l, msg = msg or err }
        diag[l] = { err = "синтаксис: " .. syntaxErr.msg }
        -- "'end' expected (to close 'function' at line 3)": начало блока тоже
        local open = tonumber(syntaxErr.msg:match("at line (%d+)"))
        if open and not diag[open] then diag[open] = { err = "не закрыто, см. строку " .. l } end
      else
        local r = ensureScan()
        for _, d in ipairs(r and r.diags or {}) do
          local e = diag[d.l] or { marks = {} }
          diag[d.l] = e
          e.warn = e.warn and (e.warn .. "; " .. d.msg) or d.msg
          e.marks[#e.marks + 1] = { d.c, d.len }
        end
      end
    end
    fullRedraw = true
  end
end

------------------------------------------------------------------ панель

-- Оболочка и вывод запущенного живут в панели внизу экрана, а редактор
-- остаётся над ней: написал, запустил, посмотрел вывод, поправил. Панель
-- рисует обычный терминал в своём окне (tty.setViewport), холст редактора
-- её не касается.
local panelX, panelY = 1, 1       -- курсор терминала в панели между заходами

--- Пересоздать холст под текущее разрешение и высоту панели.
local function relayout()
  S:close()
  gpu = tty.gpu()
  SW, SH = gpu.getResolution()
  if panelH > 0 then panelH = math.max(6, math.floor(SH / 3)) end
  S = gfx.surface(gpu, { h = SH - panelH })
  W, H = S.w, S.h
  rows = H - 1
  holes = {}
  lastCursorRow = nil
  fullRedraw = true
end

local function showPanel(on)
  if on == (panelH > 0) then return end
  panelH = on and 1 or 0
  relayout()
  if on then
    if gpu.setActiveBuffer then gpu.setActiveBuffer(0) end
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, SH - panelH + 1, SW, panelH, " ")
    panelX, panelY = 1, 1
  end
end

--- Отдать клавиатуру и панель терминалу на время fn.
local function inPanel(fn)
  showPanel(true)
  redraw()
  if gpu.setActiveBuffer then gpu.setActiveBuffer(0) end
  local window = tty.window
  local vw, vh, vdx, vdy, vx, vy = tty.getViewport()
  local full = window.fullscreen
  window.fullscreen = false
  tty.setViewport(SW, panelH, 0, SH - panelH, panelX, panelY)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  term.setCursorBlink(true)
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then io.stderr:write(tostring(err), "\n") end
  term.setCursorBlink(false)
  panelX, panelY = tty.getCursor()
  tty.setViewport(vw, vh, vdx, vdy, vx, vy)
  window.fullscreen = full
  -- программа могла рисовать где угодно, менять разрешение и освобождать
  -- видеопамять: холст редактора создаём заново
  relayout()
  forgetCaches()            -- устройства могли подключить или снять
  checkDisk()               -- а файл - поменять
end

local runFile, shellHere, debugRun
do
  --- Выполнить fn, запомнив всё, что ушло в stderr. Программа пишет в
  --- копию дескриптора (io.dup), а копия ищет метод у настоящего потока
  --- при каждом вызове - поэтому подменяем write у него.
  local function capture(fn)
    local real = io.stderr
    while type(rawget(real, "fd")) == "table" and rawget(real, "_closed") ~= nil do
      real = rawget(real, "fd")
    end
    local was, method, got = rawget(real, "write"), real.write, {}
    rawset(real, "write", function(self, ...)
      for i = 1, select("#", ...) do got[#got + 1] = tostring((select(i, ...))) end
      return method(self, ...)
    end)
    local ok, err = pcall(fn)
    rawset(real, "write", was)
    if not ok then io.stderr:write(tostring(err), "\n") end
    return table.concat(got)
  end

  --- Запустить файл path в панели; вернуть, что программа написала в stderr.
  local function runIn(path)
    local out = ""
    inPanel(function()
      if tty.getCursor() > 1 then io.write("\n") end
      io.write("\27[33m> " .. fs.name(filename) .. "\27[37m\n")
      out = capture(function()
        local sh = require("sh")
        local ok, reason = sh.execute(_ENV, '"' .. path .. '"')
        if not ok and reason then io.stderr:write(tostring(reason), "\n") end
      end)
    end)
    return out
  end

  --- Программа упала в нашем файле (path - под каким именем его запускали):
  --- запомнить строку и сообщение и поставить туда курсор.
  local function report(out, path)
    runErr = nil
    local esc = path:gsub("%p", "%%%0")
    -- сообщение - последняя строка перед трассой
    local head = out:sub(1, (out:find("stack traceback:", 1, true) or #out + 1) - 1)
    local msg = head:match("([^\n]+)\n*$") or ""
    local l = msg:match(esc .. ":(%d+):")
    if not l then
      -- упала в чужом коде: берём ближайший вызов из нашего файла
      l = out:match(esc .. ":(%d+):")
    end
    if not l then return end
    msg = msg:gsub("^" .. esc .. ":%d+: ", ""):gsub(":$", "")
    runErr = { l = math.min(tonumber(l), #buffer), msg = "ошибка: " .. msg }
    dropSelection()
    setCursor(1, runErr.l)
    fullRedraw = true
    return runErr
  end

  --- F5: сохранить и запустить файл; вывод - в панели внизу. Если упал,
  --- курсор встаёт на строку ошибки.
  function runFile()
    if modified and not readonly and not save() then return end
    status = "работает " .. fs.name(filename)
    local out = runIn(filename)
    status = not report(out, filename) and "вывод внизу, ^O скрыть панель" or nil
  end

  --- Ctrl+E: оболочка в панели. Своя, а не новый sh: тот прочитал бы
  --- /etc/profile, очистил экран и увёл в /home.
  function shellHere()
    if modified and not readonly then save() end
    local hello = "оболочка внизу, exit - обратно в редактор"
    status = hello
    inPanel(function()
      local sh = require("sh")
      local hint = { hint = sh.hintHandler }
      while true do
        if tty.getCursor() > 1 then io.write("\n") end
        io.write(sh.expand(os.getenv("PS1") or "$ "))
        tty.window.cursor = hint
        local command = io.stdin:readLine(false)
        tty.window.cursor = nil
        if command == nil then return end
        if command then
          command = text.trim(command)
          if command == "exit" then return end
          if command ~= "" then
            local ok, reason = sh.execute(_ENV, command)
            if not ok and reason then io.stderr:write(tostring(reason), "\n") end
          end
        end
      end
    end)
    if status == hello then status = nil end
  end

  ---------------------------------------------------------------- отладчик

  -- debug.sethook в песочнице мода нет, а debug.getlocal отдаёт только
  -- имена. Поэтому отладка идёт по копии файла, в которой перед каждой
  -- строкой-оператором стоит вызов
  --   __dwdbg(12,function()return a,b,c end);
  -- Замыкание видит local этого места и отдаёт их значения, когда
  -- отладчик остановился; номера строк у копии те же, что у файла.

  local dbg = nil    -- { mode, depth, stop, names, tmp, lastL, lastF, queue }

  --- Глубина стека: по ней шаг не заходит в вызовы (F10) и выходит из них.
  local function depthNow()
    local n = 3
    while debug.getinfo(n, "l") do n = n + 1 end
    return n
  end

  --- Значение одной строкой: строки в кавычках, у таблиц - начало содержимого.
  local function short(v, deep)
    local t = type(v)
    if t == "string" then
      local s = string.format("%q", v):gsub("\\\n", "\\n")
      return s
    elseif t == "table" then
      if deep then return "{..}" end
      local parts, n = {}, 0
      pcall(function()
        for k, x in pairs(v) do
          n = n + 1
          if #parts < 5 then
            parts[#parts + 1] = (type(k) == "number" and "" or (tostring(k) .. "=")) .. short(x, true)
          end
        end
      end)
      return "{" .. table.concat(parts, ", ") .. (n > #parts and ", .." or "") .. "}" ..
        (n > 0 and ("  #" .. n) or "")
    elseif t == "function" then
      local ok, info = pcall(debug.getinfo, v, "S")
      local at = ok and info and info.linedefined or 0
      return "функция" .. (at > 0 and (" стр " .. at) or "")
    end
    return tostring(v)
  end

  --- Строки дерева переменных: раскрытые таблицы показывают поля.
  local function treeOf(vars, open)
    local out = {}
    local function add(depth, key, v, path)
      out[#out + 1] = { depth = depth, key = key, v = v, path = path }
      if type(v) ~= "table" or not open[path] or depth > 6 or #out > 400 then return end
      local keys = {}
      pcall(function() for k in pairs(v) do keys[#keys + 1] = k end end)
      table.sort(keys, function(a, b)
        local na, nb = type(a) == "number", type(b) == "number"
        if na ~= nb then return na end
        if na then return a < b end
        return tostring(a) < tostring(b)
      end)
      for i = 1, math.min(#keys, 200) do
        local k = keys[i]
        local ok, x = pcall(function() return v[k] end)
        add(depth + 1, type(k) == "string" and k or ("[" .. tostring(k) .. "]"), ok and x or nil,
          path .. "\0" .. tostring(k))
      end
    end
    for _, x in ipairs(vars) do add(0, x[1], x[2], x[1]) end
    return out
  end

  --- Остановка: код с отмеченной строкой, справа - переменные. Возвращает,
  --- что делать дальше: run, over, into, out, stop. info.final - программа
  --- уже упала, показываем переменные на момент ошибки.
  local function pauseView(info)
    dbgLine = info.line
    dropSelection()
    setCursor(1, info.line)
    local open, sel, top, focus, answer = {}, 1, 1, false, nil
    while not answer do
      local list = treeOf(info.vars, open)
      if sel > #list then sel = math.max(1, #list) end
      local bw = math.max(26, math.min(60, math.floor(W * 0.45)))
      local bx = W - bw + 1
      local head = {}
      wrapInto(head, info.title, bw - 2, P.BAR_MARK)
      if info.err then wrapInto(head, info.err, bw - 2, P.ERR) end
      if info.stack and info.stack ~= "" then wrapInto(head, "стек: " .. info.stack, bw - 2, P.BAR_FG) end
      head[#head + 1] = { #list > 0 and (focus and "переменные (Tab - к коду)" or "переменные (Tab - выбрать)")
        or "local здесь не видно", P.BAR_POS }
      local lh = math.max(1, rows - #head)
      if sel < top then top = sel end
      if sel > top + lh - 1 then top = sel - lh + 1 end
      holes = { { x1 = bx, y1 = 1, x2 = W, y2 = rows } }
      popupDraw = function()
        for i = 1, rows do
          local s, fg, bg = "", P.POP_FG, P.POP_BG
          if head[i] then
            s, fg, bg = head[i][1], head[i][2], P.BAR_BG
          else
            local r = list[top + i - #head - 1]
            if r then
              local mark = type(r.v) == "table" and (open[r.path] and "- " or "+ ") or "  "
              s = ("  "):rep(r.depth) .. mark .. r.key .. " = " .. short(r.v)
              if focus and top + i - #head - 1 == sel then bg = P.POP_SEL end
              if type(r.v) == "string" then fg = P.C_STR
              elseif type(r.v) == "number" then fg = P.C_NUM
              elseif r.v == nil or type(r.v) == "boolean" then fg = P.C_BLT end
            end
          end
          S:set(bx, i, " " .. pad(s, bw - 1), fg, bg)
        end
      end
      status = info.final and "F5 или Enter - закрыть" or
        "F5 дальше  F10 шаг  F11 внутрь  S-F11 наружу  F4 стоп  F9 точка"
      fullRedraw = true
      redraw()
      local ev = table.pack(event.pull())
      local e, addr, char, code = ev[1], ev[2], ev[3], ev[4]
      if e == "key_down" and addr == term.keyboard() then
        local shift = keyboard.isShiftDown(term.keyboard())
        if code == keys.f5 or (info.final and (code == keys.enter or code == keys.back)) then
          answer = "run"
        elseif not info.final and code == keys.f10 then answer = "over"
        elseif not info.final and code == keys.f11 then answer = shift and "out" or "into"
        elseif not info.final and code == keys.f4 then answer = "stop"
        elseif code == keys.f9 then bps[cy] = not bps[cy] or nil
        elseif code == keys.tab then focus = not focus and #list > 0
        elseif focus and code == keys.up then sel = math.max(1, sel - 1)
        elseif focus and code == keys.down then sel = math.min(#list, sel + 1)
        elseif focus and (code == keys.enter or code == keys.right or code == keys.left) then
          local r = list[sel]
          if r and type(r.v) == "table" then open[r.path] = code ~= keys.left or nil end
        elseif code == keys.up or code == keys.down then
          move(cx, stepLine(cy, code == keys.up and -1 or 1) or cy)
        elseif code == keys.pageUp or code == keys.pageDown then
          move(cx, stepLines(cy, (code == keys.pageUp and -1 or 1) * (rows - 1)))
        end
      elseif e == "scroll" then
        move(cx, stepLines(cy, -(ev[5] or 0) * 3))
      elseif dbg and e ~= "key_up" and e ~= "key_down" and e ~= "touch" and e ~= "drag"
             and e ~= "drop" and e ~= "clipboard" and e ~= "interrupted" then
        -- чужие события (таймеры, сеть) - программе, когда она продолжит
        dbg.queue[#dbg.queue + 1] = ev
      end
    end
    holes, popupDraw, dbgLine, status = {}, nil, nil, nil
    fullRedraw = true
    redraw()
    return answer
  end

  --- Значения переменных строки l: замыкание f отдаёт их по порядку имён.
  local function varsOf(l, f)
    local vars, names = {}, dbg.names[l] or {}
    if f then
      local vals = table.pack(pcall(f))
      for i, nm in ipairs(names) do vars[#vars + 1] = { nm, vals[1] and vals[i + 1] or nil } end
    end
    return vars
  end

  --- То, что вставлено в копию файла перед строками.
  local function hook(l, f)
    local d = dbg
    if not d then return end
    if d.stop then error("остановлено отладчиком", 0) end
    d.lastL, d.lastF = l, f
    local depth
    local want = bps[l] ~= nil
    if not want and d.mode ~= "run" then
      depth = depthNow()
      want = d.mode == "into" or (d.mode == "over" and depth <= d.depth) or (d.mode == "out" and depth < d.depth)
    end
    if not want then return end
    depth = depth or depthNow()
    local stack = {}
    for lv = 3, 40 do
      local ok, inf = pcall(debug.getinfo, lv, "Sln")
      if not ok or not inf then break end
      if inf.source == "=" .. d.tmp and (inf.currentline or 0) > 0 then
        stack[#stack + 1] = (inf.name or "main") .. ":" .. inf.currentline
      end
    end
    -- программа могла поменять цвета, разрешение и активный буфер
    local fg, bg = gpu.getForeground(), gpu.getBackground()
    local buf = gpu.getActiveBuffer and gpu.getActiveBuffer()
    local w, h = gpu.getResolution()
    if w ~= SW or h ~= SH then relayout() end
    if buf and buf ~= 0 then gpu.setActiveBuffer(0) end
    term.setCursorBlink(false)
    local answer = pauseView({ line = l, vars = varsOf(l, f), stack = table.concat(stack, " < "),
      title = "пауза, строка " .. l })
    term.setCursorBlink(true)
    if buf and buf ~= 0 then gpu.setActiveBuffer(buf) end
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    local queue = d.queue
    d.queue = {}
    for _, ev in ipairs(queue) do computer.pushSignal(table.unpack(ev, 1, ev.n)) end
    d.mode, d.depth = answer, depth
    if answer == "stop" then
      d.stop = true
      error("остановлено отладчиком", 0)
    end
  end

  --- F6: запуск под отладчиком. Без точек останова - пауза на первой строке.
  function debugRun()
    if not lua then
      status = "отладка - только для .lua"
      return
    end
    if modified and not readonly and not save() then return end
    runChecks()
    if syntaxErr then
      dropSelection()
      setCursor(1, syntaxErr.l)
      return
    end
    local R = luascan.analyze(table.concat(buffer, "\n"), { hooks = true })
    local lines, names, hooked = {}, {}, {}
    for i, line in ipairs(buffer) do lines[i] = line end
    for l, h in pairs(R.hooks) do
      local nm = luascan.names(h.at)
      local call = "__dwdbg(" .. l .. (#nm > 0 and (",function()return " .. table.concat(nm, ",") .. " end") or "") .. ");"
      lines[l] = lines[l]:sub(1, h.c - 1) .. call .. lines[l]:sub(h.c)
      names[l], hooked[l] = nm, true
    end
    -- разбор мог где-то ошибиться: вставку, сломавшую код, убираем
    local ok
    for _ = 1, 60 do
      local fn, e = load(table.concat(lines, "\n"), "=x", "t", {})
      if fn then ok = true break end
      local bad = tonumber(tostring(e):match(":(%d+):")) or 0
      while bad > 0 and not hooked[bad] do bad = bad - 1 end
      if bad == 0 then break end
      lines[bad], hooked[bad], names[bad] = buffer[bad], nil, nil
    end
    if not ok then
      status = "не вышло подготовить файл к отладке"
      return
    end
    local tmp = "/tmp/dwdbg/" .. fs.name(filename)
    fs.makeDirectory("/tmp/dwdbg")
    local f = io.open(tmp, "w")
    if not f then
      status = "некуда положить копию для отладки"
      return
    end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
    dbg = { mode = next(bps) and "run" or "into", depth = 0, names = names, tmp = tmp, queue = {} }
    _ENV.__dwdbg = hook
    status = "отладка " .. fs.name(filename)
    local out = runIn(tmp)
    _ENV.__dwdbg = nil
    local d = dbg
    dbg = nil
    fs.remove(tmp)
    if d.stop then
      status = "отладка остановлена"
      return
    end
    local err = report(out, tmp)
    if err then
      -- на момент ошибки: переменные последней пройденной строки
      local vars = {}
      if d.lastF then
        dbg = d
        vars = varsOf(d.lastL, d.lastF)
        dbg = nil
      end
      pauseView({ line = err.l, vars = vars, final = true, err = err.msg,
        title = "упала на строке " .. err.l .. (d.lastL and d.lastL ~= err.l and
          (", переменные строки " .. d.lastL) or "") })
      status = err.msg
    else
      status = "отладка закончена"
    end
  end
end

------------------------------------------------------------------ навигация

local chooseFrom, goBack, goDefinition, showUsages, renameVar, showOutline, nextProblem, openPrompt
do
  local jumps = {}    -- откуда уходили: { файл, символ, строка }

  local function pushJump()
    jumps[#jumps + 1] = { filename, cx, cy }
    if #jumps > 50 then table.remove(jumps, 1) end
  end

  local function charCol(l, c) return unicode.len((buffer[l] or ""):sub(1, c - 1)) + 1 end
  local function cursorByte() return #unicode.sub(curLine(), 1, cx - 1) + 1 end

  --- Имя под курсором (или прямо перед ним) и его первый байт.
  local function wordHere()
    local line, ws = curLine(), cursorByte()
    while ws > 1 and line:sub(ws - 1, ws - 1):match("[%w_]") do ws = ws - 1 end
    return line:match("^[%a_][%w_]*", ws), ws
  end

  local function jumpTo(l, c)
    dropSelection()
    setCursor(c and charCol(l, c) or 1, l)
    fullRedraw = true
  end

  --- Список посреди экрана. Буквы сужают его, стрелки выбирают, Enter -
  --- выбрать, Backspace на пустом фильтре - выйти. Возвращает номер пункта.
  function chooseFrom(title, items, want)
    local filter, top, result, lastH, sel = "", 1, nil, nil, 1
    while true do
      local shown = {}
      local low = unicode.lower(filter)
      for i, it in ipairs(items) do
        if low == "" or unicode.lower(it.text):find(low, 1, true) then shown[#shown + 1] = i end
      end
      if want then
        for k, i in ipairs(shown) do if i == want then sel = k end end
        want = nil
      end
      if sel > #shown then sel = math.max(1, #shown) end
      local bw = math.min(W - 2, 76)
      local bh = math.max(3, math.min(rows - 2, #shown + 1))
      local bx, by, lh = math.floor((W - bw) / 2) + 1, 2, bh - 1
      if sel < top then top = sel end
      if sel > top + lh - 1 then top = sel - lh + 1 end
      holes = { { x1 = bx, y1 = by, x2 = bx + bw - 1, y2 = by + bh - 1 } }
      if bh ~= lastH then fullRedraw = true end
      lastH = bh
      popupDraw = function()
        S:set(bx, by, " " .. pad(title .. (filter ~= "" and ("   фильтр: " .. filter) or ""), bw - 1),
          P.BAR_MARK, P.BAR_BG)
        for r = 1, lh do
          local idx = shown[top + r - 1]
          local it = idx and items[idx]
          local hint = it and it.hint or ""
          local body = it and pad(" " .. it.text, bw - unicode.wlen(hint) - 1) .. hint .. " " or ""
          S:set(bx, by + r, pad(body, bw), it and it.colour or P.POP_FG,
            (idx and top + r - 1 == sel) and P.POP_SEL or P.POP_BG)
        end
      end
      redraw()
      local e, addr, char, code = event.pull()
      if e == "key_down" and addr == term.keyboard() then
        if code == keys.up then sel = sel > 1 and sel - 1 or #shown
        elseif code == keys.down then sel = sel < #shown and sel + 1 or 1
        elseif code == keys.pageUp then sel = math.max(1, sel - lh)
        elseif code == keys.pageDown then sel = math.min(#shown, sel + lh)
        elseif code == keys.enter or code == keys.numpadenter then
          result = shown[sel]
          break
        elseif code == keys.back then
          if filter == "" then break end
          filter, sel, top = unicode.sub(filter, 1, -2), 1, 1
        elseif code == 1 then
          break
        elseif char and char >= 32 and not keyboard.isControl(char)
               and not keyboard.isControlDown(term.keyboard()) then
          filter, sel, top = filter .. unicode.char(char), 1, 1
        end
      end
    end
    holes, popupDraw = {}, nil
    fullRedraw = true
    return result
  end

  function goBack()
    local j = table.remove(jumps)
    if not j then
      status = "назад некуда"
      return
    end
    if j[1] ~= filename and not openDoc(j[1]) then return end
    dropSelection()
    setCursor(j[2], j[3])
    fullRedraw = true
  end

  --- Открыть модуль по имени для require; field - перейти к его полю.
  local function openModule(mod, field)
    local path = package.searchpath(mod, package.path)
    if not path then
      status = "модуль не найден: " .. mod
      return
    end
    pushJump()
    if not openDoc(path) then return end
    if not field then return end
    local R = ensureScan()
    for _, f in ipairs(R and R.funcs or {}) do
      if f.name == field or f.name == "local " .. field or f.name:match("[%.:]" .. field .. "$") then
        return jumpTo(f.l)
      end
    end
    for i, line in ipairs(buffer) do
      local at = line:find("[%.:]" .. field .. "%s*=")
      if at then return jumpTo(i, at + 1) end
    end
    status = field .. " в " .. fs.name(path) .. " не нашёл"
  end

  --- F12: к определению того, что под курсором.
  function goDefinition()
    local line, b = curLine(), cursorByte()
    for s0, mod, e0 in line:gmatch("()require%s*%(?%s*[\"']([^\"']+)[\"']%s*%)?()") do
      if b >= s0 and b <= e0 then return openModule(mod) end
    end
    local word, ws = wordHere()
    local R = ensureScan(word)
    if not R then
      status = "переход к определению - только в .lua"
      return
    end
    if not word then
      status = "под курсором нет имени"
      return
    end
    -- поле: a.b - функция файла или модуля a
    local base = line:sub(1, ws - 1):match("([%a_][%w_%.]*)[%.:]$")
    if base then
      for _, f in ipairs(R.funcs) do
        if f.name == base .. "." .. word or f.name == base .. ":" .. word then
          pushJump()
          return jumpTo(f.l)
        end
      end
      local a = aliases()[base]
      if a and #a == 1 then return openModule(a[1], word) end
      if package.searchpath(base, package.path) and not base:find("%.") then return openModule(base, word) end
      for _, f in ipairs(R.funcs) do
        if f.name:match("[%.:]" .. word .. "$") then
          pushJump()
          return jumpTo(f.l)
        end
      end
      status = "не нашёл, где задано " .. base .. "." .. word
      return
    end
    local ref = luascan.refAt(R, cy, b)
    if ref and ref.decl then
      pushJump()
      return jumpTo(ref.decl.l, ref.decl.c)
    end
    local g = R.globals[word]
    if g then
      pushJump()
      return jumpTo(g.l, g.c)
    end
    if package.searchpath(word, package.path) then return openModule(word) end
    status = "определение " .. word .. " не найдено"
  end

  --- Shift+F12: все места, где стоит переменная под курсором.
  function showUsages()
    local R = ensureScan((wordHere()))
    local ref = R and luascan.refAt(R, cy, cursorByte())
    if not ref then
      status = "под курсором нет переменной"
      return
    end
    local items, sel = {}, 1
    for _, o in ipairs(luascan.occurrences(R, ref)) do
      items[#items + 1] = { text = string.format("%4d  %s", o.l, text.trim(buffer[o.l] or "")), l = o.l, c = o.c }
      if o.l == cy then sel = #items end
    end
    local i = chooseFrom(ref.name .. (ref.decl and "" or " (глобальная)") .. ": мест " .. #items, items, sel)
    if i then
      pushJump()
      jumpTo(items[i].l, items[i].c)
    end
  end

  --- F2: переименовать переменную везде, где она та же самая.
  function renameVar()
    if readonly then return end
    local R = ensureScan((wordHere()))
    local ref = R and luascan.refAt(R, cy, cursorByte())
    if not ref then
      status = "под курсором нет переменной"
      return
    end
    local new = readLine("Новое имя для " .. ref.name .. ": ", ref.name)
    if not new or new == ref.name then return end
    if not new:match("^[%a_][%w_]*$") or KEYWORD[new] then
      status = "не годится в имена: " .. new
      return
    end
    local occ = luascan.occurrences(R, ref)
    local first, last = occ[1].l, occ[#occ].l
    local lines = {}
    for i = first, last do lines[#lines + 1] = buffer[i] end
    for k = #occ, 1, -1 do
      local o = occ[k]
      local s0 = lines[o.l - first + 1]
      lines[o.l - first + 1] = s0:sub(1, o.c - 1) .. new .. s0:sub(o.c + o.len)
    end
    local x, y = cx, cy
    splice(first, last - first + 1, lines)
    commit()
    setCursor(x, y)
    fullRedraw = true
    status = "переименовано мест: " .. #occ
  end

  --- Ctrl+T: функции файла списком.
  function showOutline()
    local R = ensureScan()
    if not R or #R.funcs == 0 then
      status = "функций не нашёл"
      return
    end
    local items, sel = {}, 1
    for _, f in ipairs(R.funcs) do
      items[#items + 1] = { text = ("  "):rep(f.depth) .. f.name, hint = tostring(f.l), l = f.l }
      if f.l <= cy then sel = #items end
    end
    local i = chooseFrom("Функции файла", items, sel)
    if i then
      pushJump()
      jumpTo(items[i].l)
    end
  end

  --- F8: к следующей строке с ошибкой или предупреждением (Shift - к прошлой).
  function nextProblem(back)
    local lines, seen = {}, {}
    local function add(l) if not seen[l] then seen[l] = true lines[#lines + 1] = l end end
    for l in pairs(diag) do add(l) end
    if runErr then add(runErr.l) end
    for i = 1, #buffer do
      if buffer[i]:find("(", 1, true) and lineProblem(i) then add(i) end
    end
    if #lines == 0 then
      status = "замечаний нет"
      return
    end
    table.sort(lines)
    local target = back and lines[#lines] or lines[1]
    for k = 1, #lines do
      local l = back and lines[#lines - k + 1] or lines[k]
      if (back and l < cy) or (not back and l > cy) then target = l break end
    end
    local m = diag[target] and diag[target].marks and diag[target].marks[1]
    jumpTo(target, m and m[1])
  end

  --- Tab в строке пути: дописать имя файла или каталога.
  local function completePath(buf)
    local dir, part = buf:match("^(.-)([^/]*)$")
    local base = dir:sub(1, 1) == "/" and dir or fs.concat(fs.path(filename), dir)
    local hits = {}
    local list = fs.list(base)
    if not list then return end
    for name in list do
      if name:sub(1, #part) == part then hits[#hits + 1] = name end
    end
    if #hits == 0 then return end
    local common = hits[1]
    for _, h in ipairs(hits) do
      while h:sub(1, #common) ~= common do common = common:sub(1, -2) end
    end
    return dir .. common
  end

  --- Ctrl+P: открыть файл; пустая строка - список открытых.
  function openPrompt()
    local path = readLine("Открыть (Tab - дописать, пусто - открытые): ", nil, completePath)
    if not path then return end
    if path == "" then
      stash()
      local items = {}
      for _, d in ipairs(docs) do
        items[#items + 1] = { text = fs.name(d.filename) .. (d.modified and " *" or ""), hint = d.parent }
      end
      local i = chooseFrom("Открытые файлы", items, docIndex)
      if i then switchDoc(i) end
      return
    end
    if path:sub(1, 1) ~= "/" then path = fs.concat(fs.path(filename), path) end
    pushJump()
    openDoc(fs.canonical(path))
  end
end

------------------------------------------------------------------ строки целиком

local toggleComment, duplicateLines, moveLines, toggleFold
do
  --- Строки выделения; без выделения - текущая. Выделение, кончившееся в
  --- самом начале строки, её не берёт.
  local function lineRange()
    local l1, _, l2, c2 = selection()
    if not l1 then return cy, cy end
    if c2 == 1 and l2 > l1 then l2 = l2 - 1 end
    return l1, l2
  end

  --- Ctrl+/: закомментировать строки или снять комментарий.
  function toggleComment()
    if readonly then return end
    local l1, l2 = lineRange()
    local all, ind = true, math.huge
    for i = l1, l2 do
      local line = buffer[i]
      if line:find("%S") then
        if not line:match("^%s*%-%-") then all = false end
        ind = math.min(ind, #line:match("^%s*"))
      end
    end
    if ind == math.huge then return end
    local new = {}
    for i = l1, l2 do
      local line = buffer[i]
      if not line:find("%S") then new[#new + 1] = line
      elseif all then new[#new + 1] = (line:gsub("^(%s*)%-%- ?", "%1", 1))
      else new[#new + 1] = line:sub(1, ind) .. "-- " .. line:sub(ind + 1) end
    end
    local keep, x = anchor, cx
    splice(l1, l2 - l1 + 1, new)
    commit()
    anchor = keep
    setCursor(math.max(1, x + (all and -3 or 3)), cy)
    fullRedraw = true
  end

  --- Ctrl+D: повторить строки ниже.
  function duplicateLines()
    if readonly then return end
    local l1, l2 = lineRange()
    local new, n = {}, l2 - l1 + 1
    for i = l1, l2 do new[#new + 1] = buffer[i] end
    for i = l1, l2 do new[#new + 1] = buffer[i] end
    local keep, x, y = anchor, cx, cy
    splice(l1, n, new)
    commit()
    if keep then anchor = { keep[1], keep[2] + n } end
    setCursor(x, y + n)
    fullRedraw = true
  end

  --- Alt+стрелка: передвинуть строки вверх или вниз.
  function moveLines(dir)
    if readonly then return end
    local l1, l2 = lineRange()
    if (dir < 0 and l1 == 1) or (dir > 0 and l2 == #buffer) then return end
    local new = {}
    if dir > 0 then new[1] = buffer[l2 + 1] end
    for i = l1, l2 do new[#new + 1] = buffer[i] end
    if dir < 0 then new[#new + 1] = buffer[l1 - 1] end
    local keep, x, y = anchor, cx, cy
    splice(math.min(l1, l1 + dir), l2 - l1 + 2, new)
    commit()
    if keep then anchor = { keep[1], keep[2] + dir } end
    setCursor(x, y + dir)
    fullRedraw = true
  end

  --- Ctrl+[: свернуть блок, который начинается на этой строке (или в
  --- котором курсор), или развернуть свёрнутое. В Lua блоки знает luascan,
  --- в остальных файлах блок - строки с отступом глубже этой.
  function toggleFold()
    if folds[cy] then
      folds[cy] = nil
      fullRedraw = true
      return
    end
    local first, last
    local R = ensureScan()
    if R then
      for _, b in ipairs(R.blocks) do
        if b.first == cy and (not last or b.last > last) then first, last = b.first, b.last end
      end
      if not first then
        for _, b in ipairs(R.blocks) do
          if b.first < cy and b.last >= cy and (not first or b.first > first) then first, last = b.first, b.last end
        end
      end
    else
      local ind = #curLine():match("^%s*")
      local i = cy + 1
      while buffer[i] and (not buffer[i]:find("%S") or #buffer[i]:match("^%s*") > ind) do
        if buffer[i]:find("%S") then last = i end
        i = i + 1
      end
      if last then first = cy end
    end
    if not first then
      status = "здесь нечего сворачивать"
      return
    end
    dropSelection()
    folds[first] = last
    setCursor(cx, first)
    fullRedraw = true
  end
end

------------------------------------------------------------------ команды

local handlers = {
  left = function(k) left(k) end,
  right = function(k) right(k) end,
  up = function(k) move(cx, stepLine(cy, -1) or cy, k) end,
  down = function(k) move(cx, stepLine(cy, 1) or cy, k) end,
  home = function(k) home(k) end,
  eol = function(k) ende(k) end,
  pageUp = function(k) move(cx, stepLines(cy, -(rows - 1)), k) end,
  pageDown = function(k) move(cx, stepLines(cy, rows - 1), k) end,

  backspace = function()
    if readonly then return end
    if deleteSelection() then return end
    -- пустая пара: стёр открывающую - уходит и закрывающая, что поставилась сама
    local line = curLine()
    local before, after = unicode.sub(line, cx - 1, cx - 1), unicode.sub(line, cx, cx)
    if cx > 1 and after ~= "" and (OPEN[before] == after or ((before == '"' or before == "'") and after == before)) then
      splice(cy, 1, { unicode.sub(line, 1, cx - 2) .. unicode.sub(line, cx + 1) }, "erase")
      setCursor(cx - 1, cy)
      return
    end
    if cx == 1 and hiddenBy(cy - 1) then
      folds[hiddenBy(cy - 1)] = nil
      fullRedraw = true
    end
    if left() then delete() end
  end,
  delete = function() if not readonly then delete() end end,
  deleteLine = function() if not readonly then delete(true) end end,
  newline = function() if not readonly then enter() end end,

  save = save,
  close = closeDoc,
  find = function() find(false) end,
  findnext = function() find(true) end,
  findprev = function() find(true, true) end,
  replace = replace,

  cut = function()
    if readonly then return end
    if selection() then
      clip = selectedText()
      deleteSelection()
      status = "вырезано строк: " .. #clip
      return
    end
    -- подряд нажатый Ctrl+K копит строки, но стоит отойти - буфер новый
    if not cutting then clip = {} end
    clip[#clip + 1] = curLine()
    cutting = true
    delete(true)
    home()
  end,
  cutSelection = function()
    if readonly or not selection() then return end
    clip = selectedText()
    deleteSelection()
    status = "вырезано строк: " .. #clip
  end,
  copy = function()
    local sel = selectedText()
    if sel then
      clip = sel
      status = "скопировано строк: " .. #clip
    else
      clip = { curLine() }
      status = "скопирована строка"
    end
    dropSelection()
  end,
  uncut = function()
    if readonly or #clip == 0 then return end
    deleteSelection()
    local line = curLine()
    local head, tail = unicode.sub(line, 1, cx - 1), unicode.sub(line, cx)
    if #clip == 1 then
      splice(cy, 1, { head .. clip[1] .. tail })
      setCursor(cx + unicode.len(clip[1]), cy)
    else
      local new = { head .. clip[1] }
      for i = 2, #clip - 1 do new[#new + 1] = clip[i] end
      new[#new + 1] = clip[#clip] .. tail
      splice(cy, 1, new)
      setCursor(unicode.len(clip[#clip]) + 1, cy + #clip - 1)
    end
    commit()
  end,

  selectAll = function()
    anchor = { 1, 1 }
    setCursor(unicode.len(buffer[#buffer]) + 1, #buffer)
    fullRedraw = true
  end,
  undo = function() if not readonly then undoStep(undoStack, redoStack) end end,
  redo = function() if not readonly then undoStep(redoStack, undoStack) end end,

  complete = function()
    if readonly then return end
    if selection() then
      indentSelection(false)
    elseif ghost and not (chainBefore() or ""):match("[%.:]$") then
      -- подсказка уже на экране: Tab её просто принимает. Сразу после
      -- точки вариантов много, и Tab открывает их список
      insert(ghost.text)
      commit()
      ghost = nil
    elseif not complete() then
      insert("  ")
    end
  end,
  completeList = function()
    if not readonly then complete() end
  end,
  unindent = function() if not readonly then indentSelection(true) end end,
  run = runFile,
  shell = shellHere,
  panel = function() showPanel(panelH == 0) end,
  debug = debugRun,
  breakpoint = function()
    bps[cy] = not bps[cy] or nil
    markDirty(cy)
  end,

  open = openPrompt,
  nextDoc = function() switchDoc(docIndex % #docs + 1) end,
  prevDoc = function() switchDoc((docIndex - 2) % #docs + 1) end,
  outline = showOutline,
  definition = goDefinition,
  usages = showUsages,
  back = goBack,
  rename = renameVar,
  problem = function() nextProblem(false) end,
  problemPrev = function() nextProblem(true) end,
  comment = toggleComment,
  duplicate = duplicateLines,
  moveUp = function() moveLines(-1) end,
  moveDown = function() moveLines(1) end,
  fold = toggleFold,

  goto_line = function()
    local s = readLine("Строка: ")
    local n = tonumber(s)
    if n then
      dropSelection()
      setCursor(1, n)
      fullRedraw = true
    end
  end,
}

-- F1: все клавиши, как они заданы в /etc/edit.cfg.
handlers.help = function()
  local list = {
    { "save", "сохранить" }, { "close", "закрыть файл (последний - выйти)" },
    { "open", "открыть файл; пусто - список открытых" },
    { "nextDoc", "следующий открытый файл" }, { "prevDoc", "предыдущий открытый файл" },
    { "run", "сохранить и запустить" }, { "debug", "запустить под отладчиком" },
    { "breakpoint", "точка останова (или щелчок по номеру)" },
    { "shell", "оболочка в панели" }, { "panel", "показать или скрыть панель" },
    { "problem", "к следующей ошибке" }, { "problemPrev", "к предыдущей ошибке" },
    { "find", "поиск (/шаблон - шаблон Lua)" }, { "findnext", "искать дальше" },
    { "findprev", "искать назад" }, { "replace", "найти и заменить" },
    { "goto_line", "к строке по номеру" }, { "outline", "функции файла" },
    { "definition", "к определению (и в модуль по require)" },
    { "usages", "где ещё стоит эта переменная" }, { "back", "назад после перехода" },
    { "rename", "переименовать переменную" },
    { "complete", "дополнить; с выделением - отступ" }, { "completeList", "список вариантов" },
    { "unindent", "убрать отступ" }, { "comment", "закомментировать строки" },
    { "duplicate", "повторить строки" }, { "moveUp", "строки вверх" }, { "moveDown", "строки вниз" },
    { "fold", "свернуть или развернуть блок" },
    { "undo", "отменить" }, { "redo", "повторить отменённое" },
    { "selectAll", "выделить всё" }, { "copy", "копировать" }, { "cutSelection", "вырезать выделенное" },
    { "cut", "вырезать строку" }, { "uncut", "вставить" }, { "deleteLine", "удалить строку" },
  }
  local items = {}
  for _, it in ipairs(list) do
    local kb = config.keybinds[it[1]]
    local names = {}
    for _, bind in ipairs(type(kb) == "table" and kb or {}) do
      if type(bind) == "table" then
        local parts = {}
        for _, v in ipairs(bind) do
          parts[#parts + 1] = v == "control" and "Ctrl" or v == "shift" and "Shift" or v == "alt" and "Alt"
            or (unicode.upper(v:sub(1, 1)) .. v:sub(2))
        end
        names[#names + 1] = table.concat(parts, "+")
      end
    end
    if #names > 0 then items[#items + 1] = { text = pad(table.concat(names, ", "), 26) .. it[2] } end
  end
  items[#items + 1] = { text = pad("Отладка:", 26) .. "F5 дальше, F10 шаг, F11 внутрь, Shift+F11 наружу, F4 стоп, Tab - переменные" }
  chooseFrom("Клавиши (буквы - фильтр, Backspace - выйти)", items)
end

local MOVES = {
  left = true, right = true, up = true, down = true,
  home = true, eol = true, pageUp = true, pageDown = true,
}

local function bindFor(code)
  local result, weight = nil, 0
  local kbd = term.keyboard()
  local shift = not not keyboard.isShiftDown(kbd)
  local control = not not keyboard.isControlDown(kbd)
  local alt = not not keyboard.isAltDown(kbd)
  for command, binds in pairs(config.keybinds) do
    if type(binds) == "table" and handlers[command] then
      for _, bind in ipairs(binds) do
        if type(bind) == "table" then
          local wantAlt, wantCtrl, wantShift, key = false, false, false, nil
          for _, v in ipairs(bind) do
            if v == "alt" then wantAlt = true
            elseif v == "control" then wantCtrl = true
            elseif v == "shift" then wantShift = true
            else key = v end
          end
          if wantAlt == alt and wantCtrl == control and wantShift == shift
             and code == keys[key] and #bind > weight then
            weight = #bind
            result = command
          end
        end
      end
    end
  end
  -- Shift+стрелки выделяют: те же команды движения, только якорь остаётся
  if not result and shift and not control and not alt then
    for command, binds in pairs(config.keybinds) do
      if MOVES[command] and type(binds) == "table" then
        for _, bind in ipairs(binds) do
          if #bind == 1 and code == keys[bind[1]] then result = command end
        end
      end
    end
  end
  return result and handlers[result], result
end

local function onKeyDown(char, code)
  status = nil
  local handler, name = bindFor(code)
  local shift = not not keyboard.isShiftDown(term.keyboard())
  if handler then
    if MOVES[name] then
      -- якорь ставим там, где курсор стоял до сдвига
      if shift and not anchor then anchor = { cx, cy } end
      handler(shift)
    else
      handler()
    end
    -- любое другое действие обрывает цепочку Ctrl+K. Сам Ctrl приходит
    -- отдельным key_down, но обработчика у него нет - цепочка цела
    if name ~= "cut" then cutting = false end
  elseif readonly and code == keys.q then
    running = false
  elseif not readonly and char and not keyboard.isControl(char) then
    local ch = unicode.char(char)
    local nextCh = unicode.sub(curLine(), cx, cx)
    if (CLOSE[ch] or ch == '"' or ch == "'") and nextCh == ch then
      move(cx + 1, cy)            -- закрывающая уже стоит, просто перешагнём
    elseif lua and OPEN[ch] and not selection() then
      insert(ch .. OPEN[ch])
      setCursor(cx - 1, cy)
      commit()
    elseif lua and (ch == '"' or ch == "'") and not nextCh:match("[%w_]") and not selection() then
      insert(ch .. ch)
      setCursor(cx - 1, cy)
      commit()
    else
      insert(ch)
      if ch == "." and not selection() then autoPopup() end
    end
    cutting = false
  end
end

-- Вставка идёт одной правкой и без автоотступа на каждой строке: если к
-- своим отступам вставленного кода добавлять отступ предыдущей строки, текст
-- уезжает лесенкой вправо, а end его не возвращает. Вместо этого блок целиком
-- сдвигается к отступу строки, куда вставляют: общий отступ снимаем, свой
-- ставим, а внутренняя лесенка блока остаётся как была.
local function onClipboard(value)
  if readonly then return end
  deleteSelection()
  value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
  local parts = {}
  for piece in (value .. "\n"):gmatch("(.-)\n") do
    parts[#parts + 1] = text.detab(piece, 2)
  end
  if #parts == 1 then
    insert(parts[1], "paste")
    commit()
    return
  end
  local line = curLine()
  local head = unicode.sub(line, 1, cx - 1)
  local ws = head:match("^ *")
  -- первая строка часто скопирована с середины, без отступа: её не считаем
  local common
  for i, p in ipairs(parts) do
    local lead = #p:match("^ *")
    if p:find("%S") and (i > 1 or lead > 0) and (not common or lead < common) then
      common = lead
    end
  end
  common = common or 0
  for i, p in ipairs(parts) do
    local lead = #p:match("^ *")
    p = p:sub(math.min(lead, common) + 1)
    if i > 1 and p ~= "" then p = ws .. p end
    parts[i] = p
  end
  local last = parts[#parts]
  local new = { head .. parts[1] }
  for i = 2, #parts - 1 do new[#new + 1] = parts[i] end
  new[#new + 1] = last .. unicode.sub(line, cx)
  splice(cy, 1, new)
  setCursor(unicode.len(last) + 1, cy + #parts - 1)
  commit()
end

------------------------------------------------------------------ загрузка

openDoc(filename, readonly)

-- Падение внутри цикла не должно оставить экран в цветах холста: убираем
-- за собой в любом случае, а ошибку отдаём дальше.
local function dispatch(e, addr, a, b, c)
  -- Ctrl+C у нас копирует, поэтому прерывание редактор не закрывает:
  -- иначе несохранённое пропадало бы молча
  if e == "interrupted" or (addr ~= term.keyboard() and addr ~= term.screen()) then return end
  if e == "key_down" then
    onKeyDown(a, b)
    updateGhost()
    findPair()
    updateSig()
    redraw()
  elseif e == "clipboard" then
    onClipboard(a)
    updateGhost()
    findPair()
    updateSig()
    redraw()
  elseif e == "touch" or e == "drag" then
    local gx, gy = term.getGlobalArea()
    local col, row = a - gx + 1, b - gy + 1
    if col >= 1 and row >= 1 and col <= W and row <= rows then
      local line = math.min(view[row] or #buffer, #buffer)
      if e == "touch" and col < GW then
        -- щелчок по номеру строки - точка останова
        bps[line] = not bps[line] or nil
        markDirty(line)
        redraw()
        return
      end
      if e == "touch" then
        dropSelection()
      elseif not anchor then
        anchor = { cx, cy }
      end
      setCursor(charAt(buffer[line] or "", math.max(1, col - GW + scrollX)), line)
      commit()
      updateGhost()
      updateSig()
      if anchor then fullRedraw = true end
      redraw()
    end
  elseif e == "scroll" then
    move(cx, stepLines(cy, -(c or 0) * 12))
    updateGhost()
    fullRedraw = true
    redraw()
  end
end

local function loop()
  redraw()
  while running do
    -- после паузы в наборе - проверка файла; пока её ждём, pull с таймаутом
    local wait = checkDue and math.max(0.05, checkDue - computer.uptime())
    local ev = table.pack(event.pull(wait))
    if ev[1] then
      dispatch(table.unpack(ev, 1, ev.n))
    elseif checkDue and computer.uptime() >= checkDue then
      runChecks()
      redraw()
    end
    -- клавиша, которой закрыли список вариантов, срабатывает как обычно
    while replay and running do
      local r = replay
      replay = nil
      dispatch(table.unpack(r, 1, r.n or #r))
    end
  end
end

local ok, err = xpcall(loop, debug.traceback)
S:close()
term.setCursorBlink(true)
term.clear()
if not ok then error(err, 0) end
