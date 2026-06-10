# Monkey.Dots — AI Agent Notes

> Conventions for AI assistants (Claude Code, OpenCode, etc.) working
> in this repository.

## What this repo is

A trimmed-down personal fork of [Gentleman.Dots](https://github.com/Gentleman-Programming/Gentleman.Dots),
adapted for one developer across macOS, Linux, WSL, and Windows-native.

Scope: **terminals, shell, multiplexer, prompt, git**. Nothing else.
No Neovim, no TUI installer, no Vim Trainer.

## Quick reference

| Task | Where |
|------|-------|
| Add a new symlink target | `install.sh` (`plan_install`) + the file under the matching dir |
| Add a new package to install | `lib/install_brew.sh` (`install_recommended_stack`) |
| Change the palette | `wezterm/wezterm.lua` (ANSI table) + `starship/starship.toml` (`[palettes.monkey]`) |
| Add a new OS / platform | `lib/detect.sh` (`detect_os`) + `lib/install_brew.sh` |
| Tweak tmux config | `tmux/tmux.conf` (mirrored from upstream) + `lib/shell.sh` (renders placeholder) |
| Bump Iosevka Nerd Font version | `lib/install_font.sh` (`FONT_FALLBACK_VERSION`, `install_via_download`) |
| Change Oh My Zsh install behaviour | `lib/install_omz.sh` (`omz_run_install`, `omz_target_dir`) |
| Change TPM bootstrap behaviour | `lib/install_tpm.sh` (`tpm_clone`, `tpm_install_plugins_headless`) |
| Add/remove/bump a brew/winget package | `lib/packages.toml` (`[macos]`, `[linux]`, `[windows]`) |
| Add an alias / env var | `zsh/.zshrc` (mirror the existing detection blocks) |
| Add a test | `tests/install_smoke.sh` (assert helpers: `assert_symlink`, `assert_file_content`) |

## Style rules

- **Bash**: `set -euo pipefail` at the top of every script. Shebang on
  every file in `lib/` even if it's only sourced. Quote everything.
  Use `[[ ]]` not `[ ]`. Prefer `printf '%s\n'` over `echo`.
- **Logging**: never `echo` raw. Use `log_info` / `log_ok` / `log_warn` /
  `log_error` / `log_step` from `lib/log.sh`. Errors go to stderr.
- **Idempotency**: every mutating function must be safe to call twice.
  `monkey_link` checks the existing symlink target before clobbering.
- **Dry-run**: every destructive action must respect `$MONKEY_DRY_RUN`.
  Show what would happen, do nothing.
- **Backups**: anything about to be overwritten goes through
  `monkey_backup_if_exists`. Never `rm -rf` a regular file.
- **Cross-file globals**: variables starting with `MONKEY_` are part of
  the public API between scripts. Don't rename without grepping all
  callers. `shellcheck disable=SC2034` is allowed and expected on
  these because shellcheck can't see across `source` boundaries.

## Palette: keep in sync

The "monkey" palette is duplicated in:

- `wezterm/wezterm.lua` — `config.colors.ansi` and `.brights`
- `starship/starship.toml` — `[palettes.monkey]`

If you change one, change the other. The README documents which two
accents are intentionally different from upstream; keep the rest
byte-for-byte identical to Gentleman so future ports are easy.

## Verification

Run before committing:

```bash
bash -n install.sh uninstall.sh lib/*.sh tests/*.sh
shellcheck install.sh uninstall.sh lib/*.sh tests/*.sh
bash tests/install_smoke.sh
```

All three must pass. The smoke test creates a temp `$HOME` and runs the
real installer against it — if you add a symlink target, add a matching
assertion.

## Platform priorities

1. **macOS** — primary development host, most-tested.
2. **WSL (Ubuntu)** — primary Windows path. Treat WSL almost like
   native Linux; the installer auto-detects `/proc/version` markers.
3. **Linux (Fedora, Arch, etc.)** — Linuxbrew handles all of them
   uniformly; distro-specific code is anti-goal.
4. **Windows-native (Git Bash)** — degraded. winget installs only the
   tools that have packages; the bash scripts themselves work under
   Git Bash.
5. **Termux** — detected, not supported. Detection stays so the
   `.zshrc` doesn't break for anyone copy-pasting parts of it.

## What NOT to add

These are deliberate omissions from upstream; if you "improve" them
you're adding scope creep:

- TUI installer (Go + Bubbletea)
- Vim Trainer RPG / gamification
- Kitty / Alacritty / Ghostty configs (WezTerm only)
- Fish / Nushell configs (Zsh only)
- Zellij configs (Tmux only)
- LazyVim / Neovim config
- GitHub Actions / Docker CI / release binaries
