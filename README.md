# Initial Setup Instructions

## Homebrew

Configuración actual:

- gestor base para instalar y actualizar todo el tooling del setup

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew update
brew upgrade
```

## Nerd font

Configuración actual:

- el setup espera `Inconsolata Nerd Font` como fuente del terminal
- habilita iconos y glyphs para `powerlevel10k`, `eza`, `lualine` y varios custom plugins entre otros

### Mac

```bash
mkdir -p ~/Library/Fonts

curl -L -o /tmp/Inconsolata.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Inconsolata.zip

unzip -o /tmp/Inconsolata.zip -d ~/Library/Fonts
```

### Linux

```bash
 mkdir -p ~/.local/share/fonts
 curl -L \
   -o /tmp/Inconsolata.zip \
   https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Inconsolata.zip

 unzip -o /tmp/Inconsolata.zip -d ~/.local/share/fonts

 fc-cache -fv
```

### Remember to set terminal font to: Inconsolata Nerd Font

## Terminal

### Ghostty (MacOs)

```bash
ln -s ~/mydotfiles/ghostty/ ~/.config
```

### Wezterm (WSL)

```bash
cp ~/mydotfiles/.wezterm.lua /mnt/c/Users/<USERNAME>/
```

## Shell

Configuración actual:

- zsh con prompt `powerlevel10k` lean de 2 lineas con iconos nerd font
- `atuin` para historial y `zoxide` para navegación rápida
- `zsh-autosuggestions` y `zsh-syntax-highlighting`
- aliases: `ls`/`ll`/`la`/`lt` con `eza`, `cat` con `bat`, `find` con `fd`, `grep` con `rg`
- helpers con `fzf`: `cdf`, `ff`, `fg`, `fkill`, `glc`
- arranque automatico de `zellij` con layout aleatorio (theme everfores, sakura y kanagawa). Se puede modificar en: `~/.config/.zshrc`
- soporte WSL para `win32yank` via `~/.local/bin`

```bash
brew install zsh

brew install romkatv/powerlevel10k/powerlevel10k

brew install \
  zsh-autosuggestions \
  zsh-completions \
  zsh-syntax-highlighting

brew install \
  eza \
  bat \
  fzf \
  fd \
  ripgrep \
  zoxide \
  btop \
  atuin

$(brew --prefix)/opt/fzf/install
atuin import auto

mkdir -p ~/.config

ln -s ~/mydotfiles/zsh ~/.config/zsh

echo 'export ZDOTDIR="$HOME/.config/zsh"' > ~/.zshenv

#### enable zsh by default
chsh -s "$(which zsh)"

```

#### IMPORTANTE

Si modificas `~/.config/.zshrc` asegúrate que zsh-syntax-highlighting debe cargarse el último para evitar bugs.

## Multiplexor

### Tmux (Recomendado)

Configuración actual:

- barra superior de estado personalizada
- se inicia con theme random-theme, configurable en mydotfiles/tmux/theme/random-theme.sh
- alias creado con tdev, con dos pestañas shell y workspace, esta última dividida en panes
- plugins instalados indicados más abajo
- instalar el win32yank solo para WSL (también se usara en NeoVim)

```bash
mv ~/.tmux.conf ~/.tmux.conf.bak
mv ~/.config/tmux ~/.config/tmux.bak

ln -s ~/mydotfiles/tmux ~/.config/tmux
ln -s ~/.config/tmux/tmux.conf ~/.tmux.conf

