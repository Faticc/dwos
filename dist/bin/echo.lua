local a,b=require("shell").parse(...)
if b.help then
io.write([[
`echo` writes the provided string(s) to the standard output.
  -n      do not output the trialing newline
  -e      enable interpretation of backslash escapes
  --help  display this help and exit
]])
return
end
if b.e then
for c,d in ipairs(a)do
a[c]=assert(load("return \""..d:gsub('"',[[\"]]).."\""))()
end
end
io.write(table.concat(a," "))
if not b.n then
io.write("\n")
end
