local package=require("package")
local term=require("term")
local function optrequire(...)
local ok,module=pcall(require,...)
if ok then
return module
end
end
local env
env=setmetatable({},{
__index=function(_,k)
_ENV[k]=_ENV[k]or optrequire(k)
return _ENV[k]
end,
__pairs=function(t)
return function(_,key)
local k,v=next(t,key)
if not k and t==env then
t=_ENV
k,v=next(t)
end
if not k and t==_ENV then
t=package.loaded
k,v=next(t)
end
return k,v
end
end,
})
env._PROMPT=tostring(env._PROMPT or"\27[32mlua> \27[37m")
local function findTable(t,path)
if type(t)~="table"then return nil end
if not path or#path==0 then return t end
local name=path:match("[^.]+")
for k,v in pairs(t)do
if k==name then
return findTable(v,path:sub(#name+2))
end
end
local mt=getmetatable(t)
if t==env then mt={__index=_ENV}end
if mt then
return findTable(mt.__index,path)
end
end
local function findKeys(t,r,prefix,name)
if type(t)~="table"then return end
for k,v in pairs(t)do
if type(k)=="string"and k:match("^"..name)then
local postfix=""
if type(v)=="function"or type(v)=="table"and getmetatable(v)and getmetatable(v).__call then
postfix="()"
elseif type(v)=="table"then
postfix="."
end
r[prefix..k..postfix]=true
end
end
local mt=getmetatable(t)
if t==env then mt={__index=_ENV}end
if mt then
return findKeys(mt.__index,r,prefix,name)
end
end
local read_handler={hint=function(line,index)
line=line or""
local tail=line:sub(index)
line=line:sub(1,index-1)
local path=line:match("[a-zA-Z_][a-zA-Z0-9_.]*$")
if not path then return nil end
local suffix=path:match("[^.]+$")or""
local prefix=path:sub(1,#path-#suffix)
local tbl=findTable(env,prefix)
if not tbl then return nil end
local keys,hints={},{}
findKeys(tbl,keys,line:sub(1,#line-#suffix),suffix)
for key in pairs(keys)do
hints[#hints+1]=key..tail
end
return hints
end}
io.write("\27[37m".._VERSION.." Copyright (C) 1994-2022 Lua.org, PUC-Rio\n")
io.write("\27[33mEnter a statement and hit enter to evaluate it.\n")
io.write("Prefix an expression with '=' to show its value.\n")
io.write("Press Ctrl+D to exit the interpreter.\n\27[37m")
while term.isAvailable()do
io.write(env._PROMPT)
local command=term.read(read_handler)
if not command then
return
end
local code,reason
if command:sub(1,1)=="="then
code,reason=load("return "..command:sub(2),"=stdin","t",env)
else
code,reason=load("return "..command,"=stdin","t",env)
if not code then
code,reason=load(command,"=stdin","t",env)
end
end
if code then
local result=table.pack(xpcall(code,debug.traceback))
if not result[1]then
if type(result[2])=="table"and result[2].reason=="terminated"then
os.exit(result[2].code)
end
io.stderr:write(tostring(result[2]).."\n")
else
local ok,why=pcall(function()
local ser=require("serialization")
for i=2,result.n do
io.write(ser.serialize(result[i],true),i<result.n and"\t"or"\n")
end
end)
if not ok then
io.stderr:write("crashed serializing result: ",tostring(why))
end
end
else
io.stderr:write(tostring(reason).."\n")
end
end
