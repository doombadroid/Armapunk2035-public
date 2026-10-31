#!/usr/bin/env python3
"""
Pre-compose Malden's satellite layer into ONE image the 3D map loads in a single fetch.

    python3 tools/bake_sat_atlas.py compose [--px 128] [--tiles DIR]
    python3 tools/bake_sat_atlas.py encode  [--px 128] [--quality 85] [--png]

WHY. The map's 128-tier satellite atlas is 13x13 = 169 tiles, and every cold open of the
map (the dialog is destroyed on close) re-requested all 169 through A3API.RequestTexture:
169 engine conversions, 169 base64 round trips, 169 decodes, 169 sub-uploads. Measured
2026-09-08 on a real client with [MAPTIME]: tiles were the long pole of a ~4 s open and
the second open was no faster (the engine caches nothing across dialogs). One composed
image is one fetch, one decode, one upload.

TWO STEPS ON PURPOSE. `compose` writes scratchpad/sat_atlas/malden_sat<px>.png -- the
island as the game ships it, and the file the owner edits or replaces to STYLIZE the map
(owner 2026-09-08: "I might want to stylize it later"). `encode` reads whatever PNG is
there and writes the page asset, so a stylized drop-in needs no tool changes: edit the
PNG, run `encode`, deploy.

LAYOUT (the page depends on this): tile s_CCC_RRR_lco.paa -- the paa's OWN column/row --
sits at pixel (C*px, R*px). Nothing about the page's on-map orientation (its SWAP_XY /
row flip) is baked in here; the page slices this image exactly where it would have
placed the same tile arriving from RequestTexture, so the two paths draw the same island.
The image is 13*px square; the page asserts that before trusting it.

OUTPUT (`encode`): mission/Armapunk2035.Malden/ui/html/malden_sat<px>.txt, a single
`data:image/<jpeg|png>;base64,...` line, because A3API.RequestFile returns TEXT and the
page hands the string straight to an <img>. JPEG q85 lands ~0.4 MB for 1664^2; --png for
flat stylized art where PNG-8 wins. A sidecar .json records px/cells/layout/source.

SOURCE. Tiles are extracted from the game install with tools/texture_audit.py (PBO found
by its own `prefix` property, PAA decoded first-mip via ~/blender_work/paa_extract_textures.py)
into --tiles DIR (default: a session scratch dir -- 169 x 1024^2 PNGs, ~250 MB, NEVER
commit them). Only the composed PNG and the encoded asset are committed.
"""
import argparse, base64, hashlib, io, json, os, subprocess, sys, tempfile
from PIL import Image

REPO    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MISSION = os.path.join(REPO, "mission", "Armapunk2035.Malden")
HTML    = os.path.join(MISSION, "ui", "html")
ART     = os.path.join(REPO, "scratchpad", "sat_atlas")
GRID    = 13
LAYER   = r"a3\map_malden\data\layers\s_%03d_%03d_lco.paa"


def extract_tiles(tiles_dir):
    """169 first-mip PNGs under tiles_dir/textures/a3/map_malden/data/layers/. Idempotent."""
    layers = os.path.join(tiles_dir, "textures", "a3", "map_malden", "data", "layers")
    have = len([f for f in os.listdir(layers)]) if os.path.isdir(layers) else 0
    if have >= GRID * GRID:
        return layers
    lst = os.path.join(tiles_dir, "tiles.list")
    os.makedirs(tiles_dir, exist_ok=True)
    with open(lst, "w") as fh:
        for r in range(GRID):
            for c in range(GRID):
                fh.write(LAYER % (c, r) + "\n")
    print(f"extracting {GRID*GRID} tiles via tools/texture_audit.py -> {tiles_dir}")
    subprocess.run([sys.executable, os.path.join(REPO, "tools", "texture_audit.py"), lst, tiles_dir],
                   check=True, stdout=subprocess.DEVNULL)
    n = len(os.listdir(layers))
    if n < GRID * GRID:
        sys.exit(f"extraction incomplete: {n}/{GRID*GRID} tiles")
    return layers


def compose(px, tiles_dir):
    layers = extract_tiles(tiles_dir)
    size = GRID * px
    atlas = Image.new("RGB", (size, size))
    for r in range(GRID):
        for c in range(GRID):
            p = os.path.join(layers, "s_%03d_%03d_lco.png" % (c, r))
            im = Image.open(p).convert("RGB")
            if im.size != (px, px):
                im = im.resize((px, px), Image.LANCZOS)
            atlas.paste(im, (c * px, r * px))
    os.makedirs(ART, exist_ok=True)
    out = os.path.join(ART, f"malden_sat{px}.png")
    atlas.save(out, optimize=True)
    print(f"composed {size}x{size} -> {os.path.relpath(out, REPO)} ({os.path.getsize(out)//1024} KB)")
    print("edit or replace that PNG to stylize the map, then run `encode`")


def encode(px, quality, png):
    src = os.path.join(ART, f"malden_sat{px}.png")
    if not os.path.exists(src):
        sys.exit(f"{os.path.relpath(src, REPO)} missing -- run `compose` first")
    im = Image.open(src).convert("RGB")
    size = GRID * px
    if im.size != (size, size):
        sys.exit(f"{src} is {im.size}, expected {size}x{size} (13 cells of {px})")
    buf = io.BytesIO()
    if png:
        im.convert("P", palette=Image.ADAPTIVE, colors=256).save(buf, "PNG", optimize=True)
        mime = "image/png"
    else:
        im.save(buf, "JPEG", quality=quality, optimize=True, progressive=False)
        mime = "image/jpeg"
    raw = buf.getvalue()
    data = "data:%s;base64,%s" % (mime, base64.b64encode(raw).decode("ascii"))
    out = os.path.join(HTML, f"malden_sat{px}.txt")
    with open(out, "w", encoding="ascii", newline="\n") as fh:
        fh.write(data + "\n")
    meta = {
        "px": px, "cells": GRID, "size": size, "mime": mime, "bytes": len(raw), "text_bytes": len(data) + 1,
        "layout": "tile s_CCC_RRR_lco.paa at pixel (C*px, R*px); the page applies its own orientation",
        "source_png_sha1": hashlib.sha1(open(src, "rb").read()).hexdigest(),
        "tool": "tools/bake_sat_atlas.py",
    }
    with open(os.path.join(HTML, f"malden_sat{px}.json"), "w") as fh:
        json.dump(meta, fh, indent=2); fh.write("\n")
    print(f"encoded {os.path.relpath(src, REPO)} -> {os.path.relpath(out, REPO)}: "
          f"{mime} {len(raw)//1024} KB, text {(len(data)+1)//1024} KB")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("step", choices=["compose", "encode"])
    ap.add_argument("--px", type=int, default=128)
    ap.add_argument("--tiles", default=os.path.join(tempfile.gettempdir(), "armapunk_sat_tiles"))
    ap.add_argument("--quality", type=int, default=85)
    ap.add_argument("--png", action="store_true", help="encode as PNG-8 (flat stylized art)")
    a = ap.parse_args()
    compose(a.px, a.tiles) if a.step == "compose" else encode(a.px, a.quality, a.png)
