#!/usr/bin/env bash
# Verifica, sem alterar nada, se esta máquina atende ao install.sh e o que
# ele precisaria instalar ou substituir. Não usa sudo.
#
# Uso: bash scripts/check-deps.sh [--json]
# Saída: 0 = tudo presente | 1 = faltam itens (o instalador resolve) | 2 = bloqueio

set -uo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly CONFIG_DIR="$REPO_DIR/config"
readonly PACKAGES_FILE="$REPO_DIR/packages.txt"
readonly NVIM_MIN="0.11.0"

JSON=false
case "${1:-}" in
  --json) JSON=true ;;
  -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) printf 'Opção desconhecida: %s\n' "$1" >&2; exit 2 ;;
esac

if [[ -t 1 ]] && ! "$JSON"; then
  C_OK=$'\e[32m' C_INST=$'\e[36m' C_WARN=$'\e[33m' C_BLOCK=$'\e[31m' C_DIM=$'\e[2m' C_RST=$'\e[0m'
else
  C_OK="" C_INST="" C_WARN="" C_BLOCK="" C_DIM="" C_RST=""
fi

declare -a RESULTS=()
COUNT_OK=0 COUNT_INST=0 COUNT_WARN=0 COUNT_BLOCK=0 COUNT_REPLACE=0

# status: ok | instalar | aviso | bloqueio
add() {
  local status="$1" group="$2" item="$3" detail="${4:-}"
  RESULTS+=("$status"$'\t'"$group"$'\t'"$item"$'\t'"$detail")
  case "$status" in
    ok) ((COUNT_OK++)) ;;
    instalar) ((COUNT_INST++)) ;;
    aviso) ((COUNT_WARN++)) ;;
    bloqueio) ((COUNT_BLOCK++)) ;;
  esac
  return 0  # ((x++)) com x=0 retorna 1 e dispararia o "||" de quem chama
}

version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }

# --- Sistema -------------------------------------------------------------
check_system() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
      *" debian "*|*" ubuntu "*) add ok sistema "distribuição" "${PRETTY_NAME:-$ID}" ;;
      *) add bloqueio sistema "distribuição" "${PRETTY_NAME:-desconhecida} (só Debian/Ubuntu e derivadas)" ;;
    esac
  else
    add bloqueio sistema "distribuição" "/etc/os-release não encontrado"
  fi

  case "$(uname -m)" in
    x86_64|aarch64|arm64) add ok sistema arquitetura "$(uname -m)" ;;
    *) add bloqueio sistema arquitetura "$(uname -m) (Neovim oficial só para x86_64/arm64)" ;;
  esac

  command -v apt-get >/dev/null 2>&1 \
    && add ok sistema apt "disponível" \
    || add bloqueio sistema apt "apt-get não encontrado"

  if ((EUID == 0)); then
    add ok sistema privilégios "root"
  elif command -v sudo >/dev/null 2>&1; then
    add ok sistema privilégios "sudo disponível (será pedido na instalação)"
  else
    add bloqueio sistema privilégios "sem sudo e não é root"
  fi

  if command -v curl >/dev/null 2>&1; then
    # shellcheck disable=SC2015
    curl -fsS --max-time 8 -o /dev/null https://github.com 2>/dev/null \
      && add ok sistema internet "github.com acessível" \
      || add bloqueio sistema internet "github.com inacessível (necessário para Neovim, fonte e plugins)"
  else
    timeout 8 bash -c '</dev/tcp/github.com/443' 2>/dev/null \
      && add ok sistema internet "github.com:443 acessível" \
      || add bloqueio sistema internet "github.com:443 inacessível (necessário para Neovim, fonte e plugins)"
  fi

  local free_mb
  free_mb="$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -n "$free_mb" ]]; then
    ((free_mb >= 1500)) \
      && add ok sistema "espaço em disco" "${free_mb} MB livres em \$HOME" \
      || add aviso sistema "espaço em disco" "${free_mb} MB livres; recomendado ≥ 1500 MB"
  fi
}

