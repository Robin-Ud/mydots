--!nonstrict
-- Provedor "contas": conta em LaTeX (\sqrt{25}, \frac{1}{3}) ou com √ π × ÷ ² no Super+D.
-- A calculadora embutida da noctalia não entende LaTeX (devolve lixo) e não dá pra estender,
-- então esta entra só quando o texto tem cara de LaTeX/unicode: conta comum (2+2) continua
-- com a embutida, sem linha repetida. A conta em si é no contas.py (ast, lista branca).
-- Com variável (5x, 2x+3=7) o contas.py usa o sympy: simplifica ou resolve; Enter copia em LaTeX.

local SCRIPT = (noctalia.pluginDir() or ".") .. "/contas.py"
local MARCAS = { "\\", "√", "π", "×", "÷", "·", "⋅", "²", "³", "|" }

local function trim(s)
  return noctalia.string.trim(s or "")
end

local function temCara(texto)
  for _, m in ipairs(MARCAS) do
    if texto:find(m, 1, true) then return true end
  end
  if texto:find("[%d%)]!") then return true end -- fatorial: 5!
  -- sem marca: só se parece equação/expressão com letra solta (2x+3=7, x^2-4=0).
  -- Duas letras seguidas = palavra = busca normal ("v1-capim", "timer 10m").
  if texto:find("%a%a") or not texto:find("%a") or not texto:find("%d") then return false end
  if not texto:find("[%+%-%*/%^=]") then return false end
  return texto:match("^[%w%s%+%-%*/%^%(%)%.,=]+$") ~= nil
end

-- Última query pedida. A noctalia não descarta setResults de query velha, e o caminho com
-- sympy (~1 s) chega depois do sem variável (~50 ms): apagar o "n" de "n\frac{…}" deixava
-- o "= 28·n" velho por cima do "= 28" novo. Resposta que não é da última vai pro lixo.
local ultima = nil

function onQuery(query)
  ultima = query
  local texto = trim(query)
  if texto == "" or not temCara(texto) then
    launcher.setResults(query, {})
    return
  end
  -- -P e não -I: o sympy mora no site-packages do usuário (~/.local), que o -I desliga
  noctalia.runAsync({ "python3", "-P", SCRIPT, texto }, function(r)
    if query ~= ultima then return end
    local ok, res = pcall(noctalia.json.decode, r.stdout or "")
    if not ok or type(res) ~= "table" or not res.ok then
      launcher.setResults(query, {})
      return
    end
    launcher.setResults(query, { {
      id = res.copia or "",
      title = res.titulo,
      subtitle = texto .. "   →   " .. res.expr .. "   (Enter copia)",
      glyph = "math-function",
      score = 4096,
    } })
  end, 3000) -- simplify/solve do sympy pode demorar
end

function onActivate(id)
  if id ~= "" then
    noctalia.copyToClipboard(id, "text/plain")
    noctalia.notify("Conta", id .. " copiado")
  end
end
