#!/usr/bin/env bash
# Instala o ambiente de terminal deste repositório em Debian/Ubuntu.
# Uso: bash ./install.sh [--check] [--dry-run] [--skip-chsh] [--skip-nvim-sync]

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly PACKAGES_FILE="$SCRIPT_DIR/packages.txt"
readonly NVIM_VERSION="v0.11.5"
readonly NERD_FONT_VERSION="v3.3.0"

DRY_RUN=false
SKIP_CHSH=false
SKIP_NVIM_SYNC=false
BACKUP_DIR=""

usage() {
  cat <<'EOF'
Uso: bash ./install.sh [opções]

Opções:
  --check           Só verifica dependências (scripts/check-deps.sh) e sai.
  --dry-run         Mostra as ações sem alterar o sistema.
  --skip-chsh       Não torna o zsh o shell de login.
  --skip-nvim-sync  Não baixa plugins do LazyVim no final.
  -h, --help        Mostra esta ajuda.
EOF
}

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nAVISO: %s\n' "$*" >&2; }
die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

run() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  "$DRY_RUN" || "$@"
}

while (($#)); do
  case "$1" in
    --check) exec bash "$SCRIPT_DIR/scripts/check-deps.sh" ;;
    --dry-run) DRY_RUN=true ;;
    --skip-chsh) SKIP_CHSH=true ;;
    --skip-nvim-sync) SKIP_NVIM_SYNC=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opção desconhecida: $1" ;;
  esac
  shift
done

[[ -f /etc/os-release ]] || die "Não encontrei /etc/os-release. Este instalador atende Debian e Ubuntu."
# shellcheck disable=SC1091
source /etc/os-release
# Derivadas (Linux Mint, Pop!_OS, ...) declaram a base em ID_LIKE.
case " ${ID:-} ${ID_LIKE:-} " in
  *" debian "*|*" ubuntu "*) ;;
  *) die "Distribuição não suportada: ${PRETTY_NAME:-desconhecida}. Use Debian ou Ubuntu." ;;
esac

if ((EUID == 0)); then
  SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  die "O sudo é necessário para instalar pacotes. Entre como root ou instale o sudo."
fi

BACKUP_DIR="$HOME/.config-backups/terminal-setup/$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_DIR

backup_if_different() {
  local source_file="$1"
  local target_file="$2"
  local relative_path backup_file

  [[ -e "$target_file" || -L "$target_file" ]] || return 0
  cmp -s "$source_file" "$target_file" && return 0

  relative_path="${target_file#"$HOME"/}"
  backup_file="$BACKUP_DIR/$relative_path"
  log "Backup: $target_file -> $backup_file"
  run install -d -m 700 "$(dirname "$backup_file")"
  run cp -a -- "$target_file" "$backup_file"
}

install_dotfile() {
  local source_file="$1"
  local target_file="$2"

  [[ -f "$source_file" ]] || die "Arquivo de configuração ausente: $source_file"
  backup_if_different "$source_file" "$target_file"
  if [[ -e "$target_file" || -L "$target_file" ]] && cmp -s "$source_file" "$target_file"; then
    printf '  já está atualizado: %s\n' "$target_file"
    return 0
  fi
  run install -D -m 600 "$source_file" "$target_file"
}

install_nvim_config() {
  local source_file relative_path
  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$CONFIG_DIR/nvim"/}"
    install_dotfile "$source_file" "$HOME/.config/nvim/$relative_path"
  done < <(find "$CONFIG_DIR/nvim" -type f -print0 | sort -z)
}

clone_if_missing() {
  local repository="$1"
  local destination="$2"
  if [[ -e "$destination" ]]; then
    printf '  preservado: %s\n' "$destination"
    return 0
  fi
  run git clone --depth=1 "$repository" "$destination"
}

