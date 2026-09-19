-- Цвета шерсти Minecraft (для bundled-редстоуна): номер <-> имя.
local colors = {}
local names = { "white", "orange", "magenta", "lightblue", "yellow", "lime", "pink", "gray",
                "silver", "cyan", "purple", "blue", "brown", "green", "red", "black" }
for i, name in ipairs(names) do
  colors[i - 1] = name
  colors[name] = i - 1
end
return colors
