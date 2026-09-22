local h=require("computer")
local b={}
local c={}
local f={}
do
local i={"c","c#","d","d#","e","f","f#","g","g#","a","a#","b"}
local d={"a0","a#0","b0"}
local e={"bb0"}
for g=1,6 do
for a,a in ipairs(i)do
d[#d+1]=a..g
if#a==1 and a~="c"and a~="f"then
e[#e+1]=a.."b"..g
end
end
end
for a=21,95 do
c[d[a-20]]=tostring(a)
f[a]=d[a-20]
end
for a,a in ipairs(e)do
c[a]=tostring(c[a:gsub("(.)b(.)","%1%2")]-1)
end
end
function b.midi(a)
if type(a)=="string"then
a=a:lower()
if tonumber(c[a])then
return tonumber(c[a])
end
error("Wrong input "..tostring(a).." given to note.midi, needs to be <note>[semitone sign]<octave>, e.g. A#0 or Gb4")
elseif type(a)=="number"then
return math.floor((12*math.log(a/440,2))+69)
end
error("Wrong input "..tostring(a).." given to note.midi, needs to be a number or a string")
end
function b.freq(a)
if type(a)=="string"then
a=a:lower()
if tonumber(c[a])then
return 2^((tonumber(c[a])-69)/12)*440
end
error("Wrong input "..tostring(a).." given to note.freq, needs to be <note>[semitone sign]<octave>, e.g. A#0 or Gb4",2)
elseif type(a)=="number"then
return 2^((a-69)/12)*440
end
error("Wrong input "..tostring(a).." given to note.freq, needs to be a number or a string",2)
end
function b.name(c)
local a=f[tonumber(c)]
if a then
return a:sub(1,1):upper()..a:sub(2)
end
error("Attempt to get a note for a non-exsisting MIDI code",2)
end
function b.ticks(a)
if type(a)=="number"then
if a>=0 and a<=24 then
return a+34
elseif a>=34 and a<=58 then
return a-34
end
error("Wrong input "..tostring(a).." given to note.ticks, needs to be a number [0-24 or 34-58]",2)
end
error("Wrong input "..tostring(a).." given to note.ticks, needs to be a number",2)
end
function b.play(a,c)
h.beep(b.freq(a),c)
end
return b
