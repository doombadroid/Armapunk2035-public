#!/usr/bin/env python3
"""
bake_milspec_frame.py -- bake the APPROVED "MILSPEC GHOST rev2" shell (artifact 54932b53, owner go
2026-07-20) into the live frame pair:
  images/phone_deck.paa        (brand + // HOME suffix)
  images/phone_deck_blank.paa  (brand only -- app chassis)
Geometry: silhouette = the rev2 clip-path (stepped bottom-left cut REPLACED by a chamfer mirroring
bottom-right). Screen window unchanged (46,46,1848,932) -> drop-in, zero layout changes.
Look: demobbed-military cerakote (fine isotropic grain, worn edges), chamfer lighting, transit
latches top, key wells right rail w/ one LIVE acid key + rec dot (baked emissive), worn stencil.
Reuses the physically-shaded pipeline from render_frames_photoreal.py.
"""
import sys, os, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
SC = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SC)
sys.path.insert(0, os.path.join(SC, '..', 'tools'))
from render_frames_photoreal import (W, H, SCR, poly_mask, rounded_rect_mask, g, shade,
                                     screen_glass, brand_overlay, rng)
from make_paa import build_paa_dxt5, verify_paa

MIS = os.path.join(SC, '..', 'mission', 'Armapunk2035.Malden')

# rev2 silhouette (artifact clip-path -> px)
PTS = [(0, 52), (37, 0), (1560, 0), (1602, 26), (1902, 26), (2048, 96),
       (2048, 972), (2005, 1024), (43, 1024), (0, 972)]

def build_height_milspec(sil):
    h = g(sil, 6) * 26.0
    scr = rounded_rect_mask(SCR[0], SCR[1], SCR[2], SCR[3], 16)
    h -= g(scr, 4) * 22.0
    # key wells right rail
    d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
    for ky in range(190, 850, 150):
        dd.ellipse([1972 - 27, ky - 27, 1972 + 27, ky + 27], fill=1.0)
    h -= g(np.asarray(d, np.float32), 2.5) * 7.0
    # cam + top notch
    d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
    dd.ellipse([952, 16, 968, 32], fill=1.0)
    dd.rounded_rectangle([985, 18, 1075, 26], radius=4, fill=1.0)
    h -= g(np.asarray(d, np.float32), 1.5) * 5.0
    # transit latches (raised tabs on the top edge, artifact 26% / 58%)
    d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
    dd.rounded_rectangle([532, 0, 675, 24], radius=8, fill=1.0)
    dd.rounded_rectangle([1188, 0, 1331, 24], radius=8, fill=1.0)
    h += g(np.asarray(d, np.float32), 2.5) * 5.0
    # latch catch grooves
    d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
    dd.line([532, 26, 675, 26], width=2, fill=1.0)
    dd.line([1188, 26, 1331, 26], width=2, fill=1.0)
    h -= g(np.asarray(d, np.float32), 1.0) * 3.0
    # side chamfer seam left edge (subtle panel line)
    d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
    dd.line([1948, 60, 1948, 964], width=2, fill=1.0)
    h -= g(np.asarray(d, np.float32), 1.2) * 3.0
    return h * sil

def emissive_layer():
    """live acid key (+, well #3) + rec dot (well #5) + brand power dot handled by overlay."""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ky = list(range(190, 850, 150))
    # live key ring + glyph (well index 2 = '+')
    y = ky[2]
    d.ellipse([1972 - 22, y - 22, 1972 + 22, y + 22], outline=(201, 226, 26, 235), width=4)
    d.line([1972 - 9, y, 1972 + 9, y], fill=(220, 240, 60, 255), width=5)
    d.line([1972, y - 9, 1972, y + 9], fill=(220, 240, 60, 255), width=5)
    # rec dot (last well)
    y = ky[4]
    d.ellipse([1972 - 9, y - 9, 1972 + 9, y + 9], fill=(255, 90, 60, 255))
    glow = im.filter(ImageFilter.GaussianBlur(9))
    return Image.alpha_composite(glow, im)

