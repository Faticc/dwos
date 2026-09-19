local shell = require("shell")
local args, options = shell.parse(...)
if options.help then
  print([[Usage: sleep NUMBER[SUFFIX]...
Pause for NUMBER seconds.  SUFFIX may be 's' for seconds (the default),
'm' for minutes, 'h' for hours or 'd' for days.  Unlike most implementations
that require NUMBER be an integer, here NUMBER may be an arbitrary floating
point number.  Given two or more arguments, pause for the amount of time
specified by the sum of their values.]])
end
options.help = nil
local function bad(arg)
  print("sleep: invalid option -- '" .. tostring(arg) .. "'")
  print("Try 'sleep --help' for more information.")
  return 1
end
if next(options) then
  return bad(next(options))
end
local MULT = { [""] = 1, s = 1, m = 60, h = 3600, d = 86400 }
local total_time = 0
for _, v in ipairs(args) do
  local interval, suffix = v:match("^([%d%.]+)([smhd]?)$")
  interval = tonumber(interval)
  if not interval or interval < 0 then
    return bad(v)
  end
  total_time = total_time + MULT[suffix] * interval
end
local ins = io.stdin.stream
if ins.pull then
  ins:pull(total_time, "interrupted")
else
  require("event").pull(total_time, "interrupted")
end
