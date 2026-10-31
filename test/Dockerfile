# Homologação do term_setup em containers descartáveis.
#
# Estágios:
#   base       sistema "limpo" + usuário comum com sudo (usado por `make test`)
#   installed  base + install.sh já executado            (usado por `make try`)
#   gui        installed + Xvfb/noVNC para ver o Alacritty no navegador (`make try-gui`)
#
# BASE aceita qualquer imagem Debian/Ubuntu ou derivada (ex.: linuxmintd/mint22-amd64).
ARG BASE=debian:13

FROM ${BASE} AS base
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color
# Só o mínimo que um PC recém-instalado já teria; o resto é papel do install.sh.
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --shell /bin/bash tester \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
 && chmod 440 /etc/sudoers.d/tester
USER tester
WORKDIR /home/tester/term_setup
COPY --chown=tester:tester . .
CMD ["bash", "test/smoke.sh"]

FROM base AS installed
RUN bash ./install.sh --skip-chsh \
 && sudo chsh -s "$(command -v zsh)" tester \
 && sudo rm -rf /var/lib/apt/lists/*
WORKDIR /home/tester
ENV SHELL=/usr/bin/zsh
CMD ["tmux", "new-session", "-A", "-s", "homologacao"]

FROM installed AS gui
RUN sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends \
      xvfb x11vnc novnc python3-websockify matchbox-window-manager \
      libgl1-mesa-dri libegl1 \
      libxcursor1 libxi6 libxrandr2 libxkbcommon-x11-0 libx11-xcb1 procps \
 && sudo rm -rf /var/lib/apt/lists/* \
 && sudo install -d -m 1777 /tmp/.X11-unix
# O Alacritty carrega as libs do X11 em tempo de execução (dlopen); num desktop
# real elas já existem, aqui precisam ser instaladas.
# Renderização OpenGL por software (llvmpipe): sem GPU no container.
ENV LIBGL_ALWAYS_SOFTWARE=1 DISPLAY=:1 GEOMETRY=1440x900
EXPOSE 6080
CMD ["bash", "/home/tester/term_setup/test/gui-entrypoint.sh"]
