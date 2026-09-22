-- Что из репозитория куда ложится. Ставит get из DwOS, ярлыки в /bin
-- он делает сам. size и crc проставляет tools/genmanifest.py - руками их
-- не правь, а после правки игр перезапусти его.
--
-- Ставится всё по частям: часть (pkg у файлов ниже) и каждый ролик -
-- отдельная позиция get, лежит целиком на одном диске.
{
	dir = "/home/games",
	-- части по порядку в списке get
	packages = {
		{ "mario",  "Марио",   "платформер, восемь уровней" },
		{ "doom",   "Doom",    "шутер от первого лица" },
		{ "kart",   "Карты",   "гонки, кубок из четырёх трасс" },
		{ "chip8",  "CHIP-8",  "эмулятор приставки" },
		{ "casino", "Казино",  "однорукий бандит" },
		{ "video",  "Видео",   "проигрыватель роликов" },
		{ "tools",  "Проверки", "keytest и tapetest" },
	},
	files = {
		{ "marioart.lua",    "marioart.lua",   size = 20698, crc = "f9b0dd55", pkg = "mario" },
		{ "mario.lua",       "mario.lua",      size = 59896, crc = "3d502d0c", pkg = "mario" },
		{ "doomart.lua",     "doomart.lua",    size = 19005, crc = "2bb478d8", pkg = "doom" },
		{ "doom.lua",        "doom.lua",       size = 62023, crc = "beffbf61", pkg = "doom" },
		{ "chip8roms.lua",   "chip8roms.lua",  size = 966, crc = "074b0279", pkg = "chip8" },
		{ "chip8.lua",       "chip8.lua",      size = 13288, crc = "0440f395", pkg = "chip8" },
		{ "casino.lua",      "casino.lua",     size = 55344, crc = "28e60c50", pkg = "casino" },
		{ "kartart.lua",     "kartart.lua",    size = 21440, crc = "e4300472", pkg = "kart" },
		{ "kart.lua",        "kart.lua",       size = 71757, crc = "b302902b", pkg = "kart" },
		{ "keytest.lua",     "keytest.lua",    size = 1927, crc = "ee54ccac", pkg = "tools" },
		{ "tapetest.lua",    "tapetest.lua",   size = 6732, crc = "3e970ac5", pkg = "tools" },
		-- проигрыватель роликов: меню, цвет, звук с кассеты
		{ "video.lua",       "video.lua",      size = 31336, crc = "44b3f91a", pkg = "video" },
	},
	-- Ролики к video, каждый - отдельной строкой списка: можно взять ролик
	-- без звука или звук без ролика. Кладутся в папку videos выбранного
	-- диска (на системном - в /home/videos), там их и ищет плеер. Звук -
	-- файл с тем же именем, .dfpwm: его пишут на кассету (W в меню video).
	videos = {
		{ "video/badapple.bin", "badapple.bin",   size = 1318092, crc = "c62419b9", title = "Bad Apple!!", opt = true, secs = 219, gz = "video/badapple.bin.gz", gzsize = 819737 },
		{ "video/badapple.dfpwm", "badapple.dfpwm", size = 898969, crc = "e55e07d5", opt = true },
		{ "video/poop.bin",  "poop.bin",       size = 2005958, crc = "53c0034f", opt = true, secs = 41, gz = "video/poop.bin.gz", gzsize = 1384171 },
		{ "video/poop.dfpwm", "poop.dfpwm",     size = 167731, crc = "d3b7d404", opt = true, gz = "video/poop.dfpwm.gz", gzsize = 95984 },
		{ "video/chinenumberone.bin", "chinenumberone.bin",size = 3811336, crc = "898bd8b2", opt = true, secs = 119, gz = "video/chinenumberone.bin.gz", gzsize = 2614750 },
		{ "video/chinenumberone.dfpwm", "chinenumberone.dfpwm",size = 485649, crc = "c121119e", opt = true, gz = "video/chinenumberone.dfpwm.gz", gzsize = 395120 },
	},
	-- имя ярлыка -> что он запускает
	bin = {
		{ "mario", "mario.lua" },
		{ "doom", "doom.lua" },
		{ "chip8", "chip8.lua" },
		{ "video", "video.lua" },
		-- прежнее имя: открывает то же меню
		{ "badapple", "video.lua" },
		{ "casino", "casino.lua" },
		{ "kart", "kart.lua" },
		{ "keytest", "keytest.lua" },
		{ "tapetest", "tapetest.lua" },
	},
}
