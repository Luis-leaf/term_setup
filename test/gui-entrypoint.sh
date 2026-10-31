#!/usr/bin/env bash
# Sobe um desktop virtual com o Alacritty (rodando tmux) e o expõe via noVNC.
set -euo pipefail

Xvfb "$DISPLAY" -screen 0 "${GEOMETRY}x24" -nolisten tcp &
for _ in $(seq 50); do [[ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]] && break; sleep 0.1; done

matchbox-window-manager -use_titlebar no &
x11vnc -display "$DISPLAY" -forever -shared -nopw -localhost -rfbport 5900 -quiet &
websockify --web /usr/share/novnc 6080 localhost:5900 >/dev/null 2>&1 &

printf '\nAbra no navegador: http://localhost:6080/vnc.html?autoconnect=1&resize=remote\n'
printf 'Ctrl+C aqui encerra o container.\n\n'

# Se a janela for fechada, abre de novo.
while true; do
  alacritty -e tmux new-session -A -s homologacao || sleep 1
done
