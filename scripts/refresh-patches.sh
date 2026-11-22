#!/usr/bin/env bash
# Rebases the patch series onto an upstream release and rewrites patches/.
#
#   scripts/refresh-patches.sh 0.1.12
#
# Works in ./src, a clone of upstream with the series on the `unbound` branch.
# On a conflict it stops inside the rebase: resolve it, run `git rebase --continue`
# in ./src, then run this script again with the same version.
set -euo pipefail

version="${1:?usage: refresh-patches.sh <upstream version, for example 0.1.12>}"
version="${version#v}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$root/src"

if [[ ! -d "$src/.git" ]]; then
  git clone --filter=blob:none https://github.com/pingdotgg/t3code.git "$src"
fi
cd "$src"

if [[ -d .git/rebase-merge || -d .git/rebase-apply ]]; then
  echo "A rebase is in progress in $src. Finish it with 'git rebase --continue' first." >&2
  exit 1
fi

git fetch -q origin "refs/tags/v$version:refs/tags/v$version"

if ! git rev-parse -q --verify refs/heads/unbound >/dev/null; then
  base="$(tr -d '[:space:]' < "$root/patches/BASE")"
  git fetch -q origin "refs/tags/v$base:refs/tags/v$base"
  git checkout -q -B unbound "v$base"
  shopt -s nullglob
  patches=("$root"/patches/*.patch)
  if (( ${#patches[@]} > 0 )); then git am -3 "${patches[@]}"; fi
fi

git checkout -q unbound
old_base="$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*-*')"
if [[ "$old_base" != "v$version" ]]; then
  git rebase --onto "v$version" "$old_base" unbound
fi

rm -f "$root"/patches/*.patch
git format-patch -q --no-signature --zero-commit -N -o "$root/patches" "v$version..unbound"
echo "$version" > "$root/patches/BASE"
echo "patches/ now holds $(ls "$root"/patches/*.patch 2>/dev/null | wc -l | tr -d ' ') patch(es) on v$version."
