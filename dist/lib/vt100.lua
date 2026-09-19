local vt100 = {}
local COLORS = { 0x0, 0xff0000, 0x00ff00, 0xffff00, 0x0000ff, 0xff00ff, 0x00B6ff, 0xffffff }
local function set_cursor(window, x, y)
window.x = math.min(math.max(x, 1), window.width)
window.y = math.min(math.max(y, 1), window.height)
end
local function sgr(window, params)
local gpu = window.gpu
local fg, bg = gpu.setForeground, gpu.setBackground
if window.flip then
fg, bg = bg, fg
end
if params == ";" then params = "" end
local tokens = { "_" }
for part in (params .. ";"):gmatch("([^;]*);") do
if part ~= "" then tokens[#tokens + 1] = part end
tokens[#tokens + 1] = "_"
end
local last_was_break
for _, part in ipairs(tokens) do
local num = tonumber(part)
last_was_break, num = not num, num or last_was_break and 0
local flip = num == 7
if flip then
if not window.flip then
local rgb, pal = bg(gpu.getForeground())
fg(pal or rgb, not not pal)
fg, bg = bg, fg
end
elseif num == 5 then
window.blink = true
elseif num == 0 then
bg(COLORS[1])
fg(COLORS[8])
elseif num then
num = num - 29
local set = fg
if num > 10 then
num = num - 10
set = bg
end
local color = COLORS[num]
if color then
set(color)
end
end
window.flip = flip
end
end
local function save(window)
local gpu = window.gpu
window.saved = { window.x, window.y, { gpu.getBackground() }, { gpu.getForeground() }, window.flip, window.blink }
end
local function restore(window)
local gpu = window.gpu
local data = window.saved or { 1, 1, { 0x0 }, { 0xffffff }, window.flip, window.blink }
window.x, window.y = data[1], data[2]
gpu.setBackground(table.unpack(data[3]))
gpu.setForeground(table.unpack(data[4]))
window.flip, window.blink = data[5], data[6]
end
local function clear_line(window, n)
n = tonumber(n) or 0
local x = n == 0 and window.x or 1
local count = n == 1 and window.x or (window.width - x + 1)
window.gpu.fill(x + window.dx, window.y + window.dy, count, 1, " ")
end
local CSI = {
m = function(w, p) if not p:find("[^%d;]") then sgr(w, p) return true end end,
s = function(w, p) if p == "" then save(w) return true end end,
u = function(w, p) if p == "" then restore(w) return true end end,
h = function(w, p) if p == "?7" then w.nowrap = false return true end end,
l = function(w, p) if p == "?7" then w.nowrap = true return true end end,
K = function(w, p) if p:match("^[012]?$") then clear_line(w, p) return true end end,
J = function(w, p)
if not p:match("^[012]?$") then return end
clear_line(w, p)
local n = tonumber(p) or 0
local y = n == 0 and (w.y + 1) or 1
local count = n == 1 and (w.y - 1) or w.height
w.gpu.fill(1 + w.dx, y + w.dy, w.width, count, " ")
return true
end,
n = function(w, p)
if p ~= "6" then return end
io.stdin.bufferRead = string.format("%s%s[%d;%dR", io.stdin.bufferRead, string.char(0x1b), w.y, w.x)
return true
end,
}
local function move(w, p, dir)
if not p:match("^%d*$") then return end
local n = tonumber(p) or 1
local dx, dy = 0, 0
if dir == "A" then dy = -n elseif dir == "B" then dy = n elseif dir == "C" then dx = n else dx = -n end
set_cursor(w, w.x + dx, w.y + dy)
return true
end
CSI.A, CSI.B, CSI.C, CSI.D = move, move, move, move
local function position(w, p)
if p == "" then set_cursor(w, 1, 1) return true end
local y, x = p:match("^(%d*);(%d*)$")
if not y then return end
set_cursor(w, tonumber(x) or 1, tonumber(y) or 1)
return true
end
CSI.H, CSI.f = position, position
function vt100.consume(window, buf, pos)
local c = buf:sub(pos + 1, pos + 1)
if c == "" then
return nil
elseif c == "7" then
save(window) return 2
elseif c == "8" then
restore(window) return 2
elseif c == "D" then
window.y = window.y + 1 return 2
elseif c == "E" then
window.y = window.y + 1 window.x = 1 return 2
elseif c == "M" then
window.y = window.y - 1 return 2
elseif c == "[" then
local params, final = buf:match("^([%d;%?]*)(.?)", pos + 2)
if final == "" then
return nil
end
local handler = CSI[final]
if handler and handler(window, params, final) then
return 2 + #params + 1
end
end
return 1, "\27"
end
function vt100.parse(window)
local buf = window.output_buffer
if buf:sub(1, 1) ~= "\27" then
return ""
end
local n, literal = vt100.consume(window, buf, 1)
if not n then return nil end
window.output_buffer = buf:sub(n + 1)
return literal or ""
end
return vt100
