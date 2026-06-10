#!/usr/bin/env bash
# lib/detect.sh - OS / shell / package manager detection
# Sourced by install.sh. All MONKEY_* variables are intentionally
# exported into the caller's scope.

# shellcheck disable=SC2034  # MONKEY_REPO/MONKEY_HOME are read by sibling scripts
MONKEY_LIB_DIR="${BASH_SOURCE[0]%/*}"
MONKEY_REPO="$(cd "$MONKEY_LIB_DIR/.." && pwd)"
MONKEY_HOME="${HOME:-$(eval echo "~$USER")}"
# All MONKEY_* vars are read by callers after this file is sourced.
# shellcheck disable=SC2034

# --- OS detection ---------------------------------------------------------

detect_os() {
  local uname_s
    uname_s="$(uname -s 2>/dev/null || echo Unknown)"

  case "$uname_s" in
    Darwin)
      MONKEY_OS="macos"
      MONKEY_OS_NAME="macOS"
      ;;
    Linux)
      MONKEY_OS="linux"
      MONKEY_OS_NAME="Linux"
      # WSL detection
      if [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        MONKEY_IS_WSL=1
        MONKEY_OS_NAME="WSL"
      else
        MONKEY_IS_WSL=0
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      MONKEY_OS="windows"
      MONKEY_OS_NAME="Windows (Git Bash)"
      ;;
    *)
      MONKEY_OS="unknown"
      MONKEY_OS_NAME="Unknown ($uname_s)"
      MONKEY_IS_WSL=0
      ;;
  esac
}

# --- Package manager detection --------------------------------------------

detect_brew() {
  MONKEY_HAS_BREW=0
  if command -v brew >/dev/null 2>&1; then
    MONKEY_HAS_BREW=1
    MONKEY_BREW_BIN="$(command -v brew)"
    return
  fi
  # Common install locations even when not on PATH
  for candidate in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$candidate" ]]; then
      MONKEY_HAS_BREW=1
      MONKEY_BREW_BIN="$candidate"
      return
    fi
  done
}

detect_winget() {
  MONKEY_HAS_WINGET=0
  if command -v winget >/dev/null 2>&1; then
    MONKEY_HAS_WINGET=1
  fi
}

# --- Tooling detection ----------------------------------------------------

detect_oh_my_zsh() {
  [[ -d "$MONKEY_HOME/.oh-my-zsh" ]] && MONKEY_HAS_OH_MY_ZSH=1 || MONKEY_HAS_OH_MY_ZSH=0
}

detect_tpm() {
  [[ -d "$MONKEY_HOME/.tmux/plugins/tpm" ]] && MONKEY_HAS_TPM=1 || MONKEY_HAS_TPM=0
}

# --- Public entrypoint ----------------------------------------------------

detect_all() {
  MONKEY_IS_WSL=0
  detect_os
  detect_brew
  detect_winget
  detect_oh_my_zsh
  detect_tpm
}
