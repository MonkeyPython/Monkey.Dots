#!/usr/bin/env bash
# lib/packages_parser.sh - Minimal TOML reader for lib/packages.toml
# Sourced by install.sh.
#
# Public:
#   monkey_packages_load <toml_path>   - parse the file into PKG_FORMULA
#                                        PKG_CASK, PKG_ID globals
#   monkey_packages_field <section> <key>   - echo the value of a key
#
# Scope: we only parse the subset of TOML we use:
#   - Section headers:    [name]
#   - String values:      key = "value"   (no multiline, no escapes
#                                          beyond \" and \\, which we
#                                          don't use anyway)
#   - Comments:           lines starting with '#'
#   - Blank lines
#
# We do NOT support: arrays, integers, booleans, dotted keys, nested
# tables, inline tables, multi-line strings. If packages.toml ever
# needs any of those, swap this for a real TOML parser (or just
# convert to JSON). The file is committed alongside the script so
# the constraints are visible at a glance.

# All MONKEY_* / PKG_* vars are read by callers after this file is sourced.
# shellcheck disable=SC2034

# Globals filled by monkey_packages_load.
PKG_FORMULA=""
PKG_CASK=""
PKG_ID=""

# Echo the value of a key inside a [section]. Returns 1 if not found.
# Used internally; not part of the public API.
toml_read_value() {
  local file="$1" section="$2" key="$3"
  awk -v want_section="[$section]" -v want_key="$key" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    {
      line = trim($0)
      if (line == "" || substr(line, 1, 1) == "#") next
      if (substr(line, 1, 1) == "[") {
        in_section = (line == want_section)
        next
      }
      if (!in_section) next
      eq = index(line, "=")
      if (eq == 0) next
      lhs = trim(substr(line, 1, eq - 1))
      if (lhs != want_key) next
      rhs = trim(substr(line, eq + 1))
      # Strip surrounding quotes (single or double)
      if ((substr(rhs, 1, 1) == "\"" && substr(rhs, length(rhs), 1) == "\"") ||
          (substr(rhs, 1, 1) == "\x27" && substr(rhs, length(rhs), 1) == "\x27")) {
        rhs = substr(rhs, 2, length(rhs) - 2)
      }
      print rhs
      exit
    }
  ' "$file"
}

# Public: parse the manifest. Always succeeds if the file exists and is
# well-formed; falls back to a warning + empty globals if missing.
monkey_packages_load() {
  local file="$1"

  if [[ ! -r "$file" ]]; then
    log_warn "Package manifest not found: $file"
    log_warn "  Falling back to hardcoded defaults in lib/install_brew.sh"
    PKG_FORMULA="zsh starship tmux fzf zoxide atuin carapace fd bat eza lazygit neovim"
    PKG_CASK="wezterm"
    PKG_ID="wez.wezterm junegunn.fzf ajeetdsouza.zoxide sharkdp.bat sharkdp.fd eza-community.eza JesseDuffield.lazygit Neovim.Neovim JanDeDobbeleer.OhMyPosh"
    return 1
  fi

  PKG_FORMULA="$(toml_read_value "$file" macos formula)"
  PKG_CASK="$(toml_read_value "$file" macos cask)"
  PKG_ID="$(toml_read_value "$file" windows id)"

  # Sanity check: every platform section must be present.
  if [[ -z "$PKG_FORMULA" || -z "$PKG_ID" ]]; then
    log_warn "Package manifest is missing required fields (macos.formula, windows.id)"
    return 1
  fi
  return 0
}

# Public: echo a single field for a given section+key.
monkey_packages_field() {
  local section="$1" key="$2"
  local file="$MONKEY_REPO/lib/packages.toml"
  toml_read_value "$file" "$section" "$key"
}
