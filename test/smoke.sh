#!/usr/bin/env bash
# Roda dentro do container (estágio `base`): verifica, instala, verifica de
# novo e valida que o ambiente instalado funciona. Sai != 0 na primeira falha.
set -uo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
FAILURES=0
pass() { printf '  \e[32m✔\e[0m %s\n' "$*"; }
fail() { printf '  \e[31m✘\e[0m %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
step() { printf '\n\e[1m### %s\e[0m\n' "$*"; }
warn() { printf '  \e[33m!\e[0m %s\n' "$*"; }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi; }

INSTALL_FLAGS=(--skip-chsh)
[[ "${SKIP_NVIM_SYNC:-0}" == 1 ]] && INSTALL_FLAGS+=(--skip-nvim-sync)

step "1. check-deps antes da instalação (espera itens a instalar)"
bash scripts/check-deps.sh; code=$?
[[ $code == 1 ]] && pass "check-deps sinalizou dependências faltando (exit 1)" || fail "check-deps exit=$code, esperado 1"

step "2. install.sh --dry-run não altera nada"
before="$(find "$HOME" -xdev 2>/dev/null | sort | md5sum)"
bash ./install.sh --dry-run "${INSTALL_FLAGS[@]}" >/tmp/dry-run.log 2>&1; code=$?
after="$(find "$HOME" -xdev 2>/dev/null | sort | md5sum)"
[[ $code == 0 ]] && pass "dry-run terminou com sucesso" || { fail "dry-run exit=$code"; tail -20 /tmp/dry-run.log; }
[[ "$before" == "$after" ]] && pass "nenhum arquivo criado na home" || fail "dry-run alterou a home"

step "3. install.sh ${INSTALL_FLAGS[*]}"
if bash ./install.sh "${INSTALL_FLAGS[@]}" 2>&1 | tee /tmp/install.log; then
  pass "instalação terminou com sucesso"
else
  fail "instalação falhou (veja acima)"
  exit 1
fi

step "4. check-deps depois da instalação"
bash scripts/check-deps.sh >/tmp/check-after.log; code=$?
# O shell de login não é trocado no container (--skip-chsh), por isso exit 1 é aceito
# desde que o único item pendente seja esse.
pending="$(bash scripts/check-deps.sh --json | jq -r '.items[] | select(.status=="instalar") | .item')"
if [[ $code == 0 || "$pending" == "shell de login" ]]; then
  pass "todas as dependências presentes${pending:+ (exceto: $pending, esperado no container)}"
else
  fail "ainda faltam: $(echo "$pending" | paste -sd, -)"
  cat /tmp/check-after.log
fi

step "5. Smoke tests"
export PATH="$HOME/.local/bin:$PATH"
check "zsh carrega o .zshrc sem erros" bash -c '[[ -z "$(zsh -i -c exit 2>&1 >/dev/null | grep -iv "instant prompt")" ]]'
check "tema powerlevel10k ativo" bash -c 'zsh -i -c "echo \$ZSH_THEME" 2>/dev/null | grep -q powerlevel10k'
check "nvim >= 0.11 em ~/.local/bin" bash -c 'nvim --version | head -1 | grep -qE "v0\.(1[1-9]|[2-9][0-9])"'
check "nvim abre e fecha headless sem erro" bash -c '[[ -z "$(nvim --headless +qa 2>&1 | grep -i error)" ]]'
if command -v alacritty >/dev/null 2>&1; then
  pass "alacritty instalado"
elif [[ "$(LC_ALL=C apt-cache policy alacritty | awk '/Candidate:/ {print $2}')" =~ ^(|\(none\))$ ]]; then
  warn "alacritty indisponível no apt desta distro (pacote opcional, pulado pelo instalador)"
else
  fail "alacritty existe no apt mas não foi instalado"
fi
check "fonte JetBrainsMono Nerd Font registrada" bash -c 'fc-list | grep -q "JetBrainsMono Nerd Font"'
check "fd disponível (alias de fdfind)" bash -c 'command -v fd || command -v fdfind'

step "6. Notificações (bell do tmux + hooks do Claude Code)"
tmux -f "$HOME/.tmux.conf" new-session -d -s smoke -n primeiro
check "tmux: monitor-bell on" bash -c '[[ "$(tmux show -gwv monitor-bell)" == on ]]'
check "tmux: window-status-bell-style none (sem cores invertidas)" bash -c '[[ "$(tmux show -gwv window-status-bell-style)" == none ]]'
check "tmux: bell-action any" bash -c '[[ "$(tmux show -gv bell-action)" == any ]]'
tmux new-window -d -t smoke -n fundo "printf '\a'; sleep 30"
sleep 1
check "tmux: BEL em janela de fundo liga o window_bell_flag" \
  bash -c '[[ "$(tmux display -p -t smoke:fundo "#{window_bell_flag}")" == 1 ]]'
check "tmux: guia da janela com alerta fica amarela (colour220), sem ícone" \
  bash -c 'f="$(tmux display -p -t smoke:fundo "#{E:window-status-format}")"; [[ "$f" == *bg=colour220* && "$f" != *🔔* ]]'
check "tmux: guia sem alerta continua cinza" \
  bash -c '[[ "$(tmux display -p -t smoke:primeiro "#{E:window-status-format}")" != *colour220* ]]'
tmux kill-server 2>/dev/null
check "Claude: hook Stop mesclado em ~/.claude/settings.json" \
  jq -e '.hooks.Stop[].hooks[] | select(.command | contains("printf"))' "$HOME/.claude/settings.json"
check "Claude: hook Notification mesclado" \
  jq -e '.hooks.Notification[].hooks[] | select(.command | contains("printf"))' "$HOME/.claude/settings.json"

step "7. Idempotência: segunda execução não faz backup nem altera arquivos"
bash ./install.sh "${INSTALL_FLAGS[@]}" >/tmp/install2.log 2>&1; code=$?
[[ $code == 0 ]] && pass "segunda execução terminou com sucesso" || fail "segunda execução exit=$code"
if grep -q '^==> Backup:' /tmp/install2.log; then
  fail "segunda execução criou backups:"
  grep '^==> Backup:' /tmp/install2.log | sed 's/^/      /'
else
  pass "nenhum backup novo"
fi

printf '\n'
if ((FAILURES)); then
  printf '\e[31mHOMOLOGAÇÃO FALHOU: %d verificação(ões)\e[0m\n' "$FAILURES"
  exit 1
fi
printf '\e[32mHOMOLOGAÇÃO OK (%s)\e[0m\n' "$(. /etc/os-release; echo "$PRETTY_NAME")"
