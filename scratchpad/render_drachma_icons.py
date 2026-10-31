#!/usr/bin/env python3
"""
New Drachma (ex-LoonyCoin) inventory icon — 4 candidate designs, owner picks one.
Renders at 512px supersample -> 64x64 PNG (paa source) + 256px preview sheet.
Glyphs are drawn as strokes (no font dependency — the ₯ sign has patchy coverage).

  A  tetradrachm_owl : antique gold coin, embossed Athenian owl
  B  neon_drachma    : dark puck, glowing cyan ₯, magenta rim (NIGHT CITY)
  C  delta_circuit   : gold coin, embossed Δ with circuit traces to the rim
  D  hex_token       : hexagonal crypto token, ₯ center, tick ring

Chosen option -> tools/make_paa.py build_paa_dxt5 -> mission icons/newdrachma.paa
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

S = 512          # supersample canvas
OUT = os.path.dirname(os.path.abspath(__file__)) + "/drachma_icons"
os.makedirs(OUT, exist_ok=True)

GOLD_HI  = (255, 224, 130)
GOLD     = (242, 193, 78)     # server MINING RIG gold #f2c14e
GOLD_LO  = (150, 103, 28)
GOLD_EDGE= (96, 62, 14)
CYAN     = (0, 229, 255)      # deck cyan #00e5ff
MAGENTA  = (255, 45, 160)
DARK     = (16, 18, 26)


def radial_coin(draw_target, cx, cy, r, c_hi, c_mid, c_lo):
    """Simple radial-gradient disc: light top-left -> dark bottom-right."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    steps = 90
    for i in range(steps, 0, -1):
        t = i / steps
        rr = r * t
        # blend hi->mid->lo across radius, offset toward top-left for a lit look
        if t < 0.55:
            f = t / 0.55
            col = tuple(int(c_hi[k] + (c_mid[k] - c_hi[k]) * f) for k in range(3))
        else:
            f = (t - 0.55) / 0.45
            col = tuple(int(c_mid[k] + (c_lo[k] - c_mid[k]) * f) for k in range(3))
        off = (1 - t) * r * 0.10
        d.ellipse([cx - rr + off * 0.6, cy - rr + off * 0.6, cx + rr + off * 0.6, cy + rr + off * 0.6], fill=col + (255,))
    draw_target.alpha_composite(img)


def emboss(base, mask, hi=(255, 240, 190, 235), lo=(60, 36, 6, 235), off=5):
    """Classic emboss: shadow copy down-right, highlight copy up-left, then face."""
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sh.paste(Image.new("RGBA", (S, S), lo), (off, off), mask)
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0)); hl.paste(Image.new("RGBA", (S, S), hi), (-off, -off), mask)
    base.alpha_composite(sh); base.alpha_composite(hl)


def drachma_glyph(d, cx, cy, h, w_stroke, col):
    """₯ drawn by hand: capital D + two parallel slashes through the lower-left."""
    top, bot = cy - h / 2, cy + h / 2
    stem_x = cx - h * 0.28
    # stem
    d.line([(stem_x, top), (stem_x, bot)], fill=col, width=w_stroke)
    # bowl: arc from top of stem to bottom of stem
    bbox = [stem_x - h * 0.52, top, stem_x + h * 0.62, bot]
    d.arc(bbox, start=-90, end=90, fill=col, width=w_stroke)
    # double slash, lower-left, through the stem
    for k in (-1, 1):
        oy = k * h * 0.085
        d.line([(cx - h * 0.55, cy + h * 0.30 + oy), (cx + h * 0.10, cy + h * 0.02 + oy)],
               fill=col, width=int(w_stroke * 0.72))


def owl_mask():
    """Stylised Athenian tetradrachm owl, facing forward."""
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    cx, cy = S * 0.5, S * 0.54
    # body
    d.ellipse([cx - 96, cy - 60, cx + 96, cy + 150], fill=255)
    # head
    d.ellipse([cx - 86, cy - 150, cx + 86, cy - 10], fill=255)
    # ear tufts
    d.polygon([(cx - 80, cy - 128), (cx - 30, cy - 118), (cx - 66, cy - 172)], fill=255)
    d.polygon([(cx + 80, cy - 128), (cx + 30, cy - 118), (cx + 66, cy - 172)], fill=255)
    # eyes (punched out then re-ringed by the emboss)
    for ex in (-40, 40):
        d.ellipse([cx + ex - 34, cy - 116, cx + ex + 34, cy - 48], fill=0)
        d.ellipse([cx + ex - 12, cy - 94, cx + ex + 12, cy - 70], fill=255)
    # beak
    d.polygon([(cx - 12, cy - 58), (cx + 12, cy - 58), (cx, cy - 26)], fill=0)
    # wing line + feet notches
    d.line([(cx - 96, cy + 10), (cx - 30, cy + 120)], fill=0, width=12)
    d.line([(cx + 96, cy + 10), (cx + 30, cy + 120)], fill=0, width=12)
    for fx in (-34, 0, 34):
        d.line([(cx + fx - 8, cy + 150), (cx + fx + 8, cy + 128)], fill=0, width=10)
    return m


