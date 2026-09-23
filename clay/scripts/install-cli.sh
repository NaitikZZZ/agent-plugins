#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/cli-install-common.sh"

fail() { printf 'clay: %s\n' "$*" >&2; exit 1; }
method=auto
version=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --method) [ "$#" -ge 2 ] || fail 'Missing --method value'; method="$2"; shift 2 ;;
    --version) [ "$#" -ge 2 ] || fail 'Missing --version value'; version="$2"; shift 2 ;;
    *) fail "Unknown argument: $1. Usage: bash install-cli.sh --version X.Y.Z [--method auto|native|npm]" ;;
  esac
done
clay_valid_version "$version" || fail 'Supply an exact release with --version X.Y.Z'
case "$method" in auto|native|npm) ;; *) fail "Unknown installation method: $method" ;; esac
[ -n "${HOME:-}" ] || fail 'HOME must be set'

report_path() {
  clay_dir_on_path "$(dirname "$1")" || printf 'Add %s to PATH in your shell configuration. Use the absolute executable path in this session.\n' "$(dirname "$1")"
  local resolved
  resolved=$(command -v clay || true)
  if [ -z "$resolved" ] || [ "$(clay_canonical_path "$resolved")" != "$(clay_canonical_path "$1")" ]; then
    printf 'PATH currently resolves clay to %s. Use %s until PATH is corrected.\n' "${resolved:-nothing}" "$1"
  fi
}

existing=$(command -v clay || true)
if [ -z "$existing" ] && { [ -e "$HOME/.local/bin/clay" ] || [ -L "$HOME/.local/bin/clay" ]; }; then
  existing="$HOME/.local/bin/clay"
fi
existing_method=missing
if [ -n "$existing" ]; then
  existing_method=$(clay_install_method "$existing")
fi
if [ "$method" = auto ]; then
  case "$existing_method" in
    npm|legacy-npm) method=npm ;;
    missing|legacy|dangling|native) method=native ;;
    *) fail "Unrecognized clay executable at $existing; inspect it before choosing --method native or npm" ;;
  esac
fi
if [ -n "$existing" ] && [ "$existing_method" = "$method" ]; then
  current=$(clay_read_version "$existing" || true)
  if clay_version_at_least "$current" "$version"; then
    printf 'Clay %s is already installed at %s\n' "$current" "$existing"
    report_path "$existing"
    exit 0
  fi
fi

if [ "$method" = npm ]; then
  command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1 || fail 'The npm installation requires Node 22.21+ (Node 22) and npm'
  node -e 'const [major, minor] = process.versions.node.split(".").map(Number); process.exit(major === 22 && minor >= 21 ? 0 : 1)' || fail 'Install a supported Node 22 version (22.21 or later) before using npm'
  npm install --global --ignore-scripts "@clay-run/cli@$version" || fail 'npm installation failed; resolve the reported error and retry'
  prefix=$(npm prefix --global)
  installed="$prefix/bin/clay"
  installed_version=$(clay_read_version "$installed" || true)
  clay_version_at_least "$installed_version" "$version" || fail "npm finished but $installed did not report a compatible version"
else
  installed="$HOME/.local/bin/clay"
  reported="$installed"
  if [ "$existing_method" = native ]; then
    installed=$(clay_resolve_path "$existing") || fail 'Cannot resolve the current native installation'
    reported="$existing"
  fi
  if [ -e "$installed" ] || [ -L "$installed" ]; then
    target_method=$(clay_install_method "$installed")
    case "$target_method" in native|legacy|dangling) ;; *) fail "Refusing to overwrite $installed ($target_method); remove or relocate that installation first" ;; esac
  fi
  if [ "${target_method:-missing}" = native ]; then
    current=$(clay_read_version "$installed" || true)
    clay_valid_version "${current%%+*}" || fail "$installed does not report a Clay version; remove or relocate that executable first"
    if clay_version_at_least "$current" "$version"; then
      printf 'Clay %s is already installed at %s\n' "$current" "$installed"
      report_path "$reported"
      exit 0
    fi
    "$installed" update || fail 'clay update failed; resolve the reported error and retry'
    installed_version=$(clay_read_version "$installed" || true)
    clay_version_at_least "$installed_version" "$version" || fail "clay update finished but $installed does not meet minimum version $version"
  else
    case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) fail 'Native installation supports macOS and Linux' ;; esac
    case "$(uname -m)" in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=x64 ;; *) fail 'Unsupported CPU architecture' ;; esac
    if [ "$os" = linux ]; then
      case "$arch" in arm64) loader=/lib/ld-linux-aarch64.so.1 ;; x64) loader=/lib64/ld-linux-x86-64.so.2 ;; esac
      [ -e "$loader" ] || fail 'The native CLI requires glibc; use --method npm on other Linux systems'
    fi
    install_dir=$(dirname "$installed")
    mkdir -p "$install_dir" 2>/dev/null && work=$(mktemp -d "$install_dir/.clay-install.XXXXXX" 2>/dev/null) || fail "Cannot write to $install_dir; existing installation was not changed"
    trap 'rm -rf "$work"' EXIT
    asset="clay-$os-$arch"
    release="https://github.com/clay-run/agent-plugins/releases/download/clay-cli-v$version"
    download() {
      if command -v curl >/dev/null 2>&1; then
        curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 600 --retry 2 "$1" -o "$2" || fail "Could not download $1; existing installation was not changed"
      else
        fail 'curl is required to download the native CLI'
      fi
    }
    download "$release/checksums.txt" "$work/checksums.txt"
    expected=$(awk -v name="$asset" '$2 == name {print $1}' "$work/checksums.txt")
    [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || fail "Missing or invalid checksum for $asset"
    download "$release/$asset" "$work/clay"
    if command -v sha256sum >/dev/null 2>&1; then
      actual=$(sha256sum "$work/clay" | awk '{print $1}')
    else
      actual=$(shasum -a 256 "$work/clay" | awk '{print $1}')
    fi
    [ "$actual" = "$expected" ] || fail 'Checksum mismatch; existing installation was not changed'
    chmod 755 "$work/clay"
    installed_version=$(clay_read_version "$work/clay" || true)
    [ "${installed_version%%+*}" = "$version" ] || fail 'Downloaded CLI could not run or reported the wrong version; existing installation was not changed. If your organization requires Node-based execution, use --method npm'
    mv -f "$work/clay" "$installed"
  fi
fi
[ "$method" = npm ] && reported="$installed"

# Remove only the legacy forwarder after the replacement has passed verification.
if [ "$method" = npm ] && clay_is_legacy "$HOME/.local/bin/clay"; then
  rm "$HOME/.local/bin/clay"
fi
printf 'Installed Clay %s at %s\n' "$installed_version" "$installed"
report_path "$reported"
