-- cbtest - выполнить команду через командный блок и показать ответ
-- сервера как есть. Нужен, чтобы увидеть, что именно отвечает сервер,
-- когда bank или admins его не понимают.
--
--   cbtest <команда>        например: cbtest seen Fatic
--   cbtest --all <ник>      безопасный набор: money, seen, scoreboard
--
-- Коды цвета § выводятся как &, чтобы их было видно.
-- Команда идёт от имени командного блока - то есть с его правами.

local component = require("component")

local args = { ... }
if #args == 0 then
  print("cbtest <команда>     - выполнить и показать ответ")
  print("cbtest --all <ник>   - money, seen и scoreboard teams list")
  print("Купюры проверять вручную, по одной:")
  print("  cbtest clear <ник> CUSTOMNPCS_NPCMONEY 1")
  return
end
if not component.isAvailable("opencb") then
  io.stderr:write("нет командного блока (opencb)\n")
  return 1
end

local function run(command)
  local ok, out = component.opencb.execute(command)
  print("> " .. command)
  print("  результат: " .. tostring(ok))
  print("  ответ: " .. (tostring(out or ""):gsub("§", "&")))
  print()
end

if args[1] == "--all" then
  local nick = args[2]
  if not nick then
    io.stderr:write("укажите ник: cbtest --all <ник>\n")
    return 1
  end
  run("money " .. nick)
  run("seen " .. nick)
  run("scoreboard teams list")
else
  run(table.concat(args, " "))
end
