#!/usr/bin/env bash
# MLOD sources -> ODOL in the mission, for any list of models: bash binarize_mlods.sh <mlod.p3d>...
# p3dmemories.md section 7: binarize takes DIRECTORIES, backslash Z:\ paths, LOWERCASE source names; the
# "Cannot load material file" lines are expected (no P: drive). Output is ODOL v75; header checked by the reader.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MISSION="$HERE/../../mission/Armapunk2035.Malden"
SRC="$HOME/bin_src_$$"; DST="$HOME/bin_dst_$$"
rm -rf "$SRC" "$DST"; mkdir -p "$SRC" "$DST"
declare -A CASED
for f in "$@"; do
  head -c 4 "$f" | grep -q MLOD || { echo "not MLOD: $f"; exit 1; }
  b="$(basename "$f")"; l="$(echo "$b" | tr 'A-Z' 'a-z')"; CASED["$l"]="$b"; cp "$f" "$SRC/$l"
done
export WINEPREFIX="$HOME/.wine"
( cd "$HOME/.local/share/Steam/steamapps/common/Arma 3 Tools/Binarize" && \
  wine64 binarize_x64.exe -always -silent -maxProcesses=6 "Z:\\home\\timb\\bin_src_$$" "Z:\\home\\timb\\bin_dst_$$" ) 2>&1 \
  | grep -v 'Cannot load material file' || true
n=0
for f in "$DST"/*.p3d; do
  head -c 4 "$f" | grep -q ODOL || { echo "NOT ODOL: $f"; exit 1; }
  l="$(basename "$f")"; cp "$f" "$MISSION/custom_p3ds/${CASED[$l]}"; n=$((n+1))
done
[ "$n" -eq "$#" ] || { echo "expected $# binarized models, got $n"; exit 1; }
python3 - "$MISSION/custom_p3ds" "$@" <<'PY'
import os, sys
sys.path.insert(0, '/home/timb/blender_work')
from odol73_to_mlod import read_odol
d = sys.argv[1]; bad = 0
for f in sys.argv[2:]:
    n = os.path.basename(f); o = read_odol(os.path.join(d, n))
    res, bc = o['resolutions'], o['modelinfo']['boundingCenter']
    ok = res[0] == 1.0 and all(abs(c) < 0.05 for c in bc)
    bad += not ok
    print(f"  [{'PASS' if ok else 'FAIL'}] {n:34} v{o['version']} lods={len(res)} boundingCenter={[round(c, 3) for c in bc]}")
sys.exit(1 if bad else 0)
PY
rm -rf "$SRC" "$DST"
echo "binarized $n model(s) into custom_p3ds"
