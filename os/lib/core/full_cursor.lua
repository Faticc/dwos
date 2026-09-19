-- Курсор: мышь, подсказки по Tab и строка без переноса (горизонтальная).
local core_cursor = require("core/cursor")
local unicode = require("unicode")
local kb = require("keyboard")
local tty = require("tty")

core_cursor.horizontal = {}
local H = core_cursor.horizontal

function core_cursor.touch(cursor, gx, gy)
  if cursor.len > 0 then
    local win = tty.window
    gx, gy = gx - win.dx, gy - win.dy
    while true do
      local x, y, d = win.x, win.y, win.width
      local dx = ((gy * d + gx) - (y * d + x))
      if dx == 1 then
        dx = unicode.wlen(unicode.sub(cursor.data, cursor.index + 1, cursor.index + 1)) == 2 and 0 or dx
      end
      if dx == 0 then
        break
      end
      cursor:move(dx > 0 and 1 or -1)
      if x == win.x and y == win.y then
        break
      end
    end
  end
end

function core_cursor.tab(cursor)
  local hints = cursor.hint
  if not hints then return end
  if not cursor.cache then
    cursor.cache = type(hints) == "table" and hints or hints(cursor.data, cursor.index + 1) or {}
    cursor.cache.i = -1
  end
  local cache = cursor.cache
  if #cache == 1 and cache.i == 0 then
    -- вариант был один, просят следующий: подсказки от него
    cursor.cache = hints(cache[1], cursor.index + 1)
    if not cursor.cache then return end
    cursor.cache.i = -1
    cache = cursor.cache
  end
  local change = kb.isShiftDown() and -1 or 1
  cache.i = (cache.i + change) % math.max(#cache, 1)
  local nxt = cache[cache.i + 1]
  if nxt then
    local tail = unicode.len(cursor.data) - cursor.index
    cursor:move(cursor.len)
    cursor:update(-cursor.len)
    cursor:update(nxt, -tail)
  end
end

function H:scroll(num, final_index)
  self:move(self.vindex - self.index) -- к левому краю
  self.vindex = self.vindex + num
  self.index = self.index + num
  self:echo("\0277" .. unicode.sub(self.data, self.index + 1) .. "\27[K\0278")
  self:move(final_index - self.index)
end

function H:echo(arg, num)
  local w = tty.window
  w.nowrap = self.nowrap
  if arg == "" then -- прокрутка по запросу
    local width = w.width
    if w.x >= width then
      -- важна ширина следующего символа
      width = width - math.max(unicode.wlen(unicode.sub(self.data, self.index + 1, self.index + 1)) - 1, 0)
      if w.x > width then
        local s1 = unicode.sub(self.data, self.vindex + 1, self.index)
        self:scroll(unicode.len(unicode.wtrunc(s1, w.x - width + 1)), self.index)
      end
    end
  elseif arg == kb.keys.left then
    if self.index < self.vindex then
      local s2 = unicode.sub(self.data, self.index + 1)
      w.x = w.x - num + unicode.wlen(unicode.sub(s2, 1, self.vindex - self.index))
      local current_x = w.x
      self:echo(s2)
      w.x = current_x
      self.vindex = self.index
      return true
    end
  elseif arg == kb.keys.right then
    w.x = w.x + num
    return self:echo("") -- прокрутка
  end
  return core_cursor.vertical.echo(self, arg, num)
end

function H:update(arg, back)
  if back then
    -- без переноса хватает вывести arg и вернуться
    self:update(arg, false)
    local x = tty.window.x
    self:echo(arg)
    tty.window.x = x
    self:move(self.len - self.index + back)
    return true
  elseif not arg then -- сброс
    self.nowrap = true
    self.clear = "\27[K"
    self.vindex = 0
  end
  return core_cursor.vertical.update(self, arg, back)
end

setmetatable(H, { __index = core_cursor.vertical })
