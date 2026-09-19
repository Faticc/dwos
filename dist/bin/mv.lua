local shell = require("shell")
local transfer = require("tools/transfer")
local args, options = shell.parse(...)
options.h = options.h or options.help
if #args < 2 or options.h then
  io.write([[Usage: mv [OPTIONS] <from> <to>
  -f         overwrite without prompt
  -i         prompt before overwriting
             unless -f
  -v         verbose
  -n         do not overwrite an existing file
  --skip=P   ignore paths matching lua regex P
  -h, --help show this help
]])
  return not not options.h
end
return transfer.batch(args, {
  cmd = "mv",
  f = options.f, i = options.i, v = options.v, n = options.n,
  skip = { options.skip },
  P = true, r = true, x = true,
})
