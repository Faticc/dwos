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
completeList = { { "control", "space" } },
unindent = { { "shift", "tab" } },
run = { { "f5" }, { "control", "r" } },
shell = { { "control", "e" } },
panel = { { "control", "o" } },
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
local ERR = 0xFF6666
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
elseif c:match("[%a_\128-\255]") then
local a, b = s:find("^[%w_\128-\255]+", i)
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
local SW, SH = gpu.getResolution()
local panelH = 0
local S = gfx.surface(gpu, { h = SH })
local W, H = S.w, S.h
local rows = H - 1
local buffer = {}
local carry, carryTop = {}, 1
local cx, cy = 1, 1
local scrollX, scrollY = 0, 0
local running = true
local anchor = nil
local clip = {}
local cutting = false
local rev = 0
local ghost = nil
local status, dirty = nil, {}
local fullRedraw, modified = true, false
local match, pair = nil, nil
local GW = 2
local sigHelp = nil
local lineProblem
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
rev = rev + 1
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
local holes = {}
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
local function drawRow(i)
local y = i - scrollY
if y < 1 or y > rows then return end
local line = buffer[i]
if not line then
put(1, y, (" "):rep(W), FG, BG)
return
end
local n = tostring(i)
put(1, y, (" "):rep(GW - 1 - #n) .. n .. " ", lineProblem(i) and ERR or i == cy and GUT_CUR or GUT, BG)
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
if pos == cur then return BG, readonly and 0x88AAFF or CUR end
if pairAt[pos] then return 0xFFFFFF, PAIR end
if mf and pos >= mf and pos < mt then return BG, FIND end
if from and pos >= from and pos < to then return fg, SEL end
return fg, BG
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
if cur and cx > unicode.len(line) then
local g = ghost and ghost.text or ""
local first = unicode.sub(g, 1, 1)
emit(first ~= "" and first or " ", style(cx, FG))
if unicode.len(g) > 1 then emit(unicode.sub(g, 2), GUT, BG) end
end
if drawnTo < W then put(drawnTo + 1, y, (" "):rep(W - drawnTo), FG, BG) end
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
pretty("запуск", "run")
pretty("оболочка", "shell")
pretty("поиск", "find")
pretty("отмена", "undo")
out[#out + 1] = "Tab дополнить"
return table.concat(out, "  ")
end
local HELP = helpText()
local function bar(parts)
local x = 1
for _, p in ipairs(parts) do
local s = p[1]
if s ~= "" and x <= W then
s = fit(s, W - x + 1)
S:set(x, H, s, p[2], p[3] or BAR_BG)
x = x + unicode.wlen(s)
end
end
if x <= W then S:set(x, H, (" "):rep(W - x + 1), BAR_FG, BAR_BG) end
end
local function drawStatus()
local right = string.format("%d,%d", cy, cx)
local l1, _, l2 = selection()
if l1 then
right = string.format("выд %d  %s", l2 - l1 + 1, right)
elseif #clip > 0 then
right = string.format("#%d  %s", #clip, right)
end
right = right .. " "
local rw = unicode.wlen(right)
local name = fit(fs.name(filename), math.max(1, W - rw - 4))
local mark = readonly and " [чтение]" or modified and " *" or ""
local mid
if status then
mid = { { status, BAR_MSG } }
elseif sigHelp then
mid = sigHelp
elseif ghost then
mid = { { "Tab → " .. ghost.word .. (ghost.more > 0 and ("   ещё " .. ghost.more) or ""), BAR_POS } }
else
local miss = lineProblem(cy)
mid = miss and { { "не заполнено: " .. table.concat(miss, "; "), ERR } } or { { HELP, BAR_FG } }
end
local at = 1 + unicode.wlen(name) + unicode.wlen(mark)
local room = W - rw - at - 2
local parts = { { " ", BAR_FG }, { name, BAR_NAME }, { mark, BAR_MARK } }
if room > 0 then
parts[#parts + 1] = { "  ", BAR_FG }
for _, m in ipairs(mid) do
if room <= 0 then break end
local piece = fit(m[1], room)
parts[#parts + 1] = { piece, m[2] }
room = room - unicode.wlen(piece)
end
parts[#parts + 1] = { (" "):rep(math.max(0, room)), BAR_FG }
else
parts[#parts + 1] = { (" "):rep(math.max(0, W - rw - at)), BAR_FG }
end
parts[#parts + 1] = { right, BAR_POS }
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
local popupDraw = nil
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
if popupDraw then popupDraw() end
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
local room = W - unicode.wlen(label) - 3
local shown = buf
while room > 0 and unicode.wlen(shown) > room do shown = unicode.sub(shown, 2) end
bar({ { " ", BAR_FG }, { label, BAR_MARK }, { shown, BAR_NAME }, { " ", BAR_BG, BAR_POS } })
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
if buf == "" then
status = nil
return nil
end
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
bar({ { " ", BAR_FG }, { question, BAR_MARK } })
S:present()
while true do
local e, addr, char, code = event.pull()
if e == "key_down" and addr == term.keyboard() then
if code == keys.y or char == 121 then return true end
if code == keys.n or char == 110 then return false end
if code == keys.c or code == keys.back or code == 1 then return nil end
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
local aliasCache, aliasRev, aliasAt, aliasSig = nil, -1, -2, ""
local problemCache = {}
local function aliases()
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
local function resolve(path, depth)
local cur
for i, name in ipairs(path) do
if i == 1 then
cur = rawget(_G, name) or package.loaded[name]
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
local function splitChain(chain)
local path, frag = {}, chain
local dot = chain:match("^(.*)[%.:][%w_]*$")
if dot then
frag = chain:match("[%.:]([%w_]*)$") or ""
for name in dot:gmatch("[^%.:]+") do path[#path + 1] = name end
end
return path, frag
end
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
local function lowerBound(list, low)
local a, b = 1, #list + 1
while a < b do
local mid = math.floor((a + b) / 2)
if list[mid]:lower() < low then a = mid + 1 else b = mid end
end
return a
end
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
local function updateGhost()
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
local function replaceFrag(n, word)
if n > 0 then
local line = curLine()
splice(cy, 1, { unicode.sub(line, 1, cx - n - 1) .. unicode.sub(line, cx) })
setCursor(cx - n, cy)
end
insert(word)
commit()
end
local replay = nil
local MODS = {}
for _, k in ipairs({ "lshift", "rshift", "lcontrol", "rcontrol", "lmenu", "rmenu" }) do
if keys[k] then MODS[keys[k]] = true end
end
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
local function wrapInto(out, s, width, colour)
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
local function pad(s, width)
s = fit(s, width)
return s .. (" "):rep(width - unicode.wlen(s))
end
local sigCache = {}
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
local function codeOf(i)
local out = {}
for _, t in ipairs(tokensFor(i)) do
if t[2] == C_STR then out[#out + 1] = ("0"):rep(#t[1])
elseif t[2] == C_CMT then out[#out + 1] = (" "):rep(#t[1])
else out[#out + 1] = t[1] end
end
return table.concat(out)
end
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
local call = callAt(code, j)
if call then return call, pos + 1 end
end
end
end
end
local function updateSig()
sigHelp = nil
local call, at = callAround()
if not call then return end
local k = #call.args
for i, a in ipairs(call.args) do
if at <= a[2] + 1 then k = i break end
end
local out = { { call.name .. "(", BAR_NAME } }
for i, p in ipairs(call.sig.params) do
if i > 1 then out[#out + 1] = { ", ", BAR_FG } end
local colour = BAR_FG
if i == k then colour = BAR_MARK
elseif not p.optional and not filled(call, i) then colour = ERR end
out[#out + 1] = { p.optional and ("[" .. p.text .. "]") or p.text, colour }
end
out[#out + 1] = { ")" .. call.sig.ret, BAR_NAME }
local miss = missingOf(call)
if #miss > 0 then
out[#out + 1] = { "   не хватает: " .. table.concat(miss, ", "), ERR }
end
sigHelp = out
end
local function popup(path)
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
local width = 0
for i = 1, #shown do width = math.max(width, unicode.wlen(shown[i])) end
width = math.min(width + 3, W - 4)
local x = GW + dispCol(curLine(), cx - unicode.len(frag)) - scrollX
x = math.max(1, math.min(x, W - width))
local below = cy - scrollY + h <= rows
local y = below and (cy - scrollY + 1) or math.max(1, cy - scrollY - h)
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
wrapInto(dlines, sig or doc, dw - 2, BAR_POS)
if desc and desc ~= "" then wrapInto(dlines, desc, dw - 2, POP_FG) end
end
end
local dh = math.min(#dlines, math.max(h, 6), rows - 1)
local dy = below and y or (y + h - dh)
if below and dy + dh - 1 > rows then dy = rows - dh + 1 end
if dy < 1 then dy = 1 end
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
S:set(x, y + i, " " .. pad(shown[top + i], width - 2) .. mark, POP_FG,
(top + i == sel) and POP_SEL or POP_BG)
end
for i = 1, dh do
local l = dlines[i]
S:set(dx, dy + i - 1, " " .. pad(l[1], dw - 1), l[2], BAR_BG)
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
local function complete()
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
local function inCode()
if not lua then return false end
local at, pos = 1, cx - 1
for _, t in ipairs(tokensFor(cy)) do
local len = unicode.len(t[1])
if pos >= at and pos < at + len then return t[2] ~= C_CMT and t[2] ~= C_STR end
at = at + len
end
return true
end
local function autoPopup()
local chain = chainBefore()
if not chain or chain:sub(-1) ~= "." or chain:find("..", 1, true) or not inCode() then return end
popup((splitChain(chain)))
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
local panelX, panelY = 1, 1
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
relayout()
memberCache = {}
problemCache = {}
end
local function runFile()
if modified and not readonly and not save() then return end
status = "работает " .. fs.name(filename)
inPanel(function()
if tty.getCursor() > 1 then io.write("\n") end
io.write("\27[33m> " .. fs.name(filename) .. "\27[37m\n")
local sh = require("sh")
local ok, reason = sh.execute(_ENV, '"' .. filename .. '"')
if not ok and reason then io.stderr:write(tostring(reason), "\n") end
end)
status = "вывод внизу, ^O скрыть панель"
end
local function shellHere()
if modified and not readonly then save() end
status = "оболочка внизу, exit - обратно в редактор"
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
status = nil
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
local line = curLine()
local before, after = unicode.sub(line, cx - 1, cx - 1), unicode.sub(line, cx, cx)
if cx > 1 and after ~= "" and (OPEN[before] == after or ((before == '"' or before == "'") and after == before)) then
splice(cy, 1, { unicode.sub(line, 1, cx - 2) .. unicode.sub(line, cx + 1) }, "erase")
setCursor(cx - 1, cy)
return
end
if left() then delete() end
end,
delete = function() if not readonly then delete() end end,
deleteLine = function() if not readonly then delete(true) end end,
newline = function() if not readonly then enter() end end,
save = save,
close = function()
if modified and not readonly then
local answer = ask("Файл изменён. Сохранить перед выходом? [Y/n, C - остаться]")
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
if name ~= "cut" then cutting = false end
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
if ch == "." and not selection() then autoPopup() end
end
cutting = false
end
end
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
local function dispatch(e, addr, a, b, c)
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
if e == "touch" then
dropSelection()
elseif not anchor then
anchor = { cx, cy }
end
setCursor(charAt(buffer[row + scrollY] or "", math.max(1, col - GW + scrollX)), row + scrollY)
commit()
updateGhost()
updateSig()
if anchor then fullRedraw = true end
redraw()
end
elseif e == "scroll" then
move(cx, cy - (c or 0) * 12)
updateGhost()
fullRedraw = true
redraw()
end
end
local function loop()
redraw()
while running do
dispatch(event.pull())
while replay and running do
local ev = replay
replay = nil
dispatch(table.unpack(ev, 1, ev.n or #ev))
end
end
end
local ok, err = xpcall(loop, debug.traceback)
S:close()
term.setCursorBlink(true)
term.clear()
if not ok then error(err, 0) end
