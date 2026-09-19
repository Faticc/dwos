local uuid={}
function uuid.next()
local out={}
for i=1,16 do
local byte=math.random(0,255)
if i==7 then
byte=byte%16+0x40
elseif i==9 then
byte=byte%64+0x80
end
out[#out+1]=string.format("%02x",byte)
if i==4 or i==6 or i==8 or i==10 then
out[#out+1]="-"
end
end
return table.concat(out)
end
return uuid
