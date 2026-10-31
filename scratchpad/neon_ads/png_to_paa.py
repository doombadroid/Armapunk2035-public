#!/usr/bin/env python3
"""Convert the baked ad frames to DXT5 PAAs in the mission's images/ads/."""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools'))
from make_paa import build_paa_dxt5, verify_paa  # noqa: E402

OUT = os.path.join(REPO, 'mission', 'Armapunk2035.Malden', 'images', 'ads')
os.makedirs(OUT, exist_ok=True)
pngs = sorted(glob.glob(os.path.join(HERE, 'png', 'ad_*_f*.png')))
assert len(pngs) == 12, pngs
for p in pngs:
    out = os.path.join(OUT, os.path.basename(p).replace('.png', '.paa'))
    build_paa_dxt5(p, out)
    ok, info = verify_paa(out)
    assert ok, (out, info)
print(f'{len(pngs)} PAAs -> {OUT}')
