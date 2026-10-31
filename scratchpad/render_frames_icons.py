#!/usr/bin/env python3
"""
render_frames_icons.py -- design-round renders for the NEON AEGEAN CYBERDECK phone.
FRAMES: 4 variants, all 2048x1024 with the SAME screen window (46,46,1848,932), brand row + divider at y=150
        -> drop-in compatible with every deck dialog (safe rect / content zone unchanged).
FRAME LANES: A GHOSTLINE (evolved gunmetal+acid) / B CORPO SLAB (graphite, cyan+magenta seams)
             C SCRAP-TECH (ripperdoc franken-deck, amber) / D HOLO EDGE (frameless neon glass, violet+cyan).
ICONS: unified set for all phone apps -- 256px tiles (bake at 64): dark deck tile, per-category neon accent,
       2-tone stroke glyphs with secondary detail (not flat-minimal).
Outputs: /tmp/frame_[abcd].png + review sheets frames_review.png / icons_review.png in the scratchpad.
"""
import subprocess, os
SC = os.path.dirname(os.path.abspath(__file__))
W, H = 2048, 1024
SCR = (46, 46, 1848, 932)
CYBER = "'Orbitron', sans-serif"
MONO = "'JetBrainsMono Nerd Font', monospace"
ACID = "#c9e21a"; CYAN = "#33ffbb"; ICE = "#5fd3ff"; AMBER = "#ffb020"
DANGER = "#ff5a3c"; VIOLET = "#b57bff"; MAGENTA = "#ff3d81"
INK = "#dbe7e0"; INK_DIM = "#7f918a"; INK_FAINT = "#4c5a55"

def svg(parts, w=W, h=H):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">' + "\n".join(parts) + "</svg>"

def screen_and_brand(P, accent=ACID, tag=CYAN, scan=True, brand_dot=True):
    x, y, w, h = SCR
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="#050a08"/>')
    P.append(f'<g clip-path="url(#cl)"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#sc)"/>')
    if brand_dot: P.append(f'<circle cx="95" cy="106" r="9" fill="{accent}" filter="url(#gl)"/>')
    P.append(f'<text x="119" y="123" font-family={CYBER!r} font-size="44" font-weight="800" fill="{tag}" opacity="0.5" style="letter-spacing:5px">NEON AEGEAN</text>')
    P.append(f'<text x="116" y="120" font-family={CYBER!r} font-size="44" font-weight="800" fill="{accent}" style="letter-spacing:5px">NEON AEGEAN</text>')
    P.append(f'<text x="562" y="120" font-family={CYBER!r} font-size="25" font-weight="500" fill="{tag}" style="letter-spacing:9px">CYBERDECK</text>')
    P.append(f'<line x1="86" y1="150" x2="1854" y2="150" stroke="#2b3a35"/>')
    if scan: P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#scan)"/>')
    P.append(f'<path d="M{x},{y} L{x+820},{y} L{x+360},{y+h} L{x},{y+h} Z" fill="#fff" opacity="0.03"/></g>')

COMMON_DEFS = (
    '<radialGradient id="sc" cx="0.5" cy="0.28" r="1.0"><stop offset="0" stop-color="#0c1712"/><stop offset="0.72" stop-color="#050a08"/></radialGradient>'
    '<filter id="gl" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="6"/></filter>'
    '<filter id="gl2" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="12"/></filter>'
    '<pattern id="scan" width="1" height="3" patternUnits="userSpaceOnUse"><rect width="1" height="1" fill="#000" opacity="0.26"/></pattern>'
    f'<clipPath id="cl"><rect x="{SCR[0]}" y="{SCR[1]}" width="{SCR[2]}" height="{SCR[3]}" rx="16"/></clipPath>'
)

