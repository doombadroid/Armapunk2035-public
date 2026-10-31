#!/usr/bin/env python3
"""vending_signs/*.png -> mission/Armapunk2035.Malden/ap_vend_<slug>_{front,side}_co.paa

The twelve shop sign sets from the vending handoff, converted for the mission PBO.

HALF THE HANDED-OFF RESOLUTION, ON PURPOSE (owner call 2026-09-06). The art arrives at
512x1536 (front) and 512x1024 (side). At full size, DXT5 with mips, the 24 files come to
roughly 21 MB inside the mission PBO -- a download every player pays on every join, for a
0.55 x 1.62 m panel on a 1.83 m prop. Halved to 256x768 / 256x512 the set is ~2.6 MB and
still carries more pixels across the sign than the screen resolves at any distance you can
actually read it from. The source PNGs stay untouched in vending_signs/, so going back to
full res is a one-line change to SIZE below, not a re-export.

DXT1, NOT DXT5, AND THAT IS MEASURED NOT ASSUMED. Every sign is opaque: 23 of the 24 have a
solid 255 alpha channel and the last (airshop_front) bottoms out at 222 in a few antialiased
pixels, which is an export artifact rather than intended transparency. DXT5 would spend half
the file on an alpha channel carrying nothing. The check below is enforced per file, so a
future sign that genuinely uses alpha fails loudly here instead of silently losing its
cut-out. Material names in vending.js end `_ca`, but that is a three.js material name and has
no bearing on Arma's compression choice; the shipped files are `_co` because they are opaque.

    python3 scratchpad/skyscraper/build_vending_signs.py           # write all 24
    python3 scratchpad/skyscraper/build_vending_signs.py --list    # show what would be written
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'deploy'))
sys.path.insert(0, '/home/timb/Armapunk2035/deploy')
import make_paa                                                    # noqa: E402
from PIL import Image                                              # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'vending_signs')
OUT = os.path.abspath(os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden'))

# slug -> the PNG basename the handoff ships. The slug is what the .p3d, the .paa and the
# wiring table all key off, so it is written down once, here.
SHOPS = [
    'synthmeat', 'cyberthreads', 'lopoint', 'carshop', 'airshop', 'gearshop',
    'illeagle', 'illeaglevehicles', 'pharma', 'reallyilleagle',
    'reallyilleagleweapons', 'kabuki',
]

SIZE = {'front': (256, 768), 'side': (256, 512)}

# THE FRONT IS THREE TILES, NOT ONE (owner 2026-09-07: "the front displays aren't aligned with the
# machines"). The front slot is 0.55 x 1.615 m (1:2.94) and the art 1:3, but the only vanilla quads
# are UserTexture1m_F (1:1), UserTexture_1x2_F (1:2) and 10m -- a 1:3 art on the 1:2 quad at the
# single 0.66 scale came out 0.66 x 1.32: squashed to two-thirds height, 5.5 cm too wide each side,
# 15 cm short top and bottom. The sides (1:2 art, 1:2 quad) were fine, which is why only the fronts
# read wrong. A taller 1x2 would overhang the selection column and the Super emissive rvmat cannot
# render alpha margins, so fn_vendShop.sqf now stacks THREE 1 m quads at 0.55 (0.55 x 1.65 m, 1.75 cm
# over at each end) and the front art is cut into thirds: front0 = top, front1 = middle, front2 = bottom.
FRONT_TILES = 3
TILE = (256, 256)

# Below this, a channel is carrying real transparency and DXT1 would throw it away.
ALPHA_OPAQUE_FLOOR = 200


def build_dxt1_paa(png_path, out_path, size):
    """DXT1 twin of make_paa.build_paa_dxt5 -- same mip ladder, same container, no alpha."""
    w, h = size
    mip_sizes = make_paa.build_mip_sizes(w, h)
    assert mip_sizes, f'{png_path}: {w}x{h} produced no mip levels'
    mip_data = [(mw, mh, make_paa.convert_to_dxt1_dds(png_path, mw, mh)) for (mw, mh) in mip_sizes]
    avg = make_paa.compute_average_color_bgra(png_path)
    make_paa._build_paa(out_path, make_paa.DXT1, mip_data, avg, is_dxt5=False)
    return os.path.getsize(out_path), mip_sizes


def main():
    listing = '--list' in sys.argv
    total = 0
    for slug in SHOPS:
        for face in ('front', 'side'):
            png = os.path.join(SRC, f'{slug}_{face}.png')
            assert os.path.exists(png), f'missing source art: {png}'
            im = Image.open(png).convert('RGBA')
            lo, hi = im.getchannel('A').getextrema()
            assert lo >= ALPHA_OPAQUE_FLOOR, (
                f'{slug}_{face}.png has real transparency (alpha min {lo}); it needs DXT5, '
                f'not the DXT1 path this script takes')
            assert im.size == (512, 1536 if face == 'front' else 1024), \
                f'{slug}_{face}.png is {im.size}, not the size the handoff declares'

            if face == 'front':
                # cut into FRONT_TILES equal horizontal bands, top first, each its own 1:1 paa
                w, h = im.size
                band = h // FRONT_TILES
                for k in range(FRONT_TILES):
                    tile_png = os.path.join(SRC, '.tiles', f'{slug}_front{k}.png')
                    os.makedirs(os.path.dirname(tile_png), exist_ok=True)
                    im.crop((0, k * band, w, (k + 1) * band)).save(tile_png)
                    dst = os.path.join(OUT, f'ap_vend_{slug}_front{k}_co.paa')
                    if listing:
                        print(f'  would write {os.path.basename(dst)}  {(w, band)} -> {TILE}')
                        continue
                    n, mips = build_dxt1_paa(tile_png, dst, TILE)
                    total += n
                    print(f'  {os.path.basename(dst):42s} {n:8d} B  {len(mips)} mips')
                continue
            dst = os.path.join(OUT, f'ap_vend_{slug}_{face}_co.paa')
            if listing:
                print(f'  would write {os.path.basename(dst)}  {im.size} -> {SIZE[face]}')
                continue
            n, mips = build_dxt1_paa(png, dst, SIZE[face])
            total += n
            print(f'  {os.path.basename(dst):42s} {n:8d} B  {len(mips)} mips')

    if not listing:
        print(f'{len(SHOPS) * (FRONT_TILES + 1)} textures, {total} bytes ({total / 1e6:.2f} MB) added to the mission')


if __name__ == '__main__':
    main()
