#!/usr/bin/env bash
# Plays whole nights with the autoplay bot (no window, 30x speed) and reports PASS or STUCK.
#   tools/playtest.sh /path/to/godot            # nights 1 and 2, three play styles each
#   tools/playtest.sh /path/to/godot 2 perfect  # one night, one style
# It uses a throwaway HOME so your real save slots are never touched.
set -u
godot=${1:?usage: tools/playtest.sh /path/to/godot [night] [style]}
nights=${2:-"1 2"}
styles=${3:-"perfect sloppy notes_early"}
export HOME=$(mktemp -d)
fail=0
for n in $nights; do
  for s in $styles; do
    out=$(timeout 600 "$godot" --headless --path . -- --autoplay=$s --night=$n --speed=30 2>&1)
    line=$(echo "$out" | grep -E "^BOT RESULT" | head -1)
    echo "night $n  $s: ${line:-NO RESULT (crashed or timed out)}"
    if [[ "$line" != *PASS* ]]; then
      fail=1
      echo "$out" | grep -E "^BOT |^  |SCRIPT ERROR" | tail -12
    fi
  done
done
exit $fail
