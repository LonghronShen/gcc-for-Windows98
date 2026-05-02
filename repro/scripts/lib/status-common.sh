#!/usr/bin/env bash

# Shared helpers for utils/*-status.sh scripts.

status_say() {
  printf '%s\n' "$*"
}

status_section() {
  printf '\n== %s ==\n' "$*"
}

status_exists_line() {
  local path="$1"
  if [[ -e "$path" ]]; then
    status_say "present: $path"
  else
    status_say "missing: $path"
  fi
}

status_file_meta() {
  local path="$1"
  if [[ -f "$path" ]]; then
    stat --printf='path=%n\nsize=%s bytes\nmtime=%y\n' "$path"
  else
    status_say "missing: $path"
  fi
}

status_sha256_if_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    sha256sum "$path" || true
  fi
}

status_latest_file() {
  local dir="$1"
  local glob="${2:-*}"
  if [[ -d "$dir" ]]; then
    find "$dir" -type f -name "$glob" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-
  fi
}

status_tail_latest() {
  local dir="$1"
  local glob="${2:-*}"
  local lines="${3:-20}"
  local latest
  latest="$(status_latest_file "$dir" "$glob")"
  if [[ -n "$latest" ]]; then
    status_say "$latest"
    tail -n "$lines" "$latest" 2>/dev/null || true
  else
    status_say "no matching logs found"
  fi
}

status_step_line() {
  local step="$1"
  local label="${2:-$1}"
  if is_done "$step"; then
    status_say "[done]  $label"
  else
    status_say "[todo]  $label"
  fi
}
