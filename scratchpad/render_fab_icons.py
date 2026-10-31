#!/usr/bin/env python3
"""
render_fab_icons.py -- bake the 3D printer's material and schematic-shard icons.

Ten new virtual items need inventory icons: seven printer intermediates (the tier every printed
recipe draws on) and three schematic-shard rarities. They are drawn rather than sourced so the set
reads as one family at 64x64 in a listbox -- same plate, same stroke weight, same palette -- which
is the only size any of them are ever seen at.

Output: mission/Armapunk2035.Malden/icons/<key>.paa, referenced from column 10 of the matching
fn_virtItemCfg.sqf row. Generated art is committed; this script is the source of truth (CLAUDE.md).

Re-run:  python3 scratchpad/render_fab_icons.py
"""
import os
import sys

from PIL import Image, ImageDraw

SC = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SC, '..', 'tools'))
from make_paa import build_paa_dxt5, verify_paa  # noqa: E402

OUT = os.path.join(SC, '..', 'mission', 'Armapunk2035.Malden', 'icons')

# Rendered at 4x and downsampled -- PIL has no antialiased primitives, and a 64px icon with jagged
# diagonals reads as a compression artefact rather than a shape.
SS = 4
SIZE = 64

# Cyberpunk-adjacent but deliberately low-saturation: these sit in a dense listbox next to 238
# existing icons, so they need to be legible, not loud.
INK = (222, 234, 246, 255)
DIM = (128, 152, 178, 255)
CYAN = (86, 214, 226, 255)
AMBER = (226, 168, 74, 255)
VIOLET = (176, 130, 232, 255)
PLATE = (30, 42, 56, 255)


def _plate(d, w):
    """The shared background every icon sits on -- a chamfered slab."""
    c = 7 * SS
    d.polygon([(c, 2 * SS), (w - 2 * SS, 2 * SS), (w - 2 * SS, w - c),
               (w - c, w - 2 * SS), (2 * SS, w - 2 * SS), (2 * SS, c)], fill=PLATE)


def receiver(d, w, col):
    """lower_* -- a receiver blank: mag well, trigger pocket, takedown pins."""
    d.polygon([(16 * SS, 24 * SS), (48 * SS, 24 * SS), (48 * SS, 34 * SS),
               (34 * SS, 34 * SS), (30 * SS, 50 * SS), (20 * SS, 50 * SS), (16 * SS, 34 * SS)],
              outline=col, width=2 * SS)
    d.ellipse([21 * SS, 26 * SS, 27 * SS, 32 * SS], outline=DIM, width=SS)   # takedown pin
    d.ellipse([37 * SS, 26 * SS, 43 * SS, 32 * SS], outline=DIM, width=SS)
    d.arc([26 * SS, 32 * SS, 40 * SS, 44 * SS], 0, 180, fill=DIM, width=2 * SS)   # trigger guard


def bench(d, w, col):
    """gunsmith_bench -- worktop, pegboard, vice."""
    d.line([(12 * SS, 40 * SS), (52 * SS, 40 * SS)], fill=col, width=4 * SS)     # worktop
    d.line([(17 * SS, 42 * SS), (17 * SS, 54 * SS)], fill=col, width=3 * SS)     # legs
    d.line([(47 * SS, 42 * SS), (47 * SS, 54 * SS)], fill=col, width=3 * SS)
    d.rectangle([18 * SS, 14 * SS, 46 * SS, 36 * SS], outline=DIM, width=2 * SS)  # pegboard
    for x in (24, 32, 40):
        d.line([(x * SS, 18 * SS), (x * SS, 26 * SS)], fill=DIM, width=SS)        # hung tools
    d.rectangle([20 * SS, 34 * SS, 28 * SS, 40 * SS], fill=col)                   # vice


def spool(d, w, col):
    """filament -- a spool seen end-on."""
    cx = cy = w // 2
    d.ellipse([cx - 17 * SS, cy - 17 * SS, cx + 17 * SS, cy + 17 * SS], outline=col, width=2 * SS)
    d.ellipse([cx - 10 * SS, cy - 10 * SS, cx + 10 * SS, cy + 10 * SS], outline=DIM, width=SS)
    d.ellipse([cx - 4 * SS, cy - 4 * SS, cx + 4 * SS, cy + 4 * SS], fill=col)


def pellets(d, w, col):
    """polymer_pellet -- loose granules."""
    for (x, y, r) in [(22, 26, 6), (34, 21, 5), (42, 31, 6), (26, 39, 5), (38, 43, 6)]:
        d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=col)


def lens(d, w, col):
    """optic_blank -- an unground lens blank, with its highlight."""
    cx = cy = w // 2
    d.ellipse([cx - 16 * SS, cy - 16 * SS, cx + 16 * SS, cy + 16 * SS], outline=col, width=2 * SS)
    d.arc([cx - 11 * SS, cy - 11 * SS, cx + 11 * SS, cy + 11 * SS], 200, 300, fill=INK, width=2 * SS)


def wafer(d, w, col):
    """circuit_lamina -- a die with traces running off three edges."""
    d.rectangle([20 * SS, 20 * SS, 44 * SS, 44 * SS], outline=col, width=2 * SS)
    d.rectangle([28 * SS, 28 * SS, 36 * SS, 36 * SS], fill=col)
    for i in range(3):
        o = (26 + i * 6) * SS
        d.line([o, 20 * SS, o, 13 * SS], fill=DIM, width=SS)
        d.line([o, 44 * SS, o, 51 * SS], fill=DIM, width=SS)
        d.line([20 * SS, o, 13 * SS, o], fill=DIM, width=SS)


