local process = require("process")
local unicode = require("unicode")
local event = require("event")
local event_mt = getmetatable(event.handlers)
local elbow = unicode.char(0x2514)
local function thread_id(t, p)
if t then
return (tostring(t):gsub("^thread: 0x", ""))
end
for k, v in pairs(process.list) do
if v == p then
return thread_id(k)
end
end
return "-"
end
local function isThread(h)
local mt = getmetatable(h)
return mt and mt.__status
end
local function count(n) return n == 0 and "-" or tostring(n) end
local cols = {
{ "PID", thread_id },
{ "EVENTS", function(_, p)
local handlers = {}
if event_mt.threaded then
handlers = rawget(p.data, "handlers") or {}
elseif not p.parent then
handlers = event.handlers
end
local n = 0
for _ in pairs(handlers) do n = n + 1 end
return count(n)
end },
{ "THREADS", function(_, p)
local n = 0
for _, h in ipairs(p.data.handles) do
if isThread(h) then n = n + 1 end
end
return count(n)
end },
{ "PARENT", function(_, p)
for _, info in pairs(process.list) do
for _, h in ipairs(info.data.handles) do
if isThread(h) and getmetatable(h).process == p then
return thread_id(nil, info)
end
end
end
return thread_id(nil, p.parent)
end },
{ "HANDLES", function(_, p) return count(#p.data.handles) end },
{ "CMD", function(_, p) return p.command end },
}
local rows = {}
for t, p in pairs(process.list) do
local row = {}
for _, col in ipairs(cols) do
row[col[1]] = col[2](t, p)
end
rows[#rows + 1] = row
end
local sorted, used = {}, {}
local function family(parent, depth)
for i, row in ipairs(rows) do
if not used[i] and row.PARENT == parent then
used[i] = true
row.CMD = (" "):rep(math.max(depth - 1, 0)) .. (depth > 0 and elbow or "") .. row.CMD
sorted[#sorted + 1] = row
family(row.PID, depth + 1)
end
end
end
family("-", 0)
local shown = { "PID", "EVENTS", "THREADS", "HANDLES", "CMD" }
local widths = {}
for _, key in ipairs(shown) do
widths[key] = unicode.wlen(key)
for _, row in ipairs(sorted) do
widths[key] = math.max(widths[key], unicode.wlen(row[key]))
end
end
local function line(row)
local out = {}
for i, key in ipairs(shown) do
local v = row[key]
out[i] = i < #shown and v .. string.rep(" ", widths[key] - unicode.wlen(v)) or v
end
print(table.concat(out, "   "))
end
local header = {}
for _, key in ipairs(shown) do header[key] = key end
line(header)
for _, row in ipairs(sorted) do
line(row)
end
