# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles for macOS (Ghostty) and Linux/WSL (WezTerm). There is no build, test, or lint pipeline. Each top-level directory is **symlinked** into `~/.config/` by `install.sh`, so editing a file here changes the live config. `README.md` (in Spanish) documents the installer and the record of which tools and plugins are in use. Keep its module table and "Configuración actual" sections in sync when you add or remove tools/plugins.

**Don't modify the tool configs** (nvim, tmux, zsh, zellij, ghostty, wezterm) unless the owner explicitly asks. The owner considers them final. Work on the install process. If a config quirk affects installation, handle it in the installer (opt-in) or report it.

| Dir | Symlinked to | Notes |
|---|---|---|
| `zsh/zshrc` | sourced from the first line of `~/.zshrc` | loads `zsh/conf.d/*.zsh` in order; `.p10k.zsh` sits next to it |
| `nvim/` | `~/.config/nvim` | LazyVim-based |
| `tmux/` | `~/.config/tmux` + `~/.tmux.conf` | primary multiplexer |
| `zellij/` | `~/.config/zellij` | optional multiplexer |
| `ghostty/` | `~/.config/ghostty` | macOS terminal + GLSL shaders |
| `.wezterm.lua` | `~/.wezterm.lua` (on WSL, copied to the Windows user dir) | |
| `git/config` | included from `~/.gitconfig` (`include.path`) | global git config; identity stays in `~/.gitconfig` |
| `opencode/` | opencode agent config | `AGENTS.md`/skills/prompts here are for opencode, **not** instructions for working in this repo |

**zsh layout.** `~/.zshrc` is a regular file that belongs to each machine. Its first line sources `zsh/zshrc` from the repo, and whatever other installers append (mise, factorial-dev…) goes below it, outside the repo. Don't move machine-specific things into the repo. `90-plugins.zsh` defers autosuggestions and syntax-highlighting to the first `precmd`, so they load after everything in `~/.zshrc`. The old layout, with `zsh/` symlinked as `ZDOTDIR`, made other installers write into the repo; `install/modules/zsh.sh` migrates it. Don't commit `*.backup-*` files.

## Installer

