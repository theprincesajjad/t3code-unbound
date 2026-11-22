#!/usr/bin/env bash
# Applies patches/*.patch to the upstream checkout in the current directory.
set -euo pipefail

patch_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../patches" && pwd)"
shopt -s nullglob
patches=("$patch_dir"/*.patch)
if (( ${#patches[@]} == 0 )); then
  echo "No patches to apply."
  exit 0
fi

for patch in "${patches[@]}"; do
  echo "Applying $(basename "$patch")"
  # Three-way so a patch survives upstream edits near the lines it touches.
  if ! git apply --3way --index "$patch"; then
    echo "::error::$(basename "$patch") does not apply to this upstream version."
    git status --short | head -n 40
    exit 1
  fi
done
echo "Applied ${#patches[@]} patch(es)."
