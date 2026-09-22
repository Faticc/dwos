-- mcsrv - разговор с сервером через командный блок (компонент opencb).
--
-- Вторая половина skyLib: всё, что программам нужно от мира снаружи -
-- баланс, выдача и изъятие предметов, когда игрок заходил в последний раз.
--
-- Сервер отвечает человеку, а не машине: ответ приходит куском чата с
-- цветовыми кодами §. Разбор этих ответов - самое хрупкое место, и он
-- собран здесь одним местом, чтобы программы о нём не знали. Смещения в
-- money() подобраны к живому ответу McSkill и перенесены из skyLib как
-- есть: менять их вслепую нельзя, только сверяясь с сервером.

local component = require("component")
local unicode = require("unicode")

local srv = {}

--- Есть ли вообще командный блок.
function srv.available() return component.isAvailable("opencb") end

--- Выполнить команду от лица консоли сервера и вернуть ответ.
--- Без командного блока - пустая строка: программам достаточно того, что
--- ни один разбор ничего в ней не найдёт.  
function srv.com(command)
  if not component.isAvailable("opencb") then return "" end
  local _, answer = component.opencb.execute(command)
  return answer or ""
end

------------------------------------------------------------------ деньги

--- Баланс игрока строкой, как его печатает сервер: "1,234.00".
function srv.money(nick)
  local c = srv.com("money " .. nick)
  local _, b = string.find(c, "Баланс: §f")
  if not b then return "0.00" end
  -- хвост ответа - название валюты, у изумрудов оно длиннее
  local tail = string.find(c, "Emeralds") and 10 or 9
  return unicode.sub(c, b - 16, unicode.len(c) - tail)
end

--- Хватает ли денег, и если да - снять их со счёта.
function srv.take(nick, price)
  local balance = srv.money(nick)
  balance = string.sub(balance, 1, string.len(balance) - 3) -- ".00"
  if string.find(balance, "-") then return false end
  balance = tonumber((string.gsub(balance, ",", "")))
  if not balance or balance < price then return false end
  srv.com("money take " .. nick .. " " .. price)
  return true
end

--- Положить деньги на счёт.
function srv.give(nick, sum)
  srv.com("money give " .. nick .. " " .. sum)
end

------------------------------------------------------------------ предметы

--- Забрать предметы из инвентаря.
function srv.takeItem(nick, item, count)
  return string.find(srv.com("clear " .. nick .. " " .. item .. " " .. count), "Убрано") ~= nil
end

--- Выдать предметы. Возвращает остаток, не влезший в инвентарь (0 - всё
--- влезло): сервер называет его в ответе, а сам предмет никуда не девается.
function srv.giveItem(nick, item, count)
  local text = srv.com("egive " .. nick .. " " .. item .. " " .. count)
  local _, b = string.find(text, "Недостаточно свободного места, §c")
  if not b then return 0 end
  local rest = string.match(string.sub(text, b + 1), "^[^ ]*") or ""
  return tonumber((string.gsub(rest, ",", ""))) or 0
end

------------------------------------------------------------------ игроки

--- Когда игрок заходил: "&2online" либо "&0offline" и сколько прошло.
--- При непонятном ответе - "&4error" и ничего больше.
function srv.seen(nick)
  local c = srv.com("seen " .. nick)
  local _, b = string.find(c, "§6 с §c")
  if not b then return "&4error" end
  local text = string.sub(c, b + 1)

  local year = tonumber(text:match("(%d+) лет")) or (text:find("год") and 1) or 0
  local month = tonumber(text:match("(%d+) месяц")) or 0
  local day = tonumber(text:match("(%d+) дн")) or (text:find("день") and 1) or 0
  local hour = tonumber(text:match("(%d+) час")) or 0
  local minute = tonumber(text:match("(%d+) минут")) or 0

  local status = string.find(c, "онлайн") and "&2online" or "&0offline"
  return status, year, month, day, hour, minute
end

--- То же одной строкой для списка: крупные единицы вытесняют мелкие.
function srv.lastSeen(nick)
  local status, year, month, day, hour, minute = srv.seen(nick)
  if status == "&4error" then
    return status
  elseif year ~= 0 then
    return status .. " - " .. year .. " лет " .. month .. " мес. "
  elseif month ~= 0 then
    return status .. " - " .. month .. " мес. " .. day .. " дн. "
  elseif day ~= 0 then
    return status .. " - " .. day .. " дн. " .. hour .. " ч. "
  end
  return status .. " - " .. hour .. " ч. " .. minute .. " мин. "
end

return srv