# ---------------- FRAME A: GHOSTLINE ----------------
def frame_a():
    P = ['<defs>' + COMMON_DEFS +
         '<linearGradient id="bzA" x1="0" y1="0" x2="1" y2="0.6"><stop offset="0" stop-color="#2c3835"/><stop offset="0.42" stop-color="#141c1a"/><stop offset="1" stop-color="#0d1412"/></linearGradient>'
         '<pattern id="hz" width="36" height="18" patternUnits="userSpaceOnUse" patternTransform="rotate(0)">'
         f'<path d="M0,18 L18,0 L27,0 L9,18 Z" fill="{ACID}" opacity="0.55"/></pattern>'
         '</defs>']
    bez = "M0,52 L37,0 L1560,0 L1600,26 L1902,26 L2048,96 L2048,972 L2004,1024 L820,1024 L790,1002 L146,1002 L0,932 Z"
    P.append(f'<path d="{bez}" fill="url(#bzA)" stroke="#000" stroke-width="2"/><path d="{bez}" fill="none" stroke="#fff" stroke-width="1" opacity="0.08"/>')
    # vents top-right
    for i in range(7):
        P.append(f'<rect x="{1650+i*40}" y="8" width="22" height="10" rx="3" fill="#0a0f0d" stroke="#333f3b" stroke-width="1"/>')
    # hazard chevron strip bottom-left
    P.append('<g clip-path="url(#hzclip)"><rect x="150" y="1006" width="620" height="14" fill="url(#hz)"/></g>')
    P.append('<clipPath id="hzclip"><rect x="150" y="1006" width="620" height="14" rx="6"/></clipPath>')
    # cable channel right-bottom
    P.append(f'<path d="M1910,1010 q60,4 90,-30" stroke="#0a0f0d" stroke-width="10" fill="none"/><path d="M1910,1010 q60,4 90,-30" stroke="#26332e" stroke-width="6" fill="none"/>')
    for rx, ry in [(40, 38), (1908, 44), (40, 968), (1968, 984)]:
        P.append(f'<circle cx="{rx}" cy="{ry}" r="9" fill="#3a4a45" stroke="#0c110f" stroke-width="2"/><path d="M{rx-5},{ry} h10 M{rx},{ry-5} v10" stroke="#0c110f" stroke-width="2"/>')
    P.append('<circle cx="960" cy="22" r="6" fill="#0a0f0d" stroke="#354540" stroke-width="2"/><rect x="985" y="18" width="90" height="6" rx="3" fill="#2a3532"/>')
    ky = 190
    for lab in ["F", "◉", "+", "-", "●"]:
        col = DANGER if lab == "●" else INK_DIM
        P.append(f'<rect x="1944" y="{ky-26}" width="56" height="52" rx="10" fill="#1b2422" stroke="#000" stroke-width="2"/>')
        P.append(f'<text x="1972" y="{ky+9}" font-family="{MONO}" font-size="26" font-weight="bold" fill="{col}" text-anchor="middle">{lab}</text>')
        ky += 140
    screen_and_brand(P, ACID, CYAN)
    P.append(f'<text x="1848" y="1018" font-family="{MONO}" font-size="20" fill="{INK_FAINT}" text-anchor="end" style="letter-spacing:4px">GHOSTLINE MK-II</text>')
    return svg(P)

