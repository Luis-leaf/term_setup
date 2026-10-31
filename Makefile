# Homologação em Docker. Veja a seção "Homologar antes de instalar" do README.
#
#   make check                  verifica dependências desta máquina (sem Docker)
#   make test                   homologa na distro padrão (DISTRO=debian:13)
#   make test DISTRO=ubuntu:24.04
#   make test-all               homologa em todas as DISTROS
#   make try                    shell interativo (tmux + zsh + nvim) já instalado
#   make try-gui                Alacritty no navegador: http://localhost:6080
#   make clean                  remove as imagens de homologação

DISTRO  ?= debian:13
DISTROS ?= debian:12 debian:13 ubuntu:22.04 ubuntu:24.04
# Para adicionar uma distro: inclua a imagem em DISTROS ou passe DISTRO=<imagem>.
# Ex.: make test DISTRO=linuxmintd/mint22.1-amd64

IMAGE   := term-setup-homolog
TAG      = $(subst /,-,$(subst :,-,$(DISTRO)))
DOCKER  ?= docker

.PHONY: check test test-all try try-gui clean

check:
	@bash scripts/check-deps.sh

test:
	$(DOCKER) build -f test/Dockerfile --target base --build-arg BASE=$(DISTRO) -t $(IMAGE):$(TAG)-base .
	$(DOCKER) run --rm -e SKIP_NVIM_SYNC $(IMAGE):$(TAG)-base

test-all:
	@failed=""; for d in $(DISTROS); do \
	  printf "\n================ %s ================\n" "$$d"; \
	  $(MAKE) --no-print-directory test DISTRO=$$d || failed="$$failed $$d"; \
	done; \
	if [ -n "$$failed" ]; then printf "\nFALHOU em:%s\n" "$$failed"; exit 1; else printf "\nTodas as distros passaram: %s\n" "$(DISTROS)"; fi

try:
	$(DOCKER) build -f test/Dockerfile --target installed --build-arg BASE=$(DISTRO) -t $(IMAGE):$(TAG)-installed .
	$(DOCKER) run --rm -it $(IMAGE):$(TAG)-installed

try-gui:
	$(DOCKER) build -f test/Dockerfile --target gui --build-arg BASE=$(DISTRO) -t $(IMAGE):$(TAG)-gui .
	$(DOCKER) run --rm -it -p 127.0.0.1:6080:6080 --shm-size=256m $(IMAGE):$(TAG)-gui

clean:
	-$(DOCKER) images --format '{{.Repository}}:{{.Tag}}' | grep '^$(IMAGE):' | xargs -r $(DOCKER) rmi
