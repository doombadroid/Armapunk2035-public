#!/usr/bin/env python3
r"""
Minimal Arma 3 PBO packer (unbinarized) — stdlib only.

WHY: the prebuilt AP_server.pbo went stale (built before later source fixes, e.g. the broken
fn_weatherSync that crashed server init -> client hung at waitUntil{AP_session_completed}).
No makepbo/armake/HEMTT installed, and Arma's dedicated addon scanner only loads *.pbo (it will
NOT load an unpacked addon folder; -filePatching is for missions, not addons/). So we pack here.

PBO format packed:
  [version entry] filename="" , mime=0x56657273 ("Vers"), 4x uint32=0, then null-terminated
                  key\0value\0 property pairs, terminated by a lone \0   (we emit prefix=<$PBOPREFIX$>)
  [file entries]  filename(backslashes)\0, mime=0(raw), origsize=0, reserved=0, time=0, datasize
  [terminator]    filename=""\0 + 5x uint32=0
  [data block]    file contents concatenated in entry order
  [checksum]      0x00 + SHA1(everything before the checksum)

Usage: pack_pbo.py <src_dir> <out.pbo> [--no-prefix] [--exclude-dir=rel/path ...] [--exclude-list=<file>]
  Addons (e.g. AP_server): need a prefix (from $PBOPREFIX$ or dirname) so paths like
    \AP_server\... resolve. Default behavior.
  Missions (e.g. Armapunk2035.Malden): must have NO prefix property — the engine identifies the
    mission by the .pbo filename and roots scripts at the pbo. A wrong prefix makes
    initPlayerLocal.sqf/init.sqf fail to auto-run. Pass --no-prefix for missions.
  --exclude-list=<file>: one src-relative FILE path per line (forward slashes, `#` comments),
    matched exactly and case-insensitively; those files are left out of the PBO. Used for the
    mission's dev-only round-trip payload (deploy/pbo_exclude.txt, mapdb.md D7).
"""
import os, sys, struct, hashlib

# --- BIS/Arma PBO LZSS (Okumura LZSS: N=4096 ring, F=18, THRESHOLD=2, ring init 0x20) ----------
# Arma reads entries whose mime == PBO_MIME_COMPRESSED (0x43707273) as LZSS, using origsize as the
# decompressed length and a trailing 4-byte LE checksum = sum(decompressed bytes) & 0xFFFFFFFF.
# We encode against the linear output history (output index p lives at ring index (N-F + p) & N-1),
# greedy longest-match via a 3-byte hash chain. Every compressed entry is roundtrip-verified against
# the decoder below before use; on any mismatch (or if it doesn't shrink) we fall back to raw.
PBO_MIME_RAW = 0x00000000
PBO_MIME_COMPRESSED = 0x43707273
_LZ_N = 4096
_LZ_F = 18
_LZ_THRESH = 2
_LZ_R0 = _LZ_N - _LZ_F        # 4078: ring write start, mirrors the decoder

def _lzss_compress(data):
    n = len(data)
    out = bytearray()
    chains = {}                       # 3-byte key -> list of positions (most-recent last)
    flags_pos = -1                    # index in `out` of the current flag byte
    flag_bit = 8                      # forces a new flag byte on first use
    i = 0
    while i < n:
        if flag_bit == 8:
            out.append(0); flags_pos = len(out) - 1; flag_bit = 0
        best_len = 0; best_pos = 0
        if i + 3 <= n:
            key = data[i:i+3]
            lst = chains.get(key)
            if lst:
                lo = i - (_LZ_N - 1)          # window: distance 1.._LZ_N-1
                maxlen = _LZ_F if n - i >= _LZ_F else n - i
                depth = 0
                for s in reversed(lst):
                    if s < lo: break
                    if depth >= 256: break
                    depth += 1
                    l = 0
                    while l < maxlen and data[s + l] == data[i + l]:
                        l += 1
                    if l > best_len:
                        best_len = l; best_pos = s
                        if l == maxlen: break
        if best_len >= 3:
            ring = (_LZ_R0 + best_pos) & (_LZ_N - 1)
            out.append(ring & 0xFF)
            out.append(((ring >> 4) & 0xF0) | (best_len - 3))
            # flag bit 0 = back-reference (leave as 0)
            # index every covered position for future matches
            end = i + best_len
            while i < end:
                if i + 3 <= n:
                    chains.setdefault(data[i:i+3], []).append(i)
                i += 1
        else:
            out[flags_pos] |= (1 << flag_bit)     # 1 = literal
            out.append(data[i])
            if i + 3 <= n:
                chains.setdefault(data[i:i+3], []).append(i)
            i += 1
        flag_bit += 1
    chk = 0
    for b in data: chk = (chk + b) & 0xFFFFFFFF
    out += struct.pack("<I", chk)
    return bytes(out)

