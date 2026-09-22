local a=require("shell")
local b=a.resolve("get","lua")
if not b then
io.stderr:write("update: нет get - поставь систему заново\n")
return 1
end
local a={...}
if a[1]=="--help"or a[1]=="-h"or a[1]=="help"then
print([[Использование: update [ИМЯ]... [КЛЮЧ]...
  update            обновить всё поставленное: систему, игры, ролики, программы
  update ИМЯ...     только это (mario, bank, dwos, games...)
  --dry     только показать, что изменится
  --force   скачать всё заново
  --rehash  пересчитать хэши своих файлов, не веря записанным]])
return 0
end
return assert(loadfile(b))("update",...)
