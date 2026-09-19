local shell = require("shell")
local fs = require("filesystem")

local args, ops = shell.parse(...)
local path
local verbose = false

if ops.help then
  print("Usage cd [dir]\nFor more options, run: man cd")
  return
end

if #args == 0 then
  path = os.getenv("HOME")
  if not path then
    io.stderr:write("cd: HOME not set\n")
    return 1
  end
elseif args[1] == "-" then
  verbose = true
  path = os.getenv("OLDPWD")
  if not path then
    io.stderr:write("cd: OLDPWD not set\n")
    return 1
  end
else
  path = args[1]
end

local resolved = shell.resolve(path)
if not fs.exists(resolved) then
  io.stderr:write("cd: ", path, ": No such file or directory\n")
  return 1
end

local oldpwd = shell.getWorkingDirectory()
local result, reason = shell.setWorkingDirectory(resolved)
if not result then
  io.stderr:write("cd: ", resolved, ": ", reason)
  return 1
end
os.setenv("OLDPWD", oldpwd)
if verbose then
  os.execute("pwd")
end
