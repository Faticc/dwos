local package={}
package.config="/\n;\n?\n!\n-\n"
package.path="/lib/?.lua;/usr/lib/?.lua;/home/lib/?.lua;./?.lua;/lib/?/init.lua;/usr/lib/?/init.lua;/home/lib/?/init.lua;./?/init.lua"
local loading,preload,searchers={},{},{}
local loaded={
_G=_G,bit32=bit32,coroutine=coroutine,math=math,os=os,
package=package,string=string,table=table,
}
package.loaded,package.preload,package.searchers=loaded,preload,searchers
function package.searchpath(name,path,sep,rep)
checkArg(1,name,"string")
checkArg(2,path,"string")
sep,rep="%"..(sep or"."),rep or"/"
name=name:gsub(sep,rep)
local fs=require("filesystem")
local tried={}
for sub in path:gmatch("[^;]+")do
sub=sub:gsub("?",name)
if sub:sub(1,1)~="/"and os.getenv then
sub=fs.concat(os.getenv("PWD")or"/",sub)
end
if fs.exists(sub)and not fs.isDirectory(sub)then
return sub
end
tried[#tried+1]="no file '"..sub.."'"
end
return nil,table.concat(tried,"\n\t")
end
searchers[1]=function(module)
return preload[module]or"no field package.preload['"..module.."']"
end
searchers[2]=function(module)
local path,status=package.searchpath(module,package.path)
if not path then return status end
local library,reason=loadfile(path)
if not library then
error(string.format("error loading module '%s' from file '%s':\n\t%s",module,path,reason))
end
return library,module
end
function require(module)
checkArg(1,module,"string")
local value=loaded[module]
if value~=nil then return value end
if loading[module]then
error("already loading: "..module.."\n"..debug.traceback(),2)
end
if type(searchers)~="table"then error("'package.searchers' must be a table")end
local library,arg
local errors=""
for _,searcher in pairs(searchers)do
library,arg=searcher(module)
if type(library)=="function"then break end
if library~=nil then errors=errors.."\n\t"..tostring(library)end
library=nil
end
if not library then error(string.format("module '%s' not found:%s",module,errors))end
loading[module]=true
local ok,result=pcall(library,arg or module)
loading[module]=false
assert(ok,string.format("module '%s' load failed:\n%s",module,result))
loaded[module]=result
return result
end
function package.delay(lib,file)
local mt={}
function mt.__index(tbl,key)
mt.__index=nil
dofile(file)
return tbl[key]
end
if lib.internal then setmetatable(lib.internal,mt)end
setmetatable(lib,mt)
end
return package
