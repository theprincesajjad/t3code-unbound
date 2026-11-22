#!/bin/sh
# Installs the T3 Code Unbound desktop app on this Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/theprincesajjad/t3code-unbound/main/scripts/install-desktop.sh | sh
#
# The app is signed ad hoc, not by an Apple developer account, so Gatekeeper
# blocks a copy downloaded in a browser. This script downloads it with curl,
# which sets no quarantine flag, checks its SHA-256, and copies it into
# /Applications. Run it again to update.
#
#   T3_UNBOUND_BASE     where the files are (default: this repository's latest release)
#   T3_UNBOUND_VERSION  version to install (default: the newest at that location)
set -eu

repo="theprincesajjad/t3code-unbound"
fail() { echo "install-desktop: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "this installs the macOS app."
case "$(uname -m)" in
  arm64) arch="arm64" ;;
  x86_64) arch="x64" ;;
  *) fail "unsupported Mac architecture $(uname -m)." ;;
esac

base="${T3_UNBOUND_BASE:-}"
version="${T3_UNBOUND_VERSION:-}"
version="${version#v}"
if [ -z "$base" ]; then
  if [ -z "$version" ]; then
    version="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n 1)"
    [ -n "$version" ] || fail "could not read the newest release of $repo."
  fi
  base="https://github.com/$repo/releases/download/v$version"
fi
base="${base%/}"

work="$(mktemp -d)"
mount="$work/volume"
cleanup() {
  hdiutil detach "$mount" -force >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT INT TERM

curl -fsSL "$base/SHA256SUMS-desktop" -o "$work/SHA256SUMS-desktop" || fail "no desktop builds at $base."
# Lines are "<sha256>  <file>"; pick this Mac's architecture, and the version when one was asked for.
line="$(grep -- "-$arch\.dmg\$" "$work/SHA256SUMS-desktop" | { if [ -n "$version" ]; then grep -- "-$version-"; else cat; fi; } | tail -n 1)"
[ -n "$line" ] || fail "no $arch build listed at $base."
expected="${line%% *}"
file="${line##* }"
file="${file#\*}"

echo "Downloading $file"
curl -fL --progress-bar "$base/$file" -o "$work/$file"
actual="$(shasum -a 256 "$work/$file" | cut -d' ' -f1)"
[ "$actual" = "$expected" ] || fail "checksum mismatch for $file."

mkdir "$mount"
hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$work/$file" >/dev/null
app="$(ls -d "$mount"/*.app 2>/dev/null | head -n 1)"
[ -n "$app" ] || fail "the disk image holds no app."
name="$(basename "$app")"
target="/Applications/$name"

if pgrep -f "$target/Contents/MacOS/" >/dev/null 2>&1; then
  echo "Quitting ${name%.app}"
  osascript -e "quit app \"${name%.app}\"" >/dev/null 2>&1 || true
  sleep 3
fi

echo "Installing $target"
rm -rf "$target"
ditto "$app" "$target"
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

echo "Installed ${name%.app}. Opening it."
open "$target"