# ---------------- FRAME B: CORPO SLAB ----------------
def frame_b():
    P = ['<defs>' + COMMON_DEFS +
         '<linearGradient id="bzB" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#20262b"/><stop offset="0.5" stop-color="#14181c"/><stop offset="1" stop-color="#0c0f12"/></linearGradient>'
         '<linearGradient id="seam" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#33ffbb"/><stop offset="1" stop-color="#ff3d81"/></linearGradient>'
         '</defs>']
    P.append('<rect x="0" y="0" width="2048" height="1024" rx="42" fill="url(#bzB)" stroke="#000" stroke-width="2"/>')
    P.append('<rect x="3" y="3" width="2042" height="1018" rx="40" fill="none" stroke="#fff" stroke-width="1" opacity="0.07"/>')
    # dual neon seams
    P.append(f'<path d="M42,10 H1600" stroke="url(#seam)" stroke-width="3" opacity="0.9" filter="url(#gl)"/>')
    P.append(f'<path d="M448,1014 H2006" stroke="url(#seam)" stroke-width="3" opacity="0.9" filter="url(#gl)"/>')
    # port dots left edge
    for i in range(5):
        P.append(f'<circle cx="20" cy="{330+i*80}" r="7" fill="#0a0d10" stroke="#2c3540" stroke-width="2"/><circle cx="20" cy="{330+i*80}" r="2.5" fill="{CYAN}" opacity="{0.9-0.15*i}"/>')
    # fingerprint pad bottom-left
    P.append('<rect x="80" y="988" width="120" height="26" rx="13" fill="#0a0d10" stroke="#2c3540" stroke-width="2"/>')
    for i in range(4): P.append(f'<path d="M{104+i*20},994 q6,7 0,14" stroke="#3a4a55" stroke-width="2" fill="none"/>')
    P.append('<circle cx="960" cy="23" r="6" fill="#0a0d10" stroke="#2c3540" stroke-width="2"/><rect x="985" y="19" width="90" height="6" rx="3" fill="#242c33"/>')
    ky = 200
    for lab in ["F", "◉", "+", "-", "●"]:
        col = DANGER if lab == "●" else "#8fa0aa"
        P.append(f'<circle cx="1996" cy="{ky}" r="27" fill="#171c21" stroke="#000" stroke-width="2"/><circle cx="1996" cy="{ky}" r="27" fill="none" stroke="#2c3540" stroke-width="1"/>')
        P.append(f'<text x="1996" y="{ky+9}" font-family="{MONO}" font-size="25" font-weight="bold" fill="{col}" text-anchor="middle">{lab}</text>')
        ky += 138
    screen_and_brand(P, CYAN, MAGENTA)
    P.append(f'<text x="1840" y="1014" font-family="{MONO}" font-size="19" fill="#55636d" text-anchor="end" style="letter-spacing:5px">KIROSHI // CORPO SLAB</text>')
    return svg(P)

# ---------------- FRAME C: SCRAP-TECH ----------------
def frame_c():
    P = ['<defs>' + COMMON_DEFS +
         '<linearGradient id="bzC" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2a2622"/><stop offset="0.5" stop-color="#1a1714"/><stop offset="1" stop-color="#12100d"/></linearGradient>'
         '<pattern id="wstripe" width="28" height="28" patternUnits="userSpaceOnUse">'
         f'<rect width="28" height="28" fill="#141210"/><path d="M-7,28 L21,0 M7,28 L35,0" stroke="{AMBER}" stroke-width="8"/></pattern>'
         '</defs>']
    bez = "M0,60 L48,0 L980,0 L1010,18 L1890,18 L2048,88 L2048,960 L1990,1024 L180,1024 L0,940 Z"
    P.append(f'<path d="{bez}" fill="url(#bzC)" stroke="#000" stroke-width="3"/>')
    # mismatched panel patches
    P.append('<path d="M1010,18 L1890,18 L2048,88 L2048,300 L1010,300 Z" fill="#221f24" opacity="0.85" stroke="#000" stroke-width="2"/>')
    P.append('<path d="M0,620 L360,620 L360,940 L0,940 Z" fill="#1e2420" opacity="0.9" stroke="#000" stroke-width="2"/>')
    P.append(f'<path d="M0,60 L48,0 L980,0 L980,40 L20,40 Z" fill="#26221c" opacity="0.7"/>')
    # weld seams
    P.append('<path d="M1010,20 V300 M360,620 V940" stroke="#3a342c" stroke-width="4" stroke-dasharray="7 5"/>')
    # torx screws
    for sx, sy in [(30, 34), (1000, 36), (1912, 60), (2014, 986), (30, 968), (700, 1006), (1400, 1004)]:
        P.append(f'<circle cx="{sx}" cy="{sy}" r="11" fill="#41403c" stroke="#000" stroke-width="2"/><path d="M{sx},{sy-6} l5,3 v6 l-5,3 l-5,-3 v-6 Z" fill="#1c1b18"/>')
    # warning stripe tape bottom
    P.append('<rect x="430" y="1000" width="500" height="18" fill="url(#wstripe)" stroke="#000" stroke-width="2" transform="rotate(-1 680 1009)"/>')
    # stickers
    P.append(f'<g transform="rotate(-6 210 120)"><rect x="150" y="96" width="120" height="48" rx="6" fill="#0d0b09" stroke="{AMBER}" stroke-width="2"/>'
             f'<text x="210" y="128" font-family="{MONO}" font-size="26" fill="{AMBER}" text-anchor="middle">危険</text></g>')
    P.append(f'<g transform="rotate(4 1770 966)"><circle cx="1760" cy="966" r="26" fill="#0d0b09" stroke="{MAGENTA}" stroke-width="2"/>'
             f'<path d="M1748,960 l7,7 M1755,960 l-7,7 M1765,960 l7,7 M1772,960 l-7,7" stroke="{MAGENTA}" stroke-width="3"/>'
             f'<path d="M1748,976 q12,10 24,0" stroke="{MAGENTA}" stroke-width="3" fill="none"/></g>')
    P.append('<circle cx="960" cy="30" r="6" fill="#0a0908" stroke="#3a342c" stroke-width="2"/>')
    ky = 210
    for lab in ["F", "◉", "+", "-", "●"]:
        col = DANGER if lab == "●" else "#9a8f80"
        P.append(f'<rect x="1946" y="{ky-24}" width="52" height="48" rx="6" fill="#201c18" stroke="#000" stroke-width="3"/>')
        P.append(f'<text x="1972" y="{ky+9}" font-family="{MONO}" font-size="25" font-weight="bold" fill="{col}" text-anchor="middle">{lab}</text>')
        ky += 132
    screen_and_brand(P, AMBER, DANGER)
    P.append(f'<text x="1830" y="1016" font-family="{MONO}" font-size="20" fill="#6a5f50" text-anchor="end" style="letter-spacing:3px">SCRAP-TECH v0.9 · NO WARRANTY</text>')
    return svg(P)

