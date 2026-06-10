#!/usr/bin/env bash
# lib/log.sh - Tiny logging helpers
# Sourced by install.sh and lib/*.sh

if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'
  _C_GREEN=$'\033[32m'
  _C_YELLOW=$'\033[33m'
  _C_RED=$'\033[31m'
  _C_CYAN=$'\033[36m'
  _C_DIM=$'\033[2m'
else
  _C_RESET="" _C_GREEN="" _C_YELLOW="" _C_RED="" _C_CYAN="" _C_DIM=""
fi

log_info()  { printf '%s[info]%s  %s\n'  "$_C_CYAN"  "$_C_RESET" "$*"; }
log_ok()    { printf '%s[ ok ]%s  %s\n'  "$_C_GREEN" "$_C_RESET" "$*"; }
log_warn()  { printf '%s[warn]%s  %s\n'  "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%s[fail]%s  %s\n'  "$_C_RED"   "$_C_RESET" "$*" >&2; }
log_step()  { printf '\n%s==> %s%s\n'    "$_C_CYAN"  "$*" "$_C_RESET"; }
log_dim()   { printf '%s%s%s\n'          "$_C_DIM"   "$*" "$_C_RESET"; }
