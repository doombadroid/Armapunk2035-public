#!/usr/bin/env python3
"""
render_frames_v2.py -- PHOTOREAL pass on the deck frames (owner: "more photo realistic").
Same 2048x1024 + screen window (46,46,1848,932) + brand row/divider -> still drop-in.
Realism toolkit (all in-SVG, rsvg-supported): feTurbulence brushed-metal + micro-grain, layered
edge bevels (top-light / bottom-shadow), screen inner-shadow + glass reflection sweep, machined
key caps (radial gradients + specular dot + inset well), rubberized grip texture, scratch flecks,
vignette. 3 variants:
  A2 GHOSTLINE-R  -- worn gunmetal alloy, acid accents, hazard strip, grime.
  B2 CORPO-R      -- brushed graphite slab, precise chamfers, cyan/magenta seam light spill.
  D2 HOLO-R       -- smoked glass + machined titanium rim, violet/cyan edge light w/ falloff.
"""
import subprocess, os
SC = os.path.dirname(os.path.abspath(__file__))
W, H = 2048, 1024
SCR = (46, 46, 1848, 932)
CYBER = "'Orbitron', sans-serif"
MONO = "'JetBrainsMono Nerd Font', monospace"
ACID = "#c9e21a"; CYAN = "#33ffbb"; ICE = "#5fd3ff"; AMBER = "#ffb020"
DANGER = "#ff5a3c"; VIOLET = "#b57bff"; MAGENTA = "#ff3d81"
INK_DIM = "#7f918a"; INK_FAINT = "#4c5a55"

def svg(parts): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "\n".join(parts) + "</svg>"

def defs(extra=""):
    x, y, w, h = SCR
    return ('<defs>'
      # screen radial + scanlines
      '<radialGradient id="sc" cx="0.5" cy="0.25" r="1.05"><stop offset="0" stop-color="#0c1712"/><stop offset="0.72" stop-color="#050a08"/></radialGradient>'
      '<pattern id="scan" width="1" height="3" patternUnits="userSpaceOnUse"><rect width="1" height="1" fill="#000" opacity="0.24"/></pattern>'
      f'<clipPath id="cl"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14"/></clipPath>'
      '<filter id="gl" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="6"/></filter>'
      '<filter id="gl2" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="14"/></filter>'
      # brushed metal: horizontally-stretched turbulence
      '<filter id="brush" x="0" y="0" width="100%" height="100%">'
      '<feTurbulence type="fractalNoise" baseFrequency="0.004 0.35" numOctaves="4" seed="7" result="n"/>'
      '<feColorMatrix in="n" type="matrix" values="0 0 0 0 0.55  0 0 0 0 0.60  0 0 0 0 0.58  0 0 0 0.5 0"/>'
      '<feComposite operator="in" in2="SourceGraphic"/><feBlend mode="overlay" in2="SourceGraphic"/></filter>'
      # fine grain
      '<filter id="grain" x="0" y="0" width="100%" height="100%">'
      '<feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="11" result="g"/>'
      '<feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.18 0"/>'
      '<feComposite operator="in" in2="SourceGraphic"/><feBlend mode="multiply" in2="SourceGraphic"/></filter>'
      # scratches: stretched high-freq noise thresholded
      '<filter id="scratch" x="0" y="0" width="100%" height="100%">'
      '<feTurbulence type="turbulence" baseFrequency="0.002 0.9" numOctaves="2" seed="3" result="s"/>'
      '<feColorMatrix in="s" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 0.05 0"/>'
      '<feComposite operator="in" in2="SourceGraphic"/><feBlend mode="screen" in2="SourceGraphic"/></filter>'
      # inner shadow for the screen well
      '<filter id="innersh" x="-20%" y="-20%" width="140%" height="140%">'
      '<feOffset dx="0" dy="10"/><feGaussianBlur stdDeviation="14" result="o"/>'
      '<feComposite operator="out" in="SourceGraphic" in2="o"/>'
      '<feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.85 0"/>'
      '<feBlend mode="normal" in2="SourceGraphic"/></filter>'
      + extra + '</defs>')

