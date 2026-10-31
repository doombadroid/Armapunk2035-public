#!/usr/bin/env bash
# Signs the built addon for verifySignatures=2. Run AFTER build_addon.sh.
# Private key lives OUTSIDE the repo: ~/loonybin-keys/maldenradio.biprivatekey
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
armake2="${ARMAKE2:-$HOME/.cargo/bin/armake2}"
key="${MALDENRADIO_KEY:-$HOME/loonybin-keys/maldenradio.biprivatekey}"
[ -f "$key" ] || { echo "missing private key: $key"; exit 1; }
mod="$here/dist/@Armapunk2035"
# every PBO in the mod needs its own .bisign — an unsigned one kicks players on verifySignatures=2
for pbo in "$mod"/addons/*.pbo; do
  "$armake2" sign "$key" "$pbo"
done
mkdir -p "$mod/keys" && cp "${key%.biprivatekey}.bikey" "$mod/keys/"
ls "$mod/addons/" "$mod/keys/"
