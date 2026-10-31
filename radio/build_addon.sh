#!/usr/bin/env bash
# Builds radio/dist/@Armapunk2035/ : windows DLL + marker PBO. Unsigned (dev verifySignatures=0);
# signing is layered on by radio/sign_addon.sh (Task 12) before any live/Workshop release.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/extension"
# this box's mingw64-toolchain merges libgcc_eh into libgcc.a; rustc's link line expects the
# split archive -- provide it as a build-time shim (no system files touched, nothing committed)
shim="${TMPDIR:-/tmp}/maldenradio-libgcc-eh-shim"
mkdir -p "$shim"
libgcc="$(x86_64-w64-mingw32-gcc -print-libgcc-file-name)"
[ -f "$shim/libgcc_eh.a" ] || cp "$libgcc" "$shim/libgcc_eh.a"
cargo="${CARGO:-$HOME/.cargo/bin/cargo}"; command -v "$cargo" >/dev/null || cargo=cargo
RUSTFLAGS="${RUSTFLAGS:-} -L $shim" "$cargo" build --release --target x86_64-pc-windows-gnu
mod="$here/dist/@Armapunk2035"
rm -rf "$mod" "$here/dist/pbo_src" && mkdir -p "$mod/addons" "$here/dist/pbo_src"
# One PBO per addon/<name>/ source tree. The PBO prefix MUST equal the directory name: the
# third-party p3d/rvmat files hardcode absolute paths like \zee_fsof\Data\... and \JAS_GPNVG18\...,
# so renaming a prefix silently unloads every texture on those models.
for src in "$here"/addon/*/; do
  name="$(basename "$src")"
  python3 "$here/make_pbo.py" "$src" "$mod/addons/$name.pbo" "$name"
done
cp "$here/extension/target/x86_64-pc-windows-gnu/release/maldenradio.dll" "$mod/maldenradio_x64.dll"
cp "$here/addon/mod.cpp" "$here/addon/meta.cpp" "$mod/"   # launcher identity (MODS tab visibility)
echo "built $mod"
