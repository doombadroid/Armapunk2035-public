#!/usr/bin/env python3
"""
check_dead_assets.py -- advisory scan for unreferenced mission image assets.

Flags .paa/.jpg/.png under images/ + icons/ whose basename never appears in any mission code file
(.sqf/.hpp/.h/.cpp/.ext/.inc). Animated-frame stems (matrix_00 -> matrix_) are matched against the
printf stem so a whole flipbook isn't false-flagged. Purely advisory: prints a report and always exits 0,
so it never blocks a deploy -- it just keeps the PBO from silently accreting dead art.

Usage: python3 deploy/check_dead_assets.py [mission_dir]
       default mission_dir = mission/Armapunk2035.Malden relative to the repo root.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "mission", "Armapunk2035.Malden")
ASSET_DIRS = ["images", "icons"]
# MUST include .sqm: placed objects/flags/markers reference textures ONLY in the mission file, not in code.
# Missing it once deleted a flag texture that was live in mission.sqm and locked players out of the server.
# .rvmat/.sqe/.cpp cover material files, Eden compositions, and config texture paths.
CODE_EXT = (".sqf", ".hpp", ".h", ".cpp", ".ext", ".inc", ".sqm", ".rvmat", ".sqe")
ASSET_EXT = (".paa", ".jpg", ".jpeg", ".png")

# assets deliberately kept even when unreferenced (parked features, revival candidates)
KEEP = set()


def build_haystack(mis):
    buf = []
    for dp, _, fns in os.walk(mis):
        for fn in fns:
            if fn.lower().endswith(CODE_EXT):
                try:
                    with open(os.path.join(dp, fn), encoding="utf-8", errors="replace") as fh:
                        buf.append(fh.read().lower())
                except OSError:
                    pass
    return "\n".join(buf)


def main():
    if not os.path.isdir(MIS):
        print(f"[dead-assets] mission dir not found: {MIS} -- skipping")
        return 0
    hay = build_haystack(MIS)
    dead, dead_bytes, kept = [], 0, 0
    for sub in ASSET_DIRS:
        base = os.path.join(MIS, sub)
        for dp, _, fns in os.walk(base):
            for fn in fns:
                if not fn.lower().endswith(ASSET_EXT):
                    continue
                stem = os.path.splitext(fn)[0].lower()
                frame_stem = re.sub(r"[_-]?\d+$", "", stem)  # matrix_00 -> matrix_ ; ties a flipbook together
                if stem in hay or (frame_stem and frame_stem != stem and frame_stem in hay):
                    continue
                path = os.path.join(dp, fn)
                if fn in KEEP:
                    kept += 1
                    continue
                sz = os.path.getsize(path)
                dead.append((sz, os.path.relpath(path, MIS)))
                dead_bytes += sz
    if not dead:
        print(f"[dead-assets] clean -- no unreferenced assets ({kept} kept-by-allowlist).")
        return 0
    dead.sort(reverse=True)
    print(f"[dead-assets] WARNING: {len(dead)} unreferenced asset(s), {dead_bytes/1048576:.1f}M reclaimable "
          f"(+{kept} kept-by-allowlist):")
    for sz, rel in dead[:40]:
        print(f"[dead-assets]   {sz/1048576:7.2f}M  {rel}")
    if len(dead) > 40:
        print(f"[dead-assets]   ... and {len(dead) - 40} more")
    print("[dead-assets] advisory only -- deploy continues. Run this to prune before a live pack.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
