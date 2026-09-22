-- Что из репозитория куда ложится. Ставит get из DwOS, ярлыки в /bin
-- он делает сам. size и crc проставляет tools/genmanifest.py -
-- руками их не правь, а после правки программ перезапусти его.
{
  dir = "/home/dwapps",
  -- каталог с библиотеками рядом с программами: ярлык дописывает его в
  -- package.path, поэтому require("mcsrv") работает, а системный /lib
  -- остаётся нетронутым
  lib = "lib",
  files = {
    { "lib/mcsrv.lua",   "lib/mcsrv.lua",  size = 5319, crc = "4c7812ce" },
    { "bank.lua",        "bank.lua",       size = 21699, crc = "32b52b32" },
    { "admins.lua",      "admins.lua",     size = 31961, crc = "3c78f03c" },
    { "cbtest.lua",      "cbtest.lua",     size = 1716, crc = "f817c56b" },
  },
  -- имя ярлыка -> что он запускает
  bin = {
    { "bank", "bank.lua" },
    { "admins", "admins.lua" },
    { "cbtest", "cbtest.lua" },
  },
}
