#!/usr/bin/env bash
# lib/install_omz.sh - Oh My Zsh bootstrap
# Sourced by install.sh.
#
# Public:
#   monkey_install_oh_my_zsh   - best-effort install, idempotent
#
# Why this exists:
#   The bundled zsh/.zshrc sources $ZSH/oh-my-zsh.sh at the bottom,
#   which fails with a noisy "no such file" if OMZ is missing. So
#   instead of leaving the user with a half-broken shell, we install
#   OMZ first.
#
# Per-OS strategy:
#   macOS / Linux / WSL  - run the official install_omz.sh with
#                          --unattended --keep-zshrc (we ship our own)
#   Windows-native       - warn and skip (OMZ is fragile in Git Bash;
#                          our .zshrc falls back to starship-only)

# All MONKEY_* vars are read by callers after this file is sourced.
# shellcheck disable=SC2034

OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# Where OMZ should live. Honours $ZSH if the user has set it, defaults
# to $HOME/.oh-my-zsh. Used both for detection and for install verification.
omz_target_dir() {
  printf '%s\n' "${ZSH:-$MONKEY_HOME/.oh-my-zsh}"
}

# Returns 0 if OMZ appears to be installed (the install marker exists).
omz_already_installed() {
  local dir
  dir="$(omz_target_dir)"
  # The official installer writes this file at the end of a successful run.
  [[ -f "$dir/.git/shallow.lock" || -d "$dir/.git" || -f "$dir/oh-my-zsh.sh" ]]
}

# Pick the right env var override for the installer's --unattended mode.
# The upstream installer respects ZSH to know where to install.
omz_install_env() {
  # Use a subshell-friendly assignment; we want ZSH in the env of the
  # child process, not in our own shell.
  printf 'ZSH=%q' "$(omz_target_dir)"
}

# Run the actual install. Assumes the caller has already checked that
# OMZ is missing and prerequisites are present.
omz_run_install() {
  local target
  target="$(omz_target_dir)"

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would install Oh My Zsh into $target"
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    log_warn "zsh not found on PATH; skipping Oh My Zsh install"
    log_warn "  install zsh first (brew install zsh), then re-run"
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl not found; cannot download Oh My Zsh installer"
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_warn "git not found; cannot fetch Oh My Zsh repo"
    return 1
  fi

  log_info "Downloading Oh My Zsh installer"
  # We pass --unattended to skip the prompts, --keep-zshrc to NOT
  # overwrite the .zshrc we already symlinked. We also export ZSH so
  # the installer doesn't default to writing its own location.
  local script
  script="$(mktemp -t omz-install.XXXXXX.sh)"
  # shellcheck disable=SC2064
  trap "rm -f '$script'" EXIT

  if ! curl -fsSL --max-time 30 "$OMZ_INSTALL_URL" -o "$script"; then
    log_warn "Failed to download Oh My Zsh installer"
    rm -f "$script"
    trap - EXIT
    return 1
  fi

  log_info "Running Oh My Zsh installer (unattended, keep .zshrc)"
  # shellcheck disable=SC2086
  if ZSH="$target" RUNZSH=no CHSH=no \
     zsh "$script" --unattended --keep-zshrc >/dev/null 2>&1; then
    log_ok "Oh My Zsh installed at $target"
    rm -f "$script"
    trap - EXIT
    return 0
  fi

  log_warn "Oh My Zsh installer exited with an error"
  rm -f "$script"
  trap - EXIT
  return 1
}

# Public entry point. Honours $ZSH, $MONKEY_DRY_RUN, OS detection.
monkey_install_oh_my_zsh() {
  # Windows-native: OMZ is too fragile in Git Bash. The .zshrc already
  # degrades gracefully when $ZSH doesn't exist (the source line at
  # the bottom is guarded with the [[ -f ]] check in the latest .zshrc;
  # if not, we just warn).
  if [[ "$MONKEY_OS" == "windows" ]]; then
    log_warn "Oh My Zsh skipped on Windows-native (Git Bash is too fragile for it)"
    return 0
  fi

  if omz_already_installed; then
    log_ok "Oh My Zsh already installed at $(omz_target_dir)"
    return 0
  fi

  log_step "Installing Oh My Zsh"
  omz_run_install
}
