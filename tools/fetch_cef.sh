#!/usr/bin/env bash
# Downloads the Chromium web engine (gdCEF, MIT; Chromium/CEF, BSD) used by the
# in-game browser and unpacks it to ./cef_artifacts (Windows and Linux parts).
# It is ~2 GB unpacked, so it is not kept in git. Run once after cloning:
#   tools/fetch_cef.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VER=0.20.0
ZIP="gdcef-${VER}_godot-4.5.zip"
URL="https://github.com/Lecrapouille/gdcef/releases/download/v${VER}-godot4/${ZIP}"
TMP="$(mktemp -d)"
echo "Downloading $URL (about 1 GB)..."
curl -fL -o "$TMP/$ZIP" "$URL"
rm -rf cef_artifacts
unzip -q "$TMP/$ZIP" 'gdcef/cef_artifacts/*' -d "$TMP"
mv "$TMP/gdcef/cef_artifacts" cef_artifacts
rm -rf cef_artifacts/macos "$TMP"
sed -i.bak '/macos/d' cef_artifacts/gdcef.gdextension && rm -f cef_artifacts/gdcef.gdextension.bak
echo "Installed cef_artifacts/"