chmod +x ~/mydotfiles/tmux/scripts/*.sh
chmod +x ~/mydotfiles/tmux/layout-dev.sh
chmod +x ~/mydotfiles/tmux/themes/random-theme.sh

# plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tmux-sensible ~/.tmux/plugins/tmux-sensible
git clone https://github.com/tmux-plugins/tmux-yank ~/.tmux/plugins/tmux-yank
git clone https://github.com/christoomey/vim-tmux-navigator ~/.tmux/plugins/vim-tmux-navigator
git clone https://github.com/tmux-plugins/tmux-resurrect ~/.tmux/plugins/tmux-resurrect
git clone https://github.com/alexwforsythe/tmux-which-key ~/.tmux/plugins/tmux-which-key
git clone --recurse-submodules https://github.com/alexwforsythe/tmux-which-key ~/.tmux/plugins/tmux-which-key

tmux kill-server
```

#### Only WSL: clipboard hack

```bash
mkdir -p ~/.local/bin
curl -Lo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip
unzip /tmp/win32yank.zip -d /tmp/win32yank
mv /tmp/win32yank/win32yank.exe ~/.local/bin/
chmod +x ~/.local/bin/win32yank.exe
```

### Zellij (Opcional)

Configuración actual:

- tema base `kanagawa` con `simplified_ui` activo y sin `pane_frames` por defecto
- layouts custom con barra superior `zjstatus` y barra inferior nativa
- pestañas listas para `shell`, `workspace`
- plugin `zellij_forgot` disponible con atajos de búsqueda

```bash
brew install zellij

ln -s ~/mydotfiles/zellij ~/.config/zellij
```

#### Los plugins de zellij no funcionan con rutas relativas

```bash
sed -i "s/\/home\/david/\/home\/${USERNAME}/g" ./zellij/layouts/\*
```

### Solo en caso de tener problemas con los plugins

```bash
# descarga de nuevo si crees que están corruptos
mkdir -p ~/zellij/plugins
curl -L -o ~/zellij/plugins/zellij_forgot.wasm https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm
curl -L -o ~/.config/zellij/plugins/zjstatus.wasm https://github.com/dj95/zjstatus/releases/download/v0.23.0/zjstatus.wasm
curl -L -o ~/.config/zellij/plugins/zjframes.wasm https://github.com/dj95/zjstatus/releases/download/v0.23.0/zjframes.wasm

# borra cache y pide permisos otra vez explicitos
rm -rf ~/.cache/zellij
zellij
zellij plugin -- file:/home/david/.config/zellij/plugins/zjstatus.wasm
```

## Nvim

Configuración actual:

- Base `LazyVim`.
- Tema aleatorio entre `kanagawa`, `tokyonight-night` y `everforest`, configurable en `~/.config/nvim/init.lua`. En `lua/plugins/colors.lua` para instalar nuevos themes.
- Clipboard del sistema activo con `unnamedplus`.
- Soporte WSL para clipboard usando `win32yank`.
- LSPs instalados/configurados para Python y Go: `pyright`, `ruff`, `gopls`.
- Formatters activos: `ruff_format`, `gofmt`, `prettier`, `kdlfmt`, `shfmt`.
- Autocompletado con `blink.cmp`.
- UI/status: `lualine`, `incline`, `noice`, `smear`, `snacks`, `zen`.
- Navegación/archivos: `oil`.
- Diagnóstico y problemas: `trouble`, `nvim-lint`.
- Ayuda de atajos: `which-key`.
- Comentarios TODO: `todo-comments`.
- Markdown: configuración/plugin específico en `markdown.lua`.
- Syntax/parsing: `treesitter`.
- AI plugins: `copilot`, `copilot-chat`.
- Disabled plugins: `avante`.

### LazyVim

```bash
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
##### first run
nvim
# wait for plugins to install, then quit and reopen nvim

#### for formatter kdl and shfmt
brew install rust
cargo install kdlfmt
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
brew install prettier
brew install shfmt
```

### Only WSL: clipboard hack

No necesario si ya se instal´o para tmux

```bash
mkdir -p ~/.local/bin
curl -Lo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip
unzip /tmp/win32yank.zip -d /tmp/win32yank
mv /tmp/win32yank/win32yank.exe ~/.local/bin/
chmod +x ~/.local/bin/win32yank.exe
```

### Copy nvim config

```bash
ln -s ~/mydotfiles/nvim ~/.config/nvim

```

#### review this file for clipboard configuration

> ~/.config/nvim/lua/config/options.lua

#### review this file for disable random theme

> ~/.config/nvim/init.lua

## Opcionales

Configuración actual:

- herramientas extra que no forman parte del setup base
- `toilet` para banners, `asciicinema` para grabar terminal, `pandoc` para conversion de docs y `chafa` para ver imagenes en terminal

```bash
brew toilet # banner generator
brew asciicinema # record terminal
brew pandoc # conversor docs
brew chafa # terminal image viewer
```
