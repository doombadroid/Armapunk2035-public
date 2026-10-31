#!/usr/bin/env bash
# MLOD (scratchpad/skyscraper, the source) -> ODOL (mission custom_p3ds, what ships).
# p3dmemories.md section 7: binarize takes DIRECTORIES, wants BACKSLASH Z:\ paths and LOWERCASE
# source names, and prints "Cannot load material file" for every a3 rvmat because there is no P:
# drive here -- expected, the path is written through unchanged. Output is ODOL v75.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MISSION="$HERE/../../mission/Armapunk2035.Malden"
SRC="$HOME/f770_bin_src"; DST="$HOME/f770_bin_dst"
rm -rf "$SRC" "$DST"; mkdir -p "$SRC" "$DST"
n=0
for f in "$HERE"/ap_printer_f770_*_r4.p3d; do
  head -c 4 "$f" | grep -q MLOD || { echo "source is not MLOD: $f"; exit 1; }
  cp "$f" "$SRC/$(basename "$f" | tr 'A-Z' 'a-z')"; n=$((n+1))
done
[ "$n" -eq 6 ] || { echo "expected 6 MLOD sources, found $n (run build_f770.py first)"; exit 1; }
export WINEPREFIX="$HOME/.wine"
( cd "$HOME/.local/share/Steam/steamapps/common/Arma 3 Tools/Binarize" && \
  wine64 binarize_x64.exe -always -silent -maxProcesses=6 "Z:\\home\\timb\\f770_bin_src" "Z:\\home\\timb\\f770_bin_dst" ) 2>&1 \
  | grep -v 'Cannot load material file' || true
m=0
for f in "$DST"/ap_printer_f770_*_r4.p3d; do
  head -c 4 "$f" | grep -q ODOL || { echo "NOT ODOL: $f"; exit 1; }
  cp "$f" "$MISSION/custom_p3ds/$(basename "$f")"; m=$((m+1))
done
[ "$m" -eq 6 ] || { echo "expected 6 binarized models, got $m"; exit 1; }
python3 - "$MISSION/custom_p3ds" <<'EOF'
import os, sys
sys.path.insert(0, '/home/timb/blender_work')
from odol73_to_mlod import read_odol
d = sys.argv[1]; bad = 0
for n in ['body', 'bridge', 'head', 'platform', 'screen_ready', 'screen_printing']:
    o = read_odol(os.path.join(d, f'ap_printer_f770_{n}_r4.p3d'))
    res, bc = o['resolutions'], o['modelinfo']['boundingCenter']
    ok = 2 <= len(res) <= 5 and res[0] == 1.0 and all(abs(c) < 0.01 for c in bc)
    bad += not ok
    print(f"  [{'PASS' if ok else 'FAIL'}] {n:16} v{o['version']} lods={res} boundingCenter={[round(c, 4) for c in bc]}")
sys.exit(1 if bad else 0)
EOF
rm -rf "$SRC" "$DST"
echo "binarized 6 models into custom_p3ds"
