local a={pressedChars={},pressedCodes={}}
a.keys={
c=0x2E,d=0x20,q=0x10,w=0x11,
back=0x0E,delete=0xD3,down=0xD0,enter=0x1C,home=0xC7,
lcontrol=0x1D,left=0xCB,lmenu=0x38,lshift=0x2A,pageDown=0xD1,
rcontrol=0x9D,right=0xCD,rmenu=0xB8,rshift=0x36,space=0x39,
tab=0x0F,up=0xC8,["end"]=0xCF,numpadenter=0x9C,
}
function a.isAltDown()
return a.pressedCodes[a.keys.lmenu]or a.pressedCodes[a.keys.rmenu]
end
function a.isControl(b)
return type(b)=="number"and(b<0x20 or(b>=0x7F and b<=0x9F))
end
function a.isControlDown()
return a.pressedCodes[a.keys.lcontrol]or a.pressedCodes[a.keys.rcontrol]
end
function a.isKeyDown(b)
checkArg(1,b,"string","number")
if type(b)=="string"then
return a.pressedChars[utf8 and utf8.codepoint(b)or b:byte()]
end
return a.pressedCodes[b]
end
function a.isShiftDown()
return a.pressedCodes[a.keys.lshift]or a.pressedCodes[a.keys.rshift]
end
require("package").delay(a.keys,"/lib/core/full_keyboard.lua")
return a
