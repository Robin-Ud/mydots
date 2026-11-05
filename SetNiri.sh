#!/bin/bash
# SetNiri — monta o mesmo desktop do note (niri + Noctalia + mydots) num Fedora.
#
# Uso:  ~/.mydots/SetNiri.sh            instala e configura
#       ~/.mydots/SetNiri.sh --dry-run  só mostra o que faria (não instala nada)
#
# Pode rodar de novo quantas vezes quiser: pula o que já está feito.
# Máquina com NVIDIA: instala o driver do RPM Fusion e o ajuste de VRAM do niri.
# Máquina com bateria = note (local.note.kdl); sem bateria = PC (local.pc.kdl).
#
# Antes: git clone https://github.com/Robin-Ud/mydots ~/.mydots

set -euo pipefail

MYDOTS="${MYDOTS:-$HOME/.mydots}"
SYS="${SYS:-/sys}"                       # trocável no teste
NOCTALIA_REPO="https://github.com/noctalia-dev/noctalia-shell"
NOCTALIA_COMMIT="125a30d"                # mesma versão do note (2026-10-26)
NOCTALIA_SRC="$HOME/deving/disposable/noctalia"
# Pacotes do mydots que vão pro stow
STOW_PKGS=(niri noctalia fastfetch kitty rofi scripts vscode vim starship bash blesh bk rbw)
PENDENTE=()

DRY=""
[ "${1:-}" = "--dry-run" ] && DRY=1

