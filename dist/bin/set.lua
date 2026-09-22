local c={...}
if#c<1 then
for a,b in pairs(os.getenv())do
io.write(a.."='"..string.gsub(b,"'",[['"'"']]).."'\n")
end
return
end
local a=0
for b,b in ipairs(c)do
local c=b:find("=")
if c then
os.setenv(b:sub(1,c-1),b:sub(c+1))
else
if a==0 then
for c=1,os.getenv("#")do
os.setenv(c,nil)
end
end
a=a+1
os.setenv(a,b)
end
end
