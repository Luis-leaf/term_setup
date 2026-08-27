# Setup de terminal para Debian e Ubuntu

Este repositório transforma o ambiente atual em um setup portátil, centrado no terminal:

| Camada | Ferramenta | Papel |
| --- | --- | --- |
| Terminal gráfico | Alacritty | Abre a janela e renderiza a fonte/cores. |
| Shell | Zsh + Oh My Zsh + Powerlevel10k | Prompt, completions e comandos. |
| Multiplexador | tmux | Mantém sessões, painéis e histórico vivos. |
| Editor/IDE | Neovim + LazyVim | Edição, LSP, busca, diagnósticos e plugins. |
| Agente | Codex | Inspeção, implementação, testes e revisão no diretório do projeto. |

O diretório `config/` é a fonte de verdade. O arquivo `install.sh` instala ferramentas e copia essas configurações para a home do usuário. Ele não altera o repositório de origem nem atualiza automaticamente instalações já existentes do Oh My Zsh ou de plugins.

## O que foi preservado do computador atual

- Zsh com Oh My Zsh, tema Powerlevel10k, `git`, `zsh-autosuggestions` e `zsh-syntax-highlighting`.
- Seu prompt completo em `config/zsh/.p10k.zsh`, incluindo ícones Nerd Font e layout atual.
- tmux com mouse, histórico de 50 mil linhas, índices a partir de 1, modo de cópia Vim e integração com `wl-copy`.
- Alacritty com JetBrainsMono Nerd Font, tamanho 14, fundo preto e a paleta atual.
- LazyVim, o lockfile de plugins, TokyoDark, realces para Python e `venv-selector`.

Havia dois formatos de configuração do Alacritty no computador: `alacritty.toml` e `alacritty.yml`, com cores diferentes. Só o TOML foi versionado, pois é o formato atual e o Alacritty recente o prioriza. O YAML foi propositalmente deixado de fora. Também alinhei a declaração global do tema do Neovim para `tokyodark`, que já era o tema efetivamente escolhido pelo plugin.

## Requisitos e limitações

- Distribuições: Debian ou Ubuntu com `apt`.
- Arquiteturas do Neovim: `x86_64` e `aarch64/arm64`.
- É necessária internet na primeira execução para pacotes, Oh My Zsh, plugins, fonte e Neovim.
- O script pede `sudo` apenas para pacotes do sistema. Oh My Zsh, fonte, Neovim e dotfiles ficam na sua home.
- A cópia no tmux está configurada para Wayland (`wl-copy`). Em uma sessão X11, ajuste a linha `copy-pipe-and-cancel` de `config/tmux/tmux.conf` para `xclip -selection clipboard` se necessário.

## Instalação em um computador novo

Publique este repositório no seu Git remoto privado e, no computador novo:

```bash
git clone <url-do-seu-repositorio> ~/src/ia_setup
cd ~/src/ia_setup
bash ./install.sh --dry-run
bash ./install.sh
```

O `--dry-run` mostra as ações sem instalar ou copiar nada. Na execução real, a única ação interativa extra é `chsh`, caso o Zsh ainda não seja seu shell de login. Feche e reabra o terminal ao final, ou execute:

```bash
exec zsh
```

Opções úteis:

```bash
bash ./install.sh --skip-chsh          # não muda o shell de login
bash ./install.sh --skip-nvim-sync     # não baixa plugins do LazyVim agora
bash ./install.sh --dry-run             # apenas simula
```

O Neovim `v0.11.5` é instalado em `~/.local/opt/nvim-v0.11.5` e exposto como `~/.local/bin/nvim`. Isso evita a versão geralmente antiga do `apt` e atende aos requisitos do LazyVim. O `.zshrc` inclui `~/.local/bin` no `PATH`.

### Segurança ao aplicar novamente

O instalador é idempotente para as configurações deste repositório:

- se o arquivo de destino for igual ao versionado, ele não é tocado;
- se for diferente, uma cópia é criada em `~/.config-backups/terminal-setup/<data-hora>/` antes da substituição;
- arquivos adicionais que você tenha em `~/.config/nvim` não são removidos;
- clones existentes em `~/.oh-my-zsh` são preservados, não recebem `git pull` automático.

Para restaurar um arquivo, copie a versão correspondente do diretório de backup de volta para a home. Antes de aplicar em uma máquina com dotfiles importantes, leia o `--dry-run`.

## Arquivos instalados

```text
config/zsh/.zshrc                 -> ~/.zshrc
config/zsh/.p10k.zsh              -> ~/.p10k.zsh
config/tmux/tmux.conf             -> ~/.tmux.conf
config/alacritty/alacritty.toml   -> ~/.config/alacritty/alacritty.toml
config/nvim/**                    -> ~/.config/nvim/**
```

Além disso, o script instala Zsh, tmux, Alacritty, Git, Curl, Ripgrep, FZF, `fd-find`, Python/venv, ferramentas de compilação, fontes e utilitários de clipboard. No Debian/Ubuntu, `fd-find` fornece o binário `fdfind`; o instalador cria `~/.local/bin/fd` para compatibilidade com ferramentas que esperam o nome `fd`.

## Primeiro diagnóstico

Depois de abrir outro terminal, execute:

```bash
zsh --version
tmux -V
nvim --version
fc-match 'JetBrainsMono Nerd Font'
nvim +checkhealth
```

