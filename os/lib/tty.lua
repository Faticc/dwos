local unicode = require("unicode")
local event = require("event")
local component = require("component")
local computer = require("computer")

-- Терминал: окно на экране, курсор и вывод текста с escape-кодами vt100.
local tty = {}
tty.window = {
  fullscreen = true,
  blink = true,
  dx = 0,
  dy = 0,
  x = 1,
  y = 1,
  output_buffer = "",
}

tty.stream = {}

local screen_cache = {}
local function screen_reset(gpu, addr)
  screen_cache[addr or gpu.getScreen() or false] = nil
end

event.listen("screen_resized", screen_reset)

function tty.getViewport()
  local window = tty.window
  local screen = tty.screen()
  if window.fullscreen and screen and not screen_cache[screen] then
    screen_cache[screen] = true
    window.width, window.height = window.gpu.getViewport()
  end
  return window.width, window.height, window.dx, window.dy, window.x, window.y
end

function tty.setViewport(width, height, dx, dy, x, y)
  checkArg(1, width, "number")
  checkArg(2, height, "number")
  local window = tty.window
  dx, dy, x, y = dx or 0, dy or 0, x or 1, y or 1
  window.width, window.height, window.dx, window.dy, window.x, window.y = width, height, dx, dy, x, y
end

function tty.gpu()
  return tty.window.gpu
end

function tty.clear()
  tty.stream.scroll(math.huge)
  tty.setCursor(1, 1)
end

function tty.isAvailable()
  local gpu = tty.gpu()
  return not not (gpu and gpu.getScreen())
end

-- Не вызывать напрямую: io.read или term.read
function tty.stream.read()
  local core = require("core/cursor")
  local cursor = core.new(tty.window.cursor)
  -- курсор нужен окну и тогда, когда его не задали: перенос широких символов
  tty.window.cursor = cursor
  local ok, result, reason = xpcall(core.read, debug.traceback, cursor)
  if not ok or not result then
    pcall(cursor.update, cursor)
  end
  return select(2, assert(ok, result, reason))
end

local DELIMS = "[\27\t\r\n\a\b\v\15]"

-- Не вызывать напрямую: io.write или term.write
function tty.stream:write(value)
  local gpu = tty.gpu()
  if not gpu then
    return
  end
  local window = tty.window
  local cursor = window.cursor or {}
  cursor.sy = cursor.sy or 0
  cursor.tails = cursor.tails or {}
  local vt100 = require("vt100")
  local beeped
  local uptime = computer.uptime
  local last_sleep = uptime()

  -- вывод идёт по указателю pos, строка не режется на каждом шаге
  local buf = window.output_buffer .. value
  local pos, len = 1, #buf
  while true do
    if uptime() - last_sleep > 3 then
      os.sleep(0)
      last_sleep = uptime()
    end

    local prefix = ""
    if buf:byte(pos) == 27 then
      local consumed, literal = vt100.consume(window, buf, pos)
      if not consumed then
        break -- последовательность ещё не пришла целиком
      end
      pos = pos + consumed
      prefix = literal or ""
    end

    -- прокрутка перед следующей строкой (вывод мог быть одним переводом строки)
    cursor.sy = cursor.sy + self.scroll()
    if pos > len and prefix == "" then
      break
    end

    local x, y = window.x, window.y
    local width = window.width
    local d = buf:find(DELIMS, pos)
    local delim = d and buf:sub(d, d)
    local stop = d and d - 1 or len
    -- на строку влезает не больше width символов, а символ - до 4 байт:
    -- дальше смотреть незачем, хвост всё равно уйдёт на следующую строку
    local limit = pos + width * 4 - 1
    local cut = stop > limit
    local segment = prefix .. buf:sub(pos, cut and limit or stop)
    local consumed = stop - pos + 1

    if segment ~= "" then
      local tail = ""
      local remaining = width - x + 1
      -- ASCII меряется длиной строки, без вызова unicode
      local ascii = not segment:find("[\128-\255]")
      local wlen_needed = ascii and #segment or unicode.wlen(segment)
      if cut or remaining < wlen_needed then
        if ascii then
          segment = segment:sub(1, math.max(remaining, 0))
          wlen_needed = #segment
        else
          segment = unicode.wtrunc(segment, remaining + 1)
          wlen_needed = unicode.wlen(segment)
        end
        tail = wlen_needed < remaining and " " or ""
        cursor.tails[y + window.dy - cursor.sy] = tail
        if not window.nowrap then
          consumed = #segment - #prefix
          if consumed < 0 then consumed = 0 end
          delim = "\n" -- перенос как перевод строки
          d = nil
        end
      end
      gpu.set(x + window.dx, y + window.dy, segment .. tail)
      x = x + wlen_needed
    end

    pos = pos + consumed
    if d then pos = d + 1 end

    if delim == "\t" then
      x = ((x - 1) - ((x - 1) % 8)) + 9
    elseif delim == "\r" then
      x = 1
    elseif delim == "\n" then
      x = 1
      y = y + 1
    elseif delim == "\b" then
      x = x - 1
    elseif delim == "\v" then
      y = y + 1
    elseif delim == "\a" and not beeped then
      computer.beep()
      beeped = true
    elseif delim == "\27" then
      pos = pos - 1 -- escape разберём на следующем круге
    end

    window.x, window.y = x, y
  end
  window.output_buffer = pos <= len and buf:sub(pos) or ""
  return cursor.sy
