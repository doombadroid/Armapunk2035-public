#!/usr/bin/env python3
"""
gen_wheel_art.py -- LooneyBin Casino Wheel Spin flipbook. 12-segment prize wheel rendered at 512px, then
24 rotation frames (15deg each -> exact 30deg-segment landing) downscaled to 256px -> wheel_00..wheel_23.paa,
plus wheel_pointer.paa (fixed top marker). Animation swaps frames (client) to fake a spinning wheel.

Segment map (MUST match the server segment list in APS_fnc_casinoSRV "wheel"):
  0 CASH 1 BUST 2 CASH 3 IFRIT 4 CASH 5 BUST 6 CASH 7 QILIN 8 CASH 9 BUST 10 CASH 11 BLACKFISH
Landing frame for segment i = (2*i) % 24 (verified in-game; server+banner are authoritative regardless).
"""
import os, sys, math
sys.path.insert(0, "/home/timb/loonybin-phone/tools")
from make_paa import build_paa_dxt5, verify_paa
from PIL import Image, ImageDraw, ImageFont

OUT = "/home/timb/loonybin-doomba/mission/LooneyBin.Altis/images/casino"
FONT = "/usr/share/fonts/liberation-fonts/LiberationSans-Bold.ttf"
BASE = 512          # render resolution
FRAME = 256         # saved frame resolution
NSEG = 12
FRAMES = 24

# per-segment (label, fill, textcolor)
SEG = [
    ("$",        (34,120,68),  (255,255,255)),   # 0 CASH
    ("BUST",     (40,86,150),  (255,255,255)),   # 1 BUST (drug-bust event)
    ("$",        (34,120,68),  (255,255,255)),   # 2 CASH
    ("IFRIT",    (150,40,40),  (255,230,150)),   # 3 IFRIT
    ("$",        (34,120,68),  (255,255,255)),   # 4 CASH
    ("BUST",     (40,86,150),  (255,255,255)),   # 5 BUST (drug-bust event)
    ("$",        (34,120,68),  (255,255,255)),   # 6 CASH
    ("QILIN",    (96,52,140),  (240,220,255)),   # 7 QILIN
    ("$",        (34,120,68),  (255,255,255)),   # 8 CASH
    ("BUST",     (40,86,150),  (255,255,255)),   # 9 BUST (drug-bust event)
    ("$",        (34,120,68),  (255,255,255)),   # 10 CASH
    ("BFISH",    (196,110,30), (255,240,210)),   # 11 BLACKFISH
]

def build_wheel():
    img = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = BASE // 2
    R = int(BASE * 0.47)
    seg = 360 / NSEG
    fsmall = ImageFont.truetype(FONT, int(BASE * 0.045))
    fbig   = ImageFont.truetype(FONT, int(BASE * 0.075))
    # PIL pieslice: 0deg = east (3 o'clock), CW. Segment i centered at TOP+i*30 clockwise.
    # top = -90 in PIL(east-0). Segment i spans [ -90 + i*30 - 15, -90 + i*30 + 15 ].
    for i, (label, fill, tcol) in enumerate(SEG):
        a0 = -90 + i * seg - seg / 2
        a1 = -90 + i * seg + seg / 2
        d.pieslice([c - R, c - R, c + R, c + R], a0, a1, fill=fill + (255,), outline=(20, 20, 24, 255), width=3)
        # radial label: place at mid-radius, rotate so it reads outward
        acw = i * seg                                   # clockwise angle from top
        rad = math.radians(acw)
        lr = R * 0.66
        lx = c + lr * math.sin(rad)
        ly = c - lr * math.cos(rad)
        f = fbig if label == "$" else fsmall
        tile = Image.new("RGBA", (int(BASE * 0.34), int(BASE * 0.09)), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        bb = td.textbbox((0, 0), label, font=f)
        td.text(((tile.width - (bb[2] - bb[0])) / 2 - bb[0], (tile.height - (bb[3] - bb[1])) / 2 - bb[1]),
                label, font=f, fill=tcol + (255,))
        tile = tile.rotate(-acw, resample=Image.BICUBIC, expand=True)
        img.alpha_composite(tile, (int(lx - tile.width / 2), int(ly - tile.height / 2)))
    # outer rim + bead dots
    d.ellipse([c - R, c - R, c + R, c + R], outline=(228, 199, 87, 255), width=int(BASE * 0.02))
    beads = 24; rr = R * 1.0; br = int(BASE * 0.012)
    for k in range(beads):
        a = 2 * math.pi * k / beads
        bx = c + rr * math.cos(a); by = c + rr * math.sin(a)
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=(228, 199, 87, 255))
    # center hub
    hr = int(BASE * 0.11)
    d.ellipse([c - hr, c - hr, c + hr, c + hr], fill=(24, 26, 30, 255), outline=(228, 199, 87, 255), width=int(BASE * 0.012))
    return img

def main():
    base = build_wheel()
    c = BASE // 2
    for f in range(FRAMES):
        ang = f * (360 / FRAMES)                        # PIL rotate = CCW
        fr = base.rotate(ang, resample=Image.BICUBIC, expand=False, center=(c, c))
        fr = fr.resize((FRAME, FRAME), Image.LANCZOS)
        png = os.path.join(OUT, f"wheel_{f:02d}.png")
        fr.save(png)
        build_paa_dxt5(png, os.path.join(OUT, f"wheel_{f:02d}.paa"))
        os.remove(png)
    ok, msg = verify_paa(os.path.join(OUT, "wheel_00.paa"))
    print(f"  {FRAMES} frames written. wheel_00 verify: {msg}")
    # pointer: downward gold triangle (sits at top of wheel, pointing in)
    P = 128
    ptr = Image.new("RGBA", (P, P), (0, 0, 0, 0))
    pd = ImageDraw.Draw(ptr)
    pd.polygon([(P * 0.15, P * 0.10), (P * 0.85, P * 0.10), (P * 0.5, P * 0.9)],
               fill=(228, 199, 87, 255), outline=(30, 24, 8, 255))
    pp = os.path.join(OUT, "wheel_pointer.png")
    ptr.save(pp)
    build_paa_dxt5(pp, os.path.join(OUT, "wheel_pointer.paa"))
    os.remove(pp)
    print("  wheel_pointer.paa written")

if __name__ == "__main__":
    main()
    print("done")
