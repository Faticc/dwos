local graphic = ...
local unicode = require("unicode")
local PROMPT = {
  sources = "What do you want to install?",
  targets = "Where do you want to install to?",
}
local TITLE = {
  sources = "Что установить?",
  targets = "Куда установить?",
}
local function nameOf(src)
  local dev = src.dev
  local name = (src.prop or {}).label or dev.getLabel()
  if name then
    return string.format("%s (%s...)", name, dev.address:sub(1, 8))
  end
  return dev.address
end
local function sortDevs(devs)
  table.sort(devs, function(a, b) return a.path < b.path end)
end
local function nothing(kind, options)
  if kind == "sources" then
    if options.label then
      io.stderr:write("Nothing to install labeled: " .. options.label .. "\n")
    elseif options.from then
      io.stderr:write("Nothing to install from: " .. options.from .. "\n")
    else
      io.stderr:write("Nothing to install\n")
    end
  else
    if options.to then
      io.stderr:write("No such target to install to: " .. options.to .. "\n")
    else
      io.stderr:write("No writable disks found, aborting\n")
    end
  end
  os.exit(1)
end
local text = { graphic = false }
function text.select(kind, devs, options)
  if #devs == 0 then nothing(kind, options) end
  sortDevs(devs)
  local n = #devs
  if n < 2 then return devs[1] end
  io.write(PROMPT[kind], "\n")
  for i = 1, n do
    local src = devs[i]
    io.write(string.format("%d) %s at %s [r%s]\n",
      i, nameOf(src), src.path, src.dev.isReadOnly() and "o" or "w"))
  end
  io.write("Please enter a number between 1 and " .. n .. "\n")
  io.write("Enter 'q' to cancel the installation: ")
  for _ = 1, 5 do
    local result = io.read() or "q"
    if result == "q" then os.exit() end
    local number = tonumber(result)
    if number and number > 0 and number <= n then
      return devs[number]
    end
    io.write("Invalid input, please try again: ")
    os.sleep(0)
  end
  print("\ntoo many bad inputs, aborting")
  os.exit(1)
end
function text.note(s)
  io.write(s, "\n")
end
function text.ask(question)
  io.write(question, " [Y/n] ")
  return ((io.read() or "n") .. "y"):match("^%s*[Yy]") ~= nil
end
function text.progress() end
function text.step(from, to)
  io.write(from, " -> ", to, "\n")
end
function text.finish(s)
  io.write(s, "\n")
end
function text.pause() end
function text.close() end
if not graphic then return text end
local gfx = require("gfx")
local term = require("term")
local tty = require("tty")
local event = require("event")
local computer = require("computer")
local keys = require("keyboard").keys
local BG, FG, DIM, ACC = 0x1B2A3A, 0xE1E1E1, 0x8C8C8C, 0x66CCFF
local SEL, BAR, VOID = 0x2D4A66, 0x33B5E5, 0x000000
local ui = { graphic = true }
local S, W, H
local function open()
  if S then return end
  local gpu = tty.gpu()
  local sw, sh = gpu.getResolution()
  W = math.min(62, sw - 2)
  H = math.min(16, sh - 2)
  term.clear()
  term.setCursorBlink(false)
  S = gfx.surface(gpu, {
    x = math.floor((sw - W) / 2) + 1,
    y = math.floor((sh - H) / 2) + 1,
    w = W, h = H,
  })
end
local function fit(s, width)
  if unicode.wlen(s) > width then s = unicode.wtrunc(s, width + 1) end
  return s
end
local function line(row, s, fg, bg)
  bg = bg or BG
  S:fill(2, row, W - 2, 1, " ", FG, bg)
  if s and s ~= "" then S:set(3, row, fit(s, W - 4), fg or FG, bg) end
end
local function frame(title, hint)
  local bar = ("─"):rep(W - 2)
  S:fill(1, 1, W, H, " ", FG, BG)
  S:set(1, 1, "┌" .. bar .. "┐", DIM, BG)
  S:set(1, H, "└" .. bar .. "┘", DIM, BG)
  for i = 2, H - 1 do
    S:set(1, i, "│", DIM, BG)
    S:set(W, i, "│", DIM, BG)
  end
  S:set(1, 3, "├" .. bar .. "┤", DIM, BG)
  S:set(3, 1, " " .. fit(title, W - 6) .. " ", ACC, BG)
  if hint then S:set(3, H, " " .. fit(hint, W - 6) .. " ", DIM, BG) end
end
local function body()
  S:fill(2, 4, W - 2, H - 4, " ", FG, BG)
