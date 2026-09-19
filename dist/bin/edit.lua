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
  unindent = { { "shift", "tab" } },
}
local function loadConfig()
  local env = {}
  local config = loadfile("/etc/edit.cfg", nil, env)
  if config then pcall(config) end
  if type(env.keybinds) ~= "table" then env.keybinds = {} end
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
local FG, BG = 0xD0D0D0, 0x000000
local C_KW, C_STR, C_NUM, C_CMT, C_BLT, C_OP = 0x66CCFF, 0x88DD88, 0xFFAA00, 0x707070, 0xFF9966, 0xBBBBBB
local BAR_BG, BAR_FG, BAR_NAME = 0x1B2A3A, 0x7A8A98, 0xE1E1E1
local BAR_POS, BAR_MARK, BAR_MSG = 0x66CCFF, 0xFFAA00, 0x88DD88
local GUT, GUT_CUR, CUR = 0x4E5D6B, 0x9AA8B4, 0xFFFFFF
local SEL, FIND, PAIR = 0x2D4A66, 0xFFAA00, 0x4E7A2D
local POP_BG, POP_FG, POP_SEL = 0x22323F, 0xC8D2DA, 0x2D4A66
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
local lua = filename:sub(-4) == ".lua" or filename:sub(-4) == ".cfg"
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
local gpu = tty.gpu()
term.clear()
term.setCursorBlink(false)
local S = gfx.surface(gpu)
local W, H = S.w, S.h
local rows = H - 1
local buffer = {}
local carry, carryTop = {}, 1
local cx, cy = 1, 1
local scrollX, scrollY = 0, 0
local running = true
local anchor = nil
local clip = {}
local status, dirty = nil, {}
local fullRedraw, modified = true, false
local match, pair = nil, nil
local GW = 2
local function curLine() return buffer[cy] or "" end
local function textW() return W - GW end
local function dispCol(line, i)
  return unicode.wlen(unicode.sub(line, 1, i - 1)) + 1
end
local function charAt(line, col)
  if col > unicode.wlen(line) then return unicode.len(line) + 1 end
  return unicode.len(unicode.wtrunc(line, col)) + 1
end
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
  if not lua then return { { buffer[i] or "", FG } } end
  ensureCarry(i - 1)
  return (tokenize(buffer[i] or "", carry[i]))
end
local function markDirty(i) dirty[i] = true end
local function selection()
  if not anchor then return nil end
  local l1, c1, l2, c2 = anchor[2], anchor[1], cy, cx
  if l1 > l2 or (l1 == l2 and c1 > c2) then
    l1, c1, l2, c2 = l2, c2, l1, c1
  end
  if l1 == l2 and c1 == c2 then return nil end
  return l1, c1, l2, c2