# ---------------- FRAME D: HOLO EDGE ----------------
def frame_d():
    P = ['<defs>' + COMMON_DEFS +
         '<linearGradient id="edgeD" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b57bff"/><stop offset="0.55" stop-color="#5fd3ff"/><stop offset="1" stop-color="#33ffbb"/></linearGradient>'
         '<linearGradient id="bzD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#101318"/><stop offset="1" stop-color="#0a0c10"/></linearGradient>'
         '</defs>']
    P.append('<rect x="6" y="6" width="2036" height="1012" rx="30" fill="url(#bzD)"/>')
    P.append('<rect x="6" y="6" width="2036" height="1012" rx="30" fill="none" stroke="url(#edgeD)" stroke-width="4" filter="url(#gl2)" opacity="0.9"/>')
    P.append('<rect x="6" y="6" width="2036" height="1012" rx="30" fill="none" stroke="url(#edgeD)" stroke-width="2"/>')
    # corner antennas
    P.append(f'<path d="M30,40 L8,10 M2018,40 L2040,10" stroke="{ICE}" stroke-width="3"/><circle cx="8" cy="10" r="5" fill="{VIOLET}" filter="url(#gl)"/><circle cx="2040" cy="10" r="5" fill="{CYAN}" filter="url(#gl)"/>')
    # HUD ticks along bottom glass
    for i in range(24):
        P.append(f'<rect x="{200+i*70}" y="1002" width="16" height="4" rx="2" fill="#3c4750" opacity="0.8"/>')
    P.append('<circle cx="960" cy="26" r="5" fill="#0a0c10" stroke="#3c4750" stroke-width="2"/>')
    ky = 220
    for lab in ["F", "◉", "+", "-", "●"]:
        col = DANGER if lab == "●" else "#8fa0aa"
        P.append(f'<rect x="1990" y="{ky-24}" width="44" height="48" rx="22" fill="#12151a" stroke="url(#edgeD)" stroke-width="1.5"/>')
        P.append(f'<text x="2012" y="{ky+8}" font-family="{MONO}" font-size="22" font-weight="bold" fill="{col}" text-anchor="middle">{lab}</text>')
        ky += 128
    screen_and_brand(P, VIOLET, CYAN)
    P.append(f'<text x="1830" y="1014" font-family="{MONO}" font-size="19" fill="#4a5560" text-anchor="end" style="letter-spacing:6px">HOLO EDGE // N3XTECH</text>')
    return svg(P)