end
local function keyPress()
  while true do
    local name, _, char, code = event.pull()
    if name == "interrupted" then return nil, nil end
    if name == "key_down" then return char, code end
  end
end
function ui.select(kind, devs, options)
  if #devs == 0 then
    ui.close()
    nothing(kind, options)
  end
  sortDevs(devs)
  if #devs < 2 then return devs[1] end
  open()
  local rows = H - 5
  local sel, top = 1, 1
  while true do
    if sel < top then top = sel end
    if sel > top + rows - 1 then top = sel - rows + 1 end
    frame(TITLE[kind], "↑↓ выбор · Enter — ok · Q — отмена")
    line(2, PROMPT[kind], DIM)
    body()
    for i = 0, rows - 1 do
      local src = devs[top + i]
      if not src then break end
      local cur = top + i == sel
      local bg = cur and SEL or BG
      local mark = src.dev.isReadOnly() and "ro" or "rw"
      line(4 + i, (cur and "▸ " or "  ") .. nameOf(src), cur and FG or DIM, bg)
      local tail = src.path .. " [" .. mark .. "]"
      local at = W - 3 - unicode.wlen(tail)
      if at > 4 then S:set(at, 4 + i, tail, DIM, bg) end
    end
    if #devs > rows then
      line(H - 1, string.format("%d из %d", sel, #devs), DIM)
    end
    S:present()
    local char, code = keyPress()
    if not code then return nil end
    if code == keys.up then
      sel = sel > 1 and sel - 1 or #devs
    elseif code == keys.down then
      sel = sel < #devs and sel + 1 or 1
    elseif code == keys.home then
      sel = 1
    elseif code == keys["end"] then
      sel = #devs
    elseif code == keys.enter or code == keys.numpadenter then
      return devs[sel]
    elseif code == keys.q or char == 113 or code == 1 then
      return nil
    end
  end
end
local note_text
function ui.note(s)
  note_text = s
end
local function wrap(s, width)
  local out = {}
  for piece in (s .. "\n"):gmatch("(.-)\n") do
    local cur = ""
    for word in piece:gmatch("%S+") do
      local try = cur == "" and word or (cur .. " " .. word)
      if unicode.wlen(try) > width and cur ~= "" then
        out[#out + 1] = cur
        cur = word
      else
        cur = try
      end
    end
    out[#out + 1] = cur
  end
  return out
end
function ui.ask(question)
  open()
  frame("Подтверждение", "Enter/Y — да · N — нет")
  line(2, note_text or "", DIM)
  body()
  local rows = wrap(question, W - 6)
  local at = math.max(4, math.floor((H - 3 - #rows) / 2) + 3)
  for i, s in ipairs(rows) do
    if at + i - 1 < H then line(at + i - 1, s) end
  end
  line(H - 2, "[ Да ]   [ Нет ]", ACC)
  S:present()
  while true do
    local char, code = keyPress()
    if not code then return false end
    if code == keys.enter or code == keys.numpadenter or code == keys.y or char == 121 then
      return true
    elseif code == keys.n or char == 110 or code == keys.q or code == 1 then
      return false
    end
  end
end
local total, done, lastDraw
local function drawBar()
  local inner = W - 6
  local part = total > 0 and math.min(1, done / total) or 0
  local full = math.floor(inner * part + 0.5)
  S:fill(3, H - 3, inner, 1, " ", FG, VOID)
  if full > 0 then S:fill(3, H - 3, full, 1, " ", FG, BAR) end
  local pct = string.format("%d%%  %d/%d", math.floor(part * 100 + 0.5), done, total)
  line(H - 2, pct, DIM)
end
function ui.progress(n)
  open()
  total, done, lastDraw = n or 0, 0, 0
  frame("Установка", "Ctrl+C — прервать")
  line(2, note_text or "", DIM)
  body()
  line(5, "Копирование файлов…", FG)
  drawBar()
  S:present()
end
function ui.step(from)
  done = done + 1
  local now = computer.uptime()
  if now - lastDraw < 0.2 and done < total then return end
  lastDraw = now
  line(7, from, DIM)
  drawBar()
  S:present()
end
function ui.finish(s)
  open()
  frame("Готово", "Enter — дальше")
  body()
  local rows = wrap(s, W - 6)
  local at = math.max(4, math.floor((H - 3 - #rows) / 2) + 3)
  for i, r in ipairs(rows) do
    if at + i - 1 < H then line(at + i - 1, r) end
  end
  S:present()
end
function ui.pause()
  keyPress()
end
function ui.close()
  if not S then return end
  S:close()
  S = nil
  term.setCursorBlink(true)
  term.clear()
end
return ui