# Verdadeiro se o apt tem uma versão instalável do pacote. "apt-cache show"
# não serve: ele aceita pacotes só referenciados por outros, sem candidato.
apt_has_candidate() {
  local candidate
  candidate="$(LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

install_packages() {
  log "Instalando pacotes do sistema (${PRETTY_NAME})"
  local packages=() name flag
  [[ -f "$PACKAGES_FILE" ]] || die "Lista de pacotes ausente: $PACKAGES_FILE"
  run "${SUDO[@]}" apt-get update
  while read -r name flag; do
    if [[ "$flag" == opcional ]] && ! apt_has_candidate "$name"; then
      warn "Pacote opcional '$name' não existe no apt de ${PRETTY_NAME}; pulando."
      continue
    fi
    packages+=("$name")
  done < <(sed -e 's/#.*//' "$PACKAGES_FILE" | awk 'NF')
  run "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends "${packages[@]}"
}

install_fd_alias() {
  [[ -x /usr/bin/fdfind ]] || return 0
  if command -v fd >/dev/null 2>&1; then
    return 0
  fi
  log "Criando o alias de compatibilidade fd -> fdfind"
  run install -d -m 700 "$HOME/.local/bin"
  run ln -sfn /usr/bin/fdfind "$HOME/.local/bin/fd"
}

install_nerd_font() {
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip"
  local temporary_dir archive

  if fc-list : family 2>/dev/null | grep -q 'JetBrainsMono Nerd Font'; then
    printf '  fonte JetBrainsMono Nerd Font já está disponível.\n'
    return 0
  fi

  log "Instalando JetBrainsMono Nerd Font ${NERD_FONT_VERSION}"
  if "$DRY_RUN"; then
    printf '+ curl -fL --retry 3 %q -o <arquivo-temporário>\n' "$font_url"
    printf '+ unzip -q <arquivo-temporário> *.ttf -d %q\n' "$font_dir"
    printf '+ fc-cache -f %q\n' "$font_dir"
    return 0
  fi

  temporary_dir="$(mktemp -d)"
  trap 'rm -rf -- "$temporary_dir"' EXIT
  archive="$temporary_dir/JetBrainsMono.zip"
  run install -d -m 755 "$font_dir"
  run curl -fL --retry 3 "$font_url" -o "$archive"
  run unzip -q "$archive" '*.ttf' -d "$font_dir"
  run fc-cache -f "$font_dir"
  trap - EXIT
  rm -rf -- "$temporary_dir"
}

install_neovim() {
  local architecture archive_name archive_url install_root binary_path temporary_dir archive extracted incomplete_backup
  install_root="$HOME/.local/opt/nvim-${NVIM_VERSION}"
  binary_path="$install_root/bin/nvim"

  if [[ -x "$binary_path" ]]; then
    printf '  Neovim %s já está instalado em %s.\n' "$NVIM_VERSION" "$install_root"
  else
    case "$(uname -m)" in
      x86_64) architecture="x86_64" ;;
      aarch64|arm64) architecture="arm64" ;;
      *) die "Arquitetura não suportada para o binário oficial do Neovim: $(uname -m)" ;;
    esac
    archive_name="nvim-linux-${architecture}.tar.gz"
    archive_url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${archive_name}"

    log "Instalando Neovim ${NVIM_VERSION} em ~/.local (sem substituir o pacote do sistema)"
    if "$DRY_RUN"; then
      printf '+ curl -fL --retry 3 %q -o <arquivo-temporário>\n' "$archive_url"
      printf '+ tar -xzf <arquivo-temporário> -C <diretório-temporário>\n'
      printf '+ mv <Neovim-extraído> %q\n' "$install_root"
    else
      temporary_dir="$(mktemp -d)"
      trap 'rm -rf -- "$temporary_dir"' EXIT
      archive="$temporary_dir/$archive_name"
      run curl -fL --retry 3 "$archive_url" -o "$archive"
      run tar -xzf "$archive" -C "$temporary_dir"
      extracted="$temporary_dir/nvim-linux-${architecture}"
      [[ -x "$extracted/bin/nvim" ]] || die "O arquivo do Neovim não contém o binário esperado."
      run install -d -m 700 "$HOME/.local/opt"
      if [[ -e "$install_root" ]]; then
        incomplete_backup="${install_root}.incompleto-$(date +%Y%m%d-%H%M%S)"
        warn "A instalação incompleta do Neovim foi preservada em $incomplete_backup"
        run mv "$install_root" "$incomplete_backup"
      fi
      run mv "$extracted" "$install_root"
      trap - EXIT
      rm -rf -- "$temporary_dir"
    fi
  fi

  log "Disponibilizando nvim em ~/.local/bin"
  run install -d -m 700 "$HOME/.local/bin"
  if [[ -e "$HOME/.local/bin/nvim" && ! -L "$HOME/.local/bin/nvim" ]]; then
    warn "Não substituí $HOME/.local/bin/nvim porque ele não é um link simbólico."
  else
    run ln -sfn "$binary_path" "$HOME/.local/bin/nvim"
  fi
}

install_oh_my_zsh() {
  log "Instalando Oh My Zsh e extensões"
  clone_if_missing https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  clone_if_missing https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
}

