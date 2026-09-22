local d={}
function d.next()
local b={}
for a=1,16 do
local c=math.random(0,255)
if a==7 then
c=c%16+0x40
elseif a==9 then
c=c%64+0x80
end
b[#b+1]=string.format("%02x",c)
if a==4 or a==6 or a==8 or a==10 then
b[#b+1]="-"
end
end
return table.concat(b)
end
return d
