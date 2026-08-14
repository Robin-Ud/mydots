# init.sh — configuração do ble.sh (autosuggestion + syntax highlighting no bash).
# Lido automaticamente de ~/.config/blesh/init.sh. Sourceado pelo ~/.bashrc (seção 0).
#
# Entrou em 13/08/2026, na volta do zsh pro bash, pra repor a única coisa que o
# zsh dava e o bash não dá sozinho: a sugestão cinza inline.
#
# Os defaults do ble.sh já são o que a gente quer — só o necessário aqui:
#   complete_auto_complete = 1              (ligado)
#   complete_auto_delay    = 1              (1ms, praticamente instantâneo)
#   _ble_complete_auto_source = (history syntax)
#       ↑ history + completion real, equivalente ao ZSH_AUTOSUGGEST_STRATEGY
#         =(recente completion) que você tinha — menos o ranqueamento por
#         mtime do `recente`, que era zsh puro e não tem equivalente aqui.

# Cor da sugestão. O default do ble.sh é `bg=254,fg=238`: um BLOCO cinza-claro,
# que no Tokyo Night (fundo #1a1b26) fica gritante. `fg=8` sem fundo é o que o
# zsh-autosuggestions usava — e puxa o color8 do seu tema (#414868), então
# acompanha o terminal em vez de fixar um hex.
ble-face auto_complete=fg=8

# ---------------------------------------------------------------------------
# Atualizar o ble.sh (não tem pacote no Fedora, é build da fonte):
#   git clone --recursive --depth 1 --shallow-submodules \
#       https://github.com/akinomyoga/ble.sh /tmp/ble.sh-build
#   make -C /tmp/ble.sh-build install PREFIX=~/.local && rm -rf /tmp/ble.sh-build
# Versão instalada em 13/08/2026: 0.4.0-devel4+95ae551
# ---------------------------------------------------------------------------
