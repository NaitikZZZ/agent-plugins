#!/usr/bin/env bash

clay_valid_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

clay_version_at_least() {
  local current="${1%%+*}" minimum="$2" a b c x y z
  clay_valid_version "$current" && clay_valid_version "$minimum" || return 1
  IFS=. read -r a b c <<< "$current"
  IFS=. read -r x y z <<< "$minimum"
  (( 10#$a > 10#$x || (10#$a == 10#$x && 10#$b > 10#$y) || (10#$a == 10#$x && 10#$b == 10#$y && 10#$c >= 10#$z) ))
}

clay_is_legacy() {
  case "$1" in
    */plugins/cache/*/clay/*/bin/clay|*/plugins/local/clay/bin/clay|*/.config/clay-plugin/clay/bin/clay) return 0 ;;
  esac
  [ -f "$1" ] || return 1
  local contents
  contents=$(head -c 8192 "$1" | LC_ALL=C tr -d '\000')
  printf '%s' "$contents" | LC_ALL=C grep -Eq 'no bundled launcher found|plugins/cache/.*clay/.*bin/clay|plugins/local/clay/bin/clay|\.config/clay-plugin/clay/bin/clay' && return 0
  [[ "$contents" == *'clay-run/agent-plugins'* && "$contents" == *'version_file="$bin_dir/cli-version"'* ]]
}

clay_resolve_path() {
  local target="$1" link count=0
  while [ -L "$target" ]; do
    count=$((count + 1))
    [ "$count" -le 20 ] || return 1
    link=$(readlink "$target") || return 1
    case "$link" in
      /*) target="$link" ;;
      *) target="$(dirname "$target")/$link" ;;
    esac
  done
  printf '%s\n' "$target"
}

clay_canonical_path() {
  local target
  target=$(clay_resolve_path "$1") || return 1
  if [ -e "$target" ]; then
    target="$(cd -- "$(dirname -- "$target")" && pwd -P)/$(basename -- "$target")"
  fi
  printf '%s\n' "$target"
}

clay_dir_on_path() {
  local dir="${1%/}" canonical entry
  canonical=$(cd -- "$dir" 2>/dev/null && pwd -P)
  local IFS=:
  for entry in $PATH; do
    [ "${entry%/}" = "$dir" ] && return 0
    [ -n "$canonical" ] && [ "$(cd -- "$entry" 2>/dev/null && pwd -P)" = "$canonical" ] && return 0
  done
  return 1
}

clay_install_method() {
  local target magic
  [ -L "$1" ] && [ ! -e "$1" ] && { echo dangling; return; }
  clay_is_legacy "$1" && { echo legacy; return; }
  target=$(clay_resolve_path "$1") || { echo unknown; return; }
  case "$target" in
    */node_modules/@clay-run/cli/*) echo npm ;;
    */node_modules/@claypi/cli/*) echo legacy-npm ;;
    *)
      magic=$(od -An -N4 -tx1 "$target" 2>/dev/null | tr -d '[:space:]')
      case "$magic" in
        7f454c46|feedface|cefaedfe|feedfacf|cffaedfe|cafebabe|bebafeca|cafebabf|bfbafeca) echo native ;;
        *) echo unknown ;;
      esac
      ;;
  esac
}

# Never let a broken executable hold up a session-start hook indefinitely.
clay_read_version() {
  local output pid watchdog result
  output=$(mktemp "${TMPDIR:-/tmp}/clay-version.XXXXXX") || return 1
  "$1" --version > "$output" 2>/dev/null &
  pid=$!
  ( sleep 3; kill "$pid" 2>/dev/null; sleep 1; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  watchdog=$!
  wait "$pid" 2>/dev/null
  result=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  if [ "$result" -eq 0 ]; then
    head -n 1 "$output" | tr -d '\r'
  fi
  rm -f "$output"
  return "$result"
}
