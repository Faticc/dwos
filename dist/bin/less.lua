local shell = require("shell")
local unicode = require("unicode")
local keyboard = require("keyboard")
local keys = keyboard.keys
local term = require("term")
local text = require("text")
local args, ops = shell.parse(...)
if #args > 1 then
  local name = (os.getenv("_") or "less"):match("([^/]+)%.lua$") or "less"
  io.write("Usage: ", name, " <filename>\n")
  io.write("- or no args reads stdin\n")
  return 1
end
local cat_cmd = table.concat({ "cat", ... }, " ")
if not io.output().tty then
  return os.execute(cat_cmd)
end
local reader = io.popen(cat_cmd)
local width, height = term.getViewport()
local function split(full)
  full = text.detab(full, 8)
  local parts, index = {}, 1
  while true do
    local sub = full:sub(index, index + width * 3)
    if #sub < width or unicode.wlen(sub) <= width then
      parts[#parts + 1] = sub
      break
    end
    parts[#parts + 1] = unicode.wtrunc(sub, width + 1)
    index = index + #parts[#parts]
    if index > #full then break end
  end
  return parts
end
local lines, eof = {}, false
local function need(n)
  while not eof and #lines < n do
    local full = reader:read()
    if not full then
      eof = true
      reader:close()
      break
    end
    for _, part in ipairs(split(full)) do lines[#lines + 1] = part end
  end
end
if ops.noback then
  local shown = 0
  local function forward(n)
    term.clearLine()
    for _ = 1, n do
      need(shown + 1)
      local line = lines[shown + 1]
      if not line then return false end
      shown = shown + 1
      print(line)
      lines[shown] = nil
    end
    return true
  end
  if not forward(height - 1) then return end
  while true do
    term.clearLine()
    io.write(":")
    local e, _, _, code = term.pull()
    if e == "interrupted" then break end
    if e == "key_down" then
      if code == keys.q then
        term.clearLine()
        break
      elseif code == keys.space or code == keys.pageDown then
        if not forward(height - 1) then break end
      elseif code == keys.enter or code == keys.numpadenter or code == keys.down then
        if not forward(1) then break end
      elseif code == keys["end"] then
        while forward(height - 1) do end
        break
      end
    end
  end
  term.clearLine()
  return
end
local gfx = require("gfx")
local tty = require("tty")
local event = require("event")
local FG, BG = 0xD0D0D0, 0x000000
local BAR_BG, BAR_FG, BAR_NAME, BAR_POS = 0x1B2A3A, 0x7A8A98, 0xE1E1E1, 0x66CCFF
local HL, HL_FG, ASK = 0x2D4A66, 0xFFFFFF, 0xFFAA00
local gpu = tty.gpu()
term.clear()
term.setCursorBlink(false)
local S = gfx.surface(gpu)
local W, H = S.w, S.h
local rows = H - 1
local name = args[1] and require("filesystem").name(args[1]) or "stdin"
local top, found = 1, nil
local function lastTop()
  need(math.huge)
  return math.max(1, #lines - rows + 1)
end
local function draw()
  need(top + rows - 1)
  for i = 0, rows - 1 do
    local line = lines[top + i]
    S:fill(1, i + 1, W, 1, " ", FG, BG)
    if line and line ~= "" then S:set(1, i + 1, line, FG, BG) end
  end
  if found and found >= top and found < top + rows then
    S:fill(1, found - top + 1, W, 1, " ", HL_FG, HL)
    if lines[found] ~= "" then S:set(1, found - top + 1, lines[found], HL_FG, HL) end
  end
  local bottom = math.min(top + rows - 1, #lines)
  local tail = eof and #lines or ("~" .. #lines)
  S:fill(1, H, W, 1, " ", BAR_FG, BAR_BG)
  S:set(2, H, name, BAR_NAME, BAR_BG)
  local at = 2 + unicode.wlen(name) + 2
  local pos = string.format("%d-%d/%s", top, bottom, tail)
  if eof and bottom >= #lines then pos = pos .. "  конец" end
  S:set(at, H, pos, BAR_POS, BAR_BG)
  local hint = "q выход   / поиск   n дальше"
  local hat = W - unicode.wlen(hint) - 1
  if hat > at + unicode.wlen(pos) + 2 then S:set(hat, H, hint, BAR_FG, BAR_BG) end
  S:present()
end
local function prompt(label)
  local buf = ""
  while true do
    S:fill(1, H, W, 1, " ", BAR_FG, BAR_BG)
    S:set(2, H, label, ASK, BAR_BG)
    S:set(2 + unicode.wlen(label), H, unicode.wtrunc(buf .. " ", W - 4), BAR_NAME, BAR_BG)
    S:set(math.min(W, 2 + unicode.wlen(label) + unicode.wlen(buf)), H, "_", BAR_BG, BAR_POS)
    S:present()
    local e, _, char, code = event.pull()
    if e == "interrupted" then return nil end
    if e == "key_down" then
      if code == keys.enter or code == keys.numpadenter then return buf
      elseif code == keys.back then buf = unicode.sub(buf, 1, -2)
      elseif code == 1 then return nil
      elseif char and char >= 32 then buf = buf .. unicode.char(char) end
    elseif e == "clipboard" then
      buf = buf .. (char or ""):gsub("\n.*", "")
    end
  end
end
local query
local function search(from)
  if not query or query == "" then return end
  local low = query:lower()
  local i = from
  while true do
    need(i)
    if i > #lines then
      if eof then return end
    else
      if lines[i]:lower():find(low, 1, true) then
        found = i
        top = math.max(1, math.min(i - math.floor(rows / 2), lastTop()))
        return
      end
      i = i + 1
    end
    if eof and i > #lines then return end
  end
end
local function move(delta)
  need(top + delta + rows - 1)
  local limit = eof and math.max(1, #lines - rows + 1) or math.huge
  top = math.max(1, math.min(top + delta, limit))
end
local function quit()
  S:close()
  term.setCursorBlink(true)
  term.clear()
  if not eof then pcall(reader.close, reader) end
end
local function loop()
  draw()
  while true do
    local e, _, char, code, dir = event.pull()
    if e == "interrupted" then break end
    if e == "key_down" then
      if code == keys.q then break
      elseif code == keys.down or code == keys.enter or code == keys.numpadenter then move(1)
      elseif code == keys.up then move(-1)
      elseif code == keys.space or code == keys.pageDown then move(rows - 1)
      elseif code == keys.pageUp then move(-(rows - 1))
      elseif code == keys.home then top = 1
      elseif code == keys["end"] then top = lastTop()
      elseif char == 47 then
        query = prompt("/")
        found = nil
        if query then search(top + 1) end
      elseif code == keys.n then
        search((found or top) + 1)
      end
      draw()
    elseif e == "scroll" then
      move((dir or 0) > 0 and -3 or 3)
      draw()
    end
  end
end
local ok, err = xpcall(loop, debug.traceback)
quit()
if not ok then error(err, 0) end