# --- utilidades -------------------------------------------------------------
diz()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
avisa(){ printf '\033[1;33m!!\033[0m  %s\n' "$*"; PENDENTE+=("$*"); }
run()  {
    if [ -n "$DRY" ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}

# --- detecção (funções puras, testadas no SetNiri_test.sh) -------------------
tem_bateria() { compgen -G "$SYS/class/power_supply/BAT*" >/dev/null; }

# NVIDIA = vendor 10de numa controladora de vídeo (classe 0300 VGA ou 0302 3D)
tem_nvidia() { grep -qE '^(0300|0302) 10de$' < <(pci_video); }
pci_video() {
    local d
    for d in "$SYS"/bus/pci/devices/*; do
        [ -r "$d/class" ] || continue
        printf '%s %s\n' "$(cut -c3-6 "$d/class")" "$(cut -c3- "$d/vendor")"
    done
}

maquina() { if tem_bateria; then echo note; else echo pc; fi; }

# --- passos ----------------------------------------------------------------
pacotes() {
    diz "Pacotes do Fedora (niri, apps dos binds, deps de compilação da Noctalia)"
    run sudo dnf install -y \
        niri xwayland-satellite kitty firefox rofi grim slurp wl-clipboard wl-mirror \
        jq brightnessctl hypridle libnotify stow git python3-pip \
        meson gcc-c++ just \
        wayland-devel wayland-protocols-devel libEGL-devel mesa-libGLES-devel \
        freetype-devel fontconfig-devel cairo-devel pango-devel harfbuzz-devel \
        libxkbcommon-devel glib2-devel libsecret-devel libsodium-devel \
        sdbus-cpp-devel pipewire-devel wireplumber-devel \
        pam-devel polkit-devel libcurl-devel libwebp-devel libjxl-devel libsndfile-devel librsvg2-devel \
        libqalculate-devel libxml2-devel md4c-devel tomlplusplus-devel libical-devel \
        json-devel stb_image_resize2-devel stb_image_write-devel jemalloc-devel
    # rofi-rbw (Super+B) não tem pacote no Fedora; no note veio do pip
    run sudo dnf install -y rbw
    run pip install --user rofi-rbw
}

nvidia() {
    diz "NVIDIA detectada: driver do RPM Fusion + ajuste de VRAM do niri"
    local f
    f=$(rpm -E %fedora)
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        run sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$f.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$f.noarch.rpm"
    fi
    run sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

    # Modeset do DRM: padrão nos drivers novos, mas não custa garantir
    if ! sudo grubby --info=DEFAULT 2>/dev/null | grep -q 'nvidia-drm.modeset=1'; then
        run sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1"
    fi

    # Wiki do niri: sem isso o driver segura ~1 GB de VRAM à toa no compositor
    local perfil=/etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json
    if [ ! -f "$perfil" ]; then
        run sudo mkdir -p "$(dirname "$perfil")"
        if [ -n "$DRY" ]; then
            echo "    [dry-run] grava $perfil (GLVidHeapReuseRatio 0 pro niri)"
        else
            sudo tee "$perfil" >/dev/null <<'JSON'
{
    "rules": [
        {
            "pattern": { "feature": "procname", "matches": "niri" },
            "profile": "Limit Free Buffer Pool On Wayland Compositors"
        }
    ],
    "profiles": [
        {
            "name": "Limit Free Buffer Pool On Wayland Compositors",
            "settings": [ { "key": "GLVidHeapReuseRatio", "value": 0 } ]
        }
    ]
}
JSON
        fi
    fi

    if mokutil --sb-state 2>/dev/null | grep -qi 'enabled'; then
        avisa "Secure Boot ligado: rode 'sudo mokutil --import /etc/pki/akmods/certs/public_key.der', reinicie e confirme a chave na tela azul (MOK), senão o driver não carrega"
    fi
    avisa "NVIDIA: espere o akmod compilar (uns 5 min; 'modinfo -F version nvidia' responde quando terminou) e reinicie"
}

noctalia() {
    if [ -x "$HOME/.local/bin/noctalia" ]; then
        diz "Noctalia já instalada em ~/.local/bin (pulando a compilação)"
        return
    fi
    diz "Noctalia: compilando do fonte ($NOCTALIA_COMMIT) com prefixo ~/.local"
    if [ ! -d "$NOCTALIA_SRC/.git" ]; then
        run mkdir -p "$(dirname "$NOCTALIA_SRC")"
        run git clone "$NOCTALIA_REPO" "$NOCTALIA_SRC"
    fi
    run git -C "$NOCTALIA_SRC" checkout "$NOCTALIA_COMMIT"
    if [ -n "$DRY" ]; then
        echo "    [dry-run] (cd $NOCTALIA_SRC && just configure release ~/.local && just build release && just install release)"
    else
        (cd "$NOCTALIA_SRC" && just configure release "$HOME/.local" && just build release && just install release)
    fi
}

apps_proprios() {
    diz "Apps próprios chamados pelos binds (SetTela no Super+P, MyWpp no Super+W)"
    local app
    for app in SetTela MyWpp; do
        [ -d "$HOME/deving/desktop/$app" ] && continue
        run mkdir -p "$HOME/deving/desktop"
        run git clone "https://github.com/Robin-Ud/$app" "$HOME/deving/desktop/$app"
    done
    if [ ! -e "$HOME/.local/bin/mywpp" ]; then
        run mkdir -p "$HOME/.local/bin"
        run ln -s "$HOME/deving/desktop/MyWpp/mywpp.sh" "$HOME/.local/bin/mywpp"
    fi
}

links() {
    diz "Links do stow (só o que não dá conflito; nada é sobrescrito)"
    local pkg
    for pkg in "${STOW_PKGS[@]}"; do
        [ -d "$MYDOTS/$pkg" ] || continue
        # sem a pasta real, o stow linkaria ~/.config/Code inteira pro repo
        [ "$pkg" = vscode ] && run mkdir -p "$HOME/.config/Code/User"
        if stow -d "$MYDOTS" -t "$HOME" -n "$pkg" 2>/dev/null; then
            run stow -d "$MYDOTS" -t "$HOME" "$pkg"
        else
            avisa "stow $pkg: já existe arquivo de verdade no lugar (ex.: ~/.bashrc do Fedora). Veja com 'stow -n -v $pkg', mova o arquivo pra .orig e rode de novo"
        fi
    done
}

local_kdl() {
    local dir="$MYDOTS/niri/.config/niri" m
    m=$(maquina)
    if [ -f "$dir/local.kdl" ]; then
        diz "local.kdl já existe (não mexo)"
        return
    fi
    diz "local.kdl a partir do modelo de $m"
    run cp "$dir/local.$m.kdl" "$dir/local.kdl"
    [ "$m" = pc ] && avisa "PC: ajuste o monitor em ~/.config/niri/local.kdl (nome e modo em 'niri msg outputs', dentro do niri)"
    return 0
}

main() {
    [ -d "$MYDOTS/niri" ] || { echo "Cadê o mydots? git clone https://github.com/Robin-Ud/mydots $MYDOTS" >&2; exit 1; }
    [ "$HOME" = /home/rud ] || avisa "Os binds do niri usam /home/rud fixo; com outro usuário, troque no config.kdl"

    diz "Máquina: $(maquina) | NVIDIA: $(tem_nvidia && echo sim || echo não)${DRY:+ | DRY-RUN}"
    pacotes
    if tem_nvidia; then nvidia; fi
    noctalia
    apps_proprios
    links
    local_kdl

    echo
    diz "Pronto. Saia da sessão e escolha 'Niri' na tela de login (engrenagem do GDM)."
    if [ ${#PENDENTE[@]} -gt 0 ]; then
        echo; diz "Falta você fazer:"
        printf '  - %s\n' "${PENDENTE[@]}"
    fi
}

# Só roda se executado (o teste faz source pra pegar as funções)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
