local shell = require("shell")
local fs = require("filesystem")

local args, options = shell.parse(...)

if options.help then
  print([[Usage: rmdir [OPTION]... DIRECTORY...
Removes the DIRECTORY(ies), if they are empty.

  -q, --ignore-fail-on-non-empty
                  ignore failures due solely to non-empty directories
  -p, --parents   remove DIRECTORY and its empty ancestors
                  e.g. 'rmdir -p a/b/c' is similar to 'rmdir a/b/c a/b a'
  -v, --verbose   output a diagnostic for every directory processed
      --help      display this help and exit]])
  return 0
end

if #args == 0 then
  io.stderr:write("rmdir: missing operand\n")
  return 1
end

local parents = options.p or options.parents
local verbose = options.v or options.verbose
local quiet = options.q or options["ignore-fail-on-non-empty"]

local ec = 0
local function fail(msg)
  if msg then io.stderr:write(msg) end
  ec = 1
  return false
end

local function remove(path)
  if verbose then
    print(string.format("rmdir: removing directory, %s", path))
  end
  local rpath = shell.resolve(path)
  if path == "." then
    return fail("rmdir: failed to remove directory '.': Invalid argument\n")
  elseif not fs.exists(rpath) then
    return fail("rmdir: cannot remove " .. path .. ": path does not exist\n")
  elseif fs.isLink(rpath) or not fs.isDirectory(rpath) then
    return fail("rmdir: cannot remove " .. path .. ": not a directory\n")
  end
  local list, reason = fs.list(rpath)
  if not list then
    return fail(tostring(reason) .. "\n")
  end
  if list() then
    return fail(not quiet and ("rmdir: failed to remove " .. path .. ": Directory not empty\n") or nil)
  end
  local ok, why = fs.remove(rpath)
  if not ok then
    return fail(tostring(why) .. "\n")
  end
  return true
end

for _, path in ipairs(args) do
  path = path:gsub("/+", "/")
  -- -p a/b/c: сначала a/b/c, потом a/b, потом a
  local chain = { path }
  if parents and path:len() > 1 and path:find("/") then
    chain = {}
    local prefix = path:sub(1, 1) == "/" and "/" or ""
    for part in path:gmatch("[^/]+") do
      table.insert(chain, 1, prefix .. part)
      prefix = prefix .. part .. "/"
    end
  end
  for _, p in ipairs(chain) do
    if not remove(p) then break end
  end
end

return ec
