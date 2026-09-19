local process=require("process")
local shell=require("shell")
local text=require("text")
local sh={}
sh.internal={}
function sh.internal.isWordOf(w,vs)
if not w or#w~=1 or w[1].qr then return false end
local txt=w[1].txt
for i=1,#vs do
if vs[i]==txt then return true end
end
return false
end
local isWordOf=sh.internal.isWordOf
local DELIMS={";","&&","||","|"}
sh.internal.ec={parseCommand=127,last=0}
function sh.getLastExitCode()
return sh.internal.ec.last
end
function sh.internal.command_result_as_code(ec,reason)
local code
if ec==false then
code=1
elseif ec==nil or ec==true then
code=0
elseif type(ec)~="number"then
code=2
else
code=ec
end
if reason and code~=0 then io.stderr:write(reason,"\n")end
return code
end
function sh.internal.resolveActions(input,resolved)
resolved=resolved or{}
local processed={}
local prev_was_delim=true
local words,reason=text.internal.tokenize(input)
if not words then
return nil,reason
end
local i=1
while i<=#words do
local nxt=words[i]
i=i+1
if isWordOf(nxt,DELIMS)then
prev_was_delim=true
resolved={}
elseif prev_was_delim then
prev_was_delim=false
if#nxt==1 and not nxt[1].qr then
local key=nxt[1].txt
if key=="!"then
prev_was_delim=true
elseif not resolved[key]then
resolved[key]=shell.getAlias(key)
local value=resolved[key]
if value and key~=value then
local replacement,why=sh.internal.resolveActions(value,resolved)
if not replacement then
return replacement,why
end
local rest={}
for j=1,#replacement do rest[#rest+1]=replacement[j]end
for j=i,#words do rest[#rest+1]=words[j]end
words,i=rest,1
nxt=table.remove(words,1)
end
end
end
end
processed[#processed+1]=nxt
end
return processed
end
function sh.internal.isIdentifier(key)
if type(key)~="string"then
return false
end
return key:match("^[%a_][%w_]*$")==key
end
function sh.expand(value)
return(value:gsub("%$([_%w%?]+)",function(key)
if key=="?"then
return tostring(sh.getLastExitCode())
end
return os.getenv(key)or""
end):gsub("%${(.*)}",function(key)
if sh.internal.isIdentifier(key)then
return os.getenv(key)or""
end
io.stderr:write("${"..key.."}: bad substitution\n")
os.exit(1)
end))
end
function sh.internal.createThreads(commands,env,start_args)
local threads={}
for i=1,#commands do
local program,args,redirects=table.unpack(commands[i])
local thread_env=type(program)=="string"and env or nil
local thread,reason=process.load(program or"/dev/null",thread_env,function(...)
if redirects then
sh.internal.openCommandRedirects(redirects)
end
local all,n={},0
for j=1,#args do n=n+1 all[n]=args[j]end
local extra=start_args[i]
if extra then for j=1,extra.n or#extra do n=n+1 all[n]=extra[j]end end
local more=table.pack(...)
for j=1,more.n do n=n+1 all[n]=more[j]end
io.write("")
return table.unpack(all,1,n)
end,tostring(program))
if not thread then
for _,t in ipairs(threads)do
process.internal.close(t)
end
return nil,reason
end
threads[i]=thread
end
if#threads>1 then
require("pipe").buildPipeChain(threads)
end
return threads
end
function sh.internal.executePipes(pipe_parts,eargs,env)
local commands={}
for _,words in ipairs(pipe_parts)do
local args={}
local reparse
for _,word in ipairs(words)do
local value=""
for _,part in ipairs(word)do
reparse=reparse or part.qr or part.txt:find("[%$%*%?<>]")
value=value..part.txt
end
args[#args+1]=value
end
local redirects
if reparse then
args,redirects=sh.internal.evaluate(words)
if not args then
return false,redirects
end
end
commands[#commands+1]=table.pack(table.remove(args,1),args,redirects)
end
local threads,reason=sh.internal.createThreads(commands,env,{[#commands]=eargs})
if not threads then return false,reason end
return process.internal.continue(threads[1])
end
function sh.execute(env,command,...)
checkArg(2,command,"string")
if command:find("^%s*#")then return true,0 end
local words,reason=sh.internal.resolveActions(command)
if type(words)~="table"then
return words,reason
elseif#words==0 then
return true
end
local eargs=table.pack(...)
if not command:find("[;%$&|!<>]")then
sh.internal.ec.last=sh.internal.command_result_as_code(sh.internal.executePipes({words},eargs,env))
return sh.internal.ec.last==0
end
return sh.internal.execute_complex(words,eargs,env)
end
function sh.hintHandler(full_line,cursor)
return sh.internal.hintHandlerImpl(full_line,cursor)
end
require("package").delay(sh,"/lib/core/full_sh.lua")
return sh