No Neovim, estes comandos ajudam a identificar problemas:

```vim
:Lazy
:Mason
:checkhealth
```

`Lazy` mostra e atualiza plugins; `Mason` administra servidores LSP, formatadores e debuggers. Para projetos Python, crie `.venv` ou `venv` na raiz e use `<Space>vs` para escolher o ambiente virtual. `<Space>vc` reutiliza a escolha salva.

## Fluxo diário no terminal

Abra um projeto dentro de uma sessão persistente:

```bash
cd ~/codigo/meu-projeto
tmux new -As meu-projeto
nvim .
```

Alguns atalhos padrão do tmux configurado aqui:

| Ação | Atalho |
| --- | --- |
| Criar janela | `Ctrl-b c` |
| Dividir verticalmente | `Ctrl-b %` |
| Dividir horizontalmente | `Ctrl-b "` |
| Navegar entre painéis | `Ctrl-b` e seta, ou `Ctrl-b o` |
| Entrar no modo de cópia | `Ctrl-b [` |
| Selecionar/copiar no modo de cópia | `v`, depois `y` |
| Desanexar sem encerrar | `Ctrl-b d` |
| Retomar sessão | `tmux attach -t meu-projeto` |

Uma disposição simples que funciona bem é: editor em um painel grande, servidor/testes em outro e Codex em uma janela própria. O tmux mantém tudo rodando mesmo se você fechar o Alacritty ou trocar de terminal.

## Como colaborar bem com Codex

Entre no diretório do repositório antes de iniciar o Codex. O agente consegue então examinar os arquivos relevantes, entender a estrutura e executar os testes que já existem. Para tarefas maiores, descreva objetivo, restrições e como saber que terminou.

Bom pedido:

```text
No módulo de autenticação, adicione login por token. Preserve a API atual,
escreva testes de sucesso e erro, execute a suíte relevante e mostre os arquivos alterados.
```

Pedidos úteis para cada fase:

- Explorar: “Leia este repositório e explique o fluxo de criação de usuários. Não altere arquivos.”
- Planejar: “Proponha um plano curto para migrar X; aponte riscos antes de editar.”
- Implementar: “Implemente o plano, mantenha a compatibilidade e execute os testes Y.”
- Revisar: “Revise o diff atual em busca de bugs, regressões e lacunas de teste; não altere nada.”
- Diagnosticar: “Reproduza a falha, encontre a causa e explique-a; não aplique correção ainda.”

O detalhe que mais melhora o resultado é explicitar o limite de autonomia: diga “apenas leitura”, “não altere dependências”, “não faça push”, “pode editar e testar” ou “pare antes de qualquer migração”. Para mudanças com impacto maior, peça um plano antes da implementação; para tarefas pequenas e bem delimitadas, peça diretamente a mudança e o teste. A [documentação oficial de casos de uso do Codex](https://developers.openai.com/codex/use-cases) também reúne exemplos de análise de repositórios, automação e revisão.

## Atualização e manutenção

Edite sempre o arquivo dentro de `config/`, não somente o arquivo em `~`. Em seguida reaplique:

```bash
cd ~/src/ia_setup
git pull
bash ./install.sh --skip-chsh
```

Para atualizar plugins manualmente no Neovim, use `:Lazy update`. Isso altera `lazy-lock.json`; revise e faça commit desse lockfile se quiser que a próxima máquina receba exatamente as mesmas versões. Para reinstalar as versões já travadas, rode:

```bash
nvim --headless '+Lazy! sync' +qa
```

Se você personalizar a configuração diretamente na home, traga a mudança de volta ao repositório antes de trocar de PC. Exemplos:

```bash
cp ~/.tmux.conf config/tmux/tmux.conf
cp ~/.config/alacritty/alacritty.toml config/alacritty/alacritty.toml
cp -a ~/.config/nvim/. config/nvim/
```

Revise o diff e faça commit:

```bash
git diff
git add config install.sh README.md
git commit -m 'Atualiza setup de terminal'
```

## Solução de problemas

| Sintoma | Causa provável | Ação |
| --- | --- | --- |
| Ícones quebrados no prompt | Fonte Nerd Font ausente ou Alacritty não reiniciado | Rode `fc-match 'JetBrainsMono Nerd Font'`, reabra o Alacritty. |
| `nvim` abre uma versão antiga | `~/.local/bin` não está no PATH da sessão atual | `exec zsh`; depois `command -v nvim`. |
| `y` do tmux não copia | `wl-copy` requer sessão Wayland | Use Wayland ou troque por `xclip` conforme descrito acima. |
| Plugins não baixaram | Rede ou execução com `--skip-nvim-sync` | Rode `nvim --headless '+Lazy! sync' +qa`. |
| Prompt do Zsh não aparece | Tema Powerlevel10k não foi clonado | Confirme `~/.oh-my-zsh/custom/themes/powerlevel10k`. |
| Alacritty não abre em servidor/headless | Ele requer uma sessão gráfica | Use tmux e Neovim no terminal disponível. |

## O que não entra neste repositório

Não foram copiados credenciais, chaves SSH, configurações de Git com nome/e-mail, tokens, perfis de cloud nem a instalação do NVM. Mantenha esses itens em um gerenciador de segredos ou em um processo separado. O `.zshrc` continua compatível com NVM quando ele já estiver instalado, mas não instala Node automaticamente.