def key_glyphs():
    """etched idle glyphs on the other wells (F, cam, -)"""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ky = list(range(190, 850, 150))
    col = (118, 134, 126, 200)
    # F
    y = ky[0]; d.line([1966, y - 10, 1966, y + 10], fill=col, width=4)
    d.line([1966, y - 10, 1980, y - 10], fill=col, width=4); d.line([1966, y - 1, 1977, y - 1], fill=col, width=4)
    # cam
    y = ky[1]; d.ellipse([1972 - 7, y - 5, 1972 + 7, y + 9], outline=col, width=3)
    d.rectangle([1972 - 11, y - 9, 1972 + 11, y - 4], fill=col)
    # minus
    y = ky[3]; d.line([1972 - 9, y, 1972 + 9, y], fill=col, width=5)
    return im

def stencil_overlay():
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="1024">'
           '<defs><filter id="rough"><feTurbulence type="fractalNoise" baseFrequency="0.35" numOctaves="2" result="n"/>'
           '<feDisplacementMap in="SourceGraphic" in2="n" scale="3"/></filter></defs>'
           '<g filter="url(#rough)" opacity="0.5">'
           "<text x='62' y='1006' font-family=\"'Orbitron'\" font-size='26' font-weight='700' fill='#5a675f' style='letter-spacing:12px'>GHOSTLINE-X · LOT 77</text>"
           "<text x='1854' y='1006' font-family=\"'JetBrainsMono Nerd Font',monospace\" font-size='20' fill='#4c5a55' text-anchor='end' style='letter-spacing:4px'>MFD 2077 · NO USER SERVICEABLE PARTS</text>"
           '</g></svg>')
    open('/tmp/st.svg', 'w').write(svg)
    subprocess.run(['rsvg-convert', '-w', str(W), '-h', str(H), '/tmp/st.svg', '-o', '/tmp/st.png'], check=True)
    return Image.open('/tmp/st.png').convert('RGBA')

def bake(with_home_suffix, out_paa):
    sil = poly_mask(PTS)
    hgt = build_height_milspec(sil)
    img = shade(sil, hgt, (0.052, 0.066, 0.058), brushed=0.0, rough_base=0.68,
                metal=0.28, wear=0.5, grime_amt=0.55)
    # cerakote: extra fine stipple in albedo space
    stip = g(rng.standard_normal((H, W)).astype(np.float32), 0.7) * 0.012
    img = np.clip(img + stip[..., None] * sil[..., None], 0, 4)
    img = img / (1.0 + img * 0.55)
    img = np.clip(img ** (1 / 1.75), 0, 1)
    x, y, w, h = SCR
    glass = screen_glass()
    win = rounded_rect_mask(x, y, w, h, 14)[y:y + h, x:x + w, None]
    img[y:y + h, x:x + w, :] = img[y:y + h, x:x + w, :] * (1 - win) + glass * win
    out = Image.fromarray((img * 255).astype(np.uint8), 'RGB').convert('RGBA')
    out = Image.alpha_composite(out, key_glyphs())
    out = Image.alpha_composite(out, emissive_layer())
    extra = ''
    if with_home_suffix:
        extra = ("<text x='880' y='120' font-family=\"'JetBrainsMono Nerd Font',monospace\" font-size='28' "
                 "fill='#4c5a55' style='letter-spacing:6px'>// HOME</text>")
    out = Image.alpha_composite(out, brand_overlay('#c9e21a', '#33ffbb', extra))
    out = Image.alpha_composite(out, stencil_overlay())
    # vignette + grain
    vig = Image.new('L', (W, H), 0)
    ImageDraw.Draw(vig).ellipse([-W * 0.25, -H * 0.35, W * 1.25, H * 1.35], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(180))
    varr = np.asarray(vig, np.float32) / 255.0 * 0.35 + 0.65
    arr = np.asarray(out.convert('RGB'), np.float32) * varr[..., None]
    arr = np.clip(arr + rng.standard_normal((H, W, 1)).astype(np.float32) * 2.0, 0, 255)
    a = np.asarray(Image.fromarray((sil * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), np.float32)
    rgba = np.dstack([arr, a]).astype(np.uint8)
    png = f'/tmp/milspec_{"home" if with_home_suffix else "blank"}.png'
    Image.fromarray(rgba, 'RGBA').save(png)
    build_paa_dxt5(png, out_paa)
    ok, msg = verify_paa(out_paa)
    print(out_paa, '->', msg)

if __name__ == '__main__':
    bake(True, os.path.join(MIS, 'images', 'phone_deck.paa'))
    bake(False, os.path.join(MIS, 'images', 'phone_deck_blank.paa'))
    print('DONE')