def _lzss_decompress(comp, size):
    N = _LZ_N
    text = bytearray(b"\x20" * N)
    r = _LZ_R0
    out = bytearray()
    ip = 0; flags = 0
    while len(out) < size:
        flags >>= 1
        if (flags & 0x100) == 0:
            flags = comp[ip] | 0xFF00; ip += 1
        if flags & 1:
            c = comp[ip]; ip += 1
            out.append(c); text[r] = c; r = (r + 1) & (N - 1)
        else:
            a = comp[ip]; b = comp[ip + 1]; ip += 2
            pos = a | ((b & 0xF0) << 4)
            length = (b & 0x0F) + _LZ_THRESH + 1
            for k in range(length):
                c = text[(pos + k) & (N - 1)]
                out.append(c); text[r] = c; r = (r + 1) & (N - 1)
                if len(out) >= size: break
    return bytes(out)

# extensions worth compressing (text/config); already-compressed binaries are skipped (would grow)
_COMPRESS_EXT = (".sqf", ".hpp", ".h", ".ext", ".cpp", ".sqm", ".fsm", ".txt", ".csv", ".inc", ".bin")

def _maybe_compress(rel, data):
    """Return (mime, origsize, payload). Falls back to raw unless LZSS shrinks AND roundtrips."""
    # DEFAULT OFF: the LZSS encoder is self-consistent (roundtrips via _lzss_decompress) but Arma
    # REJECTED the output ("Error decoding config.cpp / mission.sqm") on b0036 -> not yet BIS-exact.
    # Opt in with AP_PBO_COMPRESS=1 only while validating against a reference Arma-compressed PBO.
    if os.environ.get("AP_PBO_COMPRESS", "0") != "1":
        return PBO_MIME_RAW, 0, data
    if not rel.lower().endswith(_COMPRESS_EXT) or len(data) < 64:
        return PBO_MIME_RAW, 0, data
    comp = _lzss_compress(data)
    if len(comp) >= len(data):
        return PBO_MIME_RAW, 0, data
    if _lzss_decompress(comp, len(data)) != data:
        return PBO_MIME_RAW, 0, data            # safety: never ship an entry we can't decode
    return PBO_MIME_COMPRESSED, len(data), comp

def read_exclude_list(path):
    """src-relative file paths to leave out: one per line, `#` comments and blanks ignored,
    normalised to forward slashes + lower case (the same normalisation the match applies)."""
    out = set()
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if line:
                out.add(line.strip("/\\").replace("\\", "/").lower())
    return out


