#!/usr/bin/env python3
"""
Quickhack chip inventory icon -- engram-shard/carrier look (Cyberpunk-genre data shard, own art).
4 candidates, owner picks one -> icons/qhchip.paa for EVERY chip item.
Renders 512 supersample -> 64x64 PNG + preview sheet. Shard drawn tilted ~20deg.

  A  cyan_shard    : dark slab, angular cut, cyan data-core + traces, gold contacts
  B  amber_relic   : amber glow variant, red status dot
  C  magenta_ice   : magenta glow, double notch, scanline core
  D  carrier_case  : shard seated in an open carrier frame (the "engram carrier")
"""
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 512
OUT = os.path.dirname(os.path.abspath(__file__)) + "/chip_icons"
os.makedirs(OUT, exist_ok=True)

DARK   = (22, 24, 34)
SLATE  = (44, 48, 66)
CYAN   = (0, 229, 255)
AMBER  = (255, 190, 60)
MAGENTA= (255, 45, 160)
GOLD   = (242, 193, 78)
RED    = (255, 59, 30)


def rot(pts, cx, cy, deg):
    r = math.radians(deg); c, s = math.cos(r), math.sin(r)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def shard_body(cx, cy, w, h, cut=0.30):
    """Elongated slab, top-right corner cut at 45deg (the classic shard silhouette)."""
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
    cw = w * cut
    return [(x0, y0), (x1 - cw, y0), (x1, y0 + cw), (x1, y1), (x0, y1)]


def draw_shard(img, cx, cy, w, h, tilt, glow_col, notch2=False, scan=False, dot=None):
    d = ImageDraw.Draw(img)
    body = rot(shard_body(cx, cy, w, h), cx, cy, tilt)
    # glow halo behind the slab
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(halo).polygon(body, fill=glow_col + (110,))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(22)))
    # slab + inner face
    d.polygon(body, fill=DARK + (255,), outline=SLATE + (255,))
    inner = rot(shard_body(cx, cy, w - 26, h - 26), cx, cy, tilt)
    d.polygon(inner, fill=(DARK[0] + 8, DARK[1] + 9, DARK[2] + 14, 255))
    if notch2:
        n = rot([(cx - w * 0.5, cy - h * 0.14), (cx - w * 0.38, cy - h * 0.14),
                 (cx - w * 0.38, cy + h * 0.14), (cx - w * 0.5, cy + h * 0.14)], cx, cy, tilt)
        d.polygon(n, fill=(0, 0, 0, 0))
        d.line(n + [n[0]], fill=SLATE + (255,), width=4)
    # data core: bright center line + branching traces
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    core = rot([(cx, cy - h * 0.34), (cx, cy + h * 0.34)], cx, cy, tilt)
    g.line(core, fill=glow_col + (255,), width=16)
    for i, dy in enumerate((-0.22, -0.06, 0.10, 0.26)):
        side = -1 if i % 2 else 1
        tr = rot([(cx, cy + h * dy), (cx + side * w * 0.16, cy + h * dy),
                  (cx + side * w * 0.16, cy + h * (dy + 0.07))], cx, cy, tilt)
        g.line(tr, fill=glow_col + (230,), width=7)
        e = tr[-1]
        g.ellipse([e[0] - 6, e[1] - 6, e[0] + 6, e[1] + 6], fill=glow_col + (255,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
    img.alpha_composite(glow)  # crisp pass on top of its own blur
    d = ImageDraw.Draw(img)
    if scan:
        for yy in range(int(cy - h / 2), int(cy + h / 2), 22):
            sl = rot([(cx - w * 0.42, yy), (cx + w * 0.42, yy)], cx, cy, tilt)
            d.line(sl, fill=(0, 0, 0, 40), width=3)
    # gold contact fingers at the bottom edge
    for k in range(-2, 3):
        fx = cx + k * w * 0.16
        f = rot([(fx - w * 0.05, cy + h * 0.40), (fx + w * 0.05, cy + h * 0.40),
                 (fx + w * 0.05, cy + h * 0.52), (fx - w * 0.05, cy + h * 0.52)], cx, cy, tilt)
        d.polygon(f, fill=GOLD + (255,))
    if dot:
        p = rot([(cx + w * 0.26, cy - h * 0.30)], cx, cy, tilt)[0]
        d.ellipse([p[0] - 13, p[1] - 13, p[0] + 13, p[1] + 13], fill=dot + (255,))


def opt_a():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_shard(img, S / 2, S / 2 - 8, 236, 380, -20, CYAN)
    return img

def opt_b():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_shard(img, S / 2, S / 2 - 8, 236, 380, -20, AMBER, dot=RED)
    return img

def opt_c():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_shard(img, S / 2, S / 2 - 8, 236, 380, -20, MAGENTA, notch2=True, scan=True)
    return img

def opt_d():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # carrier: rounded-rect case, open window, shard seated inside at a slight angle
    d.rounded_rectangle([60, 40, S - 60, S - 40], radius=46, fill=(30, 33, 46, 255), outline=SLATE + (255,), width=8)
    d.rounded_rectangle([92, 74, S - 92, S - 74], radius=30, fill=(14, 15, 22, 255))
    # case screws
    for px, py in [(86, 66), (S - 86, 66), (86, S - 66), (S - 86, S - 66)]:
        d.ellipse([px - 9, py - 9, px + 9, py + 9], fill=SLATE + (255,), outline=(90, 96, 122, 255), width=3)
    draw_shard(img, S / 2, S / 2, 190, 330, -14, CYAN)
    # latch lights on the case rim
    dd = ImageDraw.Draw(img)
    for i in range(3):
        dd.ellipse([S - 84, 140 + i * 42, S - 70, 154 + i * 42], fill=(CYAN if i < 2 else GOLD) + (255,))
    return img


OPTS = {"A_cyan_shard": opt_a, "B_amber_relic": opt_b, "C_magenta_ice": opt_c, "D_carrier_case": opt_d}

if __name__ == "__main__":
    sheet = Image.new("RGBA", (4 * 276 + 20, 316), (34, 36, 44, 255))
    strip = Image.new("RGBA", (4 * 200 + 20, 220), (34, 36, 44, 255))
    for i, (name, fn) in enumerate(OPTS.items()):
        im = fn()
        im.resize((64, 64), Image.LANCZOS).save(f"{OUT}/{name}_64.png")
        pv = im.resize((256, 256), Image.LANCZOS)
        sheet.paste(pv, (20 + i * 276, 30), pv)
        z = Image.open(f"{OUT}/{name}_64.png").resize((192, 192), Image.NEAREST)
        strip.paste(z, (10 + i * 200, 14), z)
        print("baked", name)
    sheet.save(f"{OUT}/preview_sheet.png")
    strip.save(f"{OUT}/strip_64px_zoom.png")
    print("done")
