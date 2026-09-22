local a=require("keyboard").keys
local b=[[
1=02 2=03 3=04 4=05 5=06 6=07 7=08 8=09 9=0A 0=0B
a=1E b=30 c=2E d=20 e=12 f=21 g=22 h=23 i=17 j=24 k=25 l=26 m=32
n=31 o=18 p=19 q=10 r=13 s=1F t=14 u=16 v=2F w=11 x=2D y=15 z=2C
apostrophe=28 at=91 back=0E backslash=2B capital=3A colon=92 comma=33
enter=1C equals=0D grave=29 lbracket=1A lcontrol=1D lmenu=38 lshift=2A
minus=0C numlock=45 pause=C5 period=34 rbracket=1B rcontrol=9D rmenu=B8
rshift=36 scroll=46 semicolon=27 slash=35 space=39 stop=95 tab=0F underline=93
up=C8 down=D0 left=CB right=CD home=C7 end=CF pageUp=C9 pageDown=D1
insert=D2 delete=D3
f1=3B f2=3C f3=3D f4=3E f5=3F f6=40 f7=41 f8=42 f9=43 f10=44 f11=57 f12=58
f13=64 f14=65 f15=66 f16=67 f17=68 f18=69 f19=71
kana=70 kanji=94 convert=79 noconvert=7B yen=7D circumflex=90 ax=96
numpad0=52 numpad1=4F numpad2=50 numpad3=51 numpad4=4B numpad5=4C
numpad6=4D numpad7=47 numpad8=48 numpad9=49 numpadmul=37 numpaddiv=B5
numpadsub=4A numpadadd=4E numpaddecimal=53 numpadcomma=B3 numpadenter=9C
numpadequals=8D
]]
for c,d in b:gmatch("(%S+)=(%x%x)")do
a[c]=tonumber(d,16)
end
setmetatable(a,{
__index=function(b,a)
if type(a)~="number"then return end
for c,d in pairs(b)do
if d==a then
return c
end
end
end,
})
