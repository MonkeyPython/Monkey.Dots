# Monkey.Dots

> Personal dotfiles for **always-configured terminals**, adapted from
> [Gentleman.Dots](https://github.com/Gentleman-Programming/Gentleman.Dots) and trimmed down to what I actually use.

📄 Read this in: **English** | [Español](README.es.md)

## What gets installed

Beyond linking the configs, the installer also:

- Installs the **Iosevka Term Nerd Font** system-wide (Homebrew cask on
  macOS, direct download from Nerd Fonts GitHub releases on Linux/WSL,
  Homebrew cask on Windows-native). Idempotent — if it's already
  present, it's skipped.
- Installs the **Homebrew packages / winget IDs** listed in
  `lib/install_brew.sh` (`install_recommended_stack`). On macOS, Linux
  and WSL, Homebrew is used. On Windows-native, winget is the fallback.
- Bootstraps **Oh My Zsh** by downloading the official install script
  and running it with `--unattended --keep-zshrc` (so it doesn't
  overwrite the `.zshrc` we ship). Idempotent — if `~/.oh-my-zsh`
  already exists, it's skipped. Skipped on Windows-native where OMZ
  is fragile. The bundled `.zshrc` has a guard so it works even if
  OMZ is absent.
- Bootstraps **TPM** (Tmux Plugin Manager) by `git clone`ing it into
  `~/.tmux/plugins/tpm`, then runs `tpm install_plugins` headlessly in
  a one-shot detached tmux session that sources the rendered
  `tmux.conf`. This is best-effort: on failure, fall back to opening
  tmux and pressing `prefix + I` manually. Idempotent. Skipped on
  Windows-native (no native tmux).
- Detects the **shell** via `lib/shell.sh` and renders
  `tmux/tmux.conf` so that `default-command` / `default-shell` point at
  the user's actual shell.

All of the above respect `MONKEY_DRY_RUN` (set via `--dry-run`) and
are safe to re-run.

## What is this?

A minimal, opinionated dotfiles manager that gives you the same terminal,
shell and multiplexer setup across **macOS, Linux and Windows (WSL + native)**.

- **Terminal**: [WezTerm](https://wezterm.org) (GPU-accelerated, Lua config, single binary on every platform)
- **Shell**: Zsh + [Oh My Zsh](https://ohmyz.sh) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Multiplexer**: Tmux with TPM, Kanagawa theme, vim-tmux-navigator
- **Prompt**: [Starship](https://starship.rs) (precedence over p10k, both work)
- **Extras**: fzf, zoxide, atuin, carapace, bat, fd, eza, lazygit, neovim
- **Git**: aliases, delta pager, autoSetupRemote, sensible defaults

No TUI installer, no Vim Trainer RPG, no Neovim LazyVim. Just the pieces
that make every terminal feel like home.

## The "monkey" palette

Forked from Gentleman's palette. The structure is identical so the
configs look and feel like his — two accents nudged to make it mine:

| Token  | Gentleman | Monkey | Why |
|--------|-----------|--------|-----|
| yellow | `#FFE066` (mustard) | `#F5A524` (amber) | warmer, more saturated |
| mauve  | `#A3B5D6` (lavender) | `#C792EA` (violet) | deeper, more recognisable |

Everything else (background, foreground, ANSI 0–7, selection, etc.)
is byte-for-byte the same.

## Quick Start

```bash
git clone https://github.com/<you>/Monkey.Dots.git ~/.dotfiles
cd ~/.dotfiles
./install.sh            # full install (installs brew packages + links configs)
```

Then restart your terminal (or `exec zsh`) and press `prefix + I` inside
tmux to install TPM plugins.

## Flags

```bash
./install.sh --no-brew   # link configs only, skip Homebrew/winget
./install.sh --dry-run   # show what would happen, do nothing
./install.sh --restore   # restore the most recent backup
./uninstall.sh           # remove all symlinks, restore latest backup
./uninstall.sh --keep-backup  # remove symlinks, leave backups alone
```

## What gets linked

| Repo path            | Destination                                | How |
|----------------------|--------------------------------------------|-----|
| `wezterm/`           | `~/.config/wezterm`                        | symlink (whole dir) |
| `tmux/tmux.conf`     | `~/.config/tmux/tmux.conf`                 | **rendered** (substitutes `MONKEY_DEFAULT_SHELL` with your real shell path) |
| `starship/starship.toml` | `~/.config/starship.toml`              | symlink |
| `zsh/.zshrc`         | `~/.zshrc`                                 | symlink |
| `zsh/.p10k.zsh`      | `~/.p10k.zsh`                              | symlink |
| `git/.gitconfig`     | `~/.gitconfig`                             | symlink |

`tmux.conf` is the only target that's **rendered** (not symlinked), so
that the installer's shell-detection result (`$SHELL` → brew `zsh` →
`bash` → `/bin/sh`) ends up in your `default-command` / `default-shell`
directives. Re-running `./install.sh` re-renders it with the current
shell. To change the shell: edit your environment, then re-run.

Any pre-existing file at those paths is backed up to
`~/.dotfiles-backup/<timestamp>/...` first.

## Supported platforms

| Platform           | Package manager  | Notes |
|--------------------|------------------|-------|
| macOS (Apple Silicon / Intel) | Homebrew | Native |
| Linux (Ubuntu, Debian, Fedora, Arch…) | Homebrew (Linuxbrew) | One Brew, same commands |
| Windows — WSL (Ubuntu) | Homebrew (Linuxbrew) | **Recommended for Windows** |
| Windows — native (Git Bash) | winget fallback | WezTerm + oh-my-posh only; some themes may not apply |
| Termux (Android)   | pkg | Detected, no auto-install (left for parity) |

### Windows native (Git Bash) — caveats

Running the installer under **Git Bash on Windows** works, but a few
pieces of the stack are degraded compared to macOS / Linux / WSL.
The installer prints these warnings on startup; this is the long version.

| Tool | Status | What to do |
|------|--------|------------|
| **WezTerm** | ✅ Works | Installed via `winget install wez.wezterm`. Reads `wezterm.lua` normally. |
| **Starship** | ✅ Works | `~/.config/starship.toml` linked, runs in any shell. |
| **fzf, zoxide, bat, fd, eza, lazygit** | ✅ Work | All available via winget. |
| **neovim** | ✅ Works | `winget install Neovim.Neovim`. |
| **Oh My Zsh + zsh plugins** | ⚠️ Degraded | Zsh exists on Windows but Oh My Zsh is fragile. The `.zshrc` detects it and falls back to starship-only if missing. |
| **Powerlevel10k** | ⚠️ Partial | Runs, but glyphs may not render in WezTerm without Iosevka Nerd Font installed system-wide. Configure p10k with WezTerm, not Windows Terminal. |
| **Tmux** | ❌ Not installed | No native Windows tmux. Use WezTerm's built-in multiplexer (tabs + panes). The `tmux/tmux.conf` symlink is created but unused. |
| **carapace completions** | ⚠️ Partial | Runs but completion files land in `~/.config/fish/completions` (a path Git Bash can create but Windows tools may not read). |
| **atuin** | ⚠️ Partial | Local search works, sync server needs extra setup. |
| **Git identity** | ✅ You set it | `git config --global user.name` / `user.email`. |

**Recommendation:** if you find yourself fighting Git Bash quirks,
install [WSL (Ubuntu)](https://learn.microsoft.com/en-us/windows/wsl/install)
and re-run `./install.sh` from there. The same repo, the same configs,
zero caveats.

## After install

1. **Tmux plugins**: the installer clones TPM and runs `install_plugins`
   headlessly. If that step fails (e.g. tmux can't fork in your
   environment), open tmux and press `prefix + I` (capital I) — TPM
   will clone Kanagawa, vim-tmux-navigator, tmux-resurrect, etc.
2. **Oh My Zsh**: installer will offer to install it if missing. Without
   it, the `.zshrc` falls back gracefully (no autosuggestions / syntax
   highlighting, but starship and fzf still work).
3. **Powerlevel10k**: run `p10k configure` the first time to generate
   the config that matches your terminal width. The bundled `.p10k.zsh`
   is a sane default if you skip that step.
4. **Git identity**: the bundled `.gitconfig` does **not** set your
   name/email on purpose. Set them globally:
   ```bash
   git config --global user.name  "Your Name"
   git config --global user.email "you@example.com"
   ```

## Verifying the installer

```bash
shellcheck install.sh uninstall.sh lib/*.sh tests/*.sh
bash tests/install_smoke.sh
```

The smoke test creates an isolated `$HOME`, runs install/uninstall, and
verifies that symlinks, backups and idempotency all work as expected.

## Repository layout

```
Monkey.Dots/
├── install.sh             # main installer (idempotent, with backup)
├── uninstall.sh           # remove symlinks, restore backup
├── lib/                   # small bash modules
│   ├── detect.sh          # OS / WSL / brew / winget detection
│   ├── backup.sh          # timestamped backups
│   ├── symlink.sh         # idempotent linking
│   ├── install_brew.sh    # best-effort package install
│   └── log.sh             # colored log helpers
├── wezterm/wezterm.lua    # terminal config
├── zsh/.zshrc             # shell config
├── zsh/.p10k.zsh          # p10k fallback
├── tmux/tmux.conf         # multiplexer config
├── starship/starship.toml # prompt
├── git/.gitconfig         # git aliases & defaults
└── tests/install_smoke.sh # end-to-end smoke test
```

## License

MIT. Do whatever, attribution appreciated.
