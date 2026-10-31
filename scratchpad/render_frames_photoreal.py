#!/usr/bin/env python3
"""
render_frames_photoreal.py -- PHYSICALLY-SHADED deck frames (owner: "look like a real thing").
Pipeline: silhouette mask -> heightfield (bezel plateau, screen recess, key wells, seams, rivets, vents)
-> normals -> key+fill+env lighting w/ Blinn-Phong spec, anisotropic brushed-metal micro-normals,
AO from height, curvature edge-wear, grime/scratch albedo modulation -> emissive neon layers ->
screen glass + baked NEON AEGEAN brand row (rsvg overlay) -> vignette + grain.
Same 2048x1024 + screen window (46,46,1848,932) -> drop-in for every deck dialog.
Variants: A GHOSTLINE-X (worn angular gunmetal) / B CORPO-X (brushed titanium slab, neon seams)
          / C STEALTH (matte polymer, violet underglow).
"""
import numpy as np, subprocess, os
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, laplace

W, H = 2048, 1024
SCR = (46, 46, 1848, 932)
SC = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)

def rounded_rect_mask(x, y, w, h, r):
    im = Image.new('F', (W, H), 0.0)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([x, y, x + w, y + h], radius=r, fill=1.0)
    return np.asarray(im, dtype=np.float32)

def poly_mask(pts):
    im = Image.new('F', (W, H), 0.0)
    ImageDraw.Draw(im).polygon(pts, fill=1.0)
    return np.asarray(im, dtype=np.float32)

def g(a, s):
    return gaussian_filter(a, s, mode='nearest')

def norm01(a):
    mn, mx = a.min(), a.max()
    return (a - mn) / (mx - mn + 1e-9)

def build_height(sil, variant):
    """height in px units; sil = silhouette mask."""
    h = g(sil, 6) * 26.0                                   # plateau w/ rounded outer edge
    # screen recess: deep well with a rounded lip
    scr = rounded_rect_mask(SCR[0], SCR[1], SCR[2], SCR[3], 16)
    h -= g(scr, 4) * 22.0
    # key wells right rail (decorative)
    d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
    ys = range(190, 850, 150) if variant != 'b' else range(200, 860, 138)
    for ky in ys:
        dd.ellipse([1972 - 27, ky - 27, 1972 + 27, ky + 27], fill=1.0)
    h -= g(np.asarray(d, np.float32), 2.5) * 7.0
    # cam pinhole + top notch
    d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
    dd.ellipse([952, 16, 968, 32], fill=1.0)
    dd.rounded_rectangle([985, 18, 1075, 26], radius=4, fill=1.0)
    h -= g(np.asarray(d, np.float32), 1.5) * 5.0
    if variant == 'a':
        # panel seams + vents + hazard strip groove
        d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
        dd.line([1010, 4, 1010, 42], width=3, fill=1.0)
        dd.line([300, 982, 300, 1020], width=3, fill=1.0)
        for i in range(7):
            dd.rounded_rectangle([1650 + i * 40, 10, 1650 + i * 40 + 22, 20], radius=3, fill=1.0)
        h -= g(np.asarray(d, np.float32), 1.2) * 6.0
        # torx bumps
        d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
        for rx, ry in [(28, 30), (2018, 34), (24, 990), (1930, 996), (1004, 22)]:
            dd.ellipse([rx - 9, ry - 9, rx + 9, ry + 9], fill=1.0)
        h += g(np.asarray(d, np.float32), 2.0) * 4.0
    if variant == 'b':
        # precision seam grooves top/bottom
        d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
        dd.line([40, 12, 2008, 12], width=2, fill=1.0)
        dd.line([40, 1012, 2008, 1012], width=2, fill=1.0)
        for i in range(5):
            dd.ellipse([12, 322 + i * 80, 30, 340 + i * 80], fill=1.0)
        h -= g(np.asarray(d, np.float32), 1.0) * 4.0
    if variant == 'c':
        # rubber corner pads (slightly raised)
        d = Image.new('F', (W, H), 0.0); dd = ImageDraw.Draw(d)
        for rx, ry in [(70, 60), (1978, 60), (70, 964), (1978, 964)]:
            dd.ellipse([rx - 30, ry - 18, rx + 30, ry + 18], fill=1.0)
        h += g(np.asarray(d, np.float32), 4.0) * 5.0
    return h * sil