def weave(d, w, col):
    """carbon_weave -- an over-under twill."""
    for i in range(4):
        o = (20 + i * 8) * SS
        d.line([o, 18 * SS, o, 46 * SS], fill=col if i % 2 == 0 else DIM, width=3 * SS)
    for i in range(4):
        o = (20 + i * 8) * SS
        d.line([18 * SS, o, 46 * SS, o], fill=DIM if i % 2 == 0 else col, width=3 * SS)


def foam(d, w, col):
    """nanofoam -- a closed-cell block."""
    d.rectangle([18 * SS, 22 * SS, 46 * SS, 42 * SS], outline=col, width=2 * SS)
    for (x, y, r) in [(25, 28, 3), (33, 26, 4), (40, 30, 3), (23, 36, 3), (31, 36, 4), (40, 37, 3)]:
        d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], outline=DIM, width=SS)


def plate_armor(d, w, col):
    """ballistic_plate -- a curved strike face."""
    d.polygon([(22 * SS, 16 * SS), (42 * SS, 16 * SS), (46 * SS, 38 * SS),
               (32 * SS, 50 * SS), (18 * SS, 38 * SS)], outline=col, width=2 * SS)
    d.line([(24 * SS, 24 * SS), (40 * SS, 24 * SS)], fill=DIM, width=SS)
    d.line([(23 * SS, 32 * SS), (41 * SS, 32 * SS)], fill=DIM, width=SS)


def shard(d, w, col):
    """schematic shard -- a data sliver. Rarity is the stroke colour, and ONLY the stroke colour:
    the item's rarity is a real field on the schematic row, never inferred from this path. The
    system this was ported from classified its whole blueprint economy by string-matching icon
    paths, so renaming one file silently reclassified a quarter of it."""
    d.polygon([(32 * SS, 12 * SS), (46 * SS, 30 * SS), (32 * SS, 52 * SS), (18 * SS, 30 * SS)],
              outline=col, width=2 * SS)
    d.line([(32 * SS, 20 * SS), (32 * SS, 44 * SS)], fill=col, width=SS)
    for y in (26, 32, 38):
        d.line([(26 * SS, y * SS), (38 * SS, y * SS)], fill=DIM, width=SS)


def printer_open(d, w, col):
    """printer_i3 -- open frame: uprights, gantry, bed, spool on top."""
    d.line([(18 * SS, 50 * SS), (18 * SS, 20 * SS)], fill=col, width=3 * SS)
    d.line([(46 * SS, 50 * SS), (46 * SS, 20 * SS)], fill=col, width=3 * SS)
    d.line([(16 * SS, 30 * SS), (48 * SS, 30 * SS)], fill=DIM, width=3 * SS)
    d.rectangle([28 * SS, 28 * SS, 36 * SS, 34 * SS], fill=DIM)
    d.line([(20 * SS, 46 * SS), (44 * SS, 46 * SS)], fill=INK, width=3 * SS)
    d.ellipse([26 * SS, 12 * SS, 38 * SS, 24 * SS], outline=AMBER, width=2 * SS)
    d.line([(18 * SS, 52 * SS), (46 * SS, 52 * SS)], fill=col, width=2 * SS)


def printer_box(d, w, col):
    """printer_corexy -- enclosed cube with a lit door panel."""
    d.rectangle([16 * SS, 14 * SS, 48 * SS, 50 * SS], outline=col, width=3 * SS)
    d.rectangle([22 * SS, 20 * SS, 42 * SS, 44 * SS], fill=(28, 54, 66, 255), outline=DIM, width=SS)
    d.line([(24 * SS, 40 * SS), (40 * SS, 40 * SS)], fill=INK, width=2 * SS)
    d.rectangle([30 * SS, 30 * SS, 34 * SS, 36 * SS], fill=col)
    d.ellipse([43 * SS, 30 * SS, 47 * SS, 34 * SS], fill=DIM)
    d.line([(16 * SS, 53 * SS), (48 * SS, 53 * SS)], fill=DIM, width=3 * SS)


ICONS = {
    "gunsmith_bench":  (bench, AMBER),
    "lower_pistol":    (receiver, DIM),
    "lower_smg":       (receiver, INK),
    "lower_rifle":     (receiver, CYAN),
    "lower_heavy":     (receiver, VIOLET),
    "printer_i3":      (printer_open, AMBER),
    "printer_corexy":  (printer_box, CYAN),
    "filament":        (spool, CYAN),
    "polymer_pellet":  (pellets, DIM),
    "optic_blank":     (lens, INK),
    "circuit_lamina":  (wafer, CYAN),
    "carbon_weave":    (weave, INK),
    # INK, not DIM: the cells inside are already DIM, and a DIM outline around them made the whole
    # icon vanish into the plate at 64px.
    "nanofoam":        (foam, INK),
    "ballistic_plate": (plate_armor, INK),
    "shard":           (shard, INK),
    "shard_rare":      (shard, CYAN),
    "shard_epic":      (shard, VIOLET),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    w = SIZE * SS
    for key, (fn, col) in ICONS.items():
        img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        _plate(d, w)
        fn(d, w, col)
        img = img.resize((SIZE, SIZE), Image.LANCZOS)

        png = os.path.join(OUT, f"{key}.png")
        paa = os.path.join(OUT, f"{key}.paa")
        img.save(png)
        build_paa_dxt5(png, paa)
        os.remove(png)
        ok = verify_paa(paa)
        print(f"  {'PASS' if ok else 'FAIL'}  icons/{key}.paa")
        if not ok:
            raise SystemExit(f"verify_paa failed for {key}")
    print(f"{len(ICONS)} icons baked into {OUT}")


if __name__ == "__main__":
    main()
