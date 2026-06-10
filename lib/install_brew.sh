#!/usr/bin/env bash
# lib/install_brew.sh - Best-effort Homebrew / winget bootstrap
# Sourced by install.sh. Never assumes sudo without prompting.

# Returns 0 if the requested tool is available after this call.
ensure_brew() {
  detect_brew
  if [[ "$MONKEY_HAS_BREW" == "1" ]]; then
    return 0
  fi

  case "$MONKEY_OS" in
    macos)
      log_warn "Homebrew not found."
      log_info  "Install it with:"
      log_info  "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      return 1
      ;;
    linux)
      log_warn "Homebrew (Linuxbrew) not found."
      log_info  "Install it with:"
      log_info  "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      log_info  "After install, ensure /home/linuxbrew/.linuxbrew/bin is on PATH."
      return 1
      ;;
    windows)
      log_warn "Homebrew is not available on native Windows. Will fall back to winget."
      return 1
      ;;
  esac
}

ensure_winget() {
  detect_winget
  if [[ "$MONKEY_HAS_WINGET" == "1" ]]; then
    return 0
  fi
  log_warn "winget not found. Install 'App Installer' from the Microsoft Store."
  return 1
}

# Best-effort install of a brew formula, only if missing.
brew_install_if_missing() {
  local formula="$1"
  if [[ "$MONKEY_HAS_BREW" != "1" ]]; then
    log_warn "Skip: brew not available, can't install $formula"
    return 1
  fi
  if brew list --formula >/dev/null 2>&1 && brew list --formula | grep -qx "$formula"; then
    log_ok "$formula already installed"
    return 0
  fi
  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would brew install $formula"
    return 0
  fi
  log_info "brew install $formula"
  brew install "$formula"
}

# Best-effort install of a brew cask, only if missing.
brew_cask_install_if_missing() {
  local cask="$1"
  if [[ "$MONKEY_HAS_BREW" != "1" ]]; then
    log_warn "Skip: brew not available, can't install --cask $cask"
    return 1
  fi
  if brew list --cask >/dev/null 2>&1 && brew list --cask | grep -qx "$cask"; then
    log_ok "$cask (cask) already installed"
    return 0
  fi
  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would brew install --cask $cask"
    return 0
  fi
  log_info "brew install --cask $cask"
  brew install --cask "$cask"
}

winget_install_if_missing() {
  local id="$1"
  local name="${2:-$id}"
  if [[ "$MONKEY_HAS_WINGET" != "1" ]]; then
    log_warn "Skip: winget not available, can't install $id"
    return 1
  fi
  if winget list --id "$id" >/dev/null 2>&1; then
    log_ok "$name already installed"
    return 0
  fi
  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would winget install --id $id"
    return 0
  fi
  log_info "winget install --id $id"
  winget install --id "$id" --accept-package-agreements --accept-source-agreements
}

# Install the full recommended set, driven by lib/packages.toml.
# The manifest may not be present (legacy mode); monkey_packages_load
# falls back to hardcoded defaults and warns in that case.
install_recommended_stack() {
  local manifest="$MONKEY_REPO/lib/packages.toml"

  if [[ ! -r "$manifest" ]]; then
    log_warn "Manifest missing: $manifest (using hardcoded fallback)"
  fi
  monkey_packages_load "$manifest" || true

  case "$MONKEY_OS" in
    macos|linux)
      ensure_brew || return 0
      log_step "Installing Homebrew packages"
      # shellcheck disable=SC2086  # word splitting is intentional here
      for formula in $PKG_FORMULA; do
        brew_install_if_missing "$formula"
      done
      if [[ -n "$PKG_CASK" ]]; then
        # shellcheck disable=SC2086
        for cask in $PKG_CASK; do
          brew_cask_install_if_missing "$cask"
        done
      fi
      # Note: Iosevka Nerd Font is installed by lib/install_font.sh, not
      # here, so that we also install it on distros without Linuxbrew.
      ;;
    windows)
      ensure_winget || return 0
      log_step "Installing packages via winget"
      # shellcheck disable=SC2086
      for id in $PKG_ID; do
        winget_install_if_missing "$id" "$id"
      done
      ;;
  esac
}
