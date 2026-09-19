local sides = {
  [0] = "bottom", [1] = "top", [2] = "back", [3] = "front", [4] = "right", [5] = "left", [6] = "unknown",
  bottom = 0, top = 1, back = 2, front = 3, right = 4, left = 5, unknown = 6,
  down = 0, up = 1, north = 2, south = 3, west = 4, east = 5,
  negy = 0, posy = 1, negz = 2, posz = 3, negx = 4, posx = 5,
  forward = 3,
}
local list = { sides[0], sides[1], sides[2], sides[3], sides[4], sides[5] }
local mt = getmetatable(sides) or {}
function mt.__len() return #list end
function mt.__ipairs() return ipairs(list) end
setmetatable(sides, mt)
return sides