# --- Pacotes apt ---------------------------------------------------------
apt_lists_present() { compgen -G '/var/lib/apt/lists/*_Packages*' >/dev/null; }
apt_has_candidate() {
  local candidate
  candidate="$(LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

check_packages() {
  local package flag status
  if [[ ! -f "$PACKAGES_FILE" ]]; then
    add bloqueio pacotes packages.txt "arquivo ausente"
    return
  fi
  while read -r package flag; do
    status="$(dpkg-query -W -f='${db:Status-Status} ${Version}' "$package" 2>/dev/null)"
    if [[ "$status" == installed* ]]; then
      add ok pacotes "$package" "${status#installed }"
    elif [[ "$flag" == opcional ]] && apt_lists_present && ! apt_has_candidate "$package"; then
      add aviso pacotes "$package" "opcional, indisponível no apt desta versão: será pulado"
    elif [[ "$flag" == opcional ]]; then
      add instalar pacotes "$package" "apt-get install (opcional: pulado se não existir no apt)"
    else
      add instalar pacotes "$package" "apt-get install"
    fi
  done < <(sed -e 's/#.*//' "$PACKAGES_FILE" | awk 'NF')
}

# --- Ferramentas fora do apt ---------------------------------------------
check_tools() {
  local nvim_bin="" version
  if [[ -x "$HOME/.local/bin/nvim" ]]; then
    nvim_bin="$HOME/.local/bin/nvim"
  elif command -v nvim >/dev/null 2>&1; then
    nvim_bin="$(command -v nvim)"
  fi
  if [[ -n "$nvim_bin" ]]; then
    version="$("$nvim_bin" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    if version_ge "${version:-0}" "$NVIM_MIN"; then
      add ok ferramentas neovim "v$version ($nvim_bin)"
    else
      add instalar ferramentas neovim "v${version:-?} é antigo; será instalada a versão fixada em ~/.local"
    fi
  else
    add instalar ferramentas neovim "será instalado em ~/.local/opt"
  fi

  if command -v fc-list >/dev/null 2>&1 && fc-list : family 2>/dev/null | grep -q 'JetBrainsMono Nerd Font'; then
    add ok ferramentas "JetBrainsMono Nerd Font" "instalada"
  else
    add instalar ferramentas "JetBrainsMono Nerd Font" "será baixada para ~/.local/share/fonts"
  fi

  local name path
  for name in ohmyzsh:.oh-my-zsh powerlevel10k:.oh-my-zsh/custom/themes/powerlevel10k \
              zsh-autosuggestions:.oh-my-zsh/custom/plugins/zsh-autosuggestions \
              zsh-syntax-highlighting:.oh-my-zsh/custom/plugins/zsh-syntax-highlighting; do
    path="$HOME/${name#*:}"
    [[ -d "$path" ]] \
      && add ok ferramentas "${name%%:*}" "~/${name#*:}" \
      || add instalar ferramentas "${name%%:*}" "git clone"
  done

  local login_shell
  login_shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
  [[ "$login_shell" == */zsh ]] \
    && add ok ferramentas "shell de login" "$login_shell" \
    || add instalar ferramentas "shell de login" "${login_shell:-?} → zsh (chsh)"
}

# --- Ambiente gráfico ----------------------------------------------------
check_environment() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    add ok ambiente "sessão gráfica" "Wayland (cópia do tmux via wl-copy)"
  elif [[ -n "${DISPLAY:-}" ]]; then
    add aviso ambiente "sessão gráfica" "X11: troque wl-copy por 'xclip -selection clipboard' em config/tmux/tmux.conf"
  else
    add aviso ambiente "sessão gráfica" "nenhuma detectada (SSH/container): Alacritty e a cópia para o clipboard não serão usados"
  fi
}