# Mescla os hooks de notificação do Claude Code em ~/.claude/settings.json
# sem sobrescrever as demais preferências do usuário. Cada hook é adicionado
# apenas se ainda não existir, então reaplicar não duplica nada.
install_claude_hooks() {
  local source_file="$CONFIG_DIR/claude/hooks.json"
  local target_file="$HOME/.claude/settings.json"
  local merged

  [[ -f "$source_file" ]] || die "Arquivo de configuração ausente: $source_file"
  if ! command -v jq >/dev/null 2>&1; then
    if "$DRY_RUN"; then
      printf '+ mesclar %q em %q (requer jq)\n' "$source_file" "$target_file"
      return 0
    fi
    die "jq é necessário para mesclar os hooks do Claude Code."
  fi

  if [[ -f "$target_file" ]]; then
    jq empty "$target_file" 2>/dev/null || { warn "$target_file não é JSON válido; hooks do Claude não aplicados."; return 0; }
    merged="$(jq -s '
      .[0] as $current | .[1].hooks as $new
      | $current
      | .hooks = reduce ($new | keys[]) as $event
          ($current.hooks // {};
           .[$event] = ((.[$event] // []) as $existing
             | $existing + [ $new[$event][] | select(. as $h | $existing | index([$h]) | not) ]))
    ' "$target_file" "$source_file")"
  else
    merged="$(cat "$source_file")"
  fi

  if [[ -f "$target_file" ]] && [[ "$(jq -S . "$target_file")" == "$(jq -S . <<<"$merged")" ]]; then
    printf '  já está atualizado: %s\n' "$target_file"
    return 0
  fi

  if [[ -f "$target_file" ]]; then
    log "Backup: $target_file -> $BACKUP_DIR/.claude/settings.json"
    run install -d -m 700 "$BACKUP_DIR/.claude"
    run cp -a -- "$target_file" "$BACKUP_DIR/.claude/settings.json"
  fi
  printf '+ mesclar hooks de notificação em %q\n' "$target_file"
  if ! "$DRY_RUN"; then
    install -d -m 700 "$HOME/.claude"
    printf '%s\n' "$merged" > "$target_file"
    chmod 600 "$target_file"
  fi
}

set_login_shell() {
  "$SKIP_CHSH" && return 0
  local desired_shell current_shell
  desired_shell="$(command -v zsh)"
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  [[ "$current_shell" == "$desired_shell" ]] && return 0

  if [[ -t 0 && -t 1 ]]; then
    log "Definindo zsh como shell de login (a senha pode ser solicitada)"
    run chsh -s "$desired_shell"
  else
    warn "Sessão não interativa: execute 'chsh -s $desired_shell' depois do login."
  fi
}

sync_lazyvim() {
  "$SKIP_NVIM_SYNC" && return 0
  local nvim_binary="$HOME/.local/bin/nvim"
  [[ -x "$nvim_binary" || -L "$nvim_binary" ]] || { warn "Neovim não encontrado; plugins não foram instalados."; return 0; }
  log "Baixando plugins fixados do LazyVim"
  # "restore" instala exatamente as versões do lazy-lock.json; "sync" atualizaria
  # os plugins e reescreveria o lockfile (gerando backup a cada reinstalação).
  # Na primeira abertura, porém, o lazy.nvim instala os plugins ausentes na versão
  # mais recente e sobrescreve o lockfile antes do restore. Por isso o lockfile do
  # repositório é recolocado e o restore roda de novo, agora com as versões fixadas.
  run "$nvim_binary" --headless "+Lazy! restore" +qa
  run install -m 600 "$CONFIG_DIR/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
  run "$nvim_binary" --headless "+Lazy! restore" +qa
}

verify_installation() {
  log "Verificação"
  zsh --version
  tmux -V
  "$HOME/.local/bin/nvim" --version | head -n 1
  if command -v alacritty >/dev/null 2>&1; then
    alacritty --version
  else
    warn "Alacritty não instalado (indisponível no apt). Veja https://github.com/alacritty/alacritty/blob/master/INSTALL.md"
  fi
  fc-match 'JetBrainsMono Nerd Font' | head -n 1
  printf '\nConcluído. Abra um novo terminal ou execute: exec zsh\n'
  printf 'Backups (se necessários): %s\n' "$BACKUP_DIR"
}

main() {
  [[ -d "$CONFIG_DIR" ]] || die "Diretório config/ não encontrado ao lado do instalador."
  install_packages
  install_fd_alias
  install_nerd_font
  install_neovim
  install_oh_my_zsh

  log "Aplicando dotfiles"
  install_dotfile "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc"
  install_dotfile "$CONFIG_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
  install_dotfile "$CONFIG_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
  install_dotfile "$CONFIG_DIR/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  install_nvim_config
  install_claude_hooks

  set_login_shell
  sync_lazyvim
  if "$DRY_RUN"; then
    log "Simulação concluída; nenhum arquivo foi alterado."
  else
    verify_installation
  fi
}

main
