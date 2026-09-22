local a={}
local d={"white","orange","magenta","lightblue","yellow","lime","pink","gray",
"silver","cyan","purple","blue","brown","green","red","black"}
for b,c in ipairs(d)do
a[b-1]=c
a[c]=b-1
end
return a
