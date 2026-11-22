#!/usr/bin/env bash
# Mirrors the newest release's desktop apps into ./dist, the folder the tailnet
# download server serves, so another device on the tailnet can install from this Mac.
set -euo pipefail

repo="theprincesajjad/t3code-unbound"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="$root/dist"
base_url="${T3_UNBOUND_DOWNLOADS_URL:?set T3_UNBOUND_DOWNLOADS_URL to the address this folder is served at}"
mkdir -p "$dist"

version="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n 1)"
[[ -n "$version" ]] || { echo "Could not read the newest release of $repo." >&2; exit 1; }
release="https://github.com/$repo/releases/download/v$version"

sums="$(mktemp)"
trap 'rm -f "$sums"' EXIT
if ! curl -fsSL "$release/SHA256SUMS-desktop" -o "$sums"; then
  echo "v$version has no desktop builds yet."
  exit 0
fi

while read -r expected file; do
  file="${file#\*}"
  [[ -n "$file" ]] || continue
  if [[ -f "$dist/$file" && "$(shasum -a 256 "$dist/$file" | cut -d' ' -f1)" == "$expected" ]]; then
    continue
  fi
  echo "Downloading $file"
  curl -fsSL "$release/$file" -o "$dist/$file.partial"
  [[ "$(shasum -a 256 "$dist/$file.partial" | cut -d' ' -f1)" == "$expected" ]] || { echo "Checksum mismatch for $file." >&2; rm -f "$dist/$file.partial"; exit 1; }
  mv "$dist/$file.partial" "$dist/$file"
done < "$sums"

# Drop apps from older releases, then publish the checksums the installer reads.
for existing in "$dist"/*.dmg; do
  [[ -e "$existing" ]] || continue
  grep -q -- "  $(basename "$existing")\$" "$sums" || rm -f "$existing"
done
cp "$sums" "$dist/SHA256SUMS-desktop"
chmod 644 "$dist/SHA256SUMS-desktop"
echo "$version" > "$dist/VERSION"

# The same installer as the repository's, pointed at this folder instead of GitHub.
sed "s|^base=\"\${T3_UNBOUND_BASE:-}\"|base=\"\${T3_UNBOUND_BASE:-$base_url}\"|" "$root/scripts/install-desktop.sh" > "$dist/install.sh"
cat > "$dist/index.html" <<HTML
<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>T3 Code Unbound $version</title>
<style>
  body { font: 16px/1.5 -apple-system, system-ui, sans-serif; max-width: 40rem; margin: 3rem auto; padding: 0 1rem; color: #1a1a1a; background: #fff; }
  code, pre { font: 13px/1.5 ui-monospace, Menlo, monospace; background: #f3f3f3; border-radius: 6px; }
  pre { padding: .75rem 1rem; overflow-x: auto; }
  code { padding: .1rem .3rem; }
  @media (prefers-color-scheme: dark) { body { color: #eee; background: #161616; } code, pre { background: #262626; } a { color: #8ab4ff; } }
</style>
<h1>T3 Code Unbound $version</h1>
<p>The desktop app with no file attachment size limit. Paste this into Terminal on the Mac you want it on:</p>
<pre>curl -fsSL $base_url/install.sh | sh</pre>
<p>It downloads the right build for that Mac, checks it, and puts it in Applications. Run it again to update.</p>
<p>Installing by hand from a downloaded disk image needs one extra step, because the app is not signed by an Apple developer account: after copying it to Applications, run <code>xattr -dr com.apple.quarantine "/Applications/T3 Code (Beta).app"</code>.</p>
<ul>
$(while read -r _ file; do file="${file#\*}"; [[ -n "$file" ]] && echo "  <li><a href=\"$file\">$file</a></li>"; done < "$sums")
</ul>
HTML
echo "dist/ holds the v$version desktop apps."
