#!/usr/bin/env python3
"""
gen_coin_art.py -- LooneyBin casino art: coin_heads.paa (GOLD), coin_tails.paa (SILVER), casino_felt.paa
(plain dark-green, no card-table arc). PNG via PIL -> PAA via the phone tools' make_paa.build_paa_dxt5.
Heads=gold / Tails=silver so the flip reads clearly as the face alternates. Writes into the casino images dir.
"""
import os, sys, math
sys.path.insert(0, "/home/timb/loonybin-phone/tools")
from make_paa import build_paa_dxt5, verify_paa
from PIL import Image, ImageDraw, ImageFont

OUT = "/home/timb/loonybin-doomba/mission/LooneyBin.Altis/images/casino"
FONT = "/usr/share/fonts/liberation-fonts/LiberationSans-Bold.ttf"

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def coin(letter, center_col, edge_col, rim_col, letter_col, out_name, size=512):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size // 2
    R = int(size * 0.48)
    # radial gradient disc (concentric fills, edge -> center)
    for r in range(R, 0, -1):
        col = lerp(edge_col, center_col, (R - r) / R) + (255,)
        d.ellipse([c - r, c - r, c + r, c + r], fill=col)
    # outer rim ring
    d.ellipse([c - R, c - R, c + R, c + R], outline=rim_col + (255,), width=int(size * 0.028))
    # inner bevel ring
    rb = int(R * 0.86)
    d.ellipse([c - rb, c - rb, c + rb, c + rb], outline=rim_col + (180,), width=int(size * 0.010))
    # beaded rim (dots around)
    beads = 40
    rr = int(R * 0.93)
    br = int(size * 0.011)
    for i in range(beads):
        a = 2 * math.pi * i / beads
        bx = c + int(rr * math.cos(a)); by = c + int(rr * math.sin(a))
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=rim_col + (220,))
    # emboss letter: dark drop then face color
    f = ImageFont.truetype(FONT, int(size * 0.62))
    bbox = d.textbbox((0, 0), letter, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = c - tw / 2 - bbox[0]; ty = c - th / 2 - bbox[1]
    d.text((tx + size * 0.012, ty + size * 0.012), letter, font=f, fill=rim_col + (160,))  # shadow
    d.text((tx, ty), letter, font=f, fill=letter_col + (255,))
    png = os.path.join(OUT, out_name + ".png")
    img.save(png)
    build_paa_dxt5(png, os.path.join(OUT, out_name + ".paa"))
    ok, msg = verify_paa(os.path.join(OUT, out_name + ".paa"))
    print(f"  {out_name}.paa verify: {msg}")
    os.remove(png)

def felt(out_name="casino_felt", w=1024, h=512):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, h / 2
    maxd = math.hypot(cx, cy)
    center_col = (26, 92, 58)   # #1a5c3a
    edge_col   = (14, 46, 30)   # darker green vignette
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - cx, y - cy) / maxd)
            r, g, b = lerp(center_col, edge_col, t)
            px[x, y] = (r, g, b, 255)
    # round the corners with an alpha mask so the felt tucks INSIDE the phone bezel's rounded corners
    # (a square felt pokes past the frame). Radius ~14% of height matches the phone_bj bezel.
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=int(h * 0.14), fill=255)
    img.putalpha(mask)
    png = os.path.join(OUT, out_name + ".png")
    img.save(png)
    build_paa_dxt5(png, os.path.join(OUT, out_name + ".paa"))
    ok, msg = verify_paa(os.path.join(OUT, out_name + ".paa"))
    print(f"  {out_name}.paa verify: {msg}")
    os.remove(png)

if __name__ == "__main__":
    print("coin_heads (gold):");  coin("H", (245,210,120), (190,140,50),  (120,90,25),  (90,62,14),   "coin_heads")
    print("coin_tails (silver):");coin("T", (238,238,245), (168,168,182), (104,104,116), (70,70,82),   "coin_tails")
    print("casino_felt:");        felt()
    print("done")
