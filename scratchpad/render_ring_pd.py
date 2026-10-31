#!/usr/bin/env python3
"""
render_ring_pd.py -- bake the MaxSec **TAL OS** quick-hack ring (police counterpart to ICEBREAKER).

Deliberately a DIFFERENT register from the civilian deck: where the civ ring is acid-green outlaw
tech on near-black, TAL is a police MDT -- navy-steel body, BADGE AMBER as the primary and
LIGHT-BAR ICE BLUE as the flavour. Reads as issued equipment, not contraband.

Outputs into mission images/cyberdeck/:
  ring_pd_base.paa      1024^2  wedges + icons + hub ring
  ring_pd_hl_0..7.paa    512^2  one lit wedge each (hover overlay)

Wedge order (clockwise from top) MUST match the cop vector table in fn_cyberdeckRing.sqf:
  0 RECORDS  1 PLATE  2 FIELD TEST  3 FIRMWARE  4 RESET  5 SWEEP  6 DISPATCH  7 BACKUP
"""
import os, sys, math
from PIL import Image, ImageDraw
SC = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SC)
sys.path.insert(0, os.path.join(SC, '..', 'tools'))
from render_ring import poly_wedge, geometry, wedge_angles, N
from make_paa import build_paa_dxt5, verify_paa

OUT = os.path.join(SC, '..', 'mission', 'Armapunk2035.Malden', 'images', 'cyberdeck')

AMBER = (240, 160, 30)      # badge gold -- primary
ICE   = (77, 184, 255)      # light bar -- flavour
RED   = (255, 59, 48)       # danger
DIM   = (125, 139, 158)     # steel grey-blue
STROKE = (42, 60, 82)
FILL   = (13, 22, 34)

# 24x24 icon box. pl=polyline  rc=rect  co=circle outline  ci=filled dot  ar=arc(centre,r,deg0,deg1)
ICONS = {
    0: {"rc": [(5.5,3.5,18.5,20.5)],                                             # RECORDS: rap sheet
        "pl": [[(8.5,8.5),(15.5,8.5)], [(8.5,12),(15.5,12)], [(8.5,15.5),(13,15.5)]]},
    1: {"rc": [(3,8,21,16)],                                                     # PLATE
        "pl": [[(6.5,12),(8.5,12)], [(11,12),(13,12)], [(15.5,12),(17.5,12)]]},
    2: {"pl": [[(8,3),(16,3)],                                                   # FIELD TEST: vial
               [(9.8,3),(9.8,15.2),(12,18.6),(14.2,15.2),(14.2,3)],
               [(9.9,12.2),(14.1,12.2)]]},
    3: {"rc": [(7,7,17,17), (10.6,10.6,13.4,13.4)],                              # FIRMWARE: chip
        "pl": [[(7,10),(4,10)], [(7,14),(4,14)], [(17,10),(20,10)], [(17,14),(20,14)],
               [(10,7),(10,4)], [(14,7),(14,4)]]},
    4: {"ar": [((12,12), 7.5, 35, 325)],                                         # RESET: cycle arrow
        "pl": [[(15.4,4.6),(17.8,8.4),(13.6,9.2)]]},
    5: {"co": [((10.6,10.6), 5.6)],                                              # SWEEP: magnifier
        "pl": [[(14.7,14.7),(20,20)]]},
    6: {"pl": [[(12,21),(6.6,12.4),(6.6,8.6),(12,4),(17.4,8.6),(17.4,12.4),(12,21)]],  # DISPATCH: pin
        "ci": [((12,9.4), 1.7)]},
    7: {"pl": [[(12,3.4),(19.8,7),(19.8,12.6),(12,20.6),(4.2,12.6),(4.2,7),(12,3.4)]]},  # BACKUP: shield
}


def draw_icon(d, idx, ox, oy, scale, col, w):
    spec = ICONS[idx]
    T = lambda p: (ox + p[0] * scale, oy + p[1] * scale)
    for pl in spec.get("pl", []):
        d.line([T(p) for p in pl], fill=col, width=w, joint="curve")
    for (x0, y0, x1, y1) in spec.get("rc", []):
        d.rectangle([T((x0, y0)), T((x1, y1))], outline=col, width=w)
    for (c, r, a0, a1) in spec.get("ar", []):
        cx0, cy0 = T(c); rr = r * scale
        d.arc([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], a0, a1, fill=col, width=w)
    for (c, r) in spec.get("co", []):
        cx0, cy0 = T(c); rr = r * scale
        d.ellipse([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], outline=col, width=w)
    for (c, r) in spec.get("ci", []):
        cx0, cy0 = T(c); rr = r * scale
        d.ellipse([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], fill=col)


def _icon_at(d, i, size, cx, cy, r0, r1, mid, col):
    s = size / 1024.0
    ix = cx + (r0 + r1) / 2 * math.cos(mid) - 26 * s
    iy = cy + (r0 + r1) / 2 * math.sin(mid) + 0.048 * size - 26 * s   # sits BELOW the live label
    draw_icon(d, i, ix, iy, 2.16 * s, col, max(2, int(4 * s)))


def render_base(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r0, r1 = geometry(size)
    for i in range(N):
        a0, a1 = wedge_angles(i)
        poly_wedge(d, cx, cy, r0, r1, a0, a1, FILL + (236,), STROKE + (255,), 3)
        _icon_at(d, i, size, cx, cy, r0, r1, (a0 + a1) / 2, DIM + (235,))
    hr = r0 - 12
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=(8, 13, 20, 248), outline=(42, 60, 82, 255), width=3)
    return img


def render_highlight(i, size=512, col=AMBER, alpha=76):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r0, r1 = geometry(size)
    a0, a1 = wedge_angles(i)
    poly_wedge(d, cx, cy, r0, r1, a0, a1, col + (alpha,), col + (255,), 4)
    _icon_at(d, i, size, cx, cy, r0, r1, (a0 + a1) / 2, col + (255,))
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    p = "/tmp/ring_pd_base.png"; render_base(1024).save(p)
    build_paa_dxt5(p, os.path.join(OUT, "ring_pd_base.paa"))
    print("ring_pd_base ->", verify_paa(os.path.join(OUT, "ring_pd_base.paa"))[1])
    for i in range(N):
        hp = f"/tmp/ring_pd_hl_{i}.png"; render_highlight(i, 512).save(hp)
        build_paa_dxt5(hp, os.path.join(OUT, f"ring_pd_hl_{i}.paa"))
    print("8 MaxSec highlight overlays baked")
