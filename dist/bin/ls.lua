local b,a=pcall(function(...)
return loadfile("/lib/core/full_ls.lua","bt",_G)(...)
end,...)
if not b then
if type(a)=="table"then
if a.code==0 then
return
end
a=a.reason
end
io.stderr:write(tostring(a).."\nFor low memory systems, try using `list` instead\n")
return 1
end
return a