# ============================ ICONS ============================
# 256px tile; glyphs authored in a 100x100 box centered.
def tile(inner, accent, label):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
            '<defs>'
            '<linearGradient id="tg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#101d17"/><stop offset="1" stop-color="#070d0b"/></linearGradient>'
            f'<filter id="ig" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="5"/></filter>'
            '</defs>'
            # tile: cut-corner squircle
            f'<path d="M40,16 H198 L240,58 V216 Q240,240 216,240 H58 L16,198 V40 Q16,16 40,16 Z" fill="url(#tg)" stroke="{accent}" stroke-width="3" stroke-opacity="0.65"/>'
            f'<path d="M40,16 H198 L240,58 V216 Q240,240 216,240 H58 L16,198 V40 Q16,16 40,16 Z" fill="none" stroke="#fff" stroke-width="1" opacity="0.06"/>'
            # corner notch tick
            f'<path d="M198,16 L240,58" stroke="{accent}" stroke-width="5"/>'
            # glyph group (scaled into center)
            f'<g transform="translate(48,44) scale(1.6)">{inner}</g>'
            # accent underline tick
            f'<rect x="96" y="216" width="64" height="6" rx="3" fill="{accent}" filter="url(#ig)"/>'
            '</svg>')

def S(paths, accent, w1=7, w2=5):
    """main strokes (ink) + accent strokes"""
    main, acc = paths
    out = ""
    if main: out += f'<path d="{main}" fill="none" stroke="{INK}" stroke-width="{w1}" stroke-linecap="round" stroke-linejoin="round"/>'
    if acc:  out += f'<path d="{acc}" fill="none" stroke="{accent}" stroke-width="{w2}" stroke-linecap="round" stroke-linejoin="round"/>'
    return out

