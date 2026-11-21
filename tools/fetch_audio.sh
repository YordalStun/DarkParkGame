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

# Radio music (CC0) goes in a "music" subfolder; pass it as the second argument
# to build_audio.py.
mkdir -p music && cd music
get midnight_drive.ogg               midnight_drive.ogg
get "Jazz%20Saxaphone.mp3"           "Jazz Saxaphone.mp3"
get dimlylit.mp3                     dimlylit.mp3
get "Slow%20Stride%20Loop.ogg"       "Slow Stride Loop.ogg"
get "Jazz%20Take%202.mp3"            "Jazz Take 2.mp3"
get cool_city_bpm124.ogg             cool_city_bpm124.ogg
get Elevator.mp3                     Elevator.mp3
