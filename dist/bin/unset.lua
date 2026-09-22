local a={...}
if#a<1 then
io.write("Usage: unset <varname>[ <varname2> [...]]\n")
else
for b,b in ipairs(a)do
os.setenv(b,nil)
end
end
