#!/usr/bin/env python3
"""
render_ring.py -- bake the ICEBREAKER visor quick-hack RING (artifact 5c41381f, owner "1 to 1") to PAA.

Outputs into mission images/cyberdeck/:
  ring_base.paa      1024^2  wedges + icons + hub ring, transparent outside (the static art)
  ring_hl_0..7.paa    512^2  one lit wedge each, transparent elsewhere (hover overlay)

Labels, hub text and telemetry are LIVE dialog controls (colour = per-context state), so only the
geometry/iconography is baked. Wedge 0 starts at the top; index increases clockwise -- same order as
AP_ringVectors in fn_cyberdeckRing.sqf.
"""
import os, sys, math
from PIL import Image, ImageDraw
SC = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SC, '..', 'tools'))
from make_paa import build_paa_dxt5, verify_paa

OUT = os.path.join(SC, '..', 'mission', 'Armapunk2035.Malden', 'images', 'cyberdeck')
N = 8
ACID = (201, 226, 26)
CYAN = (51, 255, 187)
DANGER = (255, 59, 30)
DIM = (127, 145, 138)
STROKE = (34, 53, 45)
FILL = (10, 20, 16)

# icon strokes in a 24x24 box (polylines + circles), mirroring the artifact glyphs
ICONS = {
    0: {"ar": [((12,18.5), 9.5, 213, 327), ((12,18.5), 6.4, 208, 332), ((12,18.5), 3.4, 200, 340)],
        "ci": [((12, 18.4), 1.15)]},                                           # wardrive: wifi sweeps + node
    1: {"rc": [(6,11,18,19)], "pl": [[(9,11),(9,8),(11,6.2),(13.6,6.6),(14.8,8.4)]]},   # open padlock
    2: {"pg": [[(13.5,3),(7,12.5),(11,12.5),(9,21),(15.6,11.5),(11.6,11.5)]]},          # bolt
    3: {"rc": [(3.5,7,20.5,17)], "pl": [[(3.5,11.4),(20.5,11.4)], [(7,14.6),(10.4,14.6)]]},  # card slot
    4: {"pl": [[(3.6,11.4),(12,5),(20.4,11.4)], [(6.4,10.2),(6.4,18.6),(17.6,18.6),(17.6,10.2)]]},
    5: {"rc": [(4,5,20,9.5),(4,11.6,20,16.1)], "ci": [((7.2,7.2),0.9),((7.2,13.8),0.9)],
        "pl": [[(7,18.4),(7,20.4)],[(17,18.4),(17,20.4)]]},                    # server stack
    6: {"pl": [[(10.6,14.4),(9.2,13),(9.2,10.4),(12,7.6),(15.2,7.6),(16.6,9.4)],
               [(13.4,9.6),(14.8,11),(14.8,13.6),(12,16.4),(8.8,16.4),(7.4,14.6)]]},   # chain
    7: {"ci": [((15,9),3.4)], "pl": [[(12.6,11.4),(4,20),(5.8,21.8),(7.2,20.4),(8.5,21.7),(9.9,20.3),(8.6,19)]]},
}


def poly_wedge(d, cx, cy, r0, r1, a0, a1, fill, outline, width=3):
    steps = 44
    pts = []
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / steps
        pts.append((cx + r1 * math.cos(a), cy + r1 * math.sin(a)))
    for i in range(steps + 1):
        a = a1 - (a1 - a0) * i / steps
        pts.append((cx + r0 * math.cos(a), cy + r0 * math.sin(a)))
    d.polygon(pts, fill=fill)
    if outline:
        d.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def draw_icon(d, idx, ox, oy, scale, col, w):
    spec = ICONS[idx]
    T = lambda p: (ox + p[0] * scale, oy + p[1] * scale)
    for pl in spec.get("pl", []):
        d.line([T(p) for p in pl], fill=col, width=w, joint="curve")
    for (x0, y0, x1, y1) in spec.get("rc", []):
        d.rectangle([T((x0, y0)), T((x1, y1))], outline=col, width=w)
    for (c, r, a0, a1) in spec.get("ar", []):
        cx0, cy0 = T(c)
        rr = r * scale
        d.arc([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], a0, a1, fill=col, width=w)
    for (c, r) in spec.get("ci", []):
        cx0, cy0 = T(c)
        rr = r * scale
        d.ellipse([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], fill=col)


def geometry(size):
    cx = cy = size / 2.0
    r1 = size * 0.459
    r0 = size * 0.215
    return cx, cy, r0, r1


def wedge_angles(i):
    step = 2 * math.pi / N
    a0 = (i / N) * 2 * math.pi - math.pi / 2 - math.pi / N
    pad = 0.020
    return a0 + pad, a0 + step - pad


def render_base(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r0, r1 = geometry(size)
    for i in range(N):
        a0, a1 = wedge_angles(i)
        poly_wedge(d, cx, cy, r0, r1, a0, a1, FILL + (232,), STROKE + (255,), 3)
        mid = (a0 + a1) / 2
        s = size / 1024.0
        # owner 2026-07-20: icon sits BELOW the wedge label (label is a live control at -0.048)
        ix = cx + (r0 + r1) / 2 * math.cos(mid) - 26 * s
        iy = cy + (r0 + r1) / 2 * math.sin(mid) + 0.048 * size - 26 * s
        draw_icon(d, i, ix, iy, 2.16 * s, DIM + (235,), max(2, int(4 * s)))
    # hub ring
    hr = r0 - 12
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=(5, 10, 8, 246), outline=(27, 42, 36, 255), width=3)
    return img


def render_highlight(i, size=512, col=ACID, alpha=70):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r0, r1 = geometry(size)
    a0, a1 = wedge_angles(i)
    poly_wedge(d, cx, cy, r0, r1, a0, a1, col + (alpha,), col + (255,), 4)
    mid = (a0 + a1) / 2
    s = size / 1024.0
    ix = cx + (r0 + r1) / 2 * math.cos(mid) - 26 * s
    iy = cy + (r0 + r1) / 2 * math.sin(mid) + 0.048 * size - 26 * s
    draw_icon(d, i, ix, iy, 2.16 * s, col + (255,), max(2, int(4 * s)))
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    b = render_base(1024)
    p = "/tmp/ring_base.png"; b.save(p)
    build_paa_dxt5(p, os.path.join(OUT, "ring_base.paa"))
    print("ring_base ->", verify_paa(os.path.join(OUT, "ring_base.paa"))[1])
    for i in range(N):
        h = render_highlight(i, 512)
        hp = f"/tmp/ring_hl_{i}.png"; h.save(hp)
        build_paa_dxt5(hp, os.path.join(OUT, f"ring_hl_{i}.paa"))
    print("8 highlight overlays baked")
    # grid positions for the LIVE labels (deck grid: 1 GW == 1 GH in px; ring spans 13x13 centred)
    RING = 13.0
    lab = []
    for i in range(N):
        a0, a1 = wedge_angles(i)
        mid = (a0 + a1) / 2
        rr = (0.215 + 0.459) / 2 + 0.108      # just outside the icon, inside the outer edge
        lab.append((round(RING * rr * math.cos(mid), 3), round(RING * rr * math.sin(mid), 3)))
    print("label offsets (gw,gh):", lab)
