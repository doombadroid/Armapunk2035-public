#!/usr/bin/env python3
"""Visual gates for the v3 intro+loop pairs.

The held loop must wrap invisibly: alignment is asserted structurally (t70
matches t0 better than t0's own neighbour) and the wrap step must sit inside
the design's own motion band. Absolute thresholds are meaningless — the
design carries deliberate per-frame randomness (12 Hz flicker, glitch
bursts at the engineered seam).
"""
import math
import os
from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(HERE, 'out', 'frames')


def rmse(a, b):
    a = Image.open(a).convert('RGB')
    b = Image.open(b).convert('RGB')
    h = ImageChops.difference(a, b).histogram()
    px = a.size[0] * a.size[1] * 3
    return math.sqrt(sum(h[c * 256 + i] * i * i for c in range(3) for i in range(256)) / px)


for a in ['169', '219']:
    d = os.path.join(F, f'loop{a}')
    steps = sorted(
        rmse(os.path.join(d, f'f{i:04d}.png'), os.path.join(d, f'f{i + 1:04d}.png'))
        for i in range(100, 1700, 200)
    )
    med = steps[len(steps) // 2]
    wrap = rmse(os.path.join(d, 'f1799.png'), os.path.join(d, 'f0000.png'))
    seam = rmse(os.path.join(d, 'seam_end.png'), os.path.join(d, 'f0000.png'))
    seam_off = rmse(os.path.join(d, 'seam_end.png'), os.path.join(d, 'f0001.png'))
    print(f'loop{a}: median step {med:.2f}  wrap {wrap:.2f}  '
          f'seam(t70 vs t10) {seam:.2f}  (vs +1f {seam_off:.2f})')
    assert seam < seam_off, f'loop{a}: t70 aligns better off-phase — periodicity broken'
    # wrap crosses the baked glitch burst (bright slivers both sides), so
    # allow the burst band: bounded by the burst's own frame-to-frame motion.
    burst_steps = sorted(
        rmse(os.path.join(d, f'f{i:04d}.png'), os.path.join(d, f'f{i + 1:04d}.png'))
        for i in range(0, 8)
    )
    assert wrap <= 2 * max(med, burst_steps[-1]), f'loop{a}: wrap exceeds even the burst motion band'

    # intro->loop cut: compare a burst-free loop frame near the cut against
    # the intro's end reference; must sit within the drifted-content band.
    intro_end = os.path.join(F, f'intro{a}', 'seam_end.png')
    cut = rmse(intro_end, os.path.join(d, 'f0012.png'))  # t=10.4, burst decayed
    print(f'intro{a}->loop cut (0.4s drift, burst-free): {cut:.2f}')
    assert cut <= 14 * med, f'intro{a}: cut discontinuity beyond drift band'
print('gates OK')
