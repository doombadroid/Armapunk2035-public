#!/usr/bin/env bash
# Encode per-aspect intro (plays once) + engineered held loop, then gates.
# System ffmpeg on this box lacks libtheora (Gentoo USE), so a static build
# is cached in .ffmpeg-static/ (johnvansickle release, includes libtheora).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

FF=".ffmpeg-static/ffmpeg"
FP=".ffmpeg-static/ffprobe"
if [ ! -x "$FF" ]; then
  mkdir -p .ffmpeg-static
  tarball=".ffmpeg-static/ffmpeg-release-amd64-static.tar.xz"
  curl -fsSL -o "$tarball" https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
  tar xf "$tarball" -C .ffmpeg-static --strip-components=1
fi
"$FF" -hide_banner -h encoder=libtheora >/dev/null || { echo "static ffmpeg lacks libtheora"; exit 1; }

vid="../radio/addon/armapunk_menu/video"
mkdir -p "$vid"
rm -f "$vid"/bg_169.ogv "$vid"/bg_219.ogv "$vid"/intro.ogv "$vid"/idle.ogv   # superseded

# Intros: fade in from black (covers the game-load pop). q8 — boot text detail.
for a in 169 219; do
  [ -f "out/frames/intro$a/f0299.png" ] || { echo "intro$a frames missing"; exit 1; }
  "$FF" -y -hide_banner -loglevel warning -framerate 30 -i "out/frames/intro$a/f%04d.png" \
    -vf "fade=t=in:st=0:d=0.25" \
    -c:v libtheora -q:v 8 -pix_fmt yuv420p -an "$vid/intro_$a.ogv"
done
# Loops: no fades — the loop seam hides inside the baked glitch burst, and
# restarts are script-driven (VideoStopped re-arms the texture). q7 for size.
for a in 169 219; do
  [ -f "out/frames/loop$a/f1799.png" ] || { echo "loop$a frames missing"; exit 1; }
  "$FF" -y -hide_banner -loglevel warning -framerate 30 -i "out/frames/loop$a/f%04d.png" \
    -c:v libtheora -q:v 7 -pix_fmt yuv420p -an "$vid/loop_$a.ogv"
done

for f in intro_169 intro_219 loop_169 loop_219; do
  echo -n "$f: "
  "$FP" -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of csv=p=0 "$vid/$f.ogv" | tr '\n' ' '
  "$FP" -v error -show_entries format=duration -of csv=p=0 "$vid/$f.ogv"
done

python3 gates.py
ls -la "$vid"
