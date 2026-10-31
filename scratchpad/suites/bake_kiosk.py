#!/usr/bin/env python3
"""
Bake the Luxe Suites kiosk screen -> mission/.../images/suites/kiosk_welcome.paa

The kiosk is a GalleryDioramaUnit_01_F. Its texture slots were read straight out
of AoW's config (props_f_aow.pbo), not guessed:

    slot 0 -> a3\\Props_F_AoW\\Civilian\\Gallery\\data\\screen_co.paa   <- the screen
    slot 1 -> #(argb,8,8,3)color(...)  procedural
    slot 2..4 -> diorama_base_unit_0{1,2,3}_co.paa

so slot 0 is the panel we replace. That source texture is 1024x1024 DXT1 (its
header reads 0x8400 wide -- the 0x8000 bit is the LZO flag, not part of the
width), which is why this bakes square: anything else would stretch on the UVs.

Palette matches the tower's own neon so the kiosk belongs to the building:
cyan 0.05/0.72/1.0 and magenta 1.0/0.06/0.55, the same values the suite dialogs
use.

Run:  python3 scratchpad/suites/bake_kiosk.py
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))
import make_paa  # noqa: E402

SIZE = 1024
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..",
                       "mission", "Armapunk2035.Malden", "images", "suites")
PNG = "/tmp/claude-1000/-home-timb/38f0bc2b-30dd-43e2-b32f-704a4bff5a02/scratchpad/kiosk_welcome.png"
PAA = os.path.join(OUT_DIR, "kiosk_welcome.paa")

CYAN = (13, 184, 255)
MAGENTA = (255, 15, 140)
BASE = (7, 9, 15)

FONT_DISPLAY = "/home/timb/.local/share/fonts/cyber/Orbitron.ttf"
FONT_MONO = "/usr/share/fonts/dejavu/DejaVuSansMono-Bold.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def centre(draw, y, text, fnt, fill):
    w = draw.textbbox((0, 0), text, font=fnt)[2]
    draw.text(((SIZE - w) // 2, y), text, font=fnt, fill=fill)
    return w


def tracked(draw, y, text, fnt, fill, extra):
    """Letter-spaced centred text -- PIL has no tracking, so place per glyph."""
    widths = [draw.textbbox((0, 0), c, font=fnt)[2] for c in text]
    total = sum(widths) + extra * (len(text) - 1)
    x = (SIZE - total) / 2
    for c, w in zip(text, widths):
        draw.text((x, y), c, font=fnt, fill=fill)
        x += w + extra


def glow(layer, radius, gain):
    """Bloom: blurred copy screened back under the crisp text."""
    b = layer.filter(ImageFilter.GaussianBlur(radius))
    return Image.eval(b, lambda v: min(255, int(v * gain)))


def build():
    img = Image.new("RGB", (SIZE, SIZE), BASE)
    d = ImageDraw.Draw(img)

    # vertical gradient, lighter toward the horizon
    for y in range(SIZE):
        t = y / SIZE
        v = 1.0 - abs(t - 0.62) * 1.5
        v = max(0.0, v) ** 2
        d.line([(0, y), (SIZE, y)],
               fill=(int(BASE[0] + 16 * v), int(BASE[1] + 22 * v), int(BASE[2] + 40 * v)))

    # --- perspective floor grid ---------------------------------------------
    grid = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    gd = ImageDraw.Draw(grid)
    horizon = int(SIZE * 0.62)
    vp = SIZE / 2
    for i in range(-14, 15):                       # receding verticals
        gd.line([(vp + i * 46, SIZE), (vp + i * 5, horizon)], fill=MAGENTA, width=2)
    # Horizontals, compressing toward the horizon. BOUNDED on purpose: the first
    # version walked y down by a geometrically shrinking step, and those steps sum
    # to 96/(1-0.72) = 343 px while the horizon is 390 px away -- y converged short
    # of the test and the loop never ended. Perspective spacing is a division, not
    # a decaying subtraction, so drive it off the row index and it cannot run away.
    rows = 16
    for i in range(rows):
        y = horizon + (SIZE - horizon) / (1.0 + 2.6 * (i / rows) ** 1.6)
        gd.line([(0, y), (SIZE, y)], fill=MAGENTA, width=2)
    # SCREEN, not blend. Every layer here is light on black, and Image.blend is a
    # weighted average: blending a mostly-black glow layer at 0.85 does not add
    # the glow, it multiplies the whole picture toward black. The first bake came
    # out with a dead flat background for exactly that reason -- the grid and the
    # horizon were drawn correctly and then averaged away.
    grid = ImageChops.screen(Image.eval(grid, lambda v: int(v * 0.55)),
                             glow(grid, 9, 0.5))
    # Fade the grid out toward the viewer. Undimmed it is brightest at the bottom
    # edge, where it sat directly under the strapline and made it unreadable.
    fade = Image.new("L", (SIZE, SIZE), 0)
    fd = ImageDraw.Draw(fade)
    for y in range(horizon, SIZE):
        t = (y - horizon) / max(1, SIZE - horizon)
        fd.line([(0, y), (SIZE, y)], fill=int(255 * max(0.0, 1.0 - t * 1.15)))
    grid = ImageChops.multiply(grid, Image.merge("RGB", (fade, fade, fade)))
    img = ImageChops.screen(img, grid)
    d = ImageDraw.Draw(img)

    # horizon glow bar
    bar = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    ImageDraw.Draw(bar).rectangle([0, horizon - 3, SIZE, horizon + 1], fill=CYAN)
    img = ImageChops.screen(img, glow(bar, 30, 1.5))

    # --- type ----------------------------------------------------------------
    text = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    td = ImageDraw.Draw(text)
    tracked(td, 168, "WELCOME TO", font(FONT_DISPLAY, 54), CYAN, 14)
    centre(td, 258, "LUXE", font(FONT_DISPLAY, 190), (235, 250, 255))
    centre(td, 452, "SUITES", font(FONT_DISPLAY, 150), (235, 250, 255))

    # chromatic split: magenta ghost behind, cyan ghost in front
    ghost_m = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    gm = ImageDraw.Draw(ghost_m)
    centre(gm, 258, "LUXE", font(FONT_DISPLAY, 190), MAGENTA)
    centre(gm, 452, "SUITES", font(FONT_DISPLAY, 150), MAGENTA)
    img = ImageChops.screen(img, glow(ghost_m.transform(
        (SIZE, SIZE), Image.AFFINE, (1, 0, -9, 0, 1, 0)), 4, 0.9))
    img = ImageChops.screen(img, glow(text, 26, 1.1))
    img.paste(text, (0, 0),
              Image.eval(text.convert("L"), lambda v: 255 if v > 40 else 0))

    # Scrim behind the strapline block. The grid runs straight under this text and
    # magenta-on-magenta was unreadable; a soft dark panel buys the contrast back
    # without hiding the grid elsewhere.
    scrim = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(scrim).rectangle([120, 628, SIZE - 120, 906], fill=(4, 5, 10, 208))
    scrim = scrim.filter(ImageFilter.GaussianBlur(18))
    img = Image.alpha_composite(img.convert("RGBA"), scrim).convert("RGB")

    d = ImageDraw.Draw(img)

    # rule + strapline
    d.line([(268, 646), (756, 646)], fill=CYAN, width=3)
    tracked(d, 674, "LA TRINITE  //  FLOORS 02-30", font(FONT_MONO, 34), CYAN, 6)
    tracked(d, 728, "NEW DRACHMA ONLY", font(FONT_MONO, 26), MAGENTA, 5)
    tracked(d, 852, "SCROLL TO VIEW AVAILABILITY", font(FONT_MONO, 28),
            (150, 170, 190), 4)

    # corner brackets
    for cx, cy, sx, sy in ((46, 46, 1, 1), (SIZE - 46, 46, -1, 1),
                           (46, SIZE - 46, 1, -1), (SIZE - 46, SIZE - 46, -1, -1)):
        d.line([(cx, cy), (cx + 108 * sx, cy)], fill=CYAN, width=5)
        d.line([(cx, cy), (cx, cy + 108 * sy)], fill=CYAN, width=5)

    # --- scanlines + vignette -------------------------------------------------
    px = img.load()
    for y in range(0, SIZE, 3):
        for x in range(SIZE):
            r, g, b = px[x, y]
            px[x, y] = (int(r * 0.74), int(g * 0.74), int(b * 0.78))

    vig = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(vig).ellipse([-190, -190, SIZE + 190, SIZE + 190], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(140))
    img = Image.composite(img, Image.new("RGB", (SIZE, SIZE), BASE), vig)

    img.save(PNG)
    return img


if __name__ == "__main__":
    build()
    os.makedirs(OUT_DIR, exist_ok=True)
    make_paa.build_paa_dxt5(PNG, PAA)
    ok, msg = make_paa.verify_paa(PAA)
    print(f"{'OK  ' if ok else 'FAIL'} {PAA}  ({msg})")
    if not ok:
        raise SystemExit(1)
