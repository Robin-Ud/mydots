--!nonstrict
-- Provedor "comandos": cada script executável no topo de ~/.config/comandos vira um item.
--
-- Nome do arquivo sem extensão = nome do comando. Cabeçalho opcional (primeiras linhas):
--   # Descrição curta              ← 1º comentário que não é chave
--   # icone: arrows-exchange       ← glyph tabler
--   # modo: terminal | fundo       ← padrão: roda e notifica o que imprimir
-- O que vem depois do nome vira argumento: "timer 10m chá" → timer.sh 10m chá.

local DIR = "~/.config/comandos"
local MODOS = { notificar = true, fundo = true, terminal = true }

local cache = {} -- arquivo → { mtime, cmd }

local function trim(s)
  return noctalia.string.trim(s or "")
end

-- Lê o cabeçalho das primeiras linhas do script.
local function lerCabecalho(caminho)
  local texto = noctalia.readFile(caminho) or ""
  local cab = { descricao = "", icone = "terminal-2", modo = "notificar" }
  local n = 0
  for linha in texto:gmatch("[^\n]*") do
    n += 1
    if n > 12 then break end
    if linha:sub(1, 2) ~= "#!" and linha:sub(1, 1) == "#" then
      local corpo = trim(linha:sub(2))
      local chave, valor = corpo:match("^(%a+):%s*(.-)%s*$")
      if chave ~= "icone" and chave ~= "modo" then chave = nil end -- "Timer: ..." é descrição
      if chave == "icone" and valor ~= "" then
        cab.icone = valor
      elseif chave == "modo" and MODOS[valor] then
        cab.modo = valor
      elseif not chave and cab.descricao == "" and corpo ~= "" then
        cab.descricao = corpo
      end
    end
  end
  return cab
end

-- Lista os comandos da pasta (pula pastas, ocultos, .md e *_test.*).
local function comandos()
  local lista = {}
  for _, arq in ipairs(noctalia.listDir(DIR) or {}) do
    local caminho = DIR .. "/" .. arq
    local info = noctalia.fileInfo(caminho)
    local pula = arq:sub(1, 1) == "." or arq:match("%.md$") or arq:match("_test%.")
    if info and not info.isDir and not pula then
      local c = cache[arq]
      if not c or c.mtime ~= info.mtime then
        local cab = lerCabecalho(caminho)
        cab.nome = arq:match("^(.+)%.[^.]+$") or arq
        cab.caminho = noctalia.expandPath(caminho)
        c = { mtime = info.mtime, cmd = cab }
        cache[arq] = c
      end
      table.insert(lista, c.cmd)
    end
  end
  table.sort(lista, function(a, b) return a.nome < b.nome end)
  return lista
end

local function linha(cmd, args, score)
  local titulo = cmd.nome
  if args ~= "" then titulo = titulo .. " " .. args end
  return {
    id = cmd.nome .. "\t" .. args,
    title = titulo,
    subtitle = cmd.descricao,
    glyph = cmd.icone,
    score = score,
  }
end

function onQuery(query)
  local texto = trim(query)
  local palavra, args = texto:match("^(%S+)%s*(.*)$")
  local linhas = {}
  for _, cmd in ipairs(comandos()) do
    if not palavra then
      table.insert(linhas, linha(cmd, "", 0))
    elseif palavra == cmd.nome then
      -- nome exato: aceita argumentos e vai pro topo
      table.insert(linhas, linha(cmd, args, 4096))
    elseif args == "" then
      -- o fuzzy da noctalia é frouxo (casa letra a letra): só no nome, e só se positivo;
      -- na descrição vale trecho exato com 3+ letras ("monitor" acha os do SetTela)
      local p = palavra:lower()
      local s
      if cmd.nome:sub(1, #p) == p then
        s = 1024 + #p
      else
        s = noctalia.fuzzyScore(p, cmd.nome)
        if s and s <= 0 then s = nil end
        if not s and #p >= 3 and cmd.descricao:lower():find(p, 1, true) then s = 0.5 end
      end
      if s then table.insert(linhas, linha(cmd, "", s)) end
    end
  end
  launcher.setResults(query, linhas)
end

local function aspas(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function onActivate(id)
  local nome, args = id:match("^(.-)\t(.*)$")
  if not nome then return end
  local cmd
  for _, c in ipairs(comandos()) do
    if c.nome == nome then cmd = c end
  end
  if not cmd then return end

  local argv = { cmd.caminho }
  for a in args:gmatch("%S+") do table.insert(argv, a) end

  if cmd.modo == "fundo" then
    noctalia.runAsync(argv)
  elseif cmd.modo == "terminal" then
    local partes = {}
    for _, a in ipairs(argv) do table.insert(partes, aspas(a)) end
    noctalia.runInTerminal(table.concat(partes, " "))
  else
    noctalia.runAsync(argv, function(r)
      local out, err = trim(r.stdout), trim(r.stderr)
      if r.timedOut then
        noctalia.notifyError(nome, "passou de 60 s e foi cortado")
      elseif r.exitCode ~= 0 then
        local msg = err ~= "" and err or out
        noctalia.notifyError(nome, msg ~= "" and msg or ("saiu com código " .. r.exitCode))
      elseif out ~= "" then
        noctalia.notify(nome, out)
      end
    end, 60000)
  end
end