def shade(sil, h, albedo_rgb, brushed, rough_base, metal, wear, grime_amt):
    """returns float32 HxWx3 linear-ish"""
    # micro-normal noise: brushed = horizontal streaks; matte = isotropic stipple
    if brushed > 0:
        streak = g(rng.standard_normal((H, W)).astype(np.float32), (0.6, 24)) * brushed * 8.0
        h2 = h + streak
    else:
        h2 = h + g(rng.standard_normal((H, W)).astype(np.float32), 1.1) * 0.8
    dy, dx = np.gradient(h2)
    nz = np.ones_like(h2) * 2.2
    ln = np.sqrt(dx * dx + dy * dy + nz * nz)
    nx, ny, nzn = -dx / ln, -dy / ln, nz / ln
    def L(v):
        v = np.asarray(v, np.float32); return v / np.linalg.norm(v)
    l1 = L([-0.45, -0.65, 0.62]); l2 = L([0.7, 0.35, 0.42])
    nd1 = np.clip(nx * l1[0] + ny * l1[1] + nzn * l1[2], 0, 1)
    nd2 = np.clip(nx * l2[0] + ny * l2[1] + nzn * l2[2], 0, 1)
    # AO from recess occlusion
    ao = np.clip(1.0 - np.clip(g(h, 22) - h, 0, 14) / 14 * 0.75, 0, 1)
    # curvature -> edge wear (exposed bright metal on edges)
    curv = np.abs(laplace(g(h, 2)))
    wear_m = np.clip(norm01(curv) * wear * 2.2, 0, 1) ** 1.6
    # grime: low-freq dark blotches + streak-down stains
    gr = norm01(g(rng.standard_normal((H, W)).astype(np.float32), 60))
    stains = norm01(g(rng.standard_normal((H, W)).astype(np.float32), (40, 6)))
    grime = np.clip(0.55 * gr + 0.45 * stains, 0, 1) * grime_amt
    alb = np.zeros((H, W, 3), np.float32)
    for i in range(3):
        alb[..., i] = albedo_rgb[i] * (1.0 - 0.45 * grime) + wear_m * (0.62 - albedo_rgb[i]) * 0.85
    # spec: blinn-phong, roughness modulated by grime + brushed streaks
    hv1 = L([l1[0], l1[1], l1[2] + 1.0]); hv2 = L([l2[0], l2[1], l2[2] + 1.0])
    ndh1 = np.clip(nx * hv1[0] + ny * hv1[1] + nzn * hv1[2], 0, 1)
    ndh2 = np.clip(nx * hv2[0] + ny * hv2[1] + nzn * hv2[2], 0, 1)
    rough = np.clip(rough_base + grime * 0.25 - wear_m * 0.28, 0.08, 0.98)
    exp1 = 2.0 / (rough ** 2 + 1e-3)
    s1 = np.power(ndh1, exp1) * (1.0 - rough * 0.6)
    s2 = np.power(ndh2, exp1 * 0.6) * (1.0 - rough * 0.6) * 0.35
    # env: vertical studio softbox reflected by normal.y, fresnel-boosted at grazing
    fres = np.power(1.0 - nzn, 3.5)
    env = (0.5 + 0.5 * ny)  # 1 facing up
    envcol = np.stack([env * 0.10 + 0.012, env * 0.11 + 0.015, env * 0.115 + 0.018], -1)
    out = alb * (0.16 + 0.72 * nd1[..., None] + 0.22 * nd2[..., None]) * ao[..., None]
    out += envcol * (metal * 0.35 + 0.06) * (0.15 + 0.85 * fres[..., None]) * ao[..., None]
    spec_col = alb * metal + (1 - metal) * 1.0
    out += (s1 + s2)[..., None] * spec_col * (np.clip(1.0 - rough, 0, 1) ** 1.6)[..., None] * 1.1
    return np.clip(out, 0, 4) * sil[..., None]

