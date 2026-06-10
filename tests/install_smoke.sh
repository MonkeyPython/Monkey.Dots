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

printf '\n[1/12] dry-run\n'
# Snapshot existing files to confirm dry-run is fully non-destructive.
snapshot_before="$(find "$TEST_HOME" -type f -o -type l | sort)"
"$REPO_ROOT/install.sh" --no-brew --dry-run >/dev/null
snapshot_after="$(find "$TEST_HOME" -type f -o -type l | sort)"
[[ "$snapshot_before" == "$snapshot_after" ]] || \
  fail "dry-run modified the filesystem"
pass "dry-run made no changes"

# --- 2. real install ------------------------------------------------------

printf '\n[2/12] real install\n'
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

printf '\n[3/12] idempotent re-run\n'
"$REPO_ROOT/install.sh" --no-brew >/dev/null
[[ -L "$TEST_HOME/.zshrc" ]] || fail "second run removed symlink"
pass "second install run is idempotent"

# --- 4. uninstall ---------------------------------------------------------

printf '\n[4/12] uninstall\n'
"$REPO_ROOT/uninstall.sh" --keep-backup >/dev/null
[[ ! -L "$TEST_HOME/.config/wezterm" ]] || fail "uninstall left wezterm symlink"
[[ ! -L "$TEST_HOME/.zshrc" ]]           || fail "uninstall left .zshrc symlink"
pass "uninstall removed symlinks"

# --- 5. font installer (dry-run, simulated Linux, no brew) ----------------

printf '\n[5/12] font installer (dry-run)\n'
FONT_TEST_HOME="$(mktemp -d -t monkey-font-smoke.XXXXXX)"
# Simulate Linux-without-brew by clearing the brew variables and forcing OS.
(
  export HOME="$FONT_TEST_HOME"
  export XDG_CONFIG_HOME="$FONT_TEST_HOME/.config"
  export MONKEY_DRY_RUN=1
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_font.sh"
  MONKEY_OS="linux"
  MONKEY_OS_NAME="Linux (simulated)"
  MONKEY_HAS_BREW=0
  # dry-run should NOT create any files
  monkey_install_iosevka 2>&1 || true
  if [[ -d "$FONT_TEST_HOME/.local/share/fonts" ]]; then
    fail "dry-run created fonts dir"
  fi
  pass "font installer dry-run is non-destructive"
)
rm -rf "$FONT_TEST_HOME"

# --- 6. font installer idempotency (real run, pre-seeded dir) -----------

printf '\n[6/12] font installer idempotency (pre-seeded)\n'
FONT_TEST_HOME="$(mktemp -d -t monkey-font-smoke.XXXXXX)"
(
  export HOME="$FONT_TEST_HOME"
  export XDG_CONFIG_HOME="$FONT_TEST_HOME/.config"
  export MONKEY_DRY_RUN=0
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_font.sh"
  MONKEY_OS="linux"
  # shellcheck disable=SC2034
  MONKEY_OS_NAME="Linux (simulated)"
  MONKEY_HAS_BREW=0
  # Pre-seed: pretend the font is already installed
  mkdir -p "$FONT_TEST_HOME/.local/share/fonts"
  touch "$FONT_TEST_HOME/.local/share/fonts/IosevkaTermNerdFont-Regular.ttf"
  monkey_install_iosevka 2>&1
  # The pre-seeded file must still be the only font file (no re-download).
  count=$(find "$FONT_TEST_HOME/.local/share/fonts" -type f | wc -l | tr -d ' ')
  [[ "$count" == "1" ]] || fail "idempotent run modified the seeded font dir"
  pass "font installer skips when already installed"
)
rm -rf "$FONT_TEST_HOME"

# --- 7. Oh My Zsh installer (dry-run, simulated Linux) -------------------

printf '\n[7/12] OMZ installer (dry-run)\n'
OMZ_TEST_HOME="$(mktemp -d -t monkey-omz-smoke.XXXXXX)"
(
  export HOME="$OMZ_TEST_HOME"
  export XDG_CONFIG_HOME="$OMZ_TEST_HOME/.config"
  export MONKEY_DRY_RUN=1
  unset ZSH
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_omz.sh"
  MONKEY_OS="linux"
  # shellcheck disable=SC2034
  MONKEY_OS_NAME="Linux (simulated)"
  monkey_install_oh_my_zsh 2>&1
  # dry-run must not create ~/.oh-my-zsh
  if [[ -d "$OMZ_TEST_HOME/.oh-my-zsh" ]]; then
    fail "dry-run created ~/.oh-my-zsh"
  fi
  pass "OMZ installer dry-run is non-destructive"
)
rm -rf "$OMZ_TEST_HOME"

# --- 8. OMZ installer idempotency (real run, pre-seeded dir) -------------

printf '\n[8/12] OMZ installer idempotency (pre-seeded)\n'
OMZ_TEST_HOME="$(mktemp -d -t monkey-omz-smoke.XXXXXX)"
(
  export HOME="$OMZ_TEST_HOME"
  export XDG_CONFIG_HOME="$OMZ_TEST_HOME/.config"
  export MONKEY_DRY_RUN=0
  unset ZSH
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_omz.sh"
  MONKEY_OS="linux"
  # shellcheck disable=SC2034
  MONKEY_OS_NAME="Linux (simulated)"
  # Pre-seed: pretend OMZ is already installed
  mkdir -p "$OMZ_TEST_HOME/.oh-my-zsh"
  touch "$OMZ_TEST_HOME/.oh-my-zsh/oh-my-zsh.sh"
  monkey_install_oh_my_zsh 2>&1
  # The pre-seeded file must still be the only file there.
  count=$(find "$OMZ_TEST_HOME/.oh-my-zsh" -type f | wc -l | tr -d ' ')
  [[ "$count" == "1" ]] || fail "idempotent OMZ run modified the seeded dir"
  pass "OMZ installer skips when already installed"
)
rm -rf "$OMZ_TEST_HOME"

