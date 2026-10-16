# mydotfiles

Dotfiles para macOS (Ghostty) y WSL (WezTerm): zsh, tmux, zellij y Neovim (LazyVim).

## Instalación

```bash
git clone <url-del-repo> ~/mydotfiles
cd ~/mydotfiles
./install.sh
```

`install.sh` instala Homebrew y [gum](https://github.com/charmbracelet/gum) si faltan y abre una TUI que va por pasos. En cada opción se muestra si ya está instalada:

1. **Sistema operativo:** mac, linux o wsl (por defecto, el detectado)
2. **Terminal:** ghostty (por defecto en mac), wezterm (por defecto en linux/wsl; también disponible en mac) o ninguno
3. **Intérprete:** zsh
4. **Prompt:** powerlevel10k
5. **Multiplexor:** tmux (por defecto), zellij, ambos o ninguno
6. **Paquetes** (selección múltiple): font, git y nvim vienen marcados; go y opencode no
7. **Herramientas CLI** (selección múltiple, con una descripción de cada una): las de siempre vienen marcadas y las opcionales no (ver tabla abajo)
8. **Neovim** (si está marcado): `repo` (por defecto) o `limpia`

En las listas de selección múltiple se marca con **espacio** o **x**, `a` marca o desmarca todo, enter confirma y esc sale.

Se puede ejecutar tantas veces como quieras porque solo aplica lo que falta:

- Los paquetes se instalan con `brew bundle --no-upgrade` (`install/brew/*.Brewfile`), así que no se actualiza lo que ya tienes.
- Las configs se enlazan con symlinks. Si ya existe algo en esa ruta, se mueve a `<ruta>.backup-<fecha>` tras confirmar; nunca se borra nada.
- `~/.zshrc` y `~/.gitconfig` no se sobrescriben: solo se añade lo que falta.
- Cada ejecución deja un log en `~/.cache/mydotfiles/install-<fecha>.log` (se guardan los 20 últimos) con los comandos ejecutados, sus errores y el resultado de cada módulo.
- Los plugins de tmux solo se clonan si no existen, y los de nvim se instalan en las versiones de `lazy-lock.json` sin modificarlo.

```bash
./install.sh                  # TUI
./install.sh --status         # estado de cada módulo
./install.sh --dry-run        # muestra lo que haría sin tocar nada
./install.sh --all            # opciones por defecto, sin TUI
./install.sh --os linux --all # forzar el SO destino
./install.sh zsh nvim         # solo esos módulos
./install.sh --nvim limpia nvim # LazyVim starter en vez de la config del repo
./install.sh --tools eza,bat,croc tools  # herramientas CLI concretas
./install.sh -y ...           # sin confirmaciones
```

| Módulo | Plataforma | Por defecto | Qué hace |
|---|---|---|---|
| `font` | mac, linux | sí | Inconsolata Nerd Font |
| `git` | todas | sí | git + git-lfs, incluye `git/config` desde `~/.gitconfig`, pide nombre y email (`user.name`/`user.email` globales) |
| `tools` | todas | sí | herramientas CLI elegidas una a una (ver abajo) |
| `zsh` | todas | sí | zsh y plugins, `~/.zshrc` que carga el repo, migración del layout antiguo, import de atuin, shell por defecto |
| `p10k` | todas | sí | powerlevel10k (la config está en `zsh/.p10k.zsh`) |
| `tmux` | todas | sí | tmux, `~/.config/tmux` + `~/.tmux.conf`, TPM y plugins, win32yank en WSL |
| `zellij` | todas | no | zellij, `~/.config/zellij` |
| `nvim` | todas | sí | neovim + formatters, kdlfmt (cargo), `~/.config/nvim` (variante `repo` o `limpia`), plugins, win32yank en WSL |
| `go` | todas | no | Go toolchain |
| `ghostty` | mac | sí | Ghostty, `~/.config/ghostty` |
| `wezterm` | todas | linux, wsl | mac: cask + `~/.wezterm.lua`; linux: `~/.wezterm.lua`; wsl: copia al home de Windows y winget |
| `opencode` | todas | no | opencode, `~/.config/opencode` |

**Herramientas CLI** (`install/modules/tools.sh`):

| Herramienta | Por defecto | Para qué sirve |
|---|---|---|
| `eza` | sí | `ls` moderno con iconos y vista de árbol (`ls`, `ll`, `la`, `lt`) |
| `bat` | sí | `cat` con resaltado de sintaxis |
| `fzf` | sí | buscador difuso interactivo (`cdf`, `ff`, `fg`, `fkill`) |
| `fd` | sí | `find` rápido y simple |
| `ripgrep` | sí | `grep` muy rápido que respeta `.gitignore` |
| `zoxide` | sí | `cd` que recuerda tus carpetas (`z carpeta`) |
| `atuin` | sí | historial de comandos con búsqueda (`Ctrl-R`) |
| `btop` | sí | monitor de CPU, RAM, disco y procesos |
| `mole` | no (solo mac) | limpieza y optimización del Mac |
| `hazelnut` | no | organizador automático de ficheros |
| `croc` | no | envía ficheros entre equipos con un código |
| `toilet` | no | banners de texto grandes en la terminal |
| `asciinema` | no | graba sesiones de terminal |
| `pandoc` | no | conversor de documentos (md, docx, pdf, html) |
| `chafa` | no | muestra imágenes en la terminal |

Los aliases y funciones de zsh usan eza, bat, fzf, fd, ripgrep, zoxide y atuin: si desmarcas alguna que no esté instalada, el instalador avisa.

En Linux/WSL hace falta antes: `sudo apt install -y build-essential git curl unzip`.

### Notas

- **Fuente:** configura `Inconsolata Nerd Font` en el terminal. En WSL hay que instalarla en Windows, no dentro de WSL.
- **zsh:** `~/.zshrc` es un fichero de cada máquina, no un enlace. Su primera línea carga la config del repo (`zsh/zshrc`, que carga `zsh/conf.d/*.zsh` por orden). Lo que añadan otros instaladores (mise, factorial-dev…) queda debajo y se ejecuta después, sin tocar el repo. Lo de una sola máquina (alias, `source ~/.factorialrc`…) va también ahí. `zsh-autosuggestions` y `zsh-syntax-highlighting` se cargan en el primer prompt, así que siempre quedan los últimos aunque haya cosas debajo.
  - Si ya existía un `~/.zshrc` normal, su contenido se conserva debajo de la línea del repo (con backup previo).
  - **Migración del layout antiguo** (`ZDOTDIR` → `~/.config/zsh`): el instalador quita la línea de `ZDOTDIR` de `~/.zshenv`, convierte en ficheros normales los `~/.zshenv`/`~/.zprofile` que eran enlaces, añade el historial que vivía en el repo a `~/.zsh_history` y mueve los restos (oh-my-zsh, zcompdump…) a `~/.local/state/mydotfiles/zsh-legacy-<fecha>/`. Todo con backup.
  - Las terminales y el servidor de tmux que ya estuvieran abiertos conservan el `ZDOTDIR` antiguo hasta que los cierres.
- **kdlfmt:** se instala en `~/.cargo/bin`, que debe estar en el `PATH` para que conform lo encuentre.
- **git:** pide nombre y email precargados con los valores actuales (Enter los mantiene) y los guarda como `user.name`/`user.email` globales de ese ordenador, en `~/.gitconfig`. Con `--yes` no pregunta. `~/.gitconfig` incluye `git/config` con `[include]`. El include se añade al final, de modo que sus valores tienen prioridad, y el instalador avisa de qué claves cambian. `credential.helper = store` guarda las credenciales en texto plano en `~/.git-credentials`.
- **wezterm:** `.wezterm.lua` fija `default_domain = "WSL:Ubuntu"`, un dominio que fuera de Windows no existe.
- **zellij:** los plugins no funcionan con rutas relativas y los layouts tienen `/home/david` escrito a mano. El instalador ofrece reescribirlos a tu `$HOME` (opt-in, porque modifica ficheros del repo).
- **nvim:** hay dos variantes y se puede cambiar de una a otra volviendo a ejecutar el instalador:
  - `repo` (por defecto): enlaza la config del repo e instala los plugins en las versiones de `lazy-lock.json`. Para volver a sincronizarlos: `:Lazy restore`.
  - `limpia`: el LazyVim starter, sin personalizar.

  Al cambiar de variante (o si había otra config) se mueven a `*.backup-<fecha>` tanto `~/.config/nvim` como los datos de nvim (`~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`), para que la variante nueva arranque desde cero. La TUI siempre propone `repo`, así que quien haya probado la limpia vuelve a la del repo con solo reejecutar.

## Configuración actual

### Shell

- zsh con prompt `powerlevel10k` lean de 2 lineas con iconos nerd font
- `atuin` para historial y `zoxide` para navegación rápida
- `zsh-autosuggestions` y `zsh-syntax-highlighting`
- aliases: `ls`/`ll`/`la`/`lt` con `eza`, `cat` con `bat`, `find` con `fd`, `grep` con `rg`
- helpers con `fzf`: `cdf`, `ff`, `fg`, `fkill`, `glc`
- arranque automatico de `zellij` con layout aleatorio (theme everfores, sakura y kanagawa). Se puede modificar en: `zsh/conf.d/60-functions.zsh` (función `zj`)
- soporte WSL para `win32yank` via `~/.local/bin`

### Git

- config global en `git/config`: aliases (`st`, `ci`, `br`, `co`, `df`, `lol`, `lola`, `af`...), colores, `less -FXRS` como pager, `vim` como editor, git-lfs

### Tmux (Recomendado)

- barra superior de estado personalizada
- se inicia con theme random-theme, configurable en mydotfiles/tmux/theme/random-theme.sh
- alias creado con tdev, con dos pestañas shell y workspace, esta última dividida en panes
- plugins: tpm, tmux-sensible, tmux-yank, vim-tmux-navigator, tmux-resurrect, tmux-which-key
- en WSL usa win32yank (también se usara en NeoVim)

### Zellij (Opcional)

- tema base `kanagawa` con `simplified_ui` activo y sin `pane_frames` por defecto
- layouts custom con barra superior `zjstatus` y barra inferior nativa
- pestañas listas para `shell`, `workspace`
- plugin `zellij_forgot` disponible con atajos de búsqueda

Solo en caso de tener problemas con los plugins:

```bash
# descarga de nuevo si crees que están corruptos
curl -L -o ~/.config/zellij/plugins/zellij_forgot.wasm https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm
curl -L -o ~/.config/zellij/plugins/zjstatus.wasm https://github.com/dj95/zjstatus/releases/download/v0.23.0/zjstatus.wasm

# borra cache y pide permisos otra vez explicitos
rm -rf ~/.cache/zellij
zellij
zellij plugin -- "file:$HOME/.config/zellij/plugins/zjstatus.wasm"
```

### Nvim

- Base `LazyVim`.
- Tema aleatorio entre `kanagawa`, `tokyonight-night` y `everforest`, configurable en `~/.config/nvim/init.lua`. En `lua/plugins/colors.lua` para instalar nuevos themes.
- Clipboard del sistema activo con `unnamedplus` (configuración en `lua/config/options.lua`).
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
- AI plugins: `copilot` (extra de LazyVim), `codecompanion`.
- Disabled plugins (`lua/disabled-plugins/`): `avante`, `copilot-chat`, `copilot.lua`.

### Herramientas opcionales

- `mole`, `hazelnut`, `croc`, `toilet`, `asciinema`, `pandoc` y `chafa`: se eligen en el paso "Herramientas CLI" del instalador (ver la tabla de herramientas)
