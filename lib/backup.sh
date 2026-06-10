#!/usr/bin/env bash
# lib/backup.sh - Timestamped backup of existing dotfiles
# Sourced by install.sh.
#
# Public:
#   monkey_backup_init
#   monkey_backup_path <target>      -> echoes backup destination
#   monkey_backup_if_exists <target> -> backs up if target is a non-symlink

MONKEY_BACKUP_DIR=""

backup_stamp() {
  date +%Y%m%d-%H%M%S
}

monkey_backup_init() {
  if [[ -n "$MONKEY_BACKUP_DIR" ]]; then
    return
  fi
  MONKEY_BACKUP_DIR="$MONKEY_HOME/.dotfiles-backup/$(backup_stamp)"
  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would create backup dir $MONKEY_BACKUP_DIR"
    return
  fi
  mkdir -p "$MONKEY_BACKUP_DIR"
  log_info "Backup directory: $MONKEY_BACKUP_DIR"
}

# Echoes the destination path (relative to backup dir) for a given target.
monkey_backup_path() {
  local target="$1"
  # Mirror the path under the backup root, stripping any leading $HOME.
  local rel="${target#"$MONKEY_HOME"/}"
  printf '%s/%s' "$MONKEY_BACKUP_DIR" "$rel"
}

# Back up a file/dir if it exists and is not a symlink we created.
# Args: <target path> <label> [force]
monkey_backup_if_exists() {
  local target="$1"
  local label="${2:-$1}"
  local force="${3:-0}"
  # force is accepted for future use (e.g. back up even if pointing into repo).
  : "${force}"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    log_info "Skip: $label does not exist"
    return 0
  fi

  # If it's a symlink that already points inside the repo, nothing to back up.
  if [[ -L "$target" ]]; then
    local link
    link="$(readlink "$target")"
    case "$link" in
      "$MONKEY_REPO"/*)
        log_info "Skip: $label already points into the repo"
        return 0
        ;;
    esac
  fi

  local dest
  dest="$(monkey_backup_path "$target")"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would back up $label -> $dest"
    return 0
  fi

  mkdir -p "$dest_dir"
  # mv handles both files and directories; preserves attributes.
  mv "$target" "$dest"
  log_ok "Backed up $label -> $dest"
}

monkey_backup_summary() {
  if [[ -z "$MONKEY_BACKUP_DIR" || "$MONKEY_DRY_RUN" == "1" ]]; then
    return
  fi
  if [[ -d "$MONKEY_BACKUP_DIR" ]] && \
     [[ -n "$(ls -A "$MONKEY_BACKUP_DIR" 2>/dev/null)" ]]; then
    log_ok "Backups stored in: $MONKEY_BACKUP_DIR"
  else
    log_info "No prior configs to back up (clean install)."
    rmdir "$MONKEY_BACKUP_DIR" 2>/dev/null || true
  fi
}
