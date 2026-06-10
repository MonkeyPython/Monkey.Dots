#!/usr/bin/env bash
# lib/install_chsh.sh - chsh helper (set default shell)
# Sourced by install.sh.
#
# Public:
#   monkey_offer_set_default_shell   - print the chsh command if needed
#
# Why this exists:
#   The bundled zsh/.zshrc only runs when the user is in a zsh session.
#   If their default shell is /bin/bash (the macOS default), the .zshrc
#   never loads. We can detect this and print the right chsh command
#   so the user just copy-pastes one line.
#
# We never run chsh ourselves: it requires sudo (to update /etc/shells)
# and a re-login, both of which are user decisions.
#
# Per-OS strategy:
#   macOS / Linux / WSL  - if /etc/shells doesn't already list the
#                          target shell path, print both:
#                            1. the line to add (or the chsh command
#                               that does it for us)
#                            2. the actual chsh command
#                          If $SHELL already points at zsh, skip
#                          entirely (nothing to do).
#   Windows-native       - skip; chsh doesn't exist.
#   No zsh on PATH       - skip; nothing to set.

# All MONKEY_* vars are read by callers after this file is sourced.
# shellcheck disable=SC2034

# Returns 0 if the user's current $SHELL already ends in 'zsh'.
# $SHELL is the login shell; this is the most reliable signal.
already_running_zsh() {
  [[ "${SHELL##*/}" == "zsh" ]]
}

# Echo the absolute path of zsh, or empty if not found.
zsh_path() {
  if [[ -x "${SHELL:-}" && "${SHELL##*/}" == "zsh" ]]; then
    printf '%s\n' "$SHELL"
    return 0
  fi
  # Otherwise look for a usable zsh.
  local candidate
  for candidate in \
    /opt/homebrew/bin/zsh \
    /usr/local/bin/zsh \
    /home/linuxbrew/.linuxbrew/bin/zsh \
    /bin/zsh \
    /usr/bin/zsh; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# Returns 0 if a given absolute path is already in /etc/shells.
# /etc/shells is a Debian/macOS convention; on distros without it,
# the file just won't exist and we treat that as "not present".
in_etc_shells() {
  local path="$1"
  [[ -r /etc/shells ]] || return 1
  # Match exact line, ignore comments and whitespace.
  grep -qxF "$path" /etc/shells
}

# Print the instructions the user needs to set zsh as default.
# Refuses to do anything if already in zsh, on Windows, or with no zsh.
monkey_offer_set_default_shell() {
  # Skip on Windows-native: chsh doesn't exist there.
  if [[ "$MONKEY_OS" == "windows" ]]; then
    return 0
  fi

  if already_running_zsh; then
    log_ok "Login shell is already zsh ($SHELL); nothing to do"
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    log_warn "zsh not on PATH; can't offer to set it as default"
    return 0
  fi

  local target
  if ! target="$(zsh_path)"; then
    log_warn "zsh binary not found at any known location"
    return 0
  fi

  log_step "Make zsh the default login shell"

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would print chsh instructions for $target"
    return 0
  fi

  log_info "Your login shell is currently: $SHELL"
  log_info "To make zsh the default, run ONE of these:"
  log_info ""

  if in_etc_shells "$target"; then
    log_info "  chsh -s '$target' '$USER'"
  else
    log_info "  # First, allow the shell:"
    log_info "  echo '$target' | sudo tee -a /etc/shells"
    log_info "  # Then set it as default:"
    log_info "  chsh -s '$target' '$USER'"
  fi

  log_info ""
  log_info "You'll need to log out and back in for the change to take effect."
  log_info "Until then, just run 'exec zsh' to start a zsh session manually."

  return 0
}
