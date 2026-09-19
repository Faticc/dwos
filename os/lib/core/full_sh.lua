local fs = require("filesystem")
local process = require("process")
local shell = require("shell")
local text = require("text")
local unicode = require("unicode")

local sh = require("sh")

local isWordOf = sh.internal.isWordOf

-------------------------------------------------------------------------------

function sh.internal.command_passed(ec)
  return sh.internal.command_result_as_code(ec) == 0
end

--- Вынуть из слов перенаправления (> >> < 2>&1 ...). Возвращает список
--- {откуда, куда, режим}; слова с перенаправлениями из words удаляются.
function sh.internal.buildCommandRedirects(words)
  local redirects = {}
  local index = 1
  local from_io, to_io, mode
  local syn_err_msg = "syntax error near unexpected token "
  while true do
    local word = words[index]
    if not word then break end
    -- перенаправление - одно слово из одного незакавыченного куска
    local part = word[1]
    local token = not word[2] and not part.qr and part.txt or ""
    local _, _, from_io_txt, mode_txt, to_io_txt = token:find("(%d*)([<>]>?)%&?(.*)")
    if mode_txt then
      if mode then
        return nil, syn_err_msg .. token
      end
      mode = assert(({ ["<"] = "r", [">"] = "w", [">>"] = "a" })[mode_txt], "redirect failed to detect mode")
      from_io = from_io_txt ~= "" and tonumber(from_io_txt) or mode == "r" and 0 or 1
      to_io = to_io_txt ~= "" and tonumber(to_io_txt)
    elseif mode then
      token = sh.internal.evaluate({ word })
      if #token > 1 then
        return nil, string.format("%s: ambiguous redirect", part.txt)
      end
      to_io = token[1]
    else
      index = index + 1
    end
    if mode then
      table.remove(words, index)
    end
    if to_io then
      redirects[#redirects + 1] = { from_io, to_io, mode }
      mode, to_io = nil, nil
    end
  end
  if mode then
    return nil, syn_err_msg .. "newline"
  end
  return redirects
end

function sh.internal.openCommandRedirects(redirects)
  local ios = process.info().data.io
  for _, rjob in ipairs(redirects) do
    local from_io, to_io, mode = table.unpack(rjob)
    if type(to_io) == "number" then -- поток в поток
      ios[from_io] = io.dup(ios[to_io])
    else
      local file, reason = io.open(shell.resolve(to_io), mode)
      if not file then
        io.stderr:write("could not open '" .. to_io .. "': " .. reason .. "\n")
        os.exit(1)
      end
      ios[from_io] = file
    end
  end
end

--- Маски * и ? вне кавычек -> список подходящих путей; без масок или
--- без совпадений - само слово.
function sh.internal.glob(eword)
  local globbers = { { "*", ".*" }, { "?", "." } }
  local glob_pattern = ""
  local has_globits
  for _, part in ipairs(eword) do
    local nxt = part.txt
    if not part.qr then
      local escaped = text.escapeMagic(nxt)
      nxt = escaped
      for _, rule in ipairs(globbers) do
        -- ** -> *, ?? остаётся (убираются только повторы звёздочек)
        local doubled = text.escapeMagic(rule[1]):rep(2)
        while true do
          local prev = nxt
          nxt = nxt:gsub(doubled, rule[1])
          if prev == nxt then break end
        end
        nxt = nxt:gsub("%%%" .. rule[1], rule[2])
      end
      has_globits = has_globits or nxt ~= escaped
    end
    glob_pattern = glob_pattern .. nxt
  end

  if not has_globits then
    return { eword.txt }
  end

  local segments = text.split(glob_pattern, { "/" }, true)
  local hiddens = {}
  for i, e in ipairs(segments) do hiddens[i] = e:match("^%%%.") == nil end
  local function is_visible(s, i)
    return not hiddens[i] or s:match("^%.") == nil
  end
  local function magical(s)
    for _, rule in ipairs(globbers) do
      if (" " .. s):match("[^%%]" .. text.escapeMagic(rule[2])) then
        return true
      end
    end
  end

  local is_abs = glob_pattern:sub(1, 1) == "/"
  local root = is_abs and "" or shell.getWorkingDirectory():gsub("([^/])$", "%1/")
  local paths = { is_abs and "/" or "" }
  local relative_separator = ""
  for i, segment in ipairs(segments) do
    local enclosed_pattern = string.format("^(%s)/?$", segment)
    local next_paths = {}
    for _, path in ipairs(paths) do
      if fs.isDirectory(root .. path) then
        if magical(segment) then
          for file in fs.list(root .. path) do
            if file:match(enclosed_pattern) and is_visible(file, i) then
              next_paths[#next_paths + 1] = path .. relative_separator .. file:gsub("/+$", "")
            end
          end
        else
          local plain = text.removeEscapes(segment)
          local fpath = root .. path .. relative_separator .. plain
          if fs.exists(fpath) then
            next_paths[#next_paths + 1] = path .. relative_separator .. plain:gsub("/+$", "")
          end
        end
      end
    end
    paths = next_paths
    if not next(paths) then
      return { eword.txt } -- ни одного пути - слово остаётся как есть
    end
    relative_separator = "/"
  end
  return paths
end

function sh.getMatchingPrograms(baseName)
  if not baseName or baseName == "" then return {} end
  local result, seen = {}, {}
  local function check(key)
    if key:find(baseName, 1, true) == 1 and not seen[key] then
      result[#result + 1] = key
      seen[key] = true
    end
  end
  for alias in shell.aliases() do
    check(alias)
  end
  for basePath in string.gmatch(os.getenv("PATH"), "[^:]+") do
    for file in fs.list(shell.resolve(basePath)) do
      check((file:gsub("%.lua$", "")))
    end
  end
  return result
end

function sh.getMatchingFiles(partial_path)
  local name = partial_path:gsub("^.*/", "")
  local basePath = unicode.sub(partial_path, 1, -unicode.len(name) - 1)
  local resolvedPath = shell.resolve(basePath)
  local result, baseName = {}
  -- каталог без / на конце: рядом могут быть другие варианты, внутрь не лезем
  if fs.isDirectory(resolvedPath) and name == "" then
    baseName = "^(.-)/?$"
  else
    baseName = "^(" .. text.escapeMagic(name) .. ".-)/?$"
  end
  for file in fs.list(resolvedPath) do
    local match = file:match(baseName)
    if match then
      result[#result + 1] = basePath .. match:gsub("(%s)", "\\%1")
    end
  end
  -- единственный вариант - каталог: тогда / на конце
  if #result == 1 and fs.isDirectory(shell.resolve(result[1])) then
    result[1] = result[1] .. "/"
  end
  return result
end

function sh.internal.hintHandlerSplit(line)
  if line:match("\\$") then return nil end
  local splits = text.internal.tokenize(line, { show_escapes = true })
  if not splits then -- незакрытые кавычки
    return nil
  end
  local num_splits = #splits
  local last_close = 0
  for index = num_splits, 1, -1 do
    if isWordOf(splits[index], { ";", "&&", "||", "|" }) then
      last_close = index
      break
    end
  end
  -- строка кончается разделителем (или пуста) - новая пустая команда
  if last_close == num_splits then
    return nil
  end
  local last_word = splits[num_splits]
  local normal = text.internal.normalize({ last_word })[1]
  -- после последнего слова пробел: подсказываем новый аргумент
  if unicode.sub(line, -unicode.len(normal)) ~= normal then
    return line, nil, ""
  end
  local prefix = unicode.sub(line, 1, -unicode.len(normal) - 1)
  normal = text.internal.normalize(text.internal.tokenize(normal), true)[1]
  if last_close == num_splits - 1 then
    return prefix, normal, nil -- одно слово: команда
  end
  return prefix, nil, normal -- аргумент
end

function sh.internal.hintHandlerImpl(full_line, cursor)
  local line = unicode.sub(full_line, 1, cursor - 1)
  local suffix = unicode.sub(full_line, cursor)
  local prev, cmd, arg = sh.internal.hintHandlerSplit(line)
  if not prev then
    return {}
  end
  local result
  local searchInPath = cmd and not cmd:find("/")
  if searchInPath then
    result = sh.getMatchingPrograms(cmd)
  else
    -- после = подсказываем то, что справа от него
    if arg then
      local equal_index = arg:find("=[^=]*$")
      if equal_index then
        prev = prev .. unicode.sub(arg, 1, equal_index)
        arg = unicode.sub(arg, equal_index + 1)
      end
    end
    result = sh.getMatchingFiles(cmd or arg)
  end
  -- единственный законченный вариант - добавить пробел
  local resultSuffix = suffix
  if #result > 0 and unicode.sub(result[1], -1) ~= "/" and
     not suffix:sub(1, 1):find("%s") and
     #result == 1 or searchInPath then
    resultSuffix = " " .. resultSuffix
  end
  table.sort(result)
  for i = 1, #result do
    result[i] = prev .. result[i] .. resultSuffix
  end
  return result
end

--- Нет ли двух разделителей подряд, в начале или в конце.
function sh.internal.hasValidPiping(words, pipes)
  checkArg(1, words, "table")
  checkArg(2, pipes, "table", "nil")
  if #words == 0 then
    return true
  end
  pipes = pipes or { "&&", "||?" }
  local state = "" -- начинать с разделителя нельзя
  for w = 1, #words do
    local word = words[w]
    for p = 1, #word do
      local part = word[p]
      if part.qr then
        state = nil
      elseif part.txt == "" then
        state = nil
      elseif #text.split(part.txt, pipes, true) == 0 then
        local prev = state
        state = part.txt
        if prev then
          word = nil
          break
        end
      else
        state = nil
      end
    end
    if not word then
      break
    end
  end
  if state then
    return false, "syntax error near unexpected token " .. state
  end
  return true
end

function sh.internal.boolean_executor(chains, predicator)
  local function not_gate(result, reason)
    return sh.internal.command_passed(result) and 1 or 0, reason
  end
  local last = true
  local last_reason
  local boolean_stage, negation_stage, command_stage = 1, 2, 0
  local stage = negation_stage
  local skip = false

  for ci = 1, #chains do
    local nxt = chains[ci]
    local single = #nxt == 1 and #nxt[1] == 1 and not nxt[1][1].qr and nxt[1][1].txt
    if single == "||" or single == "&&" then
      if stage ~= command_stage or #chains == 0 then
        return nil, "syntax error near unexpected token '" .. single .. "'"
      end
      local passed = sh.internal.command_passed(last)
      if (single == "||") == passed then
        skip = true
      end
      stage = boolean_stage
    elseif not skip then
      local chomped = #nxt
      local negate = sh.internal.remove_negation(nxt)
      chomped = chomped ~= #nxt
      if negate then
        local prev = predicator
        predicator = function(n, i)
          local result, reason = not_gate(prev(n, i))
          predicator = prev
          return result, reason
        end
      end
      if chomped then
        stage = negation_stage
      end
      if #nxt > 0 then
        last, last_reason = predicator(nxt, ci)
        stage = command_stage
      end
    else
      skip = false
      stage = command_stage
    end
  end
  if stage == negation_stage then
    last = not_gate(last)
  end
  return last, last_reason
end

-- Разрезать список слов по словам-разделителям. keep - оставлять
-- разделители отдельными группами (для && и ||).
local function partition(words, delims, keep)
  local result, group = {}, nil
  for _, w in ipairs(words) do
    if isWordOf(w, delims) then
      if keep then result[#result + 1] = { w } end
      group = nil
    else
      if not group then
        group = {}
        result[#result + 1] = group
      end
      group[#group + 1] = w
    end
  end
  return result
end

function sh.internal.splitStatements(words, semicolon)
  checkArg(1, words, "table")
  checkArg(2, semicolon, "string", "nil")
  return partition(words, { semicolon or ";" })
end

function sh.internal.splitChains(s, pc)
  checkArg(1, s, "table")
  checkArg(2, pc, "string", "nil")
  return partition(s, { pc or "|" })
end

function sh.internal.groupChains(s)
  checkArg(1, s, "table")
  return partition(s, { "&&", "||" }, true)
end

function sh.internal.remove_negation(chain)
  if isWordOf(chain[1], { "!" }) then
    table.remove(chain, 1)
    return not sh.internal.remove_negation(chain)
  end
  return false
end

function sh.internal.execute_complex(words, eargs, env)
  -- все каналы проверяются до выполнения первой команды
  local statements = sh.internal.splitStatements(words)
  for i = 1, #statements do
    local ok, why = sh.internal.hasValidPiping(statements[i])
    if not ok then return nil, why end
  end
  for si = 1, #statements do
    local chains = sh.internal.groupChains(statements[si])
    local last_code, reason = sh.internal.boolean_executor(chains, function(chain, chain_index)
      local pipe_parts = sh.internal.splitChains(chain)
      local next_args = chain_index == #chains and si == #statements and eargs or {}
      return sh.internal.executePipes(pipe_parts, next_args, env)
    end)
    sh.internal.ec.last = sh.internal.command_result_as_code(last_code, reason)
  end
  return sh.internal.ec.last == 0
end

--- Слова -> аргументы: перенаправления, `команды`, $переменные, маски.
function sh.internal.evaluate(words)
  local redirects, why = sh.internal.buildCommandRedirects(words)
  if not redirects then
    return nil, why
  end

  do
    local command_text = table.concat(text.internal.normalize(words), " ")
    local subbed = sh.internal.parse_sub(command_text)
    if subbed ~= command_text then
      words = text.internal.tokenize(subbed)
    end
  end

  local repack = false
  for _, word in ipairs(words) do
    for _, part in pairs(word) do
      if not (part.qr or {})[3] then
        local expanded = sh.expand(part.txt)
        if expanded ~= part.txt then
          part.txt = expanded
          repack = true
        end
      end
    end
  end

  if repack then
    words = text.internal.tokenize(table.concat(text.internal.normalize(words), " "))
  end

  local args = {}
  for _, word in ipairs(words) do
    local eword = { txt = "" }
    for _, part in ipairs(word) do
      eword.txt = eword.txt .. part.txt
      eword[#eword + 1] = { qr = part.qr, txt = part.txt }
    end
    for _, arg in ipairs(sh.internal.glob(eword)) do
      args[#args + 1] = arg
    end
  end
  return args, redirects
end

--- Подстановка `команды`: её вывод встаёт на место кавычек.
function sh.internal.parse_sub(input, quotes)
  if quotes and quotes[1] == "`" then
    input = string.format("`%s`", input)
    quotes[1], quotes[2] = "", ""
  end
  -- без gsub: gsub - вызов C, а io.popen должен уметь уступать
  local packed = {}
  local i, len = 1, #input
  while i <= len do
    local fi, si, capture = input:find("`([^`]*)`", i)
    if not fi then
      packed[#packed + 1] = input:sub(i)
      break
    end
    packed[#packed + 1] = input:sub(i, fi - 1)
    local sub = io.popen(capture)
    local result = sub:read("*a")
    sub:close()
    packed[#packed + 1] = (result:gsub("\n+$", "")) -- хвостовые переводы строк срезаются
    i = si + 1
  end
  return table.concat(packed)
end
