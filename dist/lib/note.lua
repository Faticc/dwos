local computer = require("computer")
local note = {}
local notes = {}
local reverseNotes = {}
do
local base = { "c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b" }
local sharp = { "a0", "a#0", "b0" }
local flat = { "bb0" }
for octave = 1, 6 do
for _, v in ipairs(base) do
sharp[#sharp + 1] = v .. octave
if #v == 1 and v ~= "c" and v ~= "f" then
flat[#flat + 1] = v .. "b" .. octave
end
end
end
for i = 21, 95 do
notes[sharp[i - 20]] = tostring(i)
reverseNotes[i] = sharp[i - 20]
end
for _, v in ipairs(flat) do
notes[v] = tostring(notes[v:gsub("(.)b(.)", "%1%2")] - 1)
end
end
function note.midi(n)
if type(n) == "string" then
n = n:lower()
if tonumber(notes[n]) then
return tonumber(notes[n])
end
error("Wrong input " .. tostring(n) .. " given to note.midi, needs to be <note>[semitone sign]<octave>, e.g. A#0 or Gb4")
elseif type(n) == "number" then
return math.floor((12 * math.log(n / 440, 2)) + 69)
end
error("Wrong input " .. tostring(n) .. " given to note.midi, needs to be a number or a string")
end
function note.freq(n)
if type(n) == "string" then
n = n:lower()
if tonumber(notes[n]) then
return 2 ^ ((tonumber(notes[n]) - 69) / 12) * 440
end
error("Wrong input " .. tostring(n) .. " given to note.freq, needs to be <note>[semitone sign]<octave>, e.g. A#0 or Gb4", 2)
elseif type(n) == "number" then
return 2 ^ ((n - 69) / 12) * 440
end
error("Wrong input " .. tostring(n) .. " given to note.freq, needs to be a number or a string", 2)
end
function note.name(n)
local name = reverseNotes[tonumber(n)]
if name then
return name:sub(1, 1):upper() .. name:sub(2)
end
error("Attempt to get a note for a non-exsisting MIDI code", 2)
end
function note.ticks(n)
if type(n) == "number" then
if n >= 0 and n <= 24 then
return n + 34
elseif n >= 34 and n <= 58 then
return n - 34
end
error("Wrong input " .. tostring(n) .. " given to note.ticks, needs to be a number [0-24 or 34-58]", 2)
end
error("Wrong input " .. tostring(n) .. " given to note.ticks, needs to be a number", 2)
end
function note.play(tone, duration)
computer.beep(note.freq(tone), duration)
end
return note
