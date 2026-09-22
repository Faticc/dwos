local b,a=require("shell").parse(...)
if a.V or a.version then
io.write("yes v:1.0-3\nInspired by functionality of yes from GNU coreutils\n")
return 0
end
if a.h or a.help then
io.write("Usage: yes [string]...\nOR:    yes [-V/h]\n\n")
io.write("yes prints the command line arguments, or 'y', until is killed.\n\n")
io.write("Options:\n\t-V, --version\tVersion\n\t-h, --help  \tThis help\n")
return 0
end
local a=(#b==0 and"y"or table.concat(b," ")).."\n"
while io.write(a)do
if io.stdout.tty then
os.sleep(0)
end
end
return 0
