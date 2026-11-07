--!nonstrict
-- Provedor "arquivos": busca na home com o fd, ao vivo (≈20 ms), como o KRunner.
-- Ignora ocultos e o que estiver no .gitignore (padrão do fd). Enter abre com xdg-open.
-- Várias palavras = todas em ordem no caminho ("capim semin" acha .../capim-capeta/...seminario.pdf).

local MIN = 3 -- letras mínimas antes de buscar
local MAX = 20
local HOME = noctalia.getenv("HOME") or ""
local FORA = { "node_modules", "target", "__pycache__", "Trash" }

local GLYPH = {
  pdf = "file-type-pdf", epub = "book", azw3 = "book",
  png = "photo", jpg = "photo", jpeg = "photo", webp = "photo", svg = "photo", gif = "photo",
  md = "file-text", txt = "file-text", csv = "table", xlsx = "table", ods = "table",
  docx = "file-word", odt = "file-word", pptx = "presentation",
  py = "file-code", sh = "file-code", rs = "file-code", luau = "file-code", lua = "file-code",
  kdl = "file-code", toml = "file-code", json = "file-code", r = "file-code",
  mp4 = "movie", mkv = "movie", mp3 = "music", ogg = "music", zip = "file-zip",
}

local function trim(s)
  return noctalia.string.trim(s or "")
end

-- palavras → regex do fd: cada uma escapada, unidas por ".*"
local function padrao(texto)
  local partes = {}
  for p in texto:gmatch("%S+") do
    table.insert(partes, (p:gsub("[%^%$%(%)%.%[%]%*%+%-%?%{%}%|\\]", "\\%0")))
  end
  return table.concat(partes, ".*")
end

local function linha(caminho, texto)
  local pasta = caminho:sub(-1) == "/"
  local limpo = pasta and caminho:sub(1, -2) or caminho
  local nome = limpo:match("([^/]+)$") or limpo
  local onde = (limpo:match("^(.*)/[^/]+$") or ""):gsub("^" .. HOME:gsub("%p", "%%%0"), "~")
  local ext = (nome:match("%.([^.]+)$") or ""):lower()
  local s = noctalia.fuzzyScore(texto, nome) or noctalia.fuzzyScore(texto, limpo) or 0
  return {
    id = limpo,
    title = nome,
    subtitle = onde,
    glyph = pasta and "folder" or (GLYPH[ext] or "file"),
    score = math.clamp(s, 0, 1) / 4, -- sempre abaixo de apps e comandos; desempata pelo nome
  }
end

function onQuery(query)
  local texto = trim(query)
  if #texto < MIN then
    launcher.setResults(query, {})
    return
  end
  local argv = { "fd", "--ignore-case", "--full-path", "--max-results", tostring(MAX) }
  for _, f in ipairs(FORA) do
    table.insert(argv, "--exclude")
    table.insert(argv, f)
  end
  -- --full-path casa no caminho todo; por isso a última palavra precisa estar no nome
  table.insert(argv, "--")
  table.insert(argv, padrao(texto) .. "[^/]*/?$")
  table.insert(argv, HOME)
  noctalia.runAsync(argv, function(r)
    local linhas = {}
    for caminho in (r.stdout or ""):gmatch("[^\n]+") do
      table.insert(linhas, linha(caminho, texto))
    end
    -- o query amarra a resposta: resposta atrasada de tecla anterior é descartada pelo host
    launcher.setResults(query, linhas)
  end, 2000)
end

function onActivate(id)
  if id ~= "" then noctalia.runAsync({ "xdg-open", id }) end
end
