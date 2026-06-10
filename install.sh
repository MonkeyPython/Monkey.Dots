#!/usr/bin/env bash
# Monkey.Dots installer
# Creates symlinks for: wezterm, zsh, tmux, starship, git
# Backs up any existing config to ~/.dotfiles-backup/<timestamp>/
#
# Usage:
#   ./install.sh                  # full install (with brew/winget bootstrap)
#   ./install.sh --no-brew        # link configs only, skip package install
#   ./install.sh --dry-run        # show what would happen, do nothing
#   ./install.sh --restore        # restore the most recent backup
#   ./install.sh --help

set -euo pipefail

# --- Resolve script location and load libs ---------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/backup.sh
source "$SCRIPT_DIR/lib/backup.sh"
# shellcheck source=lib/symlink.sh
source "$SCRIPT_DIR/lib/symlink.sh"
# shellcheck source=lib/install_brew.sh
source "$SCRIPT_DIR/lib/install_brew.sh"
# shellcheck source=lib/packages_parser.sh
source "$SCRIPT_DIR/lib/packages_parser.sh"
# shellcheck source=lib/shell.sh
source "$SCRIPT_DIR/lib/shell.sh"
# shellcheck source=lib/install_font.sh
source "$SCRIPT_DIR/lib/install_font.sh"
# shellcheck source=lib/install_omz.sh
source "$SCRIPT_DIR/lib/install_omz.sh"
# shellcheck source=lib/install_tpm.sh
source "$SCRIPT_DIR/lib/install_tpm.sh"
# shellcheck source=lib/install_chsh.sh
source "$SCRIPT_DIR/lib/install_chsh.sh"

# --- Defaults & flags ------------------------------------------------------

MONKEY_DRY_RUN=0
MONKEY_INSTALL_BREW=1
MONKEY_DO_RESTORE=0

usage() {
  cat <<'EOF'
Monkey.Dots installer

Usage:
  ./install.sh [options]

Options:
  --no-brew      Skip Homebrew / winget package installation
                 (only create symlinks for the dotfiles)
  --dry-run      Show what would happen without changing anything
  --restore      Restore the most recent backup from
                 ~/.dotfiles-backup/ and exit
  --uninstall    Remove all Monkey.Dots symlinks
                 (does NOT touch files installed by brew/winget)
  -h, --help     Show this help
EOF
}

require_arg() {
  if [[ $# -lt 2 || -z "${2-}" ]]; then
    log_error "Flag $1 requires an argument"
    exit 2
  fi
}

# --- Arg parsing -----------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-brew)   MONKEY_INSTALL_BREW=0 ;;
    --dry-run)   MONKEY_DRY_RUN=1 ;;
    --restore)   MONKEY_DO_RESTORE=1 ;;
    --uninstall) MONKEY_DO_UNINSTALL=1 ;;
    -h|--help)   usage; exit 0 ;;
    *)           log_error "Unknown flag: $1"; usage; exit 2 ;;
  esac
  shift
done

# --- Banner ----------------------------------------------------------------

print_banner() {
  printf '%s' "$_C_DIM"
  cat <<'EOF'
  __  __             _        _  ___
 |  \/  | ___  _ __ | |_ ___ | |/ _ \
 | |\/| |/ _ \| '_ \| __/ _ \| | | | |
 | |  | | (_) | | | | || (_) | | |_| |
 |_|  |_|\___/|_| |_|\__\___/|_|\___/

EOF
  printf '%s' "$_C_RESET"
}

# --- Restore flow ----------------------------------------------------------

