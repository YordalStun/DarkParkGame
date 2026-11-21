#!/usr/bin/env bash
# Downloads the CC0 source recordings used by tools/build_audio.py.
# Usage: tools/fetch_audio.sh <download folder>
set -euo pipefail
DEST="${1:?usage: fetch_audio.sh <download folder>}"
mkdir -p "$DEST" && cd "$DEST"
B=https://opengameart.org/sites/default/files
get() { curl -fsSL -o "$2" "$B/$1"; echo "got $2"; }
get "Rain%20OGG.zip"                 "Rain OGG.zip"
get amb_rain2.ogg                    amb_rain2.ogg
get rain_on_window_loop.wav          rain_on_window_loop.wav
get rain-gutter-loop_0.mp3           rain-gutter-loop_0.mp3
get rain-thunder.ogg                 rain-thunder.ogg
get windy_ambiance.ogg               windy_ambiance.ogg
get sfx_100_v2.zip                   sfx_100_v2.zip
get low-rumbling-176033.mp3          low-rumbling-176033.mp3
get tree_creak.ogg                   tree_creak.ogg
get buzz.ogg                         buzz.ogg
get mouseclick.wav                   mouseclick.wav
unzip -o -q "Rain OGG.zip" -d "Rain OGG"
unzip -o -q sfx_100_v2.zip -d sfx_100_v2