def opt_a():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S // 2; r = S * 0.46
    dr = ImageDraw.Draw(img)
    dr.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=GOLD_EDGE + (255,))
    radial_coin(img, cx, cy, r, GOLD_HI, GOLD, GOLD_LO)
    dr = ImageDraw.Draw(img)
    # irregular antique rim: dotted ring
    for a in range(0, 360, 12):
        x = cx + math.cos(math.radians(a)) * r * 0.90
        y = cy + math.sin(math.radians(a)) * r * 0.90
        dr.ellipse([x - 7, y - 7, x + 7, y + 7], fill=GOLD_LO + (200,))
    emboss(img, owl_mask(), off=6)
    face = Image.new("RGBA", (S, S), (0, 0, 0, 0)); face.paste(Image.new("RGBA", (S, S), GOLD_HI + (60,)), (0, 0), owl_mask())
    img.alpha_composite(face)
    return img


def opt_b():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S // 2; r = S * 0.46
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DARK + (255,))
    # magenta rim ring + cyan inner ring
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=MAGENTA + (255,), width=14)
    d.ellipse([cx - r * 0.84, cy - r * 0.84, cx + r * 0.84, cy + r * 0.84], outline=CYAN + (90,), width=4)
    # glow pass: fat blurred glyph under crisp glyph
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    drachma_glyph(ImageDraw.Draw(glow), cx + 20, cy, S * 0.52, 44, CYAN + (180,))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(glow)
    drachma_glyph(d, cx + 20, cy, S * 0.52, 26, (210, 255, 255, 255))
    # scanlines -- whisper-quiet; at 64px heavy lines moire into stripes
    for y in range(0, S, 28):
        d.line([(cx - r * 0.95, y), (cx + r * 0.95, y)], fill=(0, 0, 0, 14), width=3)
    # re-mask to the disc so scanlines don't spill
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([cx - r - 7, cy - r - 7, cx + r + 7, cy + r + 7], fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(img, (0, 0), mask)
    return out


def opt_c():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S // 2; r = S * 0.46
    dr = ImageDraw.Draw(img)
    dr.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=GOLD_EDGE + (255,))
    radial_coin(img, cx, cy, r, GOLD_HI, GOLD, GOLD_LO)
    dr = ImageDraw.Draw(img)
    # circuit traces: 8 radial runs with elbow bends + node dots
    for i, a in enumerate(range(0, 360, 45)):
        a1 = math.radians(a + 8)
        x1 = cx + math.cos(a1) * r * 0.42; y1 = cy + math.sin(a1) * r * 0.42
        x2 = cx + math.cos(a1) * r * 0.66; y2 = cy + math.sin(a1) * r * 0.66
        a2 = math.radians(a + 26)
        x3 = cx + math.cos(a2) * r * 0.80; y3 = cy + math.sin(a2) * r * 0.80
        dr.line([(x1, y1), (x2, y2), (x3, y3)], fill=GOLD_LO + (255,), width=9)
        dr.ellipse([x3 - 10, y3 - 10, x3 + 10, y3 + 10], fill=GOLD_LO + (255,))
    # embossed Delta
    dm = Image.new("L", (S, S), 0)
    dd = ImageDraw.Draw(dm)
    t = S * 0.30
    dd.polygon([(cx, cy - t), (cx - t * 0.95, cy + t * 0.72), (cx + t * 0.95, cy + t * 0.72)], fill=255)
    dd.polygon([(cx, cy - t * 0.52), (cx - t * 0.52, cy + t * 0.44), (cx + t * 0.52, cy + t * 0.44)], fill=0)
    emboss(img, dm, off=6)
    face = Image.new("RGBA", (S, S), (0, 0, 0, 0)); face.paste(Image.new("RGBA", (S, S), GOLD_HI + (70,)), (0, 0), dm)
    img.alpha_composite(face)
    return img


def opt_d():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S // 2; r = S * 0.47
    d = ImageDraw.Draw(img)
    hexpts = [(cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r) for a in range(30, 390, 60)]
    inner = [(cx + math.cos(math.radians(a)) * r * 0.86, cy + math.sin(math.radians(a)) * r * 0.86) for a in range(30, 390, 60)]
    d.polygon(hexpts, fill=GOLD_EDGE + (255,))
    d.polygon([(cx + (p[0] - cx) * 0.97, cy + (p[1] - cy) * 0.97) for p in hexpts], fill=GOLD + (255,))
    d.polygon(inner, fill=DARK + (255,))
    # tick ring inside the hex
    for a in range(0, 360, 15):
        x1 = cx + math.cos(math.radians(a)) * r * 0.78; y1 = cy + math.sin(math.radians(a)) * r * 0.78
        x2 = cx + math.cos(math.radians(a)) * r * 0.70; y2 = cy + math.sin(math.radians(a)) * r * 0.70
        d.line([(x1, y1), (x2, y2)], fill=CYAN + (150,), width=6)
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    drachma_glyph(ImageDraw.Draw(glow), cx + 16, cy, S * 0.42, 40, GOLD + (200,))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(glow)
    drachma_glyph(d, cx + 16, cy, S * 0.42, 24, GOLD_HI + (255,))
    return img


OPTS = {"A_tetradrachm_owl": opt_a, "B_neon_drachma": opt_b, "C_delta_circuit": opt_c, "D_hex_token": opt_d}

if __name__ == "__main__":
    sheet = Image.new("RGBA", (4 * 276 + 20, 316), (34, 36, 44, 255))
    for i, (name, fn) in enumerate(OPTS.items()):
        im = fn()
        im.resize((64, 64), Image.LANCZOS).save(f"{OUT}/{name}_64.png")
        pv = im.resize((256, 256), Image.LANCZOS)
        sheet.paste(pv, (20 + i * 276, 30), pv)
        print("baked", name)
    sheet.save(f"{OUT}/preview_sheet.png")
    print("sheet ->", f"{OUT}/preview_sheet.png")