end

function tty.getCursor()
  local window = tty.window
  return window.x, window.y
end

function tty.setCursor(x, y)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  local window = tty.window
  window.x, window.y = x, y
end

local gpu_intercept = {}
function tty.bind(gpu)
  checkArg(1, gpu, "table")
  if not gpu_intercept[gpu] then
    gpu_intercept[gpu] = true
    -- разрешение может смениться раньше, чем дойдёт screen_resized
    local setr, setv = gpu.setResolution, gpu.setViewport
    gpu.setResolution = function(...)
      screen_reset(gpu)
      return setr(...)
    end
    gpu.setViewport = function(...)
      screen_reset(gpu)
      return setv(...)
    end
  end
  local window = tty.window
  if window.gpu ~= gpu then
    window.gpu = gpu
    window.keyboard = nil -- без своей клавиатуры - первая клавиатура экрана
    tty.getViewport()
  end
  screen_reset(gpu)
end

function tty.keyboard()
  -- должна работать и без окна (без видеокарты)
  local window = tty.window
  if window.keyboard then
    return window.keyboard
  end
  local system_keyboard = component.isAvailable("keyboard") and component.keyboard
  system_keyboard = system_keyboard and system_keyboard.address or "no_system_keyboard"
  local screen = tty.screen()
  if not screen then
    return system_keyboard
  end
  if component.isAvailable("screen") and component.screen.address == screen then
    window.keyboard = system_keyboard
  else
    -- getKeyboards долгий (синхронный вызов): только раз, дальше из кеша
    window.keyboard = component.invoke(screen, "getKeyboards")[1] or system_keyboard
  end
  return window.keyboard
end

function tty.screen()
  local gpu = tty.gpu()
  if not gpu then
    return nil
  end
  return gpu.getScreen()
end

function tty.stream.scroll(lines)
  local gpu = tty.gpu()
  if not gpu then
    return 0
  end
  local width, height, dx, dy, x, y = tty.getViewport()

  -- без числа - вернуть курсор в окно; <0 текст вниз, >0 текст вверх
  if not lines then
    if y < 1 then
      lines = y - 1
    elseif y > height then
      lines = y - height
    else
      return 0
    end
  end

  lines = math.max(math.min(lines, height), -height)
  local abs_lines = math.abs(lines)
  local box_height = height - abs_lines
  local fill_top = dy + 1 + (lines < 0 and 0 or box_height)

  if box_height > 0 then
    gpu.copy(dx + 1, dy + 1 + math.max(0, lines), width, box_height, 0, -lines)
  end
  gpu.fill(dx + 1, fill_top, width, abs_lines, " ")

  tty.setCursor(x, math.max(1, math.min(y, height)))
  return lines
end

local function bfd() return nil, "tty: invalid operation" end
tty.stream.close = bfd
tty.stream.seek = bfd
tty.stream.handle = "tty"

return tty