def screen(P, accent, tag):
    x, y, w, h = SCR
    # recessed well: dark rim + inner shadow layers
    P.append(f'<rect x="{x-10}" y="{y-10}" width="{w+20}" height="{h+20}" rx="20" fill="#020403"/>')
    P.append(f'<rect x="{x-10}" y="{y-10}" width="{w+20}" height="{h+20}" rx="20" fill="none" stroke="#000" stroke-width="3"/>')
    P.append(f'<rect x="{x-9}" y="{y+h+6}" width="{w+18}" height="3" rx="1.5" fill="#3a4642" opacity="0.5"/>')  # bottom lip catch-light
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="#050a08"/>')
    P.append(f'<g clip-path="url(#cl)"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#sc)"/>')
    # top inner shadow (bezel overhang)
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="46" fill="#000" opacity="0.45"/>'
             f'<rect x="{x}" y="{y}" width="{w}" height="26" fill="#000" opacity="0.35"/>')
    # brand
    P.append(f'<circle cx="95" cy="106" r="9" fill="{accent}" filter="url(#gl)"/>')
    P.append(f'<text x="119" y="123" font-family={CYBER!r} font-size="44" font-weight="800" fill="{tag}" opacity="0.5" style="letter-spacing:5px">NEON AEGEAN</text>')
    P.append(f'<text x="116" y="120" font-family={CYBER!r} font-size="44" font-weight="800" fill="{accent}" style="letter-spacing:5px">NEON AEGEAN</text>')
    P.append(f'<text x="562" y="120" font-family={CYBER!r} font-size="25" font-weight="500" fill="{tag}" style="letter-spacing:9px">CYBERDECK</text>')
    P.append('<line x1="86" y1="150" x2="1854" y2="150" stroke="#2b3a35"/>')
    P.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#scan)"/>')
    # glass reflection sweep (diagonal soft band)
    P.append(f'<path d="M{x},{y} L{x+760},{y} L{x+300},{y+h} L{x},{y+h} Z" fill="#fff" opacity="0.035"/>')
    P.append(f'<path d="M{x+900},{y} L{x+1000},{y} L{x+540},{y+h} L{x+440},{y+h} Z" fill="#fff" opacity="0.018"/>')
    P.append('</g>')

def key(P, cx, cy, r, label, col, rim="#000", face1="#242e2b", face2="#101614"):
    P.append(f'<circle cx="{cx}" cy="{cy+3}" r="{r+3}" fill="#000" opacity="0.55" filter="url(#gl)"/>')     # drop shadow
    P.append(f'<circle cx="{cx}" cy="{cy}" r="{r+4}" fill="#0a0e0c" stroke="{rim}" stroke-width="2"/>')      # well
    P.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#keyface)"/>')
    P.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#fff" stroke-width="1" opacity="0.14"/>')
    P.append(f'<ellipse cx="{cx-r*0.3}" cy="{cy-r*0.45}" rx="{r*0.55}" ry="{r*0.3}" fill="#fff" opacity="0.10"/>')  # specular
    P.append(f'<text x="{cx}" y="{cy+9}" font-family="{MONO}" font-size="25" font-weight="bold" fill="{col}" text-anchor="middle">{label}</text>')

KEYFACE = ('<radialGradient id="keyface" cx="0.35" cy="0.3" r="1.1">'
           '<stop offset="0" stop-color="#2c3634"/><stop offset="0.6" stop-color="#1a2220"/><stop offset="1" stop-color="#0d1210"/></radialGradient>')

def bevel(P, path, light="#5a6a64", dark="#000", w1=3, w2=4, op=0.5):
    P.append(f'<path d="{path}" fill="none" stroke="{dark}" stroke-width="{w2}" opacity="0.9" transform="translate(0,2)"/>')
    P.append(f'<path d="{path}" fill="none" stroke="{light}" stroke-width="{w1}" opacity="{op}" transform="translate(0,-1)"/>')

def vignette(P):
    P.append('<rect x="0" y="0" width="2048" height="1024" fill="url(#vig)"/>')

VIG = '<radialGradient id="vig" cx="0.5" cy="0.5" r="0.75"><stop offset="0.72" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.42"/></radialGradient>'