ICONS = [
 # name, accent, (ink path, accent path)  -- 100x100 box
 ("cyberdeck", ACID, ("M8,22 h84 v56 h-84 Z M8,34 h84", "M20,48 l12,10 -12,10 M44,68 h20 M72,10 l10,-10 M82,0 h8")),
 ("admin", ICE, ("M50,6 L88,20 V52 q0,26 -38,40 -38,-14 -38,-40 V20 Z", "M50,34 a9,9 0 1,1 -0.1,0 M50,43 v16")),
 ("camera", INK_DIM, ("M12,30 h20 l8,-12 h20 l8,12 h20 v48 h-76 Z", "M50,52 a14,14 0 1,1 -0.1,0 M50,52 a6,6 0 1,1 -0.1,0")),
 ("group", CYAN, ("M30,34 a12,12 0 1,1 -0.1,0 M10,84 q0,-22 20,-22 t20,22 M70,38 a10,10 0 1,1 -0.1,0 M56,80 q2,-16 14,-16 t16,16", "M44,50 h12 M50,44 v12")),
 ("mygang", DANGER, ("M28,30 a11,11 0 1,1 -0.1,0 M50,26 a11,11 0 1,1 -0.1,0 M72,30 a11,11 0 1,1 -0.1,0 M8,84 q0,-20 20,-20 M36,84 q0,-24 14,-24 t14,24 M92,84 q0,-20 -20,-20", "M30,88 h40 M35,96 h30")),
 ("captures", AMBER, ("M30,90 V12 M30,14 h44 l-10,14 10,14 h-44", "M84,50 a22,22 0 0,1 0,30 M76,58 a10,10 0 0,1 0,14")),
 ("perks", VIOLET, ("M50,8 l10,22 24,3 -17,17 4,24 -21,-11 -21,11 4,-24 -17,-17 24,-3 Z", "M50,70 v20 M38,84 h24")),
 ("talents", CYAN, ("M50,12 q-20,-6 -28,10 q-12,4 -10,18 q-8,12 4,20 q2,14 16,14 q8,10 18,4 M50,12 q20,-6 28,10 q12,4 10,18 q8,12 -4,20 q-2,14 -16,14 q-8,10 -18,4 M50,12 V82", "M34,34 q10,4 8,14 M66,30 q-10,6 -6,16 M40,62 h8 M60,56 a5,5 0 1,1 -0.1,0")),
 ("infamy", DANGER, ("M50,10 q26,0 26,26 q0,14 -10,20 v10 h-32 v-10 q-10,-6 -10,-20 q0,-26 26,-26 Z M38,78 h24 M40,88 h20", "M40,34 l8,8 M48,34 l-8,8 M60,34 l8,8 M68,34 l-8,8")),
 ("keychain", ACID, ("M30,18 a16,16 0 1,1 -0.1,0 M30,50 V88 M30,66 h14 M30,80 h10", "M30,26 a7,7 0 1,1 -0.1,0 M58,74 a12,12 0 1,1 -0.1,0 M66,66 l14,-14 M74,58 l6,6")),
 ("licenses", ICE, ("M10,22 h80 v56 h-80 Z", "M22,40 a8,8 0 1,1 -0.1,0 M14,66 q8,-10 16,0 M48,38 h30 M48,50 h30 M48,62 h20")),
 ("settings", INK_DIM, ("M50,30 a20,20 0 1,1 -0.1,0 M50,10 v10 M50,80 v10 M10,50 h10 M80,50 h10 M22,22 l7,7 M71,71 l7,7 M78,22 l-7,7 M29,71 l-7,7", "M50,42 a8,8 0 1,1 -0.1,0")),
 ("wallpaper", VIOLET, ("M12,18 h76 v64 h-76 Z", "M20,70 l18,-20 12,12 14,-18 16,20 M66,32 a6,6 0 1,1 -0.1,0")),
 ("wanted", DANGER, ("M50,14 a36,36 0 1,1 -0.1,0 M50,2 v16 M50,82 v16 M2,50 h16 M82,50 h16", "M50,38 a8,8 0 1,1 -0.1,0 M36,72 q4,-12 14,-12 t14,12")),
 ("gangsonline", CYAN, ("M50,12 a38,38 0 1,1 -0.1,0 M12,50 h76 M50,12 q-18,18 -18,38 t18,38 M50,12 q18,18 18,38 t-18,38", "M32,30 a7,7 0 1,1 -0.1,0 M64,64 a7,7 0 1,1 -0.1,0")),
 ("bounty", AMBER, ("M50,16 a34,34 0 1,1 -0.1,0 M50,6 v12 M50,82 v12 M6,50 h12 M82,50 h12", "M44,38 q6,-6 12,0 t0,12 l-12,8 v6 M50,72 v4")),
 ("prestige", ICE, ("M22,44 L50,26 L78,44 M22,62 L50,44 L78,62 M22,80 L50,62 L78,80", "M50,4 l4,8 9,1 -6,6 1,9 -8,-4 -8,4 1,-9 -6,-6 9,-1 Z")),
 ("achieve", AMBER, ("M30,14 h40 v22 q0,20 -20,24 q-20,-4 -20,-24 Z M50,60 v14 M34,86 h32 M40,74 h20", "M30,20 h-14 q0,20 14,22 M70,20 h14 q0,20 -14,22")),
 ("titles", VIOLET, ("M20,16 h60 v56 l-30,-14 -30,14 Z", "M38,34 h24 M50,26 v24")),
 ("market", ACID, ("M10,86 h80 M18,78 V56 M38,78 V40 M58,78 V48 M78,78 V28", "M14,44 l22,-16 18,10 24,-22 M70,14 h10 v10")),
 ("housing", ACID, ("M14,50 L50,16 L86,50 M24,44 v40 h52 v-40", "M44,84 v-22 h12 v22 M62,58 a5,5 0 1,1 -0.1,0")),
 ("quests", AMBER, ("M26,10 h48 q-6,10 0,20 h-48 q6,-10 0,-20 Z M26,30 v58 q6,-8 12,0 q6,-8 12,0 q6,-8 12,0 q6,-8 12,0 V30", "M42,48 h22 M42,60 h22 M42,72 h14")),
 ("honor", ICE, ("M50,10 l9,18 20,3 -14,14 3,20 -18,-9 -18,9 3,-20 -14,-14 20,-3 Z", "M22,78 q28,16 56,0 M30,90 h40")),
 ("phone", CYAN, ("M26,10 q-10,0 -8,12 q6,44 52,58 q12,2 12,-8 v-12 l-16,-6 -8,8 q-20,-8 -26,-26 l8,-8 -6,-16 Z", "M62,18 q16,4 20,20 M66,6 q24,6 28,30")),
 ("casino", MAGENTA, ("M50,12 a38,38 0 1,1 -0.1,0 M50,24 a26,26 0 1,1 -0.1,0", "M50,12 v12 M50,76 v12 M12,50 h12 M76,50 h12 M28,28 l8,8 M64,64 l8,8 M72,28 l-8,8 M36,64 l-8,8")),
 ("browser", ICE, ("M50,12 a38,38 0 1,1 -0.1,0", "M18,36 h64 M18,64 h64 M50,12 q-16,18 -16,38 t16,38 M50,12 q16,18 16,38 t-16,38")),
 ("robotaxi", AMBER, ("M16,60 l7,-20 q3,-8 12,-8 h30 q9,0 12,8 l7,20 v20 h-11 v-7 h-46 v7 h-11 Z M27,42 h46", "M27,66 a6,6 0 1,1 -0.1,0 M67,66 a6,6 0 1,1 -0.1,0 M50,24 v-8 M40,8 a14,7 0 0,1 20,0 M34,2 a22,11 0 0,1 32,0")),
 ("ownermode", ACID, ("M16,72 V36 l16,14 18,-24 18,24 16,-14 v36 Z M16,80 h68", "M50,20 a5,5 0 1,1 -0.1,0")),
 # dock
 ("sync", CYAN, ("M28,44 a24,18 0 0,1 46,-6 q16,2 14,16 q-2,12 -16,12 h-40 q-14,0 -14,-12 q0,-8 10,-10 Z", "M42,78 l8,10 8,-10 M50,88 v-16")),
 ("money", ACID, ("M14,30 h72 v44 h-72 Z M14,42 h72 M14,62 h72", "M50,44 a9,9 0 1,1 -0.1,0 M26,52 h4 M70,52 h4")),
 ("message", CYAN, ("M12,18 h76 v50 h-44 l-20,16 v-16 h-12 Z", "M26,34 h48 M26,46 h48 M26,58 h28")),
 ("inventory", VIOLET, ("M30,30 v-8 q0,-12 20,-12 t20,12 v8 M14,30 h72 l-6,56 h-60 Z", "M38,46 v10 M62,46 v10 M32,72 h36")),
]

