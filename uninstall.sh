#!/usr/bin/env bash
# Monkey.Dots uninstaller - removes symlinks and (optionally) restores
# the most recent backup.
#
# Usage:
#   ./uninstall.sh                # remove symlinks, restore latest backup
#   ./uninstall.sh --keep-backup  # remove symlinks, leave backups alone
#   ./uninstall.sh --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/symlink.sh
source "$SCRIPT_DIR/lib/symlink.sh"

KEEP_BACKUP=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Monkey.Dots uninstaller

Usage:
  ./uninstall.sh [options]

Options:
  --keep-backup   Don't restore the most recent backup, just remove symlinks
  --dry-run       Show what would happen without changing anything
  -h, --help      Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --keep-backup) KEEP_BACKUP=1 ;;
    --dry-run)     DRY_RUN=1 ;;
    -h|--help)     usage; exit 0 ;;
    *)             log_error "Unknown flag: $arg"; usage; exit 2 ;;
  esac
done

MONKEY_DRY_RUN="$DRY_RUN"
MONKEY_HOME="${HOME:-$(eval echo "~$USER")}"
detect_all

log_step "Removing Monkey.Dots symlinks"
for t in \
  "$MONKEY_HOME/.config/wezterm" \
  "$MONKEY_HOME/.config/tmux/tmux.conf" \
  "$MONKEY_HOME/.config/starship.toml" \
  "$MONKEY_HOME/.zshrc" \
  "$MONKEY_HOME/.p10k.zsh" \
  "$MONKEY_HOME/.gitconfig"; do
  monkey_unlink "$t" "$t"
done

if [[ "$KEEP_BACKUP" == "1" ]]; then
  log_ok "Done. Backups are in ~/.dotfiles-backup/ (left untouched)."
  exit 0
fi

backup_root="$MONKEY_HOME/.dotfiles-backup"
if [[ -d "$backup_root" ]]; then
  latest="$(find "$backup_root" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n1 || true)"
  if [[ -n "$latest" ]]; then
    log_step "Restoring backup: $latest"
    shopt -s dotglob nullglob
    for entry in "$backup_root/$latest"/*; do
      name="$(basename "$entry")"
      dest="$MONKEY_HOME/$name"
      if [[ -L "$dest" || -e "$dest" ]]; then
        [[ "$DRY_RUN" == "1" ]] || rm -rf "$dest"
      fi
      [[ "$DRY_RUN" == "1" ]] || mv "$entry" "$dest"
      log_ok "Restored $name"
    done
    shopt -u dotglob nullglob
    [[ "$DRY_RUN" == "1" ]] || rmdir "$backup_root/$latest" 2>/dev/null || true
  else
    log_info "No prior backups to restore."
  fi
else
  log_info "No backup directory found."
fi

log_ok "Uninstall complete."