# ---------------- A2 GHOSTLINE-R ----------------
def frame_a2():
    P = [defs(KEYFACE + VIG +
        '<linearGradient id="alloy" x1="0" y1="0" x2="0.25" y2="1">'
        '<stop offset="0" stop-color="#39443f"/><stop offset="0.18" stop-color="#242e2a"/>'
        '<stop offset="0.55" stop-color="#161e1b"/><stop offset="1" stop-color="#0e1412"/></linearGradient>'
        '<pattern id="hz" width="36" height="18" patternUnits="userSpaceOnUse">'
        f'<path d="M0,18 L18,0 L27,0 L9,18 Z" fill="{ACID}" opacity="0.5"/></pattern>')]
    bez = "M0,52 L37,0 L1560,0 L1600,26 L1902,26 L2048,96 L2048,972 L2004,1024 L820,1024 L790,1002 L146,1002 L0,932 Z"
    P.append(f'<path d="{bez}" fill="url(#alloy)"/>')
    P.append(f'<g filter="url(#brush)"><path d="{bez}" fill="#39433e"/></g>')
    P.append(f'<g filter="url(#grain)"><path d="{bez}" fill="#1a221f"/></g>')
    P.append(f'<g filter="url(#scratch)"><path d="{bez}" fill="#000"/></g>')
    P.append(f'<path d="{bez}" fill="none" stroke="#000" stroke-width="3"/>')
    bevel(P, bez, light="#6d7f78")
    # edge chamfer highlight along top
    P.append('<path d="M37,2 L1558,2" stroke="#8b9a92" stroke-width="2" opacity="0.35"/>')
    # vents (recessed with inner dark + lit lower lip)
    for i in range(7):
        vx = 1650 + i * 40
        P.append(f'<rect x="{vx}" y="34" width="22" height="11" rx="3" fill="#050806"/>'
                 f'<rect x="{vx}" y="43" width="22" height="2" fill="#4a5a52" opacity="0.5"/>')
    # hazard strip, worn (grain overlay)
    P.append('<g><rect x="150" y="1004" width="620" height="14" rx="6" fill="url(#hz)"/>'
             '<rect x="150" y="1004" width="620" height="14" rx="6" fill="#000" opacity="0.25"/></g>')
    # torx bolts
    for rx, ry in [(40, 38), (1908, 48), (40, 964), (1966, 982)]:
        P.append(f'<circle cx="{rx}" cy="{ry+2}" r="11" fill="#000" opacity="0.5"/>'
                 f'<circle cx="{rx}" cy="{ry}" r="10" fill="url(#keyface)" stroke="#05080a" stroke-width="2"/>'
                 f'<path d="M{rx},{ry-5} l4.3,2.5 v5 l-4.3,2.5 l-4.3,-2.5 v-5 Z" fill="#0a0d0b"/>'
                 f'<ellipse cx="{rx-3}" cy="{ry-4}" rx="4" ry="2.5" fill="#fff" opacity="0.15"/>')
    # cam
    P.append('<circle cx="960" cy="24" r="8" fill="#02040a"/><circle cx="960" cy="24" r="8" fill="none" stroke="#39443f" stroke-width="2"/>'
             '<circle cx="957" cy="21" r="2.4" fill="#7fd3ff" opacity="0.8"/><rect x="985" y="20" width="90" height="6" rx="3" fill="#252e2b"/>')
    ky = 190
    for lab in ["F", "◉", "+", "-", "●"]:
        key(P, 1972, ky, 25, lab, DANGER if lab == "●" else INK_DIM)
        ky += 140
    screen(P, ACID, CYAN)
    P.append(f'<text x="1848" y="1018" font-family="{MONO}" font-size="20" fill="{INK_FAINT}" text-anchor="end" style="letter-spacing:4px">GHOSTLINE MK-II</text>')
    vignette(P)
    return svg(P)

