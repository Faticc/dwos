-- Службы rc стартуют по сигналу init; подписаться нужно до автозапуска дисков
require("event").listen("init", function()
  dofile(require("shell").resolve("rc", "lua"))
  return false
end)
