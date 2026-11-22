#!/usr/bin/env bash
# Switches a machine that already runs T3 Code to the Unbound build.
#
#   scripts/install.sh            install the newest Unbound release
#   scripts/install.sh 0.1.11     install that version
#   scripts/install.sh --restart  also restart the background service now
#
# T3's own updater does the work: it downloads the archive, checks its SHA-256,
# confirms the build supports this machine's database, then repoints the `t3`
# launcher and the background service. Without --restart the service keeps
# running its current version until `t3 service restart`.
set -euo pipefail

repo="theprincesajjad/t3code-unbound"
version=""
restart=()
for arg in "$@"; do
  case "$arg" in
    --restart) restart=(--yes) ;;
    *) version="${arg#v}" ;;
  esac
done

if ! command -v t3 >/dev/null 2>&1; then
  echo "t3 is not installed. Install it first with:" >&2
  echo "  curl -fsSL https://t3.codes/install.sh | T3CODE_RELEASE_BASE_URL=https://github.com/$repo/releases/download T3CODE_VERSION=<version> sh" >&2
  exit 1
fi

if [[ -z "$version" ]]; then
  version="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n 1)"
  if [[ -z "$version" ]]; then
    echo "Could not read the newest release of $repo." >&2
    exit 1
  fi
fi

echo "Installing T3 Code Unbound $version (currently $(t3 --version))."
# An official t3 only knows the official release index, so name the version and the mirror.
# Once the Unbound build is running, plain `t3 update` follows this repository by itself.
T3CODE_RELEASE_BASE_URL="https://github.com/$repo/releases/download" \
  t3 update "$version" ${restart[@]+"${restart[@]}"}
