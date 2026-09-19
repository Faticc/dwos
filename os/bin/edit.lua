-- edit: редактор текста. Экран собирается в видеопамяти (gfx.surface),
-- поэтому правка строки стоит десяток вызовов gpu, а не перерисовки всего.
-- Для .lua есть подсветка: слова языка, строки, числа, комментарии.
--
-- Раскладка клавиш читается из /etc/edit.cfg, как в OpenOS; если файла нет,
-- он создаётся со значениями по умолчанию.

local fs = require("filesystem")
local keyboard = require("keyboard")
local keys = keyboard.keys
local shell = require("shell")
local term = require("term")
local text = require("text")
local unicode = require("unicode")
local event = require("event")
local gfx = require("gfx")
local tty = require("tty")

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

local function loadConfig()
  local env = {}
  local config = loadfile("/etc/edit.cfg", nil, env)
  if config then pcall(config) end
  env.keybinds = env.keybinds or {
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
  }
  if not config then
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

------------------------------------------------------------------ подсветка

local FG, BG = 0xD0D0D0, 0x000000
local C_KW, C_STR, C_NUM, C_CMT, C_BLT, C_OP = 0x66CCFF, 0x88DD88, 0xFFAA00, 0x707070, 0xFF9966, 0xBBBBBB
local S_FG, S_BG, CUR = 0x000000, 0xB0B0B0, 0xFFFFFF

local KEYWORD = {}
for w in ("and break do else elseif end for function goto if in local not or " ..
          "repeat return then until while"):gmatch("%S+") do KEYWORD[w] = true end
local BUILTIN = {}
for w in ("nil true false self _G _ENV require print pairs ipairs type tostring tonumber " ..
          "string table math os io coroutine error assert pcall xpcall select setmetatable " ..
          "getmetatable rawget rawset next unpack component computer unicode"):gmatch("%S+") do
  BUILTIN[w] = true
end

local lua = filename:sub(-4) == ".lua" or filename:sub(-4) == ".cfg"