# --- 9. OMZ installer skips on Windows-native ----------------------------

printf '\n[9/12] OMZ installer skips on Windows-native\n'
OMZ_TEST_HOME="$(mktemp -d -t monkey-omz-smoke.XXXXXX)"
(
  export HOME="$OMZ_TEST_HOME"
  export XDG_CONFIG_HOME="$OMZ_TEST_HOME/.config"
  export MONKEY_DRY_RUN=0
  unset ZSH
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_omz.sh"
  MONKEY_OS="windows"
  # shellcheck disable=SC2034
  MONKEY_OS_NAME="Windows (simulated)"
  monkey_install_oh_my_zsh 2>&1
  # Windows must not have OMZ installed
  if [[ -d "$OMZ_TEST_HOME/.oh-my-zsh" ]]; then
    fail "OMZ installer ran on Windows-native"
  fi
  pass "OMZ installer skipped on Windows-native"
)
rm -rf "$OMZ_TEST_HOME"

# --- 10. TPM installer (dry-run, simulated Linux) ------------------------

printf '\n[10/12] TPM installer (dry-run)\n'
TPM_TEST_HOME="$(mktemp -d -t monkey-tpm-smoke.XXXXXX)"
(
  export HOME="$TPM_TEST_HOME"
  export XDG_CONFIG_HOME="$TPM_TEST_HOME/.config"
  export MONKEY_DRY_RUN=1
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_tpm.sh"
  MONKEY_OS="linux"
  # shellcheck disable=SC2034
  MONKEY_OS_NAME="Linux (simulated)"
  # Pretend tmux is available so we get past the no-tmux check
  # and into the dry-run path.
  PATH="$TPM_TEST_HOME/bin:$PATH"
  mkdir -p "$TPM_TEST_HOME/bin"
  cat > "$TPM_TEST_HOME/bin/tmux" <<'SH'
#!/usr/bin/env bash
echo "[fake-tmux] $*" >&2
SH
  chmod +x "$TPM_TEST_HOME/bin/tmux"
  monkey_install_tpm 2>&1
  # dry-run must not create ~/.tmux/plugins/tpm
  if [[ -d "$TPM_TEST_HOME/.tmux/plugins/tpm" ]]; then
    fail "dry-run created ~/.tmux/plugins/tpm"
  fi
  pass "TPM installer dry-run is non-destructive"
)
rm -rf "$TPM_TEST_HOME"

# --- 11. TPM installer idempotency (real run, pre-seeded dir) ----------

printf '\n[11/12] TPM installer idempotency (pre-seeded)\n'
TPM_TEST_HOME="$(mktemp -d -t monkey-tpm-smoke.XXXXXX)"
(
  export HOME="$TPM_TEST_HOME"
  export XDG_CONFIG_HOME="$TPM_TEST_HOME/.config"
  export MONKEY_DRY_RUN=0
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_tpm.sh"
  MONKEY_OS="linux"
  # shellcheck disable=SC2034
  MONKEY_OS_NAME="Linux (simulated)"
  PATH="$TPM_TEST_HOME/bin:$PATH"
  mkdir -p "$TPM_TEST_HOME/bin"
  cat > "$TPM_TEST_HOME/bin/tmux" <<'SH'
#!/usr/bin/env bash
echo "[fake-tmux] $*" >&2
SH
  chmod +x "$TPM_TEST_HOME/bin/tmux"
  # Pre-seed TPM
  mkdir -p "$TPM_TEST_HOME/.tmux/plugins/tpm"
  touch "$TPM_TEST_HOME/.tmux/plugins/tpm/tpm"
  monkey_install_tpm 2>&1
  # The pre-seeded file must still be the only file there
  count=$(find "$TPM_TEST_HOME/.tmux/plugins/tpm" -type f | wc -l | tr -d ' ')
  [[ "$count" == "1" ]] || fail "idempotent TPM run modified the seeded dir"
  pass "TPM installer skips when already installed"
)
rm -rf "$TPM_TEST_HOME"

# --- 12. TPM installer skips on Windows-native --------------------------

printf '\n[12/12] TPM installer skips on Windows-native\n'
TPM_TEST_HOME="$(mktemp -d -t monkey-tpm-smoke.XXXXXX)"
(
  export HOME="$TPM_TEST_HOME"
  export XDG_CONFIG_HOME="$TPM_TEST_HOME/.config"
  export MONKEY_DRY_RUN=0
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/detect.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/install_tpm.sh"
  MONKEY_OS="windows"
  # shellcheck disable=SC2034
  MONKEY_OS_NAME="Windows (simulated)"
  # Even if a fake tmux is on PATH, Windows must skip
  PATH="$TPM_TEST_HOME/bin:$PATH"
  mkdir -p "$TPM_TEST_HOME/bin"
  cat > "$TPM_TEST_HOME/bin/tmux" <<'SH'
#!/usr/bin/env bash
echo "[fake-tmux] $*" >&2
SH
  chmod +x "$TPM_TEST_HOME/bin/tmux"
  monkey_install_tpm 2>&1
  if [[ -d "$TPM_TEST_HOME/.tmux/plugins/tpm" ]]; then
    fail "TPM installer ran on Windows-native"
  fi
  pass "TPM installer skipped on Windows-native"
)
rm -rf "$TPM_TEST_HOME"

printf '\n\033[32mAll smoke tests passed.\033[0m\n'