def pack(src_dir, out_pbo, no_prefix=False, exclude_dirs=None, exclude_files=None):
    src_dir = os.path.abspath(src_dir)
    prefix = ""
    if not no_prefix:
        prefix_path = os.path.join(src_dir, "$PBOPREFIX$")
        if os.path.isfile(prefix_path):
            with open(prefix_path, "rb") as f:
                prefix = f.read().decode("utf-8", "ignore").strip().splitlines()[0].strip()
        if not prefix:
            prefix = os.path.basename(src_dir)

    # collect files (skip the prefix marker, stray .pbo, and dev cruft that bloats the PBO)
    SKIP_SUFFIX = (".pbo", ".py", ".md", ".log", ".sh", ".zip", ".orig", ".old", ".tmp",
                   ".gitignore", ".gitattributes", ".ds_store")
    SKIP_DIR_PREFIX = ("pbo-deobfuscator", ".git")
    # dev-only: opt-in relative dirs to omit entirely (e.g. sounds/radio to shrink the dev download).
    # LIVE never passes --exclude-dir, so the live pack always contains everything.
    exclude_rel = tuple((e or "").strip().strip("/\\").replace("\\", "/").lower()
                        for e in (exclude_dirs or []) if (e or "").strip())
    # dev-only: exact src-relative file paths to omit (--exclude-list). Same forward-slash +
    # lower-case normalisation as exclude_rel; tested where the .bak test runs, per file.
    exclude_files = set(exclude_files or ())
    files = []
    excluded = 0
    for root, _dirs, names in os.walk(src_dir):
        # prune cruft directories in place so os.walk doesn't descend into them
        _dirs[:] = [d for d in _dirs if not d.lower().startswith(SKIP_DIR_PREFIX)]
        if exclude_rel:
            _relroot = os.path.relpath(root, src_dir).replace("\\", "/").lower()
            _dirs[:] = [d for d in _dirs
                        if (("" if _relroot == "." else _relroot + "/") + d.lower()) not in exclude_rel]
        for n in names:
            ln = n.lower()
            if n == "$PBOPREFIX$" or ln.endswith(SKIP_SUFFIX) or n.endswith("~"):
                continue
            if ".bak" in ln:          # *.bak, *.bak-terrainmod, etc.
                continue
            full = os.path.join(root, n)
            if exclude_files and os.path.relpath(full, src_dir).replace("\\", "/").lower() in exclude_files:
                excluded += 1
                continue
            rel = os.path.relpath(full, src_dir).replace("/", "\\")
            files.append((rel, full))
    files.sort(key=lambda x: x[0].lower())

    out = bytearray()
    # --- version/header entry ---
    out += b"\x00"                                   # empty filename
    out += struct.pack("<I", 0x56657273)             # mime "Vers"
    out += struct.pack("<IIII", 0, 0, 0, 0)          # orig, reserved, time, datasize
    # properties: prefix=<prefix> (addons only; missions get none)
    if prefix:
        out += b"prefix\x00" + prefix.encode() + b"\x00"
    out += b"\x00"                                    # end of properties

    # --- file entries ---
    datas = []
    n_comp = 0; saved = 0
    for rel, full in files:
        with open(full, "rb") as f:
            data = f.read()
        mime, origsize, payload = _maybe_compress(rel, data)
        if mime == PBO_MIME_COMPRESSED:
            n_comp += 1; saved += len(data) - len(payload)
        datas.append(payload)
        out += rel.encode("utf-8") + b"\x00"
        out += struct.pack("<I", mime)                # packing method (raw / Cprs)
        out += struct.pack("<I", origsize)            # uncompressed size (0 for raw)
        out += struct.pack("<I", 0)                   # reserved
        out += struct.pack("<I", 0)                   # timestamp
        out += struct.pack("<I", len(payload))        # data size (compressed length)

    # --- header terminator ---
    out += b"\x00" + struct.pack("<IIIII", 0, 0, 0, 0, 0)

    # --- data block ---
    for data in datas:
        out += data

    # --- checksum ---
    digest = hashlib.sha1(bytes(out)).digest()
    out += b"\x00" + digest

    os.makedirs(os.path.dirname(os.path.abspath(out_pbo)), exist_ok=True)
    with open(out_pbo, "wb") as f:
        f.write(out)
    print(f"[pack_pbo] {len(files)} files ({n_comp} LZSS, -{saved//1024} KB, {excluded} excluded by list), prefix='{prefix}' -> {out_pbo} ({len(out)} bytes)")

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    no_prefix = "--no-prefix" in sys.argv
    exclude_dirs = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--exclude-dir=")]
    exclude_files = set()
    for a in sys.argv[1:]:
        if a.startswith("--exclude-list="):
            exclude_files |= read_exclude_list(a.split("=", 1)[1])   # a missing file raises: never pack blind
    if len(args) != 2:
        print("usage: pack_pbo.py <src_dir> <out.pbo> [--no-prefix] [--exclude-dir=rel/path ...] [--exclude-list=<file>]", file=sys.stderr); sys.exit(2)
    pack(args[0], args[1], no_prefix=no_prefix, exclude_dirs=exclude_dirs, exclude_files=exclude_files)
