#!/usr/bin/env bash
# lib/install_font.sh - Iosevka Term Nerd Font installer
# Sourced by install.sh.
#
# Public:
#   monkey_install_iosevka   - best-effort install per-OS, idempotent
#
# The visual layer of Monkey.Dots (wezterm, starship, tmux Kanagawa) all
# assume IosevkaTerm NF is available system-wide. This module handles the
# install so the user doesn't have to.
#
# Per-OS strategy:
#   macOS               - brew install --cask font-iosevka-term-nerd-font
#   Linux (no brew)     - download zip from Nerd Fonts GitHub releases,
#                         unzip into ~/.local/share/fonts/, fc-cache
#   Linux (brew)        - same as macOS (cask works under Linuxbrew)
#   Windows (Git Bash)  - download + extract into $HOME/.local/share/fonts,
#                         warn that it won't register with Windows directly
#                         (manual install required via the Fonts control panel)
#   WSL                 - Linux path; fonts are visible to WSL but Windows
#                         apps need a separate Windows-side install

# All MONKEY_* vars are read by callers after this file is sourced.
# shellcheck disable=SC2034

FONT_NERD_RELEASE_API="https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
FONT_FALLBACK_VERSION="v3.3.0"
FONT_FALLBACK_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_FALLBACK_VERSION}/IosevkaTerm.zip"

# Returns 0 if the font is already installed (any plausible check).
# On Linux: looks for the font dir + a font file. On macOS: asks brew.
# On Windows: looks for the font dir only.
font_already_installed() {
  case "$MONKEY_OS" in
    macos)
      if [[ "$MONKEY_HAS_BREW" == "1" ]]; then
        brew list --cask >/dev/null 2>&1 && \
          brew list --cask | grep -qi 'font-iosevka-term-nerd-font' && return 0
      fi
      # Fallback: check the user's font dir
      [[ -d "$MONKEY_HOME/Library/Fonts" ]] && \
        find "$MONKEY_HOME/Library/Fonts" -iname 'Iosevka*' -print -quit | grep -q . && return 0
      return 1
      ;;
    linux)
      local dir="$MONKEY_HOME/.local/share/fonts"
      [[ -d "$dir" ]] && \
        find "$dir" -iname 'IosevkaTerm*NerdFont*' -o -iname 'IosevkaTerm*.ttf' 2>/dev/null | head -n1 | grep -q . && return 0
      return 1
      ;;
    windows)
      local dir="$MONKEY_HOME/.local/share/fonts"
      [[ -d "$dir" ]] && \
        find "$dir" -iname 'IosevkaTerm*NerdFont*' 2>/dev/null | head -n1 | grep -q . && return 0
      return 1
      ;;
  esac
  return 1
}

# Find the latest IosevkaTerm zip URL from the Nerd Fonts release JSON.
# Falls back to a pinned URL if curl/jq fails.
font_latest_url() {
  if ! command -v curl >/dev/null 2>&1; then
    printf '%s\n' "$FONT_FALLBACK_URL"
    return 0
  fi

  local json
  json="$(curl -fsSL --max-time 15 "$FONT_NERD_RELEASE_API" 2>/dev/null || true)"
  if [[ -n "$json" ]] && command -v jq >/dev/null 2>&1; then
    local url
    url="$(printf '%s' "$json" | jq -r '
      .assets[]? | select(.name | test("IosevkaTerm"; "i")) | .browser_download_url
    ' 2>/dev/null | head -n1)"
    if [[ -n "$url" && "$url" != "null" ]]; then
      printf '%s\n' "$url"
      return 0
    fi
  fi

  printf '%s\n' "$FONT_FALLBACK_URL"
}

# Install via Homebrew cask (macOS or Linuxbrew).
install_via_brew_cask() {
  if [[ "$MONKEY_HAS_BREW" != "1" ]]; then
    return 1
  fi
  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would brew install --cask font-iosevka-term-nerd-font"
    return 0
  fi
  log_info "brew install --cask font-iosevka-term-nerd-font"
  if brew install --cask font-iosevka-term-nerd-font >/dev/null 2>&1; then
    log_ok "Iosevka Nerd Font installed via Homebrew cask"
    return 0
  fi
  log_warn "brew cask install failed; falling back to manual download"
  return 1
}

# Install via direct download + unzip into ~/.local/share/fonts/.
install_via_download() {
  local fonts_dir="$MONKEY_HOME/.local/share/fonts"

  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl not found; cannot download font archive"
    return 1
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    log_warn "unzip not found; install it (brew install unzip / apt install unzip)"
    return 1
  fi

  local url
  url="$(font_latest_url)"

  if [[ "$MONKEY_DRY_RUN" == "1" ]]; then
    log_info "DRY-RUN: would download $url"
    log_info "DRY-RUN: would unzip into $fonts_dir"
    [[ "$MONKEY_OS" == "linux" ]] && \
      log_info "DRY-RUN: would run fc-cache -fv"
    return 0
  fi

  mkdir -p "$fonts_dir"
  local tmp_zip
  tmp_zip="$(mktemp -t iosevka.XXXXXX.zip)"
  # shellcheck disable=SC2064  # we want $tmp_zip expanded now, not later.
  trap "rm -f '$tmp_zip'" EXIT

  log_info "Downloading $url"
  if ! curl -fsSL --max-time 60 -o "$tmp_zip" "$url"; then
    log_warn "Download failed (offline? no GitHub access?)"
    return 1
  fi

  log_info "Extracting into $fonts_dir"
  if ! unzip -o -q "$tmp_zip" -d "$fonts_dir"; then
    log_warn "unzip failed"
    return 1
  fi
  rm -f "$tmp_zip"
  trap - EXIT

  if [[ "$MONKEY_OS" == "linux" ]] && command -v fc-cache >/dev/null 2>&1; then
    log_info "Refreshing font cache (fc-cache -fv)"
    fc-cache -fv >/dev/null 2>&1 || true
  fi

  log_ok "Iosevka Nerd Font installed to $fonts_dir"
  return 0
}

# Public entry point. Decides per-OS and delegates.
monkey_install_iosevka() {
  if font_already_installed; then
    log_ok "Iosevka Nerd Font already installed"
    return 0
  fi

  log_step "Installing Iosevka Term Nerd Font"

  case "$MONKEY_OS" in
    macos)
      install_via_brew_cask || install_via_download
      ;;
    linux)
      # Prefer brew cask if Linuxbrew is present, fall back to direct
      # download. Many users on Fedora/Arch don't have Linuxbrew.
      if [[ "$MONKEY_HAS_BREW" == "1" ]] && install_via_brew_cask; then
        return 0
      fi
      install_via_download
      ;;
    windows)
      log_warn "Native Windows install needs manual steps too:"
      log_warn "  1. The font files will be downloaded to ~/.local/share/fonts"
      log_warn "  2. To use them in WezTerm running on Windows, install the"
      log_warn "     .ttf files via the Windows Fonts control panel (right-click"
      log_warn "     on each .ttf -> 'Install for all users')."
      install_via_download
      ;;
  esac
}