# ---------------- B2 CORPO-R ----------------
def frame_b2():
    P = [defs(KEYFACE + VIG +
        '<linearGradient id="slab" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#2b3339"/><stop offset="0.12" stop-color="#1d2429"/>'
        '<stop offset="0.6" stop-color="#131920"/><stop offset="1" stop-color="#0b0f14"/></linearGradient>'
        '<linearGradient id="seam" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#33ffbb"/><stop offset="1" stop-color="#ff3d81"/></linearGradient>')]
    P.append('<rect x="0" y="0" width="2048" height="1024" rx="44" fill="url(#slab)"/>')
    P.append('<g filter="url(#brush)"><rect x="0" y="0" width="2048" height="1024" rx="44" fill="#2a323a"/></g>')
    P.append('<g filter="url(#grain)"><rect x="0" y="0" width="2048" height="1024" rx="44" fill="#161c22"/></g>')
    P.append('<rect x="0" y="0" width="2048" height="1024" rx="44" fill="none" stroke="#000" stroke-width="3"/>')
    P.append('<rect x="2.5" y="2.5" width="2043" height="1019" rx="42" fill="none" stroke="#7d8c96" stroke-width="1.5" opacity="0.35"/>')
    P.append('<rect x="5" y="5" width="2038" height="1014" rx="41" fill="none" stroke="#000" stroke-width="1.5" opacity="0.6"/>')
    # chamfer top light
    P.append('<path d="M46,3 H2002" stroke="#a9b6be" stroke-width="1.5" opacity="0.4"/>')
    # seam lights + spill
    P.append('<path d="M42,12 H1600" stroke="url(#seam)" stroke-width="3" filter="url(#gl2)" opacity="0.8"/>')
    P.append('<path d="M42,12 H1600" stroke="url(#seam)" stroke-width="2"/>')
    P.append('<path d="M448,1012 H2006" stroke="url(#seam)" stroke-width="3" filter="url(#gl2)" opacity="0.8"/>')
    P.append('<path d="M448,1012 H2006" stroke="url(#seam)" stroke-width="2"/>')
    # machined port row (recessed)
    for i in range(5):
        py = 330 + i * 80
        P.append(f'<circle cx="20" cy="{py}" r="8" fill="#04060a"/><circle cx="20" cy="{py}" r="8" fill="none" stroke="#39434c" stroke-width="1.5"/>'
                 f'<circle cx="20" cy="{py}" r="2.6" fill="{CYAN}" opacity="{0.95-0.16*i}" filter="url(#gl)"/>')
    # fingerprint pad
    P.append('<rect x="80" y="986" width="120" height="26" rx="13" fill="#04060a" stroke="#39434c" stroke-width="1.5"/>')
    for i in range(4): P.append(f'<path d="M{104+i*20},992 q6,7 0,14" stroke="#4a5761" stroke-width="2" fill="none" opacity="0.8"/>')
    P.append('<circle cx="960" cy="24" r="7" fill="#04060a" stroke="#39434c" stroke-width="2"/><circle cx="957" cy="21" r="2" fill="#9fdcff" opacity="0.8"/>'
             '<rect x="985" y="20" width="90" height="6" rx="3" fill="#232b31"/>')
    ky = 200
    for lab in ["F", "◉", "+", "-", "●"]:
        key(P, 1996, ky, 26, lab, DANGER if lab == "●" else "#8fa0aa", face1="#262e35", face2="#0e1318")
        ky += 138
    screen(P, CYAN, MAGENTA)
    P.append('<text x="1840" y="1012" font-family="' + MONO + '" font-size="19" fill="#55636d" text-anchor="end" style="letter-spacing:5px">KIROSHI // CORPO SLAB</text>')
    vignette(P)
    return svg(P)

