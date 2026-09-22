-- update: обновить всё, что стоит, одной командой.
--
-- Система, игры, ролики, программы - всё, что поставлено из репозитория
-- (сама DwOS и через get), сверяется с манифестами на GitHub по размеру и
-- CRC32, и качается только изменившееся. Новое из репозитория не ставится
-- - это get install.
--
--   update            всё поставленное
--   update ИМЯ...     только это (mario, bank, dwos, games...)
--   --dry  только показать   --force  качать заново   --rehash  пересчитать хэши
--
-- Работает через get (bin/get.lua): у них одно состояние (/.dwos,
-- <каталог>/.installed), одна загрузка (lib/fetch: сжатым, по четыре
-- разом, систему - пакетом) и одна раскладка по дискам.

local shell = require("shell")

local path = shell.resolve("get", "lua")
if not path then
  io.stderr:write("update: нет get - поставь систему заново\n")
  return 1
end
local args = { ... }
if args[1] == "--help" or args[1] == "-h" or args[1] == "help" then
  print([[Использование: update [ИМЯ]... [КЛЮЧ]...
  update            обновить всё поставленное: систему, игры, ролики, программы
  update ИМЯ...     только это (mario, bank, dwos, games...)
  --dry     только показать, что изменится
  --force   скачать всё заново
  --rehash  пересчитать хэши своих файлов, не веря записанным]])
  return 0
end
return assert(loadfile(path))("update", ...)
