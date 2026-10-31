#!/usr/bin/env bash
# Generates royalty-free tone "songs" into ~/radio-music so the dev stream has content.
set -euo pipefail
base="${RADIO_MUSIC_DIR:-$HOME/radio-music}"
mkdir -p "$base/origin" "$base/khr"
gen() { ffmpeg -y -loglevel error -f lavfi -i "sine=frequency=$2:duration=45" \
        -af "volume=0.25" -metadata title="Tone $2 Hz" -metadata artist="Malden Radio Test" \
        -codec:a flac "$base/$1/tone_$2.flac"; }
gen origin 440; gen origin 660; gen khr 880; gen khr 1320
echo "test tracks in $base"