def screen_glass():
    """dark deck glass for the window: radial + scan + reflection wedge, returns RGB array + region."""
    x, y, w, h = SCR
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w * 0.5, h * 0.28
    r = np.sqrt(((xx - cx) / w) ** 2 + ((yy - cy) / h) ** 2)
    base = np.clip(0.72 - r, 0, 1)
    g_ = np.stack([0.012 + 0.035 * base, 0.023 + 0.055 * base, 0.018 + 0.042 * base], -1)
    g_[(yy % 3 < 1)] *= 0.74                                        # scanlines
    wedge = ((xx + yy * 0.494) < 820).astype(np.float32) * 0.030    # diagonal reflection
    wedge += (np.abs(xx + yy * 0.494 - 950) < 46).astype(np.float32) * 0.016
    g_ += wedge[..., None]
    # top inner shadow (bezel overhang)
    g_ *= (0.55 + 0.45 * np.clip(yy / 60.0, 0, 1))[..., None]
    return g_

BRAND_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="1024" viewBox="0 0 2048 1024">
<defs><filter id="gl" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="6"/></filter></defs>
<circle cx="95" cy="106" r="9" fill="{acc}" filter="url(#gl)"/>
<text x="119" y="123" font-family="'Orbitron'" font-size="44" font-weight="800" fill="{tag}" opacity="0.5" style="letter-spacing:5px">NEON AEGEAN</text>
<text x="116" y="120" font-family="'Orbitron'" font-size="44" font-weight="800" fill="{acc}" style="letter-spacing:5px">NEON AEGEAN</text>
<text x="562" y="120" font-family="'Orbitron'" font-size="25" font-weight="500" fill="{tag}" style="letter-spacing:9px">CYBERDECK</text>
<line x1="86" y1="150" x2="1854" y2="150" stroke="#2b3a35"/>
{extra}
</svg>"""

def brand_overlay(acc, tag, extra=""):
    svg = BRAND_SVG.format(acc=acc, tag=tag, extra=extra)
    open('/tmp/br.svg', 'w').write(svg)
    subprocess.run(['rsvg-convert', '-w', str(W), '-h', str(H), '/tmp/br.svg', '-o', '/tmp/br.png'], check=True)
    return Image.open('/tmp/br.png').convert('RGBA')

def emissive_edge(pts_or_rect, color, width, blur):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if isinstance(pts_or_rect, tuple):
        x, y, w, h, r = pts_or_rect
        d.rounded_rectangle([x, y, x + w, y + h], radius=r, outline=color, width=width)
    else:
        d.polygon(pts_or_rect, outline=color, width=width)
    return im.filter(ImageFilter.GaussianBlur(blur))

def render(variant):
    if variant == 'a':
        pts = [(0, 52), (37, 0), (1560, 0), (1600, 26), (1902, 26), (2048, 96), (2048, 972),
               (2004, 1024), (820, 1024), (790, 1002), (146, 1002), (0, 932)]
        sil = poly_mask(pts)
        hgt = build_height(sil, 'a')
        img = shade(sil, hgt, (0.085, 0.105, 0.095), brushed=0.9, rough_base=0.46,
                    metal=0.85, wear=1.0, grime_amt=0.85)
        acc, tag = "#c9e21a", "#33ffbb"
        extra = ('<g opacity="0.8"><rect x="150" y="1004" width="620" height="13" rx="6" fill="none"/>' +
                 ''.join(f'<path d="M{160+i*34},1017 L{176+i*34},1004 L{184+i*34},1004 L{168+i*34},1017 Z" fill="#c9e21a" opacity="0.85"/>' for i in range(17)) +
                 '</g><text x="1848" y="1019" font-family="monospace" font-size="19" fill="#4c5a55" text-anchor="end" style="letter-spacing:4px">GHOSTLINE-X</text>')
        emis = None
    elif variant == 'b':
        sil = rounded_rect_mask(0, 0, W - 1, H - 1, 46)
        hgt = build_height(sil, 'b')
        img = shade(sil, hgt, (0.085, 0.098, 0.115), brushed=1.4, rough_base=0.34,
                    metal=0.95, wear=0.3, grime_amt=0.3)
        acc, tag = "#33ffbb", "#ff3d81"
        extra = '<text x="1840" y="1016" font-family="monospace" font-size="18" fill="#55636d" text-anchor="end" style="letter-spacing:5px">KIROSHI // CORPO-X</text>'
        e1 = emissive_edge((40, 9, 1560, 6, 3), (51, 255, 187, 255), 4, 6)
        e2 = emissive_edge((448, 1008, 1560, 6, 3), (255, 61, 129, 255), 4, 6)
        emis = Image.alpha_composite(e1, e2)
    else:
        sil = rounded_rect_mask(0, 0, W - 1, H - 1, 32)
        hgt = build_height(sil, 'c')
        img = shade(sil, hgt, (0.040, 0.042, 0.050), brushed=0.0, rough_base=0.85,
                    metal=0.10, wear=0.15, grime_amt=0.4)
        acc, tag = "#b57bff", "#33ffbb"
        extra = '<text x="1836" y="1014" font-family="monospace" font-size="18" fill="#4a5560" text-anchor="end" style="letter-spacing:6px">STEALTH // N3XTECH</text>'
        emis = emissive_edge((13, 13, W - 27, H - 27, 28), (181, 123, 255, 235), 5, 9)

    # tonemap
    img = img / (1.0 + img * 0.55)
    img = np.clip(img ** (1 / 1.75), 0, 1)
    # screen glass into the window
    x, y, w, h = SCR
    glass = screen_glass()
    win = rounded_rect_mask(x, y, w, h, 14)[y:y + h, x:x + w, None]
    img[y:y + h, x:x + w, :] = img[y:y + h, x:x + w, :] * (1 - win) + glass * win
    out = Image.fromarray((img * 255).astype(np.uint8), 'RGB').convert('RGBA')
    # emissive neon
    if emis is not None:
        out = Image.alpha_composite(out, emis)
        out = Image.alpha_composite(out, emis.filter(ImageFilter.GaussianBlur(16)))
        out = Image.alpha_composite(out, emis)
    # brand + decals
    out = Image.alpha_composite(out, brand_overlay(acc, tag, extra))
    # vignette + grain
    vig = Image.new('L', (W, H), 0); dv = ImageDraw.Draw(vig)
    dv.ellipse([-W * 0.25, -H * 0.35, W * 1.25, H * 1.35], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(180))
    varr = np.asarray(vig, np.float32) / 255.0 * 0.35 + 0.65
    arr = np.asarray(out.convert('RGB'), np.float32) * varr[..., None]
    grain = rng.standard_normal((H, W, 1)).astype(np.float32) * 2.2
    arr = np.clip(arr + grain, 0, 255)
    # alpha = silhouette (transparent corners in-game)
    a = (np.asarray(Image.fromarray((sil * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), np.float32))
    rgba = np.dstack([arr, a]).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(f'/tmp/pr_{variant}.png')
    print('rendered', variant)

for v in ['a', 'b', 'c']:
    render(v)
F = subprocess.run(['fc-match', '-f', '%{file}', 'DejaVu Sans:style=Bold'], capture_output=True, text=True).stdout.strip()
subprocess.run(['magick', 'montage', '-font', F, '-background', '#161616', '-geometry', '1600x800+14+16', '-tile', '1x3',
                '-label', 'A  GHOSTLINE-X (worn gunmetal alloy)', '/tmp/pr_a.png',
                '-label', 'B  CORPO-X (brushed titanium, neon seams)', '/tmp/pr_b.png',
                '-label', 'C  STEALTH (matte polymer, violet underglow)', '/tmp/pr_c.png',
                '-fill', 'white', '-pointsize', '30', f'{SC}/frames_photoreal_review.png'], check=True)
print('wrote frames_photoreal_review.png')