-- Разобрать строку на куски {текст, цвет}. state - "мы внутри длинной
-- скобки" ({level = число =, comment = строка это комментарий}).
local function tokenize(s, state)
  local out, i, n = {}, 1, #s
  local function push(t, c) if t ~= "" then out[#out + 1] = { t, c } end end
  while i <= n do
    if state then
      local close = "]" .. ("="):rep(state.level) .. "]"
      local a = s:find(close, i, true)
      local col = state.comment and C_CMT or C_STR
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
        push(s:sub(a, b), FG)
        i = b + 1
      elseif s:find("^%-%-", i) then
        local eq = s:match("^%-%-%[(=*)%[", i)
        if eq then
          state = { level = #eq, comment = true }
          push(s:sub(i, i + #eq + 3), C_CMT)
          i = i + #eq + 4
        else
          push(s:sub(i), C_CMT)
          i = n + 1
        end
      elseif s:find("^%[=*%[", i) then
        local eq = s:match("^%[(=*)%[", i)
        state = { level = #eq, comment = false }
        push(s:sub(i, i + #eq + 1), C_STR)
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
        push(s:sub(i, j - 1), C_STR)
        i = j
      elseif c:match("%d") or (c == "." and s:sub(i + 1, i + 1):match("%d")) then
        local a, b = s:find("^0[xX]%x+", i)
        if not a then a, b = s:find("^%d+%.?%d*[eE][-+]?%d+", i) end
        if not a then a, b = s:find("^%d*%.?%d+", i) end
        if not a then a, b = i, i end
        push(s:sub(a, b), C_NUM)
        i = b + 1
      elseif c:match("[%a_]") then
        local a, b = s:find("^[%w_]+", i)
        local word = s:sub(a, b)
        push(word, KEYWORD[word] and C_KW or BUILTIN[word] and C_BLT or FG)
        i = b + 1
      else
        push(c, C_OP)
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
local S = gfx.surface(gpu)
local W, H = S.w, S.h
local rows = H - 1

local buffer = {}
local carry, carryTop = {}, 1     -- состояние подсветки на входе в строку
local cx, cy = 1, 1               -- курсор: символ в строке и номер строки
local scrollX, scrollY = 0, 0
local running, cutBuffer, cutting = true, {}, false
local status, dirty = nil, {}
local fullRedraw = true
local modified = false

local function curLine() return buffer[cy] or "" end

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
  if not lua then return { { buffer[i] or "", FG } } end
  ensureCarry(i - 1)
  return (tokenize(buffer[i] or "", carry[i]))
end

local function markDirty(i)
  dirty[i] = true
end

local function drawRow(i)
  local y = i - scrollY
  if y < 1 or y > rows then return end
  S:fill(1, y, W, 1, " ", FG, BG)
  if not buffer[i] then return end
  local col = 1
  for _, t in ipairs(tokensFor(i)) do
    local piece, color = t[1], t[2]
    local wl = unicode.wlen(piece)
    if col + wl - 1 > scrollX and col <= scrollX + W then
      local at = col - scrollX
      if at < 1 then
        piece = removePrefix(piece, scrollX - col + 1)
        at = 1
      end
      local room = W - at + 1
      if unicode.wlen(piece) > room then piece = unicode.wtrunc(piece, room + 1) end
      if piece ~= "" then S:set(at, y, piece, color, BG) end
    end
    col = col + wl
  end
end

local function helpText()
  local function pretty(label, command)
    local kb = type(config.keybinds) == "table" and config.keybinds[command]
    if type(kb) ~= "table" or type(kb[1]) ~= "table" then return "" end
    local alt, control, shift, key
    for _, v in ipairs(kb[1]) do
      if v == "alt" then alt = true
      elseif v == "control" then control = true
      elseif v == "shift" then shift = true
      else key = v end
    end
    if not key then return "" end
    return label .. ": [" .. (control and "Ctrl+" or "") .. (alt and "Alt+" or "") ..
      (shift and "Shift+" or "") .. unicode.upper(key) .. "] "
  end
  return pretty("Сохранить", "save") .. pretty("Выход", "close") .. pretty("Поиск", "find") ..
    pretty("Вырезать", "cut") .. pretty("Вставить", "uncut") .. pretty("Строка", "goto_line")
end

local function drawStatus()
  local right = string.format("%d,%d", cy, cx)
  if #cutBuffer > 0 then right = string.format("(#%d) %s", #cutBuffer, right) end
  right = text.padLeft(right, 10)
  local left = status or helpText()
  S:fill(1, H, W, 1, " ", S_FG, S_BG)
  local room = W - #right - 1
  if unicode.wlen(left) > room then left = unicode.wtrunc(left, room + 1) end
  if left ~= "" then S:set(1, H, left, S_FG, S_BG) end
  S:set(W - #right + 1, H, right, S_FG, S_BG)
end

local function drawCursor()
  local y = cy - scrollY
  local col = dispCol(curLine(), cx) - scrollX
  if y < 1 or y > rows or col < 1 or col > W then return end
  local ch = unicode.sub(curLine(), cx, cx)
  if ch == "" or ch == "\t" then ch = " " end
  S:set(col, y, ch, BG, readonly and 0x88AAFF or CUR)
end

local lastCursorRow

local function redraw()
  if fullRedraw then
    for i = scrollY + 1, math.min(scrollY + rows, math.max(#buffer, scrollY + rows)) do
      drawRow(i)
    end
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
  drawCursor()
  S:present()
end

------------------------------------------------------------------ движение

local function clampScroll()
  local before = scrollX .. ":" .. scrollY
  if cy - scrollY < 1 then scrollY = cy - 1 end
  if cy - scrollY > rows then scrollY = cy - rows end
  if scrollY < 0 then scrollY = 0 end
  local col = dispCol(curLine(), cx)
  if col - scrollX < 1 then scrollX = col - 1 end
  if col - scrollX > W then scrollX = col - W end
  if scrollX < 0 then scrollX = 0 end
  if before ~= (scrollX .. ":" .. scrollY) then fullRedraw = true end
end

local function setCursor(nx, ny)
  cy = math.max(1, math.min(#buffer, math.floor(ny)))
  cx = math.max(1, math.min(unicode.len(curLine()) + 1, math.floor(nx)))
  clampScroll()
end

local function home() setCursor(1, cy) end
local function ende() setCursor(unicode.len(curLine()) + 1, cy) end

local function left()
  if cx > 1 then
    setCursor(cx - 1, cy)
    return true
  elseif cy > 1 then
    cy = cy - 1
    ende()
    return true
  end
end

local function right()
  if cx <= unicode.len(curLine()) then
    setCursor(cx + 1, cy)
  elseif cy < #buffer then
    setCursor(1, cy + 1)
  end
end

local function up(n) setCursor(cx, cy - (n or 1)) cutting = false end
local function down(n) setCursor(cx, cy + (n or 1)) cutting = false end

------------------------------------------------------------------ правка

local function touch(i)
  modified = true
  status = nil
  invalidate(i)
  markDirty(i)
end

local function insert(value)
  if not value or value == "" then return end
  local line = curLine()
  buffer[cy] = unicode.sub(line, 1, cx - 1) .. value .. unicode.sub(line, cx)
  touch(cy)
  setCursor(cx + unicode.len(value), cy)
end

local function enter()
  local line = curLine()
  table.insert(buffer, cy + 1, unicode.sub(line, cx))
  buffer[cy] = unicode.sub(line, 1, cx - 1)
  touch(cy)
  fullRedraw = true
  setCursor(1, cy + 1)
  cutting = false
end

local function delete(fullLine)
  if fullLine then
    if #buffer > 1 then
      table.remove(buffer, cy)
    else
      buffer[1] = ""
    end
    touch(cy)
    fullRedraw = true
    setCursor(1, cy)
    return
  end
  local line = curLine()
  if cx <= unicode.len(line) then
    buffer[cy] = unicode.sub(line, 1, cx - 1) .. unicode.sub(line, cx + 1)
    touch(cy)
  elseif cy < #buffer then
    buffer[cy] = line .. table.remove(buffer, cy + 1)
    touch(cy)
    fullRedraw = true
  end
end

------------------------------------------------------------------ строка снизу

--- Прочитать строку в служебной строке экрана. Возвращает nil при отмене.
--- onChange вызывается после каждого изменения (для поиска на лету).
local function readLine(label, initial, onChange)
  local buf = initial or ""
  while true do
    status = label .. buf
    drawStatus()
    S:set(math.min(W, unicode.wlen(label) + unicode.wlen(buf) + 1), H, "_", S_BG, S_FG)
    S:present()
    local e, addr, char, code = event.pull()
    if e == "interrupted" then status = nil return nil end
    if e == "key_down" and addr == term.keyboard() then
      if code == keys.enter or code == keys.numpadenter then
        status = nil
        return buf
      elseif code == 1 then
        status = nil
        return nil
      elseif code == keys.back then
        buf = unicode.sub(buf, 1, -2)
        if onChange then onChange(buf) end
      elseif char and not keyboard.isControl(char) then
        buf = buf .. unicode.char(char)
        if onChange then onChange(buf) end
      end
    elseif e == "clipboard" then
      buf = buf .. tostring(char):gsub("\n.*", "")
      if onChange then onChange(buf) end
    end
  end
end

------------------------------------------------------------------ поиск

local findText = ""

local function searchFrom(bx, by)
  if findText == "" then return end
  local low = unicode.lower(findText)
  for step = 0, #buffer do
    local i = (by - 1 + step) % #buffer + 1
    -- find работает по байтам, а курсор считает символы
    local from = step == 0 and #unicode.sub(buffer[i], 1, bx - 1) + 1 or 1
    local at = unicode.lower(buffer[i]):find(low, from, true)
    if at then
      setCursor(unicode.len(buffer[i]:sub(1, at - 1)) + 1, i)
      fullRedraw = true
      return true
    end
  end
  status = "не найдено: " .. findText
end

local function find(again)
  if again and findText ~= "" then
    searchFrom(cx + 1, cy)
    return
  end
  local q = readLine("Поиск: ", "", nil)
  if q and q ~= "" then
    findText = q
    searchFrom(cx, cy)
  end
end

------------------------------------------------------------------ файл

local function save()
  if readonly then return end
  local new = not fs.exists(filename)
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
    return
  end
  local chars = 0
  for i, line in ipairs(buffer) do
    f:write(i == 1 and line or ("\n" .. line))
    chars = chars + unicode.len(line)
  end
  f:write("\n")
  f:close()
  modified = false
  status = string.format(new and [["%s" [новый] %dL,%dC записано]] or [["%s" %dL,%dC записано]],
    fs.name(filename), #buffer, chars)
  if not new then fs.remove(backup) end
end

------------------------------------------------------------------ команды

local handlers
handlers = {
  left = left,
  right = right,
  up = up,
  down = down,
  home = home,
  eol = ende,
  pageUp = function() up(rows - 1) end,
  pageDown = function() down(rows - 1) end,

  backspace = function() if not readonly and left() then delete() end end,
  delete = function() if not readonly then delete() end end,
  deleteLine = function() if not readonly then delete(true) end end,
  newline = function() if not readonly then enter() end end,

  save = save,
  close = function() running = false end,
  find = function() find(false) end,
  findnext = function() find(true) end,
  cut = function()
    if readonly then return end
    if not cutting then cutBuffer = {} end
    cutBuffer[#cutBuffer + 1] = curLine()
    delete(true)
    cutting = true
    home()
  end,
  uncut = function()
    if readonly then return end
    home()
    for _, line in ipairs(cutBuffer) do
      insert(line)
      enter()
    end
  end,
  goto_line = function()
    local s = readLine("Строка: ", "", nil)
    local n = tonumber(s)
    if n then
      setCursor(1, n)
      fullRedraw = true
    end
  end,
}

local function bindFor(code)
  if type(config.keybinds) ~= "table" then return end
  local result, weight = nil, 0
  local kbd = term.keyboard()
  for command, binds in pairs(config.keybinds) do
    if type(binds) == "table" and handlers[command] then
      for _, bind in ipairs(binds) do
        if type(bind) == "table" then
          local alt, control, shift, key = false, false, false, nil
          for _, v in ipairs(bind) do
            if v == "alt" then alt = true
            elseif v == "control" then control = true
            elseif v == "shift" then shift = true
            else key = v end
          end
          if alt == not not keyboard.isAltDown(kbd) and
             control == not not keyboard.isControlDown(kbd) and
             shift == not not keyboard.isShiftDown(kbd) and
             code == keys[key] and #bind > weight then
            weight = #bind
            result = handlers[command]
          end
        end
      end
    end
  end
  -- Ctrl+L работает и со старым /etc/edit.cfg, где о нём ещё не знали
  if not result and code == keys.l and keyboard.isControlDown(kbd) then
    return handlers.goto_line
  end
  return result
end

local function onKeyDown(char, code)
  local handler = bindFor(code)
  if handler then
    handler()
  elseif readonly and code == keys.q then
    running = false
  elseif not readonly then
    if char and not keyboard.isControl(char) then
      insert(unicode.char(char))
    elseif char == 9 then
      insert("  ")
    end
  end
end

local function onClipboard(value)
  if readonly then return end
  value = value:gsub("\r\n", "\n")
  local start = 1
  local at = value:find("\n", 1, true)
  while at do
    insert(text.detab(value:sub(start, at - 1), 2))
    enter()
    start = at + 1
    at = value:find("\n", start, true)
  end
  insert(text.detab(value:sub(start), 2))
end

------------------------------------------------------------------ загрузка

do
  local f = io.open(filename)
  local chars = 0
  if f then
    for line in f:lines() do
      buffer[#buffer + 1] = line
      chars = chars + unicode.len(line)
    end
    f:close()
  end
  if #buffer == 0 then buffer[1] = "" end
  if f then
    status = string.format(readonly and [["%s" [только чтение] %dL,%dC]] or [["%s" %dL,%dC]],
      fs.name(filename), #buffer, chars)
  else
    status = string.format([==["%s" [новый файл]]==], fs.name(filename))
  end
end

redraw()

while running do
  local e, addr, a, b, c = event.pull()
  if e == "interrupted" then break end
  if addr == term.keyboard() or addr == term.screen() then
    if e == "key_down" then
      onKeyDown(a, b)
      redraw()
    elseif e == "clipboard" then
      onClipboard(a)
      redraw()
    elseif e == "touch" or e == "drag" then
      local gx, gy = term.getGlobalArea()
      local col, row = a - gx + 1, b - gy + 1
      if col >= 1 and row >= 1 and col <= W and row <= rows then
        setCursor(charAt(buffer[row + scrollY] or "", col + scrollX), row + scrollY)
        redraw()
      end
    elseif e == "scroll" then
      setCursor(cx, cy - (c or 0) * 12)
      fullRedraw = true
      redraw()
    end
  end
end

S:close()
term.setCursorBlink(true)
term.clear()
