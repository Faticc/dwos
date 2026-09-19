local M={}
local KW={}
for w in("and break do else elseif end false for function goto if in local nil not or "..
"repeat return then true until while"):gmatch("%S+")do KW[w]=true end
local OPS2={}
for o in(".. == ~= <= >= :: // << >>"):gmatch("%S+")do OPS2[o]=true end
function M.lexer(src)
local i,len,line,ls=1,#src,1,1
local function long(pos,eq)
local _,b=src:find("]"..eq.."]",pos,true)
local stop=b or len
local from=pos
while true do
local nl=src:find("\n",from,true)
if not nl or nl>stop then break end
line,ls,from=line+1,nl+1,nl+1
end
return stop+1
end
return function()
while i<=len do
local b=src:byte(i)
if b==10 then
line,i=line+1,i+1
ls=i
elseif b==32 or b==9 or b==13 or b==11 or b==12 then
i=i+1
elseif b==45 and src:byte(i+1)==45 then
local eq=src:match("^%[(=*)%[",i+2)
if eq then i=long(i+4+#eq,eq)
else i=src:find("\n",i,true)or len+1 end
else
local at,l,t,v=i,line
if(b>=65 and b<=90)or(b>=97 and b<=122)or b==95 or b>=128 then
local _,e=src:find("^[%w_\128-\255]+",i)
v=src:sub(i,e)
t=KW[v]and"kw"or"name"
i=e+1
elseif(b>=48 and b<=57)or(b==46 and(src:byte(i+1)or 0)>=48 and(src:byte(i+1)or 0)<=57)then
local _,e=src:find("^0[xX][%x%.]*[pP][-+]?%d+",i)
if not e then _,e=src:find("^0[xX][%x%.]*",i)end
if not e then _,e=src:find("^[%d%.]*[eE][-+]?%d+",i)end
if not e then _,e=src:find("^[%d%.]+",i)end
t,v,i="num","0",e+1
elseif b==34 or b==39 then
local j=i+1
while j<=len do
local d=src:byte(j)
if d==92 then
if src:byte(j+1)==10 then line,ls=line+1,j+2 end
if src:byte(j+1)==122 then
local _,e=src:find("^%s*",j+2)
local from=j+2
while true do
local nl=src:find("\n",from,true)
if not nl or nl>e then break end
line,ls,from=line+1,nl+1,nl+1
end
j=e+1
else
j=j+2
end
elseif d==b then
j=j+1
break
elseif d==10 then
break
else
j=j+1
end
end
t,v,i="str","",j
elseif b==91 and src:find("^%[=*%[",i)then
local eq=src:match("^%[(=*)%[",i)
local c0=i-ls+1
i=long(i+2+#eq,eq)
return{t="str",v="",l=l,c=c0}
else
local two=src:sub(i,i+1)
if src:sub(i,i+2)=="..."then v="..."
elseif OPS2[two]then v=two
else v=src:sub(i,i)end
t,i="op",i+#v
end
return{t=t,v=v,l=l,c=at-ls+1}
end
end
return{t="eof",v="",l=line,c=i-ls+1}
end
end
local ENDS={["then"]=true,["do"]=true,["else"]=true,["repeat"]=true,
["break"]=true,["end"]=true,["true"]=true,["false"]=true,["nil"]=true,
[")"]=true,["]"]=true,["}"]=true,["..."]=true,[";"]=true}
local STARTS={["local"]=true,["if"]=true,["for"]=true,["while"]=true,
["repeat"]=true,["return"]=true,["function"]=true,["do"]=true,
["end"]=true,["else"]=true,["elseif"]=true,["until"]=true,
["break"]=true,["goto"]=true,["::"]=true,[";"]=true}
local STMT={["local"]=true,["if"]=true,["for"]=true,["while"]=true,
["repeat"]=true,["return"]=true,["end"]=true,["do"]=true,
["break"]=true,["goto"]=true,[";"]=true,["else"]=true,["elseif"]=true}
local function isOp(tok,v)return tok.t=="op"and tok.v==v end
function M.analyze(src,opt)
opt=opt or{}
local want=opt.name
local R={diags={},funcs={},blocks={},refs={},decls={},globals={}}
if opt.hooks then R.hooks={}end
local nextTok=M.lexer(src)
local ahead,back={},{}
local function peek(n)
while#ahead<=n do ahead[#ahead+1]=nextTok()end
return ahead[n+1]
end
local function skip(n)
for _=1,n do
local t=table.remove(ahead,1)or nextTok()
back[#back+1]=t
if#back>16 then table.remove(back,1)end
end
end
local function behind(n)return back[#back-n+1]end
local scope={vars={},fn=true,list={}}
local scopes={scope}
local cons={}
local brk={}
local brkStack={}
local pending,pendingLine
local lingering
local fnDepth=0
local globalWrites,globalReads={},{}
local known=opt.known or function()return false end
local head
local function declare(name,tok,kind,into)
local d={name=name,l=tok.l,c=tok.c,kind=kind,used=false,up=head}
head=d
if name==want then R.decls[#R.decls+1]=d end
into=into or scope
into.vars[name]=d
into.list[#into.list+1]=d
return d
end
local function ref(tok,d,write)
if tok.v==want then
R.refs[#R.refs+1]={l=tok.l,c=tok.c,len=#tok.v,name=tok.v,decl=d,write=write}
end
end
local function activate()
if pending then
for _,p in ipairs(pending)do declare(p[1],p[2],"local",p.scope)end
pending=nil
end
end
local function lookup(name)
if lingering and lingering[name]then return lingering[name]end
for k=#scopes,1,-1 do
local d=scopes[k].vars[name]
if d then return d end
end
end
local function push(fn)
scope={vars={},fn=fn,list={},base=head}
scopes[#scopes+1]=scope
if fn then
brkStack[#brkStack+1]=brk
brk={}
fnDepth=fnDepth+1
end
end
local function unused(sc)
for _,d in ipairs(sc.list)do
if not d.used and(d.kind=="local"or d.kind=="fn")and d.name:sub(1,1)~="_"then
R.diags[#R.diags+1]={l=d.l,c=d.c,len=#d.name,
msg=d.name.." объявлена, но не используется"}
end
end
end
local function endLinger()
if lingering then unused(lingering._scope)end
lingering=nil
end
local function pop(later)
if#scopes==1 then return end
activate()
if not later then unused(scope)end
local was=table.remove(scopes)
scope=scopes[#scopes]
head=was.base
if was.fn then
brk=table.remove(brkStack)or{}
fnDepth=fnDepth-1
end
return was
end
local function openCons(kind,tok)
cons[#cons+1]={l=tok.l,kind=kind}
return cons[#cons]
end
local function closeCons(tok)
local c=table.remove(cons)
if c and tok.l>c.l then R.blocks[#R.blocks+1]={first=c.l,last=tok.l,kind=c.kind}end
end
local function params(n,into,method)
if method then declare("self",peek(n),"param",into)end
if not isOp(peek(n),"(")then return n end
n=n+1
while peek(n).t~="eof"and not isOp(peek(n),")")do
if peek(n).t=="name"then declare(peek(n).v,peek(n),"param",into)end
n=n+1
end
return n+1
end
local function fnName()
if not(behind(1)and isOp(behind(1),"="))then return nil end
local j,parts=2,{}
while behind(j)and(behind(j).t=="name"or isOp(behind(j),".")or isOp(behind(j),":"))do
table.insert(parts,1,behind(j).v)
j=j+1
end
if#parts==0 then return nil end
local b=behind(j)
return((b and b.t=="kw"and b.v=="local")and"local "or"")..table.concat(parts)
end
local lastLine=0
local prev={t="op",v=";"}
while true do
local tok=peek(0)
if tok.t=="eof"then break end
local v=tok.v
local step=1
if pending and(tok.l>pendingLine or(STMT[v]and(tok.t=="kw"or tok.t=="op")))then
activate()
end
if lingering and tok.l>lingering._line then endLinger()end
if R.hooks and tok.l>lastLine then
local okPrev=prev.t=="name"or prev.t=="num"or prev.t=="str"or ENDS[prev.v]
local okCur=tok.t=="name"or STARTS[v]
if okPrev and okCur and#brk==0 and not scope.ret then
R.hooks[tok.l]={c=tok.c,at=head}
end
end
lastLine=tok.l
if tok.t=="kw"then
if v=="local"then
local nx=peek(1)
if nx.t=="kw"and nx.v=="function"then
local nm=peek(2)
if nm.t=="name"then
declare(nm.v,nm,"fn")
R.funcs[#R.funcs+1]={name="local "..nm.v,l=tok.l,depth=fnDepth}
end
openCons("function",nx)
push(true)
step=params(3,scope)
else
pending,pendingLine={},tok.l
local n=1
while peek(n).t=="name"do
pending[#pending+1]={peek(n).v,peek(n),scope=scope}
n=n+1
if isOp(peek(n),"<")and isOp(peek(n+2),">")then n=n+3 end
if isOp(peek(n),",")then n=n+1 else break end
end
step=n
end
elseif v=="function"then
local nx=peek(1)
openCons("function",tok)
if nx.t=="name"then
local n,parts,method=1,{},false
while true do
parts[#parts+1]=peek(n).v
local s=peek(n+1)
if s.t=="op"and(s.v=="."or s.v==":")and peek(n+2).t=="name"then
parts[#parts+1]=s.v
method=s.v==":"
n=n+2
else
break
end
end
R.funcs[#R.funcs+1]={name=table.concat(parts),l=tok.l,depth=fnDepth}
local d=lookup(nx.v)
local single=#parts==1
ref(nx,d,single)
if d then
if not single then d.used=true end
elseif single then
R.globals[nx.v]=R.globals[nx.v]or{l=nx.l,c=nx.c}
elseif not known(nx.v)then
globalReads[#globalReads+1]={name=nx.v,l=nx.l,c=nx.c}
end
push(true)
step=params(n+1,scope,method)
else
local name=fnName()
if name then R.funcs[#R.funcs+1]={name=name,l=tok.l,depth=fnDepth}end
push(true)
step=params(1,scope)
end
elseif v=="for"then
local c=openCons("for",tok)
local n,vars=1,{}
while peek(n).t=="name"do
vars[#vars+1]=peek(n)
n=n+1
if isOp(peek(n),",")then n=n+1 else break end
end
scope.pend={vars=vars,cons=c}
step=n
elseif v=="while"then
scope.pend={vars={},cons=openCons("while",tok)}
elseif v=="do"then
local p=scope.pend
scope.pend=nil
if not p then openCons("do",tok)end
push(false)
if p then for _,t in ipairs(p.vars)do declare(t.v,t,"for")end end
elseif v=="if"then
openCons("if",tok)
elseif v=="then"then
push(false)
elseif v=="elseif"then
pop()
elseif v=="else"then
pop()
push(false)
elseif v=="repeat"then
openCons("repeat",tok)
push(false)
elseif v=="until"then
endLinger()
local was=pop(true)
closeCons(tok)
if was then
lingering={_line=tok.l,_scope=was}
for nm,d in pairs(was.vars)do lingering[nm]=d end
end
elseif v=="end"then
pop()
closeCons(tok)
elseif v=="return"then
scope.ret=true
elseif v=="goto"then
step=2
end
elseif tok.t=="op"then
if v=="("or v=="["or v=="{"then
brk[#brk+1]={v=v,l=tok.l}
elseif v==")"or v=="]"or v=="}"then
local o=table.remove(brk)
if o and o.v=="{"and tok.l>o.l then
R.blocks[#R.blocks+1]={first=o.l,last=tok.l,kind="table"}
end
elseif v=="::"then
step=3
end
elseif tok.t=="name"then
local nx=peek(1)
local field=prev.t=="op"and(prev.v=="."or prev.v==":")
local top=brk[#brk]
local key=top and top.v=="{"and prev.t=="op"and(prev.v=="{"or prev.v==","or prev.v==";")
and isOp(nx,"=")
if not field and not key then
local write=false
if#brk==0 then
if isOp(nx,"=")then
write=true
elseif isOp(nx,",")and not scope.ret then
local n=1
while isOp(peek(n),",")and peek(n+1).t=="name"do
n=n+2
while isOp(peek(n),".")and peek(n+1).t=="name"do n=n+2 end
end
write=isOp(peek(n),"=")
end
end
local d=lookup(v)
ref(tok,d,write)
if d then
if not write then d.used=true end
elseif write then
if fnDepth==0 then
R.globals[v]=R.globals[v]or{l=tok.l,c=tok.c}
elseif not known(v)then
globalWrites[#globalWrites+1]={name=v,l=tok.l,c=tok.c}
end
elseif not known(v)then
globalReads[#globalReads+1]={name=v,l=tok.l,c=tok.c}
end
end
end
for _=1,step-1 do skip(1)end
prev=peek(0)
skip(1)
end
endLinger()
while#scopes>1 do pop()end
activate()
unused(scopes[1])
local everWritten={}
for _,w in ipairs(globalWrites)do everWritten[w.name]=true end
for _,w in ipairs(globalWrites)do
if not R.globals[w.name]then
R.diags[#R.diags+1]={l=w.l,c=w.c,len=#w.name,
msg="глобальная "..w.name.." внутри функции - забыт local?"}
end
end
for _,r in ipairs(globalReads)do
if not everWritten[r.name]and not R.globals[r.name]and r.name~="_ENV"then
R.diags[#R.diags+1]={l=r.l,c=r.c,len=#r.name,msg="неизвестное имя "..r.name}
end
end
table.sort(R.diags,function(a,b)return a.l<b.l or(a.l==b.l and a.c<b.c)end)
return R
end
function M.names(at,max)
local out,seen={},{}
while at and#out<(max or 60)do
if not seen[at.name]then
seen[at.name]=true
out[#out+1]=at.name
end
at=at.up
end
return out
end
function M.refAt(R,l,c)
for _,r in ipairs(R.refs)do
if r.l==l and c>=r.c and c<=r.c+r.len then return r end
end
for _,d in ipairs(R.decls)do
if d.l==l and c>=d.c and c<=d.c+#d.name then
return{l=d.l,c=d.c,len=#d.name,name=d.name,decl=d}
end
end
end
function M.occurrences(R,ref)
local out={}
if ref.decl then
local d=ref.decl
out[1]={l=d.l,c=d.c,len=#d.name}
for _,r in ipairs(R.refs)do
if r.decl==d then out[#out+1]={l=r.l,c=r.c,len=r.len}end
end
else
for _,r in ipairs(R.refs)do
if not r.decl and r.name==ref.name then out[#out+1]={l=r.l,c=r.c,len=r.len}end
end
end
table.sort(out,function(a,b)return a.l<b.l or(a.l==b.l and a.c<b.c)end)
local uniq={}
for _,o in ipairs(out)do
local last=uniq[#uniq]
if not(last and last.l==o.l and last.c==o.c)then uniq[#uniq+1]=o end
end
return uniq
end
return M
