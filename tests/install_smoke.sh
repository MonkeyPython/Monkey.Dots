#!/usr/bin/env bash
# Smoke test for Monkey.Dots installer.
#
# Creates an isolated $HOME in a temp dir, runs install.sh in --no-brew
# --dry-run mode, then in real mode, and verifies:
#   1. Symlinks are created at the expected paths.
#   2. Each symlink points into the repo.
#   3. A pre-existing file is backed up to ~/.dotfiles-backup/...
#   4. Running install.sh a second time is idempotent.
#   5. uninstall.sh removes the symlinks.
#
# Exits non-zero on the first failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Use a fresh, isolated HOME for the whole test.
TEST_HOME="$(mktemp -d -t monkey-dots-smoke.XXXXXX)"
export HOME="$TEST_HOME"
export XDG_CONFIG_HOME="$TEST_HOME/.config"
mkdir -p "$XDG_CONFIG_HOME"

# Pre-existing configs that should be backed up, not overwritten.
mkdir -p "$TEST_HOME/.config/wezterm"
echo "old-wezterm" > "$TEST_HOME/.config/wezterm/wezterm.lua"
echo "old-zshrc" > "$TEST_HOME/.zshrc"

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

pass() { printf '\033[32m  ok \033[0m %s\n' "$*"; }
fail() { printf '\033[31m  FAIL\033[0m %s\n' "$*" >&2; exit 1; }

assert_symlink() {
  local target="$1"
  local expected_source="$2"
  [[ -L "$target" ]] || fail "expected symlink: $target"
  local dest
  dest="$(readlink "$target")"
  [[ "$dest" == "$expected_source" ]] || \
    fail "wrong target for $target: $dest (expected $expected_source)"
  pass "symlink ok: $target"
}

assert_file_content() {
  local path="$1"
  local needle="$2"
  grep -qF -- "$needle" "$path" || fail "missing '$needle' in $path"
  pass "content ok: $path contains '$needle'"
}

# --- 1. dry-run -----------------------------------------------------------

printf '\n[1/4] dry-run\n'
# Snapshot existing files to confirm dry-run is fully non-destructive.
snapshot_before="$(find "$TEST_HOME" -type f -o -type l | sort)"
"$REPO_ROOT/install.sh" --no-brew --dry-run >/dev/null
snapshot_after="$(find "$TEST_HOME" -type f -o -type l | sort)"
[[ "$snapshot_before" == "$snapshot_after" ]] || \
  fail "dry-run modified the filesystem"
pass "dry-run made no changes"

# --- 2. real install ------------------------------------------------------

printf '\n[2/4] real install\n'
"$REPO_ROOT/install.sh" --no-brew >/dev/null

assert_symlink "$TEST_HOME/.config/wezterm"      "$REPO_ROOT/wezterm"
# tmux/tmux.conf is a *rendered* file (not a symlink) because the installer
# substitutes the MONKEY_DEFAULT_SHELL placeholder with the user's real
# shell path. Verify it exists, is a regular file, and contains the
# substituted directives.
[[ -f "$TEST_HOME/.config/tmux/tmux.conf" ]] || \
  fail "tmux.conf not rendered to $TEST_HOME/.config/tmux/tmux.conf"
[[ ! -L "$TEST_HOME/.config/tmux/tmux.conf" ]] || \
  fail "tmux.conf should be a regular file, not a symlink"
grep -q '^set -g default-shell' "$TEST_HOME/.config/tmux/tmux.conf" || \
  fail "rendered tmux.conf missing 'set -g default-shell'"
grep -q '# MONKEY_DEFAULT_SHELL' "$TEST_HOME/.config/tmux/tmux.conf" && \
  fail "rendered tmux.conf still contains the placeholder"
pass "rendered tmux.conf is a regular file with substituted shell path"
assert_symlink "$TEST_HOME/.config/starship.toml"  "$REPO_ROOT/starship/starship.toml"
assert_symlink "$TEST_HOME/.zshrc"                 "$REPO_ROOT/zsh/.zshrc"
assert_symlink "$TEST_HOME/.p10k.zsh"              "$REPO_ROOT/zsh/.p10k.zsh"
assert_symlink "$TEST_HOME/.gitconfig"             "$REPO_ROOT/git/.gitconfig"

# Backed-up file should still be reachable via the backup directory.
[[ -d "$TEST_HOME/.dotfiles-backup" ]] || fail "no backup directory created"
backup_wezterm="$(find "$TEST_HOME/.dotfiles-backup" -name 'wezterm.lua' -print -quit)"
[[ -n "$backup_wezterm" ]] || fail "wezterm.lua backup not found"
assert_file_content "$backup_wezterm" "old-wezterm"

# Symlinked config should now resolve to the repo's file.
assert_file_content "$TEST_HOME/.config/wezterm/wezterm.lua" "MONKEY DOTS - WEZTERM"
assert_file_content "$TEST_HOME/.zshrc"                       "MONKEY DOTS - ZSH"
assert_file_content "$TEST_HOME/.config/starship.toml"        "MONKEY DOTS - STARSHIP"

# --- 3. idempotency -------------------------------------------------------

printf '\n[3/4] idempotent re-run\n'
"$REPO_ROOT/install.sh" --no-brew >/dev/null
[[ -L "$TEST_HOME/.zshrc" ]] || fail "second run removed symlink"
pass "second install run is idempotent"

# --- 4. uninstall ---------------------------------------------------------

printf '\n[4/4] uninstall\n'
"$REPO_ROOT/uninstall.sh" --keep-backup >/dev/null
[[ ! -L "$TEST_HOME/.config/wezterm" ]] || fail "uninstall left wezterm symlink"
[[ ! -L "$TEST_HOME/.zshrc" ]]           || fail "uninstall left .zshrc symlink"
pass "uninstall removed symlinks"

printf '\n\033[32mAll smoke tests passed.\033[0m\n'
