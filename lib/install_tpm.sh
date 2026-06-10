#!/usr/bin/env bash
# lib/install_tpm.sh - TPM (Tmux Plugin Manager) bootstrap
# Sourced by install.sh.
#
# Public:
#   monkey_install_tpm            - clone TPM if missing, install plugins
#
# Why this exists:
#   The bundled tmux/tmux.conf declares @plugin lines for Kanagawa,
#   vim-tmux-navigator, tmux-resurrect, etc. None of those plugins
#   load until TPM clones them. The traditional flow requires the
#   user to open tmux and press 'prefix + I' - which is a manual
#   step we can automate.
#
# Strategy:
#   1. Skip entirely if no tmux on PATH (e.g. Windows-native, or user
#      ran --no-brew and didn't install tmux themselves).
#   2. Skip entirely on Windows-native (no native tmux).
#   3. If ~/.tmux/plugins/tpm doesn't exist, git clone it.
#   4. Optionally run `tpm install_plugins` headless so the user
#      doesn't have to press prefix + I the first time. This is
#      best-effort: it fails silently if tmux can't fork, and the
#      user can still trigger it manually.
#
# All steps are idempotent and respect $MONKEY_DRY_RUN.

# All MONKEY_* vars are read by callers after this file is sourced.
# shellcheck disable=SC2034

TPM_REPO="https://github.com/tmux-plugins/tpm"
TPM_TARGET_DIR_NAME=".tmux/plugins/tpm"

# Where TPM should live. Defaults to ~/.tmux/plugins/tpm, which is the
# path the bundled tmux.conf uses (`run '~/.tmux/plugins/tpm/tpm'`).
tpm_target_dir() {
  printf '%s\n' "$MONKEY_HOME/$TPM_TARGET_DIR_NAME"
}

# Returns 0 if TPM is already installed (the tpm script exists).
tpm_already_installed() {
  local dir
  dir="$(tpm_target_dir)"
  [[ -x "$dir/tpm" || -f "$dir/tpm" ]]
}

# Returns 0 if tmux is available on PATH. Used to decide whether to
# even attempt the install (no point cloning TPM if we can't run it).
tpm_can_run() {
  command -v tmux >/dev/null 2>&1
}

# Clone the TPM repo into the target dir. Idempotent: if it already
# exists, skip.
tpm_clone() {
  local target
  target="$(tpm_target_dir)"
  local parent
  parent="$(dirname "$target")"

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would git clone $TPM_REPO into $target"
    return 0
  fi

  if [[ ! -d "$parent" ]]; then
    mkdir -p "$parent"
  fi

  if [[ -d "$target" ]]; then
    log_info "TPM dir already exists at $target, skipping clone"
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_warn "git not found; cannot clone TPM"
    return 1
  fi

  log_info "Cloning TPM into $target"
  if git clone --depth 1 "$TPM_REPO" "$target" >/dev/null 2>&1; then
    log_ok "TPM cloned to $target"
    return 0
  fi

  log_warn "TPM clone failed (offline? no GitHub access?)"
  return 1
}

# Try to install plugins headless. This spawns a detached tmux session
# that sources the rendered tmux.conf and runs TPM's install_plugins,
# then kills itself. If anything fails, the user can still press
# 'prefix + I' inside their own tmux session.
tpm_install_plugins_headless() {
  local tmux_conf="$MONKEY_HOME/.config/tmux/tmux.conf"

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would run tpm install_plugins headless"
    return 0
  fi

  if [[ ! -f "$tmux_conf" ]]; then
    log_info "No rendered tmux.conf yet; skipping headless plugin install"
    log_info "  (open tmux and press prefix + I to install plugins manually)"
    return 0
  fi

  # Adapt the same pattern Gentleman.Dots' manual installation guide
  # uses: spawn a detached session, source the conf, run the install,
  # then kill the session.
  log_info "Installing tmux plugins headless (one-shot session)"

  # Use a unique session name to avoid colliding with the user's
  # running session.
  local session="monkey-tpm-install-$$"
  if tmux new-session -d -s "$session" -x 200 -y 50 \
       "source '$tmux_conf' \; run-shell '$MONKEY_HOME/$TPM_TARGET_DIR_NAME/bin/install_plugins' \; kill-session" \
       2>/dev/null; then
    # Wait briefly for the install to complete (or fail).
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      if ! tmux has-session -t "$session" 2>/dev/null; then
        log_ok "tmux plugins installed"
        return 0
      fi
      sleep 1
    done
    # If the session is still around, kill it and warn.
    tmux kill-session -t "$session" 2>/dev/null || true
    log_warn "Plugin install session did not finish in 10s"
    log_info "  (open tmux and press prefix + I to retry manually)"
    return 1
  fi

  log_warn "Could not spawn detached tmux session for plugin install"
  log_info "  (open tmux and press prefix + I to install manually)"
  return 1
}

# Public entry point.
monkey_install_tpm() {
  # Skip on Windows-native: no native tmux there.
  if [[ "$MONKEY_OS" == "windows" ]]; then
    log_info "TPM skipped on Windows-native (no native tmux)"
    return 0
  fi

  # Skip if tmux isn't installed (e.g. --no-brew on a fresh box).
  if ! tpm_can_run; then
    log_warn "tmux not found on PATH; skipping TPM install"
    log_warn "  install tmux first (brew install tmux), then re-run"
    return 0
  fi

  log_step "Installing TPM (Tmux Plugin Manager)"

  if tpm_already_installed; then
    log_ok "TPM already installed at $(tpm_target_dir)"
  else
    tpm_clone || return 1
  fi

  # After cloning, try to install the plugins headlessly so the user
  # doesn't have to remember the prefix + I trick. This is best-effort.
  tpm_install_plugins_headless
}