# ---------------- D2 HOLO-R ----------------
def frame_d2():
    P = [defs(KEYFACE + VIG +
        '<linearGradient id="edgeD" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b57bff"/><stop offset="0.55" stop-color="#5fd3ff"/><stop offset="1" stop-color="#33ffbb"/></linearGradient>'
        '<linearGradient id="ti" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#20262e"/><stop offset="0.5" stop-color="#12161d"/><stop offset="1" stop-color="#0a0d12"/></linearGradient>')]
    # titanium rim
    P.append('<rect x="0" y="0" width="2048" height="1024" rx="34" fill="url(#ti)"/>')
    P.append('<g filter="url(#brush)"><rect x="0" y="0" width="2048" height="1024" rx="34" fill="#242b33"/></g>')
    P.append('<g filter="url(#grain)"><rect x="0" y="0" width="2048" height="1024" rx="34" fill="#141920"/></g>')
    P.append('<rect x="0" y="0" width="2048" height="1024" rx="34" fill="none" stroke="#000" stroke-width="3"/>')
    P.append('<rect x="2.5" y="2.5" width="2043" height="1019" rx="32" fill="none" stroke="#8b98a4" stroke-width="1.2" opacity="0.4"/>')
    # smoked glass inner slab
    P.append('<rect x="14" y="14" width="2020" height="996" rx="26" fill="#0a0d11" opacity="0.92"/>')
    P.append('<rect x="14" y="14" width="2020" height="996" rx="26" fill="none" stroke="#000" stroke-width="2"/>')
    # neon edge with glow falloff (outside glass, inside rim)
    P.append('<rect x="14" y="14" width="2020" height="996" rx="26" fill="none" stroke="url(#edgeD)" stroke-width="5" filter="url(#gl2)" opacity="0.85"/>')
    P.append('<rect x="14" y="14" width="2020" height="996" rx="26" fill="none" stroke="url(#edgeD)" stroke-width="2"/>')
    # glass diagonal reflection across the slab
    P.append('<path d="M60,14 L520,14 L300,1010 L120,1010 Z" fill="#fff" opacity="0.022"/>')
    # corner antennas (machined)
    P.append(f'<path d="M30,42 L10,12 M2018,42 L2038,12" stroke="#7e8a96" stroke-width="3"/>'
             f'<circle cx="10" cy="12" r="5" fill="{VIOLET}" filter="url(#gl)"/><circle cx="2038" cy="12" r="5" fill="{CYAN}" filter="url(#gl)"/>')
    # HUD ticks
    for i in range(24):
        P.append(f'<rect x="{200+i*70}" y="1000" width="16" height="4" rx="2" fill="#46525c" opacity="0.7"/>')
    P.append('<circle cx="960" cy="26" r="6" fill="#04060a" stroke="#46525c" stroke-width="2"/><circle cx="957.5" cy="23.5" r="2" fill="#bfe6ff" opacity="0.9"/>')
    ky = 220
    for lab in ["F", "◉", "+", "-", "●"]:
        key(P, 2012, ky, 22, lab, DANGER if lab == "●" else "#8fa0aa")
        ky += 128
    screen(P, VIOLET, CYAN)
    P.append('<text x="1830" y="1010" font-family="' + MONO + '" font-size="19" fill="#4a5560" text-anchor="end" style="letter-spacing:6px">HOLO EDGE // N3XTECH</text>')
    vignette(P)
    return svg(P)

def build():
    os.makedirs('/tmp/nf2', exist_ok=True)
    for k, fn in [('a2', frame_a2), ('b2', frame_b2), ('d2', frame_d2)]:
        open(f'/tmp/nf2/frame_{k}.svg', 'w').write(fn())
        subprocess.run(['rsvg-convert', '-w', str(W), '-h', str(H), f'/tmp/nf2/frame_{k}.svg', '-o', f'/tmp/nf2/frame_{k}.png'], check=True)
        print('rendered', k)
    F = subprocess.run(['fc-match', '-f', '%{file}', 'DejaVu Sans:style=Bold'], capture_output=True, text=True).stdout.strip()
    subprocess.run(['magick', 'montage', '-font', F, '-background', '#141414', '-geometry', '1500x750+14+14', '-tile', '1x3',
                    '-label', 'A2  GHOSTLINE-R (worn alloy)', '/tmp/nf2/frame_a2.png',
                    '-label', 'B2  CORPO-R (brushed slab)', '/tmp/nf2/frame_b2.png',
                    '-label', 'D2  HOLO-R (smoked glass + titanium)', '/tmp/nf2/frame_d2.png',
                    '-fill', 'white', '-pointsize', '30', f'{SC}/frames_v2_review.png'], check=True)
    print('wrote frames_v2_review.png')

if __name__ == '__main__':
    build()