# --- Dotfiles que seriam substituídos ------------------------------------
check_dotfiles() {
  local pair source_file target_file relative
  local -a pairs=(
    "zsh/.zshrc:$HOME/.zshrc"
    "zsh/.p10k.zsh:$HOME/.p10k.zsh"
    "tmux/tmux.conf:$HOME/.tmux.conf"
    "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
  )
  while IFS= read -r -d '' source_file; do
    relative="${source_file#"$CONFIG_DIR/nvim"/}"
    pairs+=("nvim/$relative:$HOME/.config/nvim/$relative")
  done < <(find "$CONFIG_DIR/nvim" -type f -print0 2>/dev/null | sort -z)

  for pair in "${pairs[@]}"; do
    source_file="$CONFIG_DIR/${pair%%:*}"
    target_file="${pair#*:}"
    if [[ -e "$target_file" ]] && ! cmp -s "$source_file" "$target_file"; then
      add aviso dotfiles "${target_file/#$HOME/\~}" "difere do repositório: backup + substituição"
      ((COUNT_REPLACE++))
    fi
  done

  local settings="$HOME/.claude/settings.json"
  if [[ -f "$settings" ]]; then
    if command -v jq >/dev/null 2>&1 && ! jq empty "$settings" 2>/dev/null; then
      add aviso dotfiles "~/.claude/settings.json" "JSON inválido: hooks não serão aplicados"
    else
      add ok dotfiles "~/.claude/settings.json" "hooks serão mesclados (sem apagar o resto)"
    fi
  fi
}

# --- Relatório -----------------------------------------------------------
print_text() {
  local line status group item detail last_group="" icon color pad
  for line in "${RESULTS[@]}"; do
    IFS=$'\t' read -r status group item detail <<<"$line"
    if [[ "$group" != "$last_group" ]]; then
      printf '\n%s\n' "${group^^}"
      last_group="$group"
    fi
    case "$status" in
      ok) icon="✔" color="$C_OK" ;;
      instalar) icon="+" color="$C_INST" ;;
      aviso) icon="!" color="$C_WARN" ;;
      bloqueio) icon="✘" color="$C_BLOCK" ;;
    esac
    # Padding manual: printf %-Ns conta bytes e desalinha textos acentuados.
    pad=$((28 - ${#item})); ((pad < 1)) && pad=1
    printf '  %s%s %s%*s%s%s%s%s\n' "$color" "$icon" "$item" "$pad" "" "$C_RST" "$C_DIM" "$detail" "$C_RST"
  done
  printf '\nResumo: %d ok, %s%d a instalar%s, %s%d avisos%s (%d dotfiles com backup), %s%d bloqueios%s\n' \
    "$COUNT_OK" "$C_INST" "$COUNT_INST" "$C_RST" "$C_WARN" "$COUNT_WARN" "$C_RST" "$COUNT_REPLACE" \
    "$C_BLOCK" "$COUNT_BLOCK" "$C_RST"
  if ((COUNT_BLOCK)); then
    printf 'Resolva os bloqueios antes de rodar install.sh.\n'
  elif ((COUNT_INST)); then
    printf 'Pode instalar: bash ./install.sh --dry-run && bash ./install.sh\n'
  else
    printf 'Todas as dependências estão presentes.\n'
  fi
}

print_json() {
  local line status group item detail first=true
  printf '{"summary":{"ok":%d,"install":%d,"warn":%d,"block":%d,"replace":%d},"items":[' \
    "$COUNT_OK" "$COUNT_INST" "$COUNT_WARN" "$COUNT_BLOCK" "$COUNT_REPLACE"
  for line in "${RESULTS[@]}"; do
    IFS=$'\t' read -r status group item detail <<<"$line"
    "$first" || printf ','
    first=false
    printf '{"status":"%s","group":"%s","item":"%s","detail":"%s"}' \
      "$status" "$group" "${item//\"/\\\"}" "${detail//\"/\\\"}"
  done
  printf ']}\n'
}

check_system
check_packages
check_tools
check_environment
check_dotfiles

"$JSON" && print_json || print_text

if ((COUNT_BLOCK)); then exit 2; elif ((COUNT_INST)); then exit 1; else exit 0; fi
