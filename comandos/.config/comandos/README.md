# comandos

O "KRunner" do Super+Espaço (ou Alt+Espaço). Todo script executável aqui vira um item do launcher da noctalia:
digita o nome, Enter, roda. O mesmo plugin também busca arquivos da home, ao vivo, com o `fd`.
Puro bash + Python stdlib + um plugin Luau, zero deps além do `fd`.

| Digitou no Super+Espaço | O que acontece |
|---|---|
| `telas` | roda `telas.sh` (comandos aparecem misturados com os apps) |
| `timer 10m chá` | roda `timer.sh 10m chá`: o que vem depois do nome vira argumento |
| `capim semin` | arquivos da home cujo caminho tem "capim" e depois "semin" no nome; Enter abre |
| `2+2`, `10 usd` | calculadora da própria noctalia (já vinha) |
| `\sqrt{25}`, `\frac{3}{4}\cdot 8`, `2\pi`, `√25`, `3²`, `5!` | conta em LaTeX/unicode → `= 5`; Enter copia (a embutida não entende LaTeX) |
| `/c` | só comandos (lista todos) |
| `/a dossie` | só arquivos |
| `\sqrt{25}\cdot x`, `2x+3=7`, `x^2-5x+6=0` | com variável: simplifica (`= 5·x`) ou resolve (`x = 2 ou x = 3`); Enter copia em LaTeX |
| `/tex` | só contas em LaTeX |

## Criar um comando

`novo nome` no Super+Espaço cria `nome.sh` aqui já com o molde e abre no VS Code. Ou à mão:

```bash
#!/bin/bash
# O que faz (aparece embaixo do nome)
# icone: alarm          ← glyph do tabler-icons (opcional)
# modo: fundo           ← opcional, ver abaixo
echo "isso vira notificação"
```

`chmod +x` e pronto: aparece na hora, sem recarregar nada. Pode ser `.py`, `.sh`, o que for.

**Modos**
- `notificar` (padrão): roda e mostra o que imprimir numa notificação; erro (exit ≠ 0) vira
  notificação vermelha com o stderr. Tem limite de 60 s.
- `fundo`: só dispara, sem esperar. Pra abrir app ou coisa demorada (`timer`).
- `terminal`: abre num kitty, pra coisa interativa.

Ficam de fora da lista: pastas, ocultos, `*.md` e `*_test.*`.

## Os que já vêm

`telas` (= Super+Ctrl+P), `espelhar`/`estender`/`so-externo`/`so-notebook` (SetTela),
`ip`, `cor` (conta-gotas da tela → hex copiado), `timer`, `cafe` (tela não apaga),
`novo`, `comandos` (abre esta pasta no VS Code).

## Por dentro

- `noctalia/comandos/plugin.toml`: o plugin `matheus/comandos`, com três provedores do launcher.
- `comandos.luau`: lista esta pasta, lê o cabeçalho e roda. Nome exato fica no topo; prefixo do
  nome, logo depois; trecho da descrição (3+ letras) entra por último.
- `arquivos.luau`: `fd --full-path` na home com 3+ letras, 20 resultados, ignora ocultos e o
  `.gitignore`. Score baixo de propósito, pra apps e comandos virem antes.
- `contas.luau` + `contas.py`: entra só quando o texto tem `\`, `√ π × ÷ · ² ³ |` ou `n!` (conta comum fica
  com a embutida, sem linha repetida). O Python traduz o LaTeX (`\frac`, `\sqrt[n]`, `\binom`, `\cdot`,
  `\left(`, vírgula decimal, multiplicação implícita) e avalia pelo `ast` com lista branca, sem `eval`.
  Com variável (letra solta ou grego: `x`, `\alpha`) usa o **sympy**, o único extra, opcional
  e já instalado com `pip --user`: simplifica, ou resolve quando tem `=` (pro `x`, se tiver).
  `2x+3=7` entra sem `\`; duas letras grudadas (`xy`) contam como palavra, então escreva `x y`.
  Testes em `contas_test.py`.
- Registrado no `config.toml` da noctalia (`[[plugins.source]]` "comandos" + `enabled`).
- `./comandos_test.sh`: checa os cabeçalhos e roda os scripts numa HOME falsa.

Esta pasta é o pacote `comandos` do mydots (`stow comandos`); `~/.config/comandos` é link pra cá,
então script criado lá já cai no repo.
