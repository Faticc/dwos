require("event").listen("init",function()
dofile(require("shell").resolve("rc","lua"))
return false
end)