def build():
    os.makedirs('/tmp/nf', exist_ok=True)
    frames = {'a': frame_a(), 'b': frame_b(), 'c': frame_c(), 'd': frame_d()}
    for k, s in frames.items():
        open(f'/tmp/nf/frame_{k}.svg', 'w').write(s)
        subprocess.run(['rsvg-convert', '-w', str(W), '-h', str(H), f'/tmp/nf/frame_{k}.svg', '-o', f'/tmp/nf/frame_{k}.png'], check=True)
    # frames review sheet (2x2 half-scale + labels)
    subprocess.run(['magick', 'montage', '-background', '#141414', '-geometry', '1024x512+12+12', '-tile', '2x2',
                    '-label', 'A  GHOSTLINE MK-II', '/tmp/nf/frame_a.png', '-label', 'B  CORPO SLAB', '/tmp/nf/frame_b.png',
                    '-label', 'C  SCRAP-TECH', '/tmp/nf/frame_c.png', '-label', 'D  HOLO EDGE', '/tmp/nf/frame_d.png',
                    '-fill', 'white', '-pointsize', '28', f'{SC}/frames_review.png'], check=True)
    # icons
    for name, accent, paths in ICONS:
        open(f'/tmp/nf/ic_{name}.svg', 'w').write(tile(S(paths, accent), accent, name))
        subprocess.run(['rsvg-convert', '-w', '256', '-h', '256', f'/tmp/nf/ic_{name}.svg', '-o', f'/tmp/nf/ic_{name}.png'], check=True)
    args = ['magick', 'montage', '-background', '#101010', '-geometry', '128x128+10+16', '-tile', '7x',
            '-fill', 'white', '-pointsize', '13']
    for name, _, _ in ICONS:
        args += ['-label', name, f'/tmp/nf/ic_{name}.png']
    args.append(f'{SC}/icons_review.png')
    subprocess.run(args, check=True)
    print("wrote frames_review.png + icons_review.png")

if __name__ == '__main__':
    build()