end
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
local undoStack, redoStack = {}, {}
local pending = nil
local UNDO_MAX = 120
local function apply(at, count, new)
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
local function splice(at, count, new, kind)
  local old = {}
  for i = at, at + count - 1 do old[#old + 1] = buffer[i] or "" end
  local merge = pending and kind and pending.kind == kind and pending.at == at
    and #pending.new == 1 and count == 1 and #new == 1
  if merge then
    pending.new = new
  else
    pending = { at = at, old = old, new = new, kind = kind, cx = cx, cy = cy }
    undoStack[#undoStack + 1] = pending
    if #undoStack > UNDO_MAX then table.remove(undoStack, 1) end
    redoStack = {}
  end
  apply(at, count, new)
  modified = true
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
  apply(entry.at, #entry.new, entry.old)
  entry.old, entry.new = entry.new, entry.old
  local wasX, wasY = entry.cx, entry.cy
  entry.cx, entry.cy = cx, cy
  to[#to + 1] = entry
  commit()
  anchor = nil
  setCursor(wasX, wasY)
  invalidate(entry.at)
  modified = true
  fullRedraw = true
end
local function drawRow(i)
  local y = i - scrollY
  if y < 1 or y > rows then return end
  S:fill(1, y, W, 1, " ", FG, BG)
  if not buffer[i] then return end
  local n = tostring(i)
  S:set(GW - #n, y, n, i == cy and GUT_CUR or GUT, BG)
  local sl1, sc1, sl2, sc2 = selection()
  local from, to
  if sl1 and i >= sl1 and i <= sl2 then
    from = (i == sl1) and sc1 or 1
    to = (i == sl2) and sc2 or (unicode.len(buffer[i]) + 2)
  end
  local TW, col, at = textW(), 1, 1
  for _, t in ipairs(tokensFor(i)) do
    local piece, color = t[1], t[2]
    local len = unicode.len(piece)
    local parts
    if from then
      parts = {}
      local pos, rest = at, piece
      local function cut(upto)
        local k = upto - pos
        if k > 0 and k < unicode.len(rest) then
          parts[#parts + 1] = { unicode.sub(rest, 1, k), color,
            (pos >= from and pos < to) and SEL or BG }
          rest = unicode.sub(rest, k + 1)
          pos = upto
        end
      end
      cut(from)
      cut(to)
      parts[#parts + 1] = { rest, color, (pos >= from and pos < to) and SEL or BG }
    else
      parts = { { piece, color, BG } }
    end
    for _, part in ipairs(parts) do
      local s, fg, bg = part[1], part[2], part[3]
      local wl = unicode.wlen(s)
      if col + wl - 1 > scrollX and col <= scrollX + TW then
        local x = col - scrollX
        if x < 1 then
          s = removePrefix(s, scrollX - col + 1)
          x = 1
        end
        s = fit(s, TW - x + 1)
        if s ~= "" then S:set(GW + x, y, s, fg, bg) end
      end
      col = col + wl
    end
    at = at + len
  end
  if match and match.line == i then
    local x = dispCol(buffer[i], match.from) - scrollX
    local txt = unicode.sub(buffer[i], match.from, match.from + match.len - 1)
    if x >= 1 and x <= TW and txt ~= "" then
      S:set(GW + x, y, fit(txt, TW - x + 1), BG, FIND)
    end
  end
  if pair then
    for _, p in ipairs(pair) do
      if p[2] == i then
        local x = dispCol(buffer[i], p[1]) - scrollX
        if x >= 1 and x <= TW then
          S:set(GW + x, y, unicode.sub(buffer[i], p[1], p[1]), 0xFFFFFF, PAIR)
        end
      end
    end
  end
end
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
  pretty("поиск", "find")
  pretty("отмена", "undo")
  out[#out + 1] = "Tab дополнить"
  return table.concat(out, "  ")
end
local HELP = helpText()
local function drawStatus()
  S:fill(1, H, W, 1, " ", BAR_FG, BAR_BG)
  local right = string.format("%d,%d", cy, cx)
  local l1, _, l2 = selection()
  if l1 then
    right = string.format("выд %d  %s", l2 - l1 + 1, right)
  elseif #clip > 0 then
    right = string.format("#%d  %s", #clip, right)
  end
  S:set(W - #right, H, right, BAR_POS, BAR_BG)
  local name = fs.name(filename)
  S:set(2, H, name, BAR_NAME, BAR_BG)
  local at = 2 + unicode.wlen(name)
  local mark = readonly and " [чтение]" or modified and " *" or ""
  if mark ~= "" then
    S:set(at, H, mark, BAR_MARK, BAR_BG)
    at = at + unicode.wlen(mark)
  end
  local mid = status or HELP
  local room = W - #right - at - 2
  if room > 0 then
    mid = fit(mid, room)
    if mid ~= "" then S:set(at + 2, H, mid, status and BAR_MSG or BAR_FG, BAR_BG) end
  end
end
local function drawCursor()
  local y = cy - scrollY
  local col = dispCol(curLine(), cx) - scrollX
  if y < 1 or y > rows or col < 1 or col > textW() then return end
  local ch = unicode.sub(curLine(), cx, cx)
  if ch == "" or ch == "\t" then ch = " " end
  S:set(GW + col, y, ch, BG, readonly and 0x88AAFF or CUR)
end
local lastCursorRow
local function syncGutter()
  local w = #tostring(math.max(#buffer, 1)) + 1
  if w ~= GW then
    GW = w
    fullRedraw = true
  end
end
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
local function clampScroll()
  local before = scrollX .. ":" .. scrollY
  if cy - scrollY < 1 then scrollY = cy - 1 end
  if cy - scrollY > rows then scrollY = cy - rows end
  if scrollY < 0 then scrollY = 0 end
  local col, TW = dispCol(curLine(), cx), textW()
  if col - scrollX < 1 then scrollX = col - 1 end
  if col - scrollX > TW then scrollX = col - TW end
  if scrollX < 0 then scrollX = 0 end
  if before ~= (scrollX .. ":" .. scrollY) then fullRedraw = true end
end
local function redraw()
  syncGutter()
  clampScroll()
  if fullRedraw or anchor then
    for i = scrollY + 1, scrollY + rows do drawRow(i) end
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
  elseif cy > 1 then
    move(math.huge, cy - 1, keep)
    return true
  end
end
local function right(keep)
  if cx <= unicode.len(curLine()) then move(cx + 1, cy, keep)
  elseif cy < #buffer then move(1, cy + 1, keep) end
end
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
local function readLine(label)
  local buf = ""
  while true do
    S:fill(1, H, W, 1, " ", BAR_FG, BAR_BG)
    S:set(2, H, label, BAR_MARK, BAR_BG)
    local at = 2 + unicode.wlen(label)
    local room = W - at - 1
    if room > 0 then
      local shown = buf
      while unicode.wlen(shown) > room do shown = unicode.sub(shown, 2) end
      if shown ~= "" then S:set(at, H, shown, BAR_NAME, BAR_BG) end
      S:set(at + unicode.wlen(shown), H, "_", BAR_BG, BAR_POS)
    end
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
        buf = unicode.sub(buf, 1, -2)
      elseif char and not keyboard.isControl(char) then
        buf = buf .. unicode.char(char)
      end
    elseif e == "clipboard" then
      buf = buf .. tostring(char):gsub("\n.*", "")
    end
  end
end
local function ask(question)
  S:fill(1, H, W, 1, " ", BAR_FG, BAR_BG)
  S:set(2, H, fit(question, W - 4), BAR_MARK, BAR_BG)
  S:present()
  while true do
    local e, addr, char, code = event.pull()
    if e == "key_down" and addr == term.keyboard() then
      if code == keys.y or char == 121 then return true end
      if code == keys.n or char == 110 then return false end
      if code == 1 then return nil end
    end
  end
end
local findText = ""
local function searchFrom(bx, by)
  if findText == "" then return end
  local low = unicode.lower(findText)
  for step = 0, #buffer do
    local i = (by - 1 + step) % #buffer + 1
    local from = step == 0 and #unicode.sub(buffer[i], 1, bx - 1) + 1 or 1
    local at = unicode.lower(buffer[i]):find(low, from, true)
    if at then
      setCursor(unicode.len(buffer[i]:sub(1, at - 1)) + 1, i)
      match = { line = i, from = cx, len = unicode.len(findText) }
      fullRedraw = true
      return true
    end
  end
  status = "не найдено: " .. findText
end
local function find(again)
  if match then
    markDirty(match.line)
    match = nil
  end
  if again and findText ~= "" then
    searchFrom(cx + 1, cy)
    return
  end
  local q = readLine("Поиск: ")
  if q and q ~= "" then
    findText = q
    searchFrom(cx, cy)
  end
end
local function chainBefore()
  local upto = unicode.sub(curLine(), 1, cx - 1)
  return upto:match("[%a_][%w_%.:]*$")
end
local function resolve(path)
  local cur
  for i, name in ipairs(path) do
    if i == 1 then
      cur = rawget(_G, name) or package.loaded[name]
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
local function candidates(chain)
  local path, frag = {}, chain
  local dot = chain:match("^(.*)[%.:][%w_]*$")
  if dot then
    frag = chain:match("[%.:]([%w_]*)$") or ""
    for name in dot:gmatch("[^%.:]+") do path[#path + 1] = name end
  end
  local all, seen = {}, {}
  if #path > 0 then
    local t = resolve(path)
    if type(t) ~= "table" then return nil end
    keysOf(t, all, seen)
  else
    for _, line in ipairs(buffer) do
      for word in line:gmatch("[%a_][%w_]*") do
        if not seen[word] then seen[word] = true all[#all + 1] = word end
      end
    end
    for w in pairs(KEYWORD) do if not seen[w] then seen[w] = true all[#all + 1] = w end end
    for w in pairs(BUILTIN) do if not seen[w] then seen[w] = true all[#all + 1] = w end end
    keysOf(_G, all, seen)
    keysOf(package.loaded, all, seen)
  end
  local out, low = {}, frag:lower()
  for _, w in ipairs(all) do
    if w ~= frag and w:lower():sub(1, #low) == low then out[#out + 1] = w end
  end
  table.sort(out, function(a, b)
    if #a ~= #b then return #a < #b end
    return a < b
  end)
  return out, frag
end
local function popup(list, frag)
  local sel, top, base = 1, 1, frag
  while true do
    local shown, low = {}, frag:lower()
    for _, w in ipairs(list) do
      if w:lower():sub(1, #low) == low then shown[#shown + 1] = w end
    end
    if #shown == 0 then
      fullRedraw = true
      return nil
    end
    if sel > #shown then sel = #shown end
    local h = math.min(8, #shown)
    if sel < top then top = sel end
    if sel > top + h - 1 then top = sel - h + 1 end
    local width = 0
    for i = top, math.min(top + h - 1, #shown) do
      width = math.max(width, unicode.wlen(shown[i]))
    end
    width = math.min(width + 3, W - 4)
    local x = math.max(1, math.min(GW + dispCol(curLine(), cx) - scrollX, W - width))
    local y = cy - scrollY + 1
    if y + h - 1 > rows then y = math.max(1, cy - scrollY - h) end
    for i = 0, h - 1 do
      local bg = (top + i == sel) and POP_SEL or POP_BG
      S:fill(x, y + i, width, 1, " ", POP_FG, bg)
      S:set(x + 1, y + i, fit(shown[top + i], width - 2), POP_FG, bg)
    end
    if #shown > h then S:set(x + width - 1, y, "+", BAR_POS, POP_SEL) end
    drawStatus()
    S:present()
    local e, addr, char, code = event.pull()
    if e == "key_down" and addr == term.keyboard() then
      if code == keys.up then
        sel = sel > 1 and sel - 1 or #shown
      elseif code == keys.down then
        sel = sel < #shown and sel + 1 or 1
      elseif code == keys.enter or code == keys.numpadenter or code == keys.tab then
        fullRedraw = true
        return shown[sel], base
      elseif code == keys.back then
        if unicode.len(frag) <= unicode.len(base) then
          fullRedraw = true
          return nil
        end
        frag = unicode.sub(frag, 1, -2)
        sel = 1
      elseif char and char > 32 and not keyboard.isControl(char) and unicode.char(char):match("[%w_]") then
        frag = frag .. unicode.char(char)
        sel = 1
      else
        fullRedraw = true
        return nil
      end
    elseif e ~= "key_up" and e ~= "interrupted" then
      fullRedraw = true
      return nil
    end
  end
end
local function complete()
  local chain = chainBefore()
  if not chain then return false end
  local list, frag = candidates(chain)
  if not list or #list == 0 then
    status = "нечем дополнить"
    return true
  end
  local pick, base = list[1], frag
  if #list > 1 then
    pick, base = popup(list, frag)
    if not pick then return true end
  end
  local n = unicode.len(base or frag)
  if n > 0 then
    local line = curLine()
    splice(cy, 1, { unicode.sub(line, 1, cx - n - 1) .. unicode.sub(line, cx) })
    setCursor(cx - n, cy)
  end
  insert(pick)
  commit()
  return true
end
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
local function save()
  if readonly then return true end
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
    return false
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
  return true
end
local handlers = {
  left = function(k) left(k) end,
  right = function(k) right(k) end,
  up = function(k) move(cx, cy - 1, k) end,
  down = function(k) move(cx, cy + 1, k) end,
  home = function(k) home(k) end,
  eol = function(k) ende(k) end,
  pageUp = function(k) move(cx, cy - (rows - 1), k) end,
  pageDown = function(k) move(cx, cy + (rows - 1), k) end,
  backspace = function()
    if readonly then return end
    if deleteSelection() then return end
    if left() then delete() end
  end,
  delete = function() if not readonly then delete() end end,
  deleteLine = function() if not readonly then delete(true) end end,
  newline = function() if not readonly then enter() end end,
  save = save,
  close = function()
    if modified and not readonly then
      local answer = ask("Файл изменён. Сохранить перед выходом? [Y/n, Esc - остаться]")
      if answer == nil then
        status = nil
        return
      end
      if answer and not save() then return end
    end
    running = false
  end,
  find = function() find(false) end,
  findnext = function() find(true) end,
  cut = function()
    if readonly then return end
    if selection() then
      clip = selectedText()
      deleteSelection()
      status = "вырезано строк: " .. #clip
      return
    end
    clip[#clip + 1] = curLine()
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
    elseif not complete() then
      insert("  ")
    end
  end,
  unindent = function() if not readonly then indentSelection(true) end end,
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
      if shift and not anchor then anchor = { cx, cy } end
      handler(shift)
    else
      handler()
    end
  elseif readonly and code == keys.q then
    running = false
  elseif not readonly and char and not keyboard.isControl(char) then
    local ch = unicode.char(char)
    local nextCh = unicode.sub(curLine(), cx, cx)
    if (CLOSE[ch] or ch == '"' or ch == "'") and nextCh == ch then
      move(cx + 1, cy)
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
    end
  end
end
local function onClipboard(value)
  if readonly then return end
  deleteSelection()
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
local function loop()
  redraw()
  while running do
    local e, addr, a, b, c = event.pull()
    if e ~= "interrupted" and (addr == term.keyboard() or addr == term.screen()) then
      if e == "key_down" then
        onKeyDown(a, b)
        findPair()
        redraw()
      elseif e == "clipboard" then
        onClipboard(a)
        findPair()
        redraw()
      elseif e == "touch" or e == "drag" then
        local gx, gy = term.getGlobalArea()
        local col, row = a - gx + 1, b - gy + 1
        if col >= 1 and row >= 1 and col <= W and row <= rows then
          if e == "touch" then
            dropSelection()
          elseif not anchor then
            anchor = { cx, cy }
          end
          setCursor(charAt(buffer[row + scrollY] or "", math.max(1, col - GW + scrollX)), row + scrollY)
          commit()
          if anchor then fullRedraw = true end
          redraw()
        end
      elseif e == "scroll" then
        move(cx, cy - (c or 0) * 12)
        fullRedraw = true
        redraw()
      end
    end
  end
end
local ok, err = xpcall(loop, debug.traceback)
S:close()
term.setCursorBlink(true)
term.clear()
if not ok then error(err, 0) end
