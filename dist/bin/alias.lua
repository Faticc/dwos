local shell = require("shell")
local args, options = shell.parse(...)
if options.help then
  print("Usage: alias: [name[=value] ... ]")
  return
end
local ec = 0
if not next(args) then
  for k, v in shell.aliases() do
    print(string.format("alias %s='%s'", k, v))
  end
  return ec
end
for _, arg in ipairs(args) do
  checkArg(1, arg, "string")
  local eq = arg:find("=")
  if not eq or eq == 1 then
    local v = shell.getAlias(arg)
    if not v then
      io.stderr:write(string.format("alias: %s: not found\n", arg))
      ec = 1
    else
      io.write(string.format("alias %s='%s'\n", arg, v))
    end
  else
    local k, v = arg:sub(1, eq - 1), arg:sub(eq + 1)
    if k:match("[/%$`=|&;%(%)<> \t]") then
      io.stderr:write(string.format("alias: `%s': invalid alias name\n", k))
    else
      shell.setAlias(k, v)
    end
  end
end
return ec
