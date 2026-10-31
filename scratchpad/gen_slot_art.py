#!/usr/bin/env python3
"""
gen_slot_art.py -- LooneyBin Casino Slots reel symbols. 5 self-contained reel cells (cream tile + bold icon)
-> slot_0..slot_4.paa. Symbol order MUST match the server paytable in APS_fnc_casinoSRV "slots":
  0 cherry  1 lemon  2 bell  3 bar  4 seven   (weights [6,5,4,3,2], 3-oak pays [8,12,22,45,150]x)
Client swaps these on the 3 reel controls to animate a spin.
"""
import os, sys, math
sys.path.insert(0, "/home/timb/loonybin-phone/tools")
from make_paa import build_paa_dxt5, verify_paa
from PIL import Image, ImageDraw, ImageFont

OUT = "/home/timb/loonybin-doomba/mission/LooneyBin.Altis/images/casino"
FONT = "/usr/share/fonts/liberation-fonts/LiberationSans-Bold.ttf"
S = 256

def cell():
    """cream reel tile with a subtle border + inner shading"""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(S * 0.14)
    d.rounded_rectangle([6, 6, S - 6, S - 6], radius=r, fill=(244, 236, 216, 255), outline=(120, 96, 40, 255), width=int(S * 0.03))
    d.rounded_rectangle([int(S*0.11), int(S*0.11), int(S*0.89), int(S*0.89)], radius=int(r*0.7), outline=(210, 196, 160, 255), width=max(1, int(S*0.008)))
    return img, d

def cherry():
    img, d = cell()
    # stems
    d.arc([int(S*0.42), int(S*0.18), int(S*0.80), int(S*0.62)], 200, 330, fill=(60, 130, 40, 255), width=int(S*0.03))
    for cx, cy in [(int(S*0.40), int(S*0.66)), (int(S*0.62), int(S*0.70))]:
        rr = int(S*0.15)
        d.ellipse([cx-rr, cy-rr, cx+rr, cy+rr], fill=(196, 30, 40, 255), outline=(120, 12, 20, 255), width=3)
        d.ellipse([cx-int(rr*0.45), cy-int(rr*0.5), cx-int(rr*0.05), cy-int(rr*0.1)], fill=(255, 180, 180, 220))  # highlight
    return img

def lemon():
    img, d = cell()
    cx, cy = S//2, int(S*0.56)
    d.ellipse([cx-int(S*0.26), cy-int(S*0.17), cx+int(S*0.26), cy+int(S*0.17)], fill=(240, 210, 40, 255), outline=(180, 150, 20, 255), width=4)
    d.ellipse([cx-int(S*0.20), cy-int(S*0.12), cx-int(S*0.02), cy+int(S*0.02)], fill=(255, 240, 150, 160))
    d.polygon([(int(S*0.60), int(S*0.34)), (int(S*0.74), int(S*0.28)), (int(S*0.66), int(S*0.42))], fill=(60, 140, 50, 255))  # leaf
    return img

def bell():
    img, d = cell()
    cx = S//2
    d.pieslice([int(S*0.28), int(S*0.24), int(S*0.72), int(S*0.68)], 180, 360, fill=(228, 180, 40, 255), outline=(150, 110, 20, 255), width=4)
    d.rectangle([int(S*0.28), int(S*0.46), int(S*0.72), int(S*0.66)], fill=(228, 180, 40, 255), outline=(150, 110, 20, 255), width=4)
    d.rounded_rectangle([int(S*0.24), int(S*0.64), int(S*0.76), int(S*0.72)], radius=6, fill=(240, 200, 60, 255), outline=(150, 110, 20, 255), width=3)
    d.ellipse([cx-int(S*0.05), int(S*0.72), cx+int(S*0.05), int(S*0.80)], fill=(150, 110, 20, 255))  # clapper
    d.ellipse([cx-int(S*0.03), int(S*0.20), cx+int(S*0.03), int(S*0.26)], fill=(150, 110, 20, 255))  # top knob
    return img

def _centered(d, txt, f, fill, cy_frac=0.5):
    bb = d.textbbox((0, 0), txt, font=f)
    d.text(((S - (bb[2]-bb[0]))/2 - bb[0], S*cy_frac - (bb[3]-bb[1])/2 - bb[1]), txt, font=f, fill=fill)

def bar():
    img, d = cell()
    f = ImageFont.truetype(FONT, int(S*0.26))
    d.rounded_rectangle([int(S*0.18), int(S*0.40), int(S*0.82), int(S*0.60)], radius=8, fill=(30, 30, 40, 255))
    _centered(d, "BAR", f, (244, 236, 216, 255), 0.5)
    return img

def seven():
    img, d = cell()
    f = ImageFont.truetype(FONT, int(S*0.60))
    # shadow + red 7
    bb = d.textbbox((0, 0), "7", font=f)
    x = (S - (bb[2]-bb[0]))/2 - bb[0]; y = S*0.5 - (bb[3]-bb[1])/2 - bb[1]
    d.text((x+4, y+4), "7", font=f, fill=(120, 12, 20, 200))
    d.text((x, y), "7", font=f, fill=(206, 32, 42, 255))
    return img

def main():
    for i, fn in enumerate([cherry, lemon, bell, bar, seven]):
        img = fn()
        png = os.path.join(OUT, f"slot_{i}.png")
        img.save(png)
        build_paa_dxt5(png, os.path.join(OUT, f"slot_{i}.paa"))
        os.remove(png)
    ok, msg = verify_paa(os.path.join(OUT, "slot_0.paa"))
    print("  5 slot symbols written. slot_0 verify:", msg)

if __name__ == "__main__":
    main()
    print("done")
