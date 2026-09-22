local b=require("computer")
local c=b.totalMemory()
local a=0
for d=1,40 do
a=math.max(a,b.freeMemory())
os.sleep(0)
end
io.write(string.format("Total%12d\nUsed%13d\nFree%13d\n",c,c-a,a))
