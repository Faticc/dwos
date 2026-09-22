require("filesystem").mount(setmetatable({
address="f5501a9b-9c23-1e7a-4afe-4b65eed9b88a",
},{
__index=function(c,a)
local b=({getLabel="devfs",spaceTotal=0,spaceUsed=0,isReadOnly=false})[a]
if b~=nil then
return function()return b end
end
local b=require("devfs")
b.register(c)
return b.proxy[a]
end,
}),"/dev")
