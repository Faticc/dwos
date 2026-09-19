local component = require("component")
local fs = require("filesystem")
local internet = require("internet")
local shell = require("shell")
local text = require("text")

if not component.isAvailable("internet") then
  io.stderr:write("This program requires an internet card to run.")
  return
end

local args, options = shell.parse(...)
options.q = options.q or options.Q

if #args < 1 then
  io.write("Usage: wget [-fq] <url> [<filename>]\n")
  io.write(" -f: Force overwriting existing files.\n")
  io.write(" -q: Quiet mode - no status messages.\n")
  io.write(" -Q: Superquiet mode - no error messages.")
  return
end

local function fail(msg, ret)
  if not options.Q then io.stderr:write(msg) end
  return nil, ret or msg -- для программ, вызывающих wget как функцию
end

local url = text.trim(args[1])
local filename = args[2]
if not filename then
  -- имя из адреса: после последнего / и до ?
  filename = url:match("/([^/]*)$") or url
  filename = filename:match("^[^?]*")
end
filename = text.trim(filename)
if filename == "" then
  return fail("could not infer filename, please specify one", "missing target filename")
end
filename = shell.resolve(filename)

local preexisted
if fs.exists(filename) then
  preexisted = true
  if not options.f then
    return fail("file already exists")
  end
end

local f, reason = io.open(filename, "a")
if not f then
  return fail("failed opening file for writing: " .. reason)
end
f:close()
f = nil

if not options.q then
  io.write("Downloading... ")
end
local ok, response = pcall(internet.request, url, nil, { ["user-agent"] = "Wget/OpenComputers" })
if not ok then
  if not options.q then io.write("failed.\n") end
  return fail("HTTP request failed: " .. response .. "\n", response)
end

local result
result, reason = pcall(function()
  for chunk in response do
    if not f then
      f, reason = io.open(filename, "wb")
      assert(f, "failed opening file for writing: " .. tostring(reason))
    end
    f:write(chunk)
  end
end)
if not result then
  if not options.q then
    io.stderr:write("failed.\n")
  end
  if f then
    f:close()
    if not preexisted then
      fs.remove(filename)
    end
  end
  return fail("HTTP request failed: " .. tostring(reason) .. "\n", reason)
end
if f then
  f:close()
end
if not options.q then
  io.write("success.\nSaved data to " .. filename .. "\n")
end
return true
