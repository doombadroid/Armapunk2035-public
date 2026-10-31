#!/usr/bin/env python3
"""Letter outlines for the HQ signs, taken from a REAL FONT.

These began as hand-authored parametric shapes and it showed: the M's diagonals came out a third of
the weight of its stems, the S read blocky, the O read as a zero. Drawing letterforms by hand is a
specialist job and there is no reason to do it here -- the box has fonts, and fontTools hands back
their exact contours.

Contours come from the TTF's glyf table with curves flattened to segments, scaled so the font's cap
height matches the sign's, and positioned on the font's own advance widths. Outer contours and holes
are kept apart because the sign pipeline needs them apart: an outer contour becomes an aperture cut
through the wall, a hole becomes an island of wall left standing inside it (the counter of an O).
"""
import os

from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTFont

# Owner's pick: a squared techno face, so the signs read as lit/digital rather than municipal.
FONT = os.path.expanduser("~/.local/share/fonts/cyber/Audiowide.ttf")
for _alt in ("/usr/share/fonts/liberation-fonts/LiberationSans-Bold.ttf",
             "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
    if not os.path.exists(FONT):
        FONT = _alt

CURVE_STEPS = 8            # the letters are ~2.5 m tall; this is already finer than the eye


class _Flatten(BasePen):
    def __init__(self, glyphSet):
        super().__init__(glyphSet)
        self.contours = []
        self._cur = []

    def _moveTo(self, pt):
        if len(self._cur) > 2:
            self.contours.append(self._cur)
        self._cur = [pt]

    def _lineTo(self, pt):
        self._cur.append(pt)

    def _curveToOne(self, p1, p2, p3):
        p0 = self._cur[-1]
        for i in range(1, CURVE_STEPS + 1):
            t = i / CURVE_STEPS
            u = 1 - t
            self._cur.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                              u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))

    def _qCurveToOne(self, p1, p2):
        p0 = self._cur[-1]
        for i in range(1, CURVE_STEPS + 1):
            t = i / CURVE_STEPS
            u = 1 - t
            self._cur.append((u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                              u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]))

    def _closePath(self):
        if len(self._cur) > 2:
            self.contours.append(self._cur)
        self._cur = []

    def _endPath(self):
        self._closePath()


def _area(poly):
    n = len(poly)
    return sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1]
               for i in range(n)) / 2.0


def _inside(poly, p):
    x, y = p
    hit = False
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x0 + (y - y0) * (x1 - x0) / (y1 - y0) > x:
            hit = not hit
    return hit


_font = None
_gs = None


def _load():
    global _font, _gs
    if _font is None:
        _font = TTFont(FONT)
        _gs = _font.getGlyphSet()
    return _font, _gs


def _cap_units():
    font, gs = _load()
    cap = getattr(font.get("OS/2"), "sCapHeight", None)
    if not cap:
        pen = _Flatten(gs)
        gs[font.getBestCmap()[ord("H")]].draw(pen)
        cap = max(p[1] for c in pen.contours for p in c)
    return cap


def glyph(ch, cap_height):
    """-> (outer_contours, hole_contours, advance), in metres, baseline at y = 0."""
    font, gs = _load()
    s = cap_height / _cap_units()
    pen = _Flatten(gs)
    gs[font.getBestCmap()[ord(ch)]].draw(pen)
    cs = [[(x * s, y * s) for (x, y) in c] for c in pen.contours]
    outers, holes = [], []
    for c in cs:
        bigger = [o for o in cs if o is not c and abs(_area(o)) > abs(_area(c))]
        (holes if any(_inside(o, c[0]) for o in bigger) else outers).append(c)
    return outers, holes, gs[font.getBestCmap()[ord(ch)]].width * s


def layout(word, cap_height, tracking=0.04):
    """Lay a word out from x = 0 on the font's own advances -> (width, [(outers, holes), ...])."""
    out, x = [], 0.0
    for i, ch in enumerate(word):
        outers, holes, adv = glyph(ch, cap_height)
        mv = lambda cs: [[(px + x, py) for (px, py) in c] for c in cs]
        out.append((mv(outers), mv(holes)))
        x += adv + (tracking * cap_height if i < len(word) - 1 else 0.0)
    xs = [p[0] for (o, h) in out for c in o for p in c]
    return max(xs) - min(xs), out
