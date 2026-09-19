local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local gfx = require("gfx")
local keys = require("keyboard").keys
local term = require("term")
local tty = require("tty")
local unicode = require("unicode")
if not term.isAvailable() then return end
local BG, GRID = 0x000000, 0x181818
local MEM, PWR = 0x66CCFF, 0x88DD66
local FG, DIM, HEAD = 0xD0D0D0, 0x888888, 0xFFCC66
local gpu = tty.gpu()
local sw, sh = gpu.getResolution()
term.clear()
term.setCursorBlink(false)
local S = gfx.new(gpu, sw, sh, { rgb = true, keepResolution = true, background = BG })
local W, H = S.w, S.h
local GH = math.min(10, math.max(3, math.floor((H - 14) / 2)))
local ROW_MEM = 3
local ROW_PWR = ROW_MEM + GH + 1
local ROW_LIST = ROW_PWR + GH + 2
local mem, pwr = {}, {}
local maxSamples = W
local function push(t, v)
t[#t + 1] = v
while #t > maxSamples do table.remove(t, 1) end
end
local function human(n)
if n >= 1048576 then return string.format("%.1fM", n / 1048576) end
if n >= 1024 then return string.format("%.0fK", n / 1024) end
return tostring(math.floor(n))
end
local function clock(t)
local s = math.floor(t)
return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end
local function graph(row, rows, data, color)
local y0, ph = (row - 1) * 2 + 1, rows * 2
S:rect(1, y0, W, ph, BG)
for y = y0, y0 + ph - 1, 4 do S:rect(1, y, W, 1, GRID) end
local n = #data
local from = math.max(1, n - W + 1)
for i = from, n do
local v = math.max(0, math.min(1, data[i]))
local bars = math.floor(v * ph + 0.5)
if bars > 0 then S:rect(W - (n - i), y0 + ph - bars, 1, bars, color) end
end
end
local function hardware()
local out, kinds = {}, {}
for _, t in pairs(component.list()) do kinds[t] = (kinds[t] or 0) + 1 end
local names = {}
for t in pairs(kinds) do names[#names + 1] = t end
table.sort(names)
local parts = {}
for _, t in ipairs(names) do
parts[#parts + 1] = kinds[t] > 1 and (t .. " x" .. kinds[t]) or t
end
out[#out + 1] = { "Железо", table.concat(parts, ", ") }
local seen = {}
for dev, path in fs.mounts() do
if not seen[dev.address] and dev.spaceTotal then
seen[dev.address] = true
local ok, total = pcall(dev.spaceTotal)
local ok2, used = pcall(dev.spaceUsed)
if ok and ok2 and used then
local label = dev.getLabel() or dev.address:sub(1, 8)
local room = (total and total < math.huge) and (human(used) .. " / " .. human(total))
or (human(used) .. " занято")
out[#out + 1] = { label, room .. "  " .. path }
end
end
end
return out
end
local hw, hwAt = hardware(), computer.uptime()
local function draw()
local total, free = computer.totalMemory(), computer.freeMemory()
local used = total - free
local energy, maxEnergy = computer.energy(), computer.maxEnergy()
push(mem, used / total)
push(pwr, maxEnergy > 0 and energy / maxEnergy or 0)
graph(ROW_MEM, GH, mem, MEM)
graph(ROW_PWR, GH, pwr, PWR)
S:rect(1, 1, W, (ROW_MEM - 1) * 2, BG)
S:rect(1, (ROW_LIST - 2) * 2 + 1, W, (H - ROW_LIST + 2) * 2, BG)
S:flush(true)
S:text(2, 1, "DwOS · монитор", HEAD, BG)
local up = "аптайм " .. clock(computer.uptime())
S:text(W - unicode.wlen(up) - 1, 1, up, DIM, BG)
S:text(2, ROW_MEM - 1, string.format("Память  %s из %s  (%d%%)",
human(used), human(total), math.floor(used / total * 100 + 0.5)), MEM, BG)
S:text(2, ROW_PWR - 1, string.format("Энергия  %d из %d  (%d%%)",
math.floor(energy), math.floor(maxEnergy),
maxEnergy > 0 and math.floor(energy / maxEnergy * 100 + 0.5) or 0), PWR, BG)
for i, row in ipairs(hw) do
local at = ROW_LIST + i - 1
if at <= H - 1 then
S:text(2, at, row[1], FG, BG)
S:text(16, at, row[2], DIM, BG)
end
end
S:text(2, H, "q — выход", DIM, BG)
S:present()
end
local function loop()
draw()
while true do
local e, _, _, code = event.pull(0.5)
if e == "interrupted" then break end
if e == "key_down" and (code == keys.q or code == 1) then break end
if computer.uptime() - hwAt > 5 then
hw, hwAt = hardware(), computer.uptime()
end
draw()
end
end
local ok, err = xpcall(loop, debug.traceback)
S:close()
term.setCursorBlink(true)
term.clear()
if not ok then error(err, 0) end
