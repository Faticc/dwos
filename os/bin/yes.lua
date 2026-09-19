local args, options = require("shell").parse(...)
if options.V or options.version then
  io.write("yes v:1.0-3\nInspired by functionality of yes from GNU coreutils\n")
  return 0
end
if options.h or options.help then
  io.write("Usage: yes [string]...\nOR:    yes [-V/h]\n\n")
  io.write("yes prints the command line arguments, or 'y', until is killed.\n\n")
  io.write("Options:\n\t-V, --version\tVersion\n\t-h, --help  \tThis help\n")
  return 0
end
local msg = (#args == 0 and "y" or table.concat(args, " ")) .. "\n"
while io.write(msg) do
  if io.stdout.tty then
    os.sleep(0)
  end
end
return 0
