#!/usr/bin/env bash
# Exports DarkPark.exe and puts the Chromium engine files next to it, then zips
# the folder. Usage: tools/package_windows.sh <godot binary> [out dir]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:?usage: package_windows.sh <godot binary> [out dir]}"
OUT="${2:-build/windows}"
rm -rf "$OUT" && mkdir -p "$OUT/DarkPark"
"$GODOT" --headless --path . --export-release "Windows Desktop" "$OUT/DarkPark/DarkPark.exe"
if [ -d cef_artifacts/windows ]; then
	# gdCEF looks for its files in the folder that holds libgdcef.dll (next to the exe).
	for f in cef_artifacts/windows/*; do
		case "$f" in *.lib|*.exp|*/vulkan-1.dll) ;;  # vulkan-1.dll would replace the system Vulkan loader for the game itself
		 *) cp -r "$f" "$OUT/DarkPark/" ;; esac
	done
else
	echo "warning: no cef_artifacts/ (run tools/fetch_cef.sh) - the browser will use its simple renderer"
fi
(cd "$OUT" && rm -f DarkPark-windows.zip && python3 - <<'PY'
import os, zipfile
z = zipfile.ZipFile("DarkPark-windows.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=6)
for root, _, files in os.walk("DarkPark"):
    for f in files:
        z.write(os.path.join(root, f))
z.close()
PY
)
ls -la "$OUT" "$OUT/DarkPark" | head -40
