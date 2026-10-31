#!/usr/bin/env python3
"""Convert the baked hologram frames to DXT5 PAAs (alpha preserved)."""
import glob
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools'))
from make_paa import build_paa_dxt5, verify_paa  # noqa: E402

OUT = os.path.join(REPO, 'mission', 'Armapunk2035.Malden', 'images', 'ads')
os.makedirs(OUT, exist_ok=True)
pngs = sorted(glob.glob(os.path.join(HERE, 'png', 'holo_*_f*.png')))
assert len(pngs) == 9, pngs
for p in pngs:
    # the whole point is the transparent background — refuse an opaque bake
    a = Image.open(p).convert('RGBA').getchannel('A')
    lo, hi = a.getextrema()
    assert lo < 16 < 120 < hi, f'{p}: alpha extrema {lo},{hi} — not a cutout'
    out = os.path.join(OUT, os.path.basename(p).replace('.png', '.paa'))
    build_paa_dxt5(p, out)
    ok, info = verify_paa(out)
    assert ok, (out, info)
print(f'{len(pngs)} holo PAAs -> {OUT}')