do_restore() {
  local backup_root="$MONKEY_HOME/.dotfiles-backup"
  if [[ ! -d "$backup_root" ]]; then
    log_warn "No backup directory at $backup_root"
    exit 1
  fi
  local latest
  latest="$(find "$backup_root" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n1 || true)"
  if [[ -z "$latest" ]]; then
    log_warn "No backups found in $backup_root"
    exit 1
  fi
  local src="$backup_root/$latest"
  log_step "Restoring from $src"
  # Move everything back over the symlinks/dotfiles, then remove the dir.
  shopt -s dotglob nullglob
  for entry in "$src"/*; do
    local name
    name="$(basename "$entry")"
    local dest="$MONKEY_HOME/$name"
    if [[ -L "$dest" || -e "$dest" ]]; then
      rm -rf "$dest"
    fi
    mv "$entry" "$dest"
    log_ok "Restored $name"
  done
  shopt -u dotglob nullglob
  rmdir "$src" 2>/dev/null || true
  log_ok "Restore complete."
}

# --- Uninstall flow --------------------------------------------------------

do_uninstall() {
  log_step "Removing Monkey.Dots symlinks"
  local targets=(
    "$MONKEY_HOME/.config/wezterm"
    "$MONKEY_HOME/.config/tmux"
    "$MONKEY_HOME/.config/starship.toml"
    "$MONKEY_HOME/.zshrc"
    "$MONKEY_HOME/.p10k.zsh"
    "$MONKEY_HOME/.gitconfig"
  )
  for t in "${targets[@]}"; do
    monkey_unlink "$t" "$t"
  done
  log_ok "Uninstall complete. Backups remain in ~/.dotfiles-backup/."
  exit 0
}

# --- Install plan ----------------------------------------------------------

# Render the repo's tmux/tmux.conf (with placeholder substitution) to
# ~/.config/tmux/tmux.conf. Unlike the other configs, this one is written
# as a real file (not a symlink) because it must reflect the user's
# actual shell path.
install_tmux_conf() {
  local target="$MONKEY_HOME/.config/tmux/tmux.conf"
  local source="$MONKEY_REPO/tmux/tmux.conf"
  local shell_path
  shell_path="$(monkey_resolve_shell)"

  log_info "Default shell for tmux: $shell_path"

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would render $source -> $target"
    return 0
  fi

  # Back up any existing target.
  if [[ -e "$target" || -L "$target" ]]; then
    monkey_backup_if_exists "$target" "tmux config"
  fi

  mkdir -p "$(dirname "$target")"
  if ! monkey_render_tmux_conf "$source" "$shell_path" > "$target"; then
    log_error "Failed to render tmux.conf"
    return 1
  fi
  log_ok "Rendered tmux config -> $target"
}

plan_install() {
  log_step "System summary"
  log_info  "OS:         $MONKEY_OS_NAME"
  log_info  "Homebrew:   $([[ $MONKEY_HAS_BREW == 1 ]] && echo "yes ($MONKEY_BREW_BIN)" || echo "no")"
  log_info  "winget:     $([[ $MONKEY_HAS_WINGET == 1 ]] && echo "yes" || echo "no")"
  log_info  "Oh My Zsh:  $([[ $MONKEY_HAS_OH_MY_ZSH == 1 ]] && echo "yes" || echo "no")"
  log_info  "TPM:        $([[ $MONKEY_HAS_TPM == 1 ]] && echo "yes" || echo "no")"
  log_info  "Repo:       $MONKEY_REPO"

  if [[ "$MONKEY_OS" == "windows" ]]; then
    log_warn "Running on native Windows (Git Bash)."
    log_warn "Some tools are degraded here:"
    log_warn "  - Oh My Zsh / zsh plugins: not installed, .zshrc falls back to starship-only"
    log_warn "  - Tmux: not available; use WezTerm's built-in multiplexer instead"
    log_warn "  - Powerlevel10k: runs but glyphs may not render in all terminals"
    log_warn "Recommended: install WSL (Ubuntu) and run ./install.sh from there."
  fi

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_warn "DRY-RUN mode: no changes will be made"
  fi

  monkey_backup_init

  log_step "Creating symlinks"

  # ~/.config/wezterm -> <repo>/wezterm  (whole dir, contains wezterm.lua)
  monkey_link "wezterm"      "$MONKEY_HOME/.config/wezterm"      "wezterm config"

  # ~/.config/tmux/tmux.conf
  # NOTE: unlike the other targets, this one is *rendered*, not symlinked.
  # The repo's tmux.conf has a # MONKEY_DEFAULT_SHELL placeholder that we
  # substitute with the user's actual shell path. To re-render, just
  # re-run ./install.sh.
  install_tmux_conf

  # ~/.config/starship.toml
  monkey_link "starship/starship.toml" "$MONKEY_HOME/.config/starship.toml" "starship config"

  # Home dotfiles
  monkey_link "zsh/.zshrc"    "$MONKEY_HOME/.zshrc"    "zshrc"
  monkey_link "zsh/.p10k.zsh" "$MONKEY_HOME/.p10k.zsh" "p10k config"
  monkey_link "git/.gitconfig" "$MONKEY_HOME/.gitconfig" "gitconfig"

  monkey_backup_summary
}

# --- Main ------------------------------------------------------------------

print_banner

detect_all

if [[ "${MONKEY_DO_RESTORE:-0}" == "1" ]]; then
  do_restore
  exit 0
fi

if [[ "${MONKEY_DO_UNINSTALL:-0}" == "1" ]]; then
  do_uninstall
fi

if [[ "$MONKEY_INSTALL_BREW" == "1" ]]; then
  install_recommended_stack
fi

# Oh My Zsh bootstrap. Needs zsh on PATH (from brew above) but is
# idempotent: if ~/.oh-my-zsh already exists, it's skipped. Skipped
# entirely on Windows-native where it would break the .zshrc.
monkey_install_oh_my_zsh

# Font install is independent of brew: we always try to get Iosevka Term
# Nerd Font, because every other config (wezterm, starship, tmux theme)
# assumes it. This call is idempotent and respects $MONKEY_DRY_RUN.
monkey_install_iosevka

plan_install

log_step "Done"

# TPM bootstrap runs AFTER the tmux.conf is rendered, because the
# headless plugin install sources it. Idempotent and OS-aware.
monkey_install_tpm

# Final UX nudge: if the user's login shell isn't zsh, print the
# chsh command they need to run. We don't do it ourselves (sudo +
# re-login = user decision).
monkey_offer_set_default_shell

log_ok "Restart your terminal (or run: exec zsh) to load the new config."

if [[ "$MONKEY_HAS_TPM" != "1" ]]; then
  log_info "Tmux: prefix + I  (capital I) to install TPM plugins on first run."
fi
