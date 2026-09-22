local n={}
local j={}
for a in("and break do else elseif end false for function goto if in local nil not or "..
"repeat return then true until while"):gmatch("%S+")do j[a]=true end
local k={}
for a in(".. == ~= <= >= :: // << >>"):gmatch("%S+")do k[a]=true end
function n.lexer(b)
local a,i,e,g=1,#b,1,1
local function l(c,d)
local f,f=b:find("]"..d.."]",c,true)
local d=f or i
local f=c
while true do
local c=b:find("\n",f,true)
if not c or c>d then break end
e,g,f=e+1,c+1,c+1
end
return d+1
end
return function()
while a<=i do
local c=b:byte(a)
if c==10 then
e,a=e+1,a+1
g=a
elseif c==32 or c==9 or c==13 or c==11 or c==12 then
a=a+1
elseif c==45 and b:byte(a+1)==45 then
local d=b:match("^%[(=*)%[",a+2)
if d then a=l(a+4+#d,d)
else a=b:find("\n",a,true)or i+1 end
else
local q,m,h,f=a,e
if(c>=65 and c<=90)or(c>=97 and c<=122)or c==95 or c>=128 then
local d,d=b:find("^[%w_\128-\255]+",a)
f=b:sub(a,d)
h=j[f]and"kw"or"name"
a=d+1
elseif(c>=48 and c<=57)or(c==46 and(b:byte(a+1)or 0)>=48 and(b:byte(a+1)or 0)<=57)then
local j,d=b:find("^0[xX][%x%.]*[pP][-+]?%d+",a)
if not d then j,d=b:find("^0[xX][%x%.]*",a)end
if not d then j,d=b:find("^[%d%.]*[eE][-+]?%d+",a)end
if not d then j,d=b:find("^[%d%.]+",a)end
h,f,a="num","0",d+1
elseif c==34 or c==39 then
local d=a+1
while d<=i do
local j=b:byte(d)
if j==92 then
if b:byte(d+1)==10 then e,g=e+1,d+2 end
if b:byte(d+1)==122 then
local i,o=b:find("^%s*",d+2)
local p=d+2
while true do
local i=b:find("\n",p,true)
if not i or i>o then break end
e,g,p=e+1,i+1,i+1
end
d=o+1
else
d=d+2
end
elseif j==c then
d=d+1
break
elseif j==10 then
break
else
d=d+1
end
end
h,f,a="str","",d
elseif c==91 and b:find("^%[=*%[",a)then
local c=b:match("^%[(=*)%[",a)
local d=a-g+1
a=l(a+2+#c,c)
return{t="str",v="",l=m,c=d}
else
local c=b:sub(a,a+1)
if b:sub(a,a+2)=="..."then f="..."
elseif k[c]then f=c
else f=b:sub(a,a)end
h,a="op",a+#f
end
return{t=h,v=f,l=m,c=q-g+1}
end
end
return{t="eof",v="",l=e,c=a-g+1}
end
end
local C={["then"]=true,["do"]=true,["else"]=true,["repeat"]=true,
["break"]=true,["end"]=true,["true"]=true,["false"]=true,["nil"]=true,
[")"]=true,["]"]=true,["}"]=true,["..."]=true,[";"]=true}
local H={["local"]=true,["if"]=true,["for"]=true,["while"]=true,
["repeat"]=true,["return"]=true,["function"]=true,["do"]=true,
["end"]=true,["else"]=true,["elseif"]=true,["until"]=true,
["break"]=true,["goto"]=true,["::"]=true,[";"]=true}
local I={["local"]=true,["if"]=true,["for"]=true,["while"]=true,
["repeat"]=true,["return"]=true,["end"]=true,["do"]=true,
["break"]=true,["goto"]=true,[";"]=true,["else"]=true,["elseif"]=true}
local function f(a,b)return a.t=="op"and a.v==b end
function n.analyze(a,g)
g=g or{}
local r=g.name
local b={diags={},funcs={},blocks={},refs={},decls={},globals={}}
if g.hooks then b.hooks={}end
local e=n.lexer(a)
local c,a={},{}
local function d(h)
while#c<=h do c[#c+1]=e()end
return c[h+1]
end
local function D(h)
for i=1,h do
local h=table.remove(c,1)or e()
a[#a+1]=h
if#a>16 then table.remove(a,1)end
end
end
local function c(e)return a[#a-e+1]end
local e={vars={},fn=true,list={}}
local i={e}
local h={}
local j={}
local q={}
local o,v
local k
local l=0
local w,s={},{}
local x=g.known or function()return false end
local g
local function t(p,u,y,a)
local m={name=p,l=u.l,c=u.c,kind=y,used=false,up=g}
g=m
if p==r then b.decls[#b.decls+1]=m end
a=a or e
a.vars[p]=m
a.list[#a.list+1]=m
return m
end
local function E(a,m,p)
if a.v==r then
b.refs[#b.refs+1]={l=a.l,c=a.c,len=#a.v,name=a.v,decl=m,write=p}
end
end
local function y()
if o then
for a,a in ipairs(o)do t(a[1],a[2],"local",a.scope)end
o=nil
end
end
local function F(a)
if k and k[a]then return k[a]end
for p=#i,1,-1 do
local m=i[p].vars[a]
if m then return m end
end
end
local function p(a)
e={vars={},fn=a,list={},base=g}
i[#i+1]=e
if a then
q[#q+1]=j
j={}
l=l+1
end
end
local function z(m)
for a,a in ipairs(m.list)do
if not a.used and(a.kind=="local"or a.kind=="fn")and a.name:sub(1,1)~="_"then
b.diags[#b.diags+1]={l=a.l,c=a.c,len=#a.name,
msg=a.name.." объявлена, но не используется"}
end
end
end
local function A()
if k then z(k._scope)end
k=nil
end
local function u(a)
if#i==1 then return end
y()
if not a then z(e)end
local a=table.remove(i)
e=i[#i]
g=a.base
if a.fn then
j=table.remove(q)or{}
l=l-1
end
return a
end
local function q(a,m)
h[#h+1]={l=m.l,kind=a}
return h[#h]
end
local function G(m)
local a=table.remove(h)
if a and m.l>a.l then b.blocks[#b.blocks+1]={first=a.l,last=m.l,kind=a.kind}end
end
local function B(a,h,m)
if m then t("self",d(a),"param",h)end
if not f(d(a),"(")then return a end
a=a+1
while d(a).t~="eof"and not f(d(a),")")do
if d(a).t=="name"then t(d(a).v,d(a),"param",h)end
a=a+1
end
return a+1
end
local function J()
if not(c(1)and f(c(1),"="))then return nil end
local a,h=2,{}
while c(a)and(c(a).t=="name"or f(c(a),".")or f(c(a),":"))do
table.insert(h,1,c(a).v)
a=a+1
end
if#h==0 then return nil end
local m=c(a)
return((m and m.t=="kw"and m.v=="local")and"local "or"")..table.concat(h)
end
local r=0
local h={t="op",v=";"}
while true do
local a=d(0)
if a.t=="eof"then break end
local c=a.v
local m=1
if o and(a.l>v or(I[c]and(a.t=="kw"or a.t=="op")))then
y()
end
if k and a.l>k._line then A()end
if b.hooks and a.l>r then
local I=h.t=="name"or h.t=="num"or h.t=="str"or C[h.v]
local C=a.t=="name"or H[c]
if I and C and#j==0 and not e.ret then
b.hooks[a.l]={c=a.c,at=g}
end
end
r=a.l
if a.t=="kw"then
if c=="local"then
local r=d(1)
if r.t=="kw"and r.v=="function"then
local g=d(2)
if g.t=="name"then
t(g.v,g,"fn")
b.funcs[#b.funcs+1]={name="local "..g.v,l=a.l,depth=l}
end
q("function",r)
p(true)
m=B(3,e)
else
o,v={},a.l
local g=1
while d(g).t=="name"do
o[#o+1]={d(g).v,d(g),scope=e}
g=g+1
if f(d(g),"<")and f(d(g+2),">")then g=g+3 end
if f(d(g),",")then g=g+1 else break end
end
m=g
end
elseif c=="function"then
local g=d(1)
q("function",a)
if g.t=="name"then
local o,r,H=1,{},false
while true do
r[#r+1]=d(o).v
local v=d(o+1)
if v.t=="op"and(v.v=="."or v.v==":")and d(o+2).t=="name"then
r[#r+1]=v.v
H=v.v==":"
o=o+2
else
break
end
end
b.funcs[#b.funcs+1]={name=table.concat(r),l=a.l,depth=l}
local v=F(g.v)
local C=#r==1
E(g,v,C)
if v then
if not C then v.used=true end
elseif C then
b.globals[g.v]=b.globals[g.v]or{l=g.l,c=g.c}
elseif not x(g.v)then
s[#s+1]={name=g.v,l=g.l,c=g.c}
end
p(true)
m=B(o+1,e,H)
else
local g=J()
if g then b.funcs[#b.funcs+1]={name=g,l=a.l,depth=l}end
p(true)
m=B(1,e)
end
elseif c=="for"then
local r=q("for",a)
local g,o=1,{}
while d(g).t=="name"do
o[#o+1]=d(g)
g=g+1
if f(d(g),",")then g=g+1 else break end
end
e.pend={vars=o,cons=r}
m=g
elseif c=="while"then
e.pend={vars={},cons=q("while",a)}
elseif c=="do"then
local g=e.pend
e.pend=nil
if not g then q("do",a)end
p(false)
if g then for o,o in ipairs(g.vars)do t(o.v,o,"for")end end
elseif c=="if"then
q("if",a)
elseif c=="then"then
p(false)
elseif c=="elseif"then
u()
elseif c=="else"then
u()
p(false)
elseif c=="repeat"then
q("repeat",a)
p(false)
elseif c=="until"then
A()
local g=u(true)
G(a)
if g then
k={_line=a.l,_scope=g}
for o,p in pairs(g.vars)do k[o]=p end
end
elseif c=="end"then
u()
G(a)
elseif c=="return"then
e.ret=true
elseif c=="goto"then
m=2
end
elseif a.t=="op"then
if c=="("or c=="["or c=="{"then
j[#j+1]={v=c,l=a.l}
elseif c==")"or c=="]"or c=="}"then
local g=table.remove(j)
if g and g.v=="{"and a.l>g.l then
b.blocks[#b.blocks+1]={first=g.l,last=a.l,kind="table"}
end
elseif c=="::"then
m=3
end
elseif a.t=="name"then
local k=d(1)
local o=h.t=="op"and(h.v=="."or h.v==":")
local g=j[#j]
local p=g and g.v=="{"and h.t=="op"and(h.v=="{"or h.v==","or h.v==";")
and f(k,"=")
if not o and not p then
local g=false
if#j==0 then
if f(k,"=")then
g=true
elseif f(k,",")and not e.ret then
local e=1
while f(d(e),",")and d(e+1).t=="name"do
e=e+2
while f(d(e),".")and d(e+1).t=="name"do e=e+2 end
end
g=f(d(e),"=")
end
end
local e=F(c)
E(a,e,g)
if e then
if not g then e.used=true end
elseif g then
if l==0 then
b.globals[c]=b.globals[c]or{l=a.l,c=a.c}
elseif not x(c)then
w[#w+1]={name=c,l=a.l,c=a.c}
end
elseif not x(c)then
s[#s+1]={name=c,l=a.l,c=a.c}
end
end
end
for a=1,m-1 do D(1)end
h=d(0)
D(1)
end
A()
while#i>1 do u()end
y()
z(i[1])
local c={}
for a,a in ipairs(w)do c[a.name]=true end
for a,a in ipairs(w)do
if not b.globals[a.name]then
b.diags[#b.diags+1]={l=a.l,c=a.c,len=#a.name,
msg="глобальная "..a.name.." внутри функции - забыт local?"}
end
end
for a,a in ipairs(s)do
if not c[a.name]and not b.globals[a.name]and a.name~="_ENV"then
b.diags[#b.diags+1]={l=a.l,c=a.c,len=#a.name,msg="неизвестное имя "..a.name}
end
end
table.sort(b.diags,function(a,c)return a.l<c.l or(a.l==c.l and a.c<c.c)end)
return b
end
function n.names(a,d)
local b,c={},{}
while a and#b<(d or 60)do
if not c[a.name]then
c[a.name]=true
b[#b+1]=a.name
end
a=a.up
end
return b
end
function n.refAt(c,d,b)
for a,a in ipairs(c.refs)do
if a.l==d and b>=a.c and b<=a.c+a.len then return a end
end
for a,a in ipairs(c.decls)do
if a.l==d and b>=a.c and b<=a.c+#a.name then
return{l=a.l,c=a.c,len=#a.name,name=a.name,decl=a}
end
end
end
function n.occurrences(e,d)
local a={}
if d.decl then
local b=d.decl
a[1]={l=b.l,c=b.c,len=#b.name}
for c,c in ipairs(e.refs)do
if c.decl==b then a[#a+1]={l=c.l,c=c.c,len=c.len}end
end
else
for b,b in ipairs(e.refs)do
if not b.decl and b.name==d.name then a[#a+1]={l=b.l,c=b.c,len=b.len}end
end
end
table.sort(a,function(b,c)return b.l<c.l or(b.l==c.l and b.c<c.c)end)
local b={}
for c,c in ipairs(a)do
local a=b[#b]
if not(a and a.l==c.l and a.c==c.c)then b[#b+1]=c end
end
return b
end
return n
