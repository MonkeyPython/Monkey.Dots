#!/usr/bin/env bash
# lib/shell.sh - Shell resolution + tmux.conf templating
# Sourced by install.sh.
#
# Public:
#   monkey_resolve_shell          -> echoes a sensible default shell path
#   monkey_render_tmux_conf      -> writes a templated tmux.conf to stdout
#                                    (replaces the MONKEY_DEFAULT_SHELL placeholder)

# All MONKEY_* vars are read by callers after this file is sourced.
# shellcheck disable=SC2034

# Resolve the best shell path. Priority:
#   1. The user's currently-running $SHELL (most likely what they expect)
#   2. zsh from common brew locations
#   3. bash as a last resort
monkey_resolve_shell() {
  if [[ -n "${SHELL:-}" && -x "$SHELL" ]]; then
    printf '%s\n' "$SHELL"
    return 0
  fi

  local candidate
  for candidate in \
    /opt/homebrew/bin/zsh \
    /usr/local/bin/zsh \
    /home/linuxbrew/.linuxbrew/bin/zsh \
    /bin/zsh \
    /usr/bin/zsh \
    /opt/homebrew/bin/bash \
    /usr/local/bin/bash \
    /bin/bash \
    /usr/bin/bash; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' "/bin/sh"
}

# Render the tmux.conf from the repo, substituting MONKEY_DEFAULT_SHELL
# with real `set -g default-command` / `set -g default-shell` directives.
# Args: <tmux.conf source path> <shell path>
monkey_render_tmux_conf() {
  local source="$1"
  local shell_path="$2"

  if [[ ! -r "$source" ]]; then
    log_error "tmux.conf source not readable: $source"
    return 1
  fi

  # Build the substitution string. Use %q to safely quote the path
  # even if it contains spaces or shell metacharacters.
  # IMPORTANT: keep the two directives on separate lines WITHOUT using
  # \n in the awk -v string, since awk treats backslashes literally
  # when passed via -v on some platforms. Use a sentinel character and
  # split on it inside awk instead.
  local placeholder='# MONKEY_DEFAULT_SHELL'
  local sentinel='@@MONKEY_NEWLINE@@'
  local cmd_quoted shell_quoted
  cmd_quoted="$(printf '%q' "$shell_path")"
  shell_quoted="$(printf '%q' "$shell_path")"
  local repl_combined="set -g default-command ${cmd_quoted}${sentinel}set -g default-shell ${shell_quoted}"

  awk -v repl="$repl_combined" -v sep="$sentinel" -v sentinel="$placeholder" '
    !done && index($0, sentinel) {
      n = split(repl, parts, sep)
      for (i = 1; i <= n; i++) print parts[i]
      done = 1
      next
    }
    { print }
  ' "$source"
}
