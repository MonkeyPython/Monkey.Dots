#!/usr/bin/env bash
# lib/symlink.sh - Idempotent symlink creation
# Sourced by install.sh.
#
# Public:
#   monkey_link <source> <target> <label>

# Internal: create parent directory for a target.
_link_ensure_parent() {
  local target="$1"
  local parent
  parent="$(dirname "$target")"
  if [[ ! -d "$parent" ]]; then
    if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
      log_info "DRY-RUN: would mkdir -p $parent"
    else
      mkdir -p "$parent"
    fi
  fi
}

# Link a single file/dir from $MONKEY_REPO/<source> to $MONKEY_HOME/<target>.
# Backs up the target first if it exists and is not already a link to the repo.
monkey_link() {
  local source="$1"
  local target="$2"
  local label="${3:-$2}"

  local abs_source="$MONKEY_REPO/$source"

  if [[ ! -e "$abs_source" ]]; then
    log_warn "Skip: source does not exist: $abs_source"
    return 1
  fi

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would link $label -> $abs_source"
    return 0
  fi

  # If the symlink already points to the right place, do nothing.
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$abs_source" ]]; then
    log_info "Already linked: $label"
    return 0
  fi

  # Back up existing target (if any) before we touch it.
  if [[ -e "$target" || -L "$target" ]]; then
    monkey_backup_if_exists "$target" "$label"
  fi

  _link_ensure_parent "$target"

  ln -s "$abs_source" "$target"
  log_ok "Linked $label -> $abs_source"
}

# Remove a symlink we previously created. Does not touch regular files.
monkey_unlink() {
  local target="$1"
  local label="${2:-$1}"

  if [[ ! -L "$target" ]]; then
    log_info "Skip: $label is not a symlink"
    return 0
  fi

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would rm $target"
    return 0
  fi

  rm "$target"
  log_ok "Unlinked $label"
}
