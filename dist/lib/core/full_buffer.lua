local buffer = require("buffer")
local unicode = require("unicode")
function buffer:getTimeout()
return self.readTimeout
end
function buffer:setTimeout(value)
self.readTimeout = tonumber(value)
end
function buffer:seek(whence, offset)
whence = tostring(whence or "cur")
assert(whence == "set" or whence == "cur" or whence == "end",
"bad argument #1 (set, cur or end expected, got " .. whence .. ")")
offset = offset or 0
checkArg(2, offset, "number")
assert(math.floor(offset) == offset, "bad argument #2 (not an integer)")
if self.mode.w or self.mode.a then
self:flush()
elseif whence == "cur" then
offset = offset - #self.bufferRead
end
local result, reason = self.stream:seek(whence, offset)
if result then
self.bufferRead = ""
return result
end
return nil, reason
end
function buffer:buffered_write(arg)
local result, reason
if self.bufferMode == "full" then
if self.bufferSize - #self.bufferWrite < #arg then
result, reason = self:flush()
if not result then
return nil, reason
end
end
if #arg > self.bufferSize then
return self.stream:write(arg)
end
self.bufferWrite = self.bufferWrite .. arg
return self
end
local l = arg:find("\n[^\n]*$")
if l or #arg > self.bufferSize then
result, reason = self:flush()
if not result then
return nil, reason
end
end
if l then
result, reason = self.stream:write(arg:sub(1, l))
if not result then
return nil, reason
end
arg = arg:sub(l + 1)
end
if #arg > self.bufferSize then
return self.stream:write(arg)
end
self.bufferWrite = self.bufferWrite .. arg
return self
end
local function measure(self)
if self.mode.b then return rawlen, string.sub end
return unicode.len, unicode.sub
end
function buffer:readNumber(readChunk)
local len, sub = measure(self)
local number_text = ""
local white_done
local function peek()
if len(self.bufferRead) == 0 then
local result, reason = readChunk(self)
if not result then
return result, reason
end
end
return sub(self.bufferRead, 1, 1)
end
local function pop()
local n = sub(self.bufferRead, 1, 1)
self.bufferRead = sub(self.bufferRead, 2)
return n
end
while true do
local peeked = peek()
if not peeked then
break
end
if peeked:match("%s") then
if white_done then
break
end
pop()
else
white_done = true
if not tonumber(number_text .. peeked .. "0") then
break
end
number_text = number_text .. pop()
end
end
return tonumber(number_text)
end
function buffer:readBytesOrChars(readChunk, n)
n = math.max(n, 0)
local len, sub = measure(self)
local parts, have = {}, 0
while have < n do
local needed = n - have
if #self.bufferRead == 0 then
local result, reason = readChunk(self)
if not result then
if reason then
return result, reason
end
return have > 0 and table.concat(parts) or nil
end
end
local splice = self.bufferRead
if len(splice) > needed then
splice = sub(self.bufferRead, 1, needed)
if len(splice) ~= needed then
splice = self.bufferRead
end
end
parts[#parts + 1] = splice
have = have + len(splice)
self.bufferRead = string.sub(self.bufferRead, #splice + 1)
end
return table.concat(parts)
end
function buffer:readAll(readChunk)
repeat
local result, reason = readChunk(self)
if not result and reason then
return result, reason
end
until not result
local result = self.bufferRead
self.bufferRead = ""
return result
end
function buffer:formatted_read(readChunk, ...)
self.timeout = require("computer").uptime() + self.readTimeout
local function read(n, format)
if type(format) == "number" then
return self:readBytesOrChars(readChunk, format)
end
if type(format) ~= "string" then
error("bad argument #" .. n .. " (invalid option)")
end
local first = unicode.sub(format, 1, 1) == "*" and 2 or 1
format = unicode.sub(format, first, first)
if format == "n" then
return self:readNumber(readChunk)
elseif format == "l" then
return self:readLine(true, self.timeout)
elseif format == "L" then
return self:readLine(false, self.timeout)
elseif format == "a" then
return self:readAll(readChunk)
end
error("bad argument #" .. n .. " (invalid format)")
end
local results = {}
local formats = table.pack(...)
for i = 1, formats.n do
local result, reason = read(i, formats[i])
if result then
results[i] = result
elseif reason then
return nil, reason
end
end
return table.unpack(results, 1, formats.n)
end
function buffer:size()
local len = self.mode.b and rawlen or unicode.len
local size = len(self.bufferRead)
if self.stream.size then
size = size + self.stream:size()
end
return size
end
