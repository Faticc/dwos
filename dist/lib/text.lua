local unicode = require("unicode")
local text = {}
text.internal = {}
text.syntax = { "^%d?>>?&%d+", "^%d?>>?", ">>?", "<%&%d+", "<", ";", "&&", "||?" }
function text.trim(value)
  local from = value:match("^%s*()")
  return from > #value and "" or value:match(".*%S", from)
end
function text.escapeMagic(txt)
  return txt:gsub("[%(%)%.%%%+%-%*%?%[%^%$]", "%%%1")
end
function text.removeEscapes(txt)
  return txt:gsub("%%([%(%)%.%%%+%-%*%?%[%^%$])", "%1")
end
function text.internal.tokenize(value, options)
  checkArg(1, value, "string")
  checkArg(2, options, "table", "nil")
  options = options or {}
  local delimiters = options.delimiters
  local custom = not not delimiters
  delimiters = delimiters or text.syntax
  local words, reason = text.internal.words(value, options)
  local splitter = text.escapeMagic(custom and table.concat(delimiters) or "<>|;&")
  if type(words) ~= "table" or #splitter == 0 or not value:find("[" .. splitter .. "]") then
    return words, reason
  end
  return text.internal.splitWords(words, delimiters)
end
local QUOTES = { { "'", "'", true }, { '"', '"' }, { "`", "`" } }
function text.internal.words(input, options)
  checkArg(1, input, "string")
  checkArg(2, options, "table", "nil")
  options = options or {}
  local quotes = options.quotes or QUOTES
  local show_escapes = options.show_escapes
  local qr = nil
  local function append(dst, txt, _qr)
    local size = #dst
    if size == 0 or dst[size].qr ~= _qr then
      dst[size + 1] = { txt = txt, qr = _qr }
    else
      dst[size].txt = dst[size].txt .. txt
    end
  end
  local tokens, token = {}, {}
  local escaped, start = false, -1
  local i = 0
  for char in input:gmatch(".[\128-\191]*") do
    i = i + 1
    if escaped then
      escaped = false
      if show_escapes or (qr and not qr[3] and qr[2] ~= char) then
        append(token, "\\", qr)
      end
      append(token, char, qr)
    elseif char == "\\" and (not qr or not qr[3]) then
      escaped = true
    elseif qr and qr[2] == char then
      if #token == 0 or #token[#token] == 0 then
        append(token, "", qr)
      end
      qr = nil
    elseif not qr and (function()
      for _, Q in ipairs(quotes) do
        if Q[1] == char then qr = Q return true end
      end
    end)() then
      start = i
    elseif not qr and char:find("^%s$") then
      if #token > 0 then
        tokens[#tokens + 1] = token
      end
      token = {}
    else
      append(token, char, qr)
    end
  end
  if qr then
    return nil, "unclosed quote at index " .. start
  end
  if #token > 0 then
    tokens[#tokens + 1] = token
  end
  return tokens
end
require("package").delay(text, "/lib/core/full_text.lua")
return text