`install.sh` is an idempotent installer with a TUI built on bash and [gum](https://github.com/charmbracelet/gum):

```bash
./install.sh --status            # per-module state: instalado / parcial / pendiente / conflicto
./install.sh --dry-run --all     # preview without changing anything
./install.sh -y zsh nvim         # run specific modules non-interactively
```

- It must stay **bash 3.2 compatible** because it runs on macOS `/bin/bash`, which rules out associative arrays, `${x,,}` and `mapfile`. Check syntax with `/bin/bash -n`.
- `install/lib.sh` holds the shared idempotent helpers: `link` (backs up conflicts to `*.backup-<ts>`, never deletes), `ensure_line`, `git_clone`, `brew_bundle` (`--no-upgrade`), and `run`/`confirm`, which respect `DRY_RUN`/`ASSUME_YES`.
- The TUI goes in steps: OS, then one choice each for terminal, shell, prompt and multiplexer, then multi-selects for packages and CLI tools, then the nvim variant. Single choices use `gum choose`. Multi-selects use `choose_many` in `lib.sh`, a bash widget, because gum 2 only toggles with x/tab and the owner wants space too. The lists live in the `TERMINALS`/`SHELLS`/`PROMPTS`/`MULTIPLEXERS`/`PACKAGES` variables in `install.sh`, and an `a+b` option installs both. `os_kind` returns the chosen `TARGET_OS` (`--os`), and `detect_os` returns the real one. Module descriptions must not contain commas, because gum's `--selected` splits on them.
- `install/modules/<name>.sh` defines `<name>_desc`, `_supported` (OS filter), `_default` (preselected in the TUI), `_status` and `_install`. Register a new module in `MODULES` in `install.sh`. Every module runs in a `set -e` subshell, so a failing command aborts that module only.
- Packages for each module go in `install/brew/<name>.Brewfile`. The exception is CLI tools: they live in `TOOLS_CATALOG` in `install/modules/tools.sh` (`id|formula|os|default|description`), are chosen one by one (`--tools a,b`), and `tools` runs before `zsh` (zsh imports history with atuin).
- To test the TUI without a human, drive it in an isolated tmux server: `tmux -L tuitest -f /dev/null new-session -d "./install.sh --dry-run"`, then `send-keys` and `capture-pane -p`. `script` doesn't work, because gum waits for terminal query replies.
- Every run that installs something writes a plain-text log to `~/.cache/mydotfiles/install-<ts>.log` (the last 20 are kept), via `log_*` and `run()`. Output isn't redirected wholesale, because gum needs the TTY.
- nvim has two variants (`--nvim repo|limpia`, asked in the TUI with `repo` preselected). Switching variants backs up the config and nvim's data/state/cache dirs.
- opencode has the same two variants (`--opencode repo|limpia`, asked in the TUI after nvim). `limpia` is an empty `~/.config/opencode` with a marker file. Switching backs up only the config, not opencode's data (login, sessions). opencode writes `cli.json`/`service.json` (secrets) into its config dir, which is the repo under the `repo` variant, so they're gitignored.
- Avoid `grep -q` at the end of pipelines: with `pipefail`, the producer gets SIGPIPE and the pipeline fails even on a match. Use `grep ... >/dev/null` or `case`.
- To test real installs, run against a throwaway `HOME`: `env -u XDG_CONFIG_HOME HOME=/tmp/x ./install.sh -y <module>`. The symlinks still point into this repo, so check `git status` afterwards. lazy.nvim rewrites `nvim/lazy-lock.json` on first install, and the nvim module saves and restores that file to protect it.

## Reloading / verifying changes

- zsh: `exec zsh` to reload; `for f in zsh/zshrc zsh/conf.d/*.zsh; do zsh -n $f; done` to check syntax. Measure startup with `time zsh -lic exit` (about 0.26s); `zsh -lixc exit` traces it, and `zsh/zshrc` should load exactly once.
- tmux: `prefix R` reloads `~/.tmux.conf`; `prefix r` picks a random theme.
- nvim: restart; `:Lazy` for plugin state. Lua is formatted with stylua (2 spaces, 120 cols, see `nvim/stylua.toml`).
- Shell scripts: format with `shfmt`. KDL (zellij): `kdlfmt`.

## Architecture notes

**Random theming in every layer.** Each tool picks a random theme at startup, and the theme names line up across tools (kanagawa, everforest, sakura, tokyonight):
- nvim: `nvim/init.lua` holds the `my_themes` list. Colorscheme plugins are installed in `lua/plugins/colors.lua`.
- tmux: `tmux.conf` runs `themes/random-theme.sh`, which sources one `themes/*.conf`. Theme files only set `@theme_*` user options (colors). `tmux.conf` builds the status bar from them through `#{E:@theme_...}`. A new theme must define the same set of `@theme_*` variables. Add it to `random-theme.sh` and to the theme menu in `tmux.conf`.
- zellij: the `zj` function in `zsh/conf.d/60-functions.zsh` picks a random file from `zellij/layouts/`. Each layout embeds its own `zjstatus` colors.

**Status bar scripts.** `tmux/scripts/` and `zellij/scripts/` (`cpu.sh`, `ram.sh`, `battery.sh`) are near-duplicates. When you change one, check the other.

**Zellij plugin paths are absolute.** Layouts reference `file:/home/david/.config/zellij/plugins/*.wasm`. Relative paths don't work, and the README has a `sed` command to rewrite the username.

**nvim plugin layout.** `lua/config/lazy.lua` imports LazyVim extras, then `{ import = "plugins" }`. Each file in `lua/plugins/` returns one plugin spec, with a header comment giving the plugin name, URL, and description. `lua/disabled-plugins/` isn't imported. To disable a plugin, move its spec file there (avante, copilot-chat, and copilot.lua are there now). The active AI chat is `codecompanion-chat.lua`, with prompts and behaviour in `lua/config/ai-*.lua`. Copilot completion still comes from the LazyVim `ai.copilot` extra in `lazy.lua`. Clipboard handling, including WSL `win32yank`, is in `lua/config/clipboard.lua` / `options.lua`.

**zsh ordering constraint.** `zsh-syntax-highlighting` must load last. That's why it is deferred to the first prompt: keep it in `90-plugins.zsh`, not inline. Tools in `40-tools.zsh` are guarded with `(( $+commands[x] ))`. Homebrew is detected for both macOS (`/opt/homebrew`) and Linux (`/home/linuxbrew`). WSL- and Linux-specific blocks are guarded by `/proc/version` / `$OSTYPE` checks. Keep new platform-specific code behind the same kind of check.

**Comments and docs are in Spanish.** Match that in README and config comments.

**Commits.** Never add `Co-Authored-By` or any AI attribution to commit messages or PRs. The commit identity for this repo is David Barreiro <davidi.b23@gmail.com>, set in the repo-local git config. Don't use the global (work) identity.
