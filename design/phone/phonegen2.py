#!/usr/bin/env python3
# LooneyBin phone redesign -> Samsung One UI style. SVG -> PNG. Mockups only.
import math, html, subprocess, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from phonegen import GLYPHS, APPS, ACC, esc   # reuse glyph + app set

W, H, SCALE, R = 430, 920, 2, 62
PAD = 28          # One UI side margin (screen edge -> content)
ICON = 78         # app icon size (+50%)
COLS = 4          # Samsung One UI home grid is 4-wide
FONT = "Roboto,Inter,Segoe UI,Helvetica,Arial,sans-serif"

# One UI accent + neutrals
BLUE = "#0F7BFF"
LBG  = "#F3F3F5"      # light settings bg
CARD = "#FFFFFF"
INK1 = "#161616"      # primary text (light theme)
INK2 = "#86868B"      # secondary
WHT  = "#FFFFFF"
WSUB = "#E7ECF5"
CHEV="#C2C2C7"; LINE="#ECECEF"; TOFF="#C9C9CE"; CHIP="#E9E9EE"; AVBG="#E8EEFF"

# extra glyphs for One UI rows
GLYPHS = dict(GLYPHS)
GLYPHS["apps"]   = '<g fill="#fff">' + "".join(f'<rect x="{4+ (i%3)*7}" y="{4+(i//3)*7}" width="4.4" height="4.4" rx="1.4"/>' for i in range(9)) + '</g>'
GLYPHS["bell"]   = '<g fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 10a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6z"/><path d="M10 19a2 2 0 0 0 4 0"/></g>'
GLYPHS["sound"]  = '<g fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h3l5 4V5L7 9z"/><path d="M16 8a5 5 0 0 1 0 8M18.5 5.5a9 9 0 0 1 0 13"/></g>'
GLYPHS["moon"]   = '<path d="M16.5 3.4a8 8 0 1 0 5.1 13.4A9 9 0 0 1 16.5 3.4z" fill="#fff"/>'
GLYPHS["sun"]    = '<g fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.2 5.2l1.8 1.8M17 17l1.8 1.8M18.8 5.2L17 7M7 17l-1.8 1.8"/></g>'

def gly(cx, cy, scale, key, stroke=None):
    g = GLYPHS[key]
    if stroke:
        import re
        g = re.sub(r'#fff', stroke, g)
    return f'<g transform="translate({cx-12*scale},{cy-12*scale}) scale({scale})">{g}</g>'

def squircle(cx, cy, rad, n=4.4, steps=72):
    pts = []
    for i in range(steps + 1):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        x = cx + rad * math.copysign(abs(ct) ** (2 / n), ct)
        y = cy + rad * math.copysign(abs(st) ** (2 / n), st)
        pts.append(f"{x:.2f},{y:.2f}")
    return "M" + " L".join(pts) + " Z"

def rr(x, y, w, h, r):
    return (f"M{x+r},{y} H{x+w-r} A{r},{r} 0 0 1 {x+w},{y+r} V{y+h-r} "
            f"A{r},{r} 0 0 1 {x+w-r},{y+h} H{x+r} A{r},{r} 0 0 1 {x},{y+h-r} "
            f"V{y+r} A{r},{r} 0 0 1 {x+r},{y} Z")

def app_icon(cx, cy, size, color, glyph, label=None, lab_col=WHT, gscale=None):
    gid = f"ig{glyph}{int(cx)}{int(cy)}"
    s = [f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
         f'<stop offset="0" stop-color="{color}" stop-opacity="1"/>'
         f'<stop offset="1" stop-color="{color}" stop-opacity="0.78"/></linearGradient></defs>',
         f'<path d="{squircle(cx, cy, size/2)}" fill="url(#{gid})"/>',
         # soft top gloss
         f'<path d="{squircle(cx, cy-size*0.12, size*0.42)}" fill="#fff" opacity="0.10"/>']
    s.append(gly(cx, cy, (gscale or size/24*0.58), glyph))
    if label:
        s.append(f'<text x="{cx}" y="{cy+size/2+18}" font-size="12" fill="{lab_col}" text-anchor="middle" '
                 f'font-family="{FONT}" font-weight="500">{esc(label)}</text>')
    return "".join(s)

def statusbar(dark=False, restart_min=23):
    c = INK1 if dark else WHT
    # LEFT: server-restart countdown -- left edge at PAD, baseline aligned to the right icons
    glyph = (f'<g transform="translate({PAD+2},11)" fill="none" stroke="{c}" stroke-width="2" '
             f'stroke-linecap="round" stroke-linejoin="round"><path d="M2 6a5 5 0 1 1 1.5 3.6"/>'
             f'<path d="M2 2v4h4"/></g>')
    left = glyph + (f'<text x="{PAD+20}" y="22" font-size="14.5" fill="{c}" font-weight="700" '
                    f'font-family="{FONT}">{restart_min}m</text>')
    # RIGHT cluster (no wifi): signal bars, iGG, battery % + icon -- ending PAD from the right edge
    bars = "".join(f'<rect x="{300+i*5}" y="{16-i*3}" width="3.4" height="{6+i*3}" rx="1.2" fill="{c}"/>' for i in range(4))
    igg  = (f'<text x="348" y="22" font-size="12.5" fill="{c}" text-anchor="end" font-weight="700" '
            f'font-family="{FONT}" letter-spacing="0.2">iGG</text>')
    pct  = f'<text x="372" y="22" font-size="12.5" fill="{c}" text-anchor="end" font-weight="600" font-family="{FONT}">34</text>'
    bx   = W - PAD - 23     # battery right edge (nub) at W-PAD
    batt = (f'<rect x="{bx}" y="11.5" width="20" height="11" rx="3.2" fill="none" stroke="{c}" stroke-opacity="0.55"/>'
            f'<rect x="{bx+2}" y="13.5" width="14" height="7" rx="1.6" fill="{c}"/>'
            f'<rect x="{bx+21}" y="14.5" width="2" height="5" rx="1" fill="{c}" opacity="0.55"/>')
    return f'<g transform="translate(0,5)">{left + bars + igg + pct + batt}</g>'

def frame(bg_inner, notch_dark=True):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*SCALE}" height="{H*SCALE}" viewBox="0 0 {W} {H}">'
            f'<defs>'
            f'<linearGradient id="wall" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="#6D5BFF"/><stop offset="0.5" stop-color="#2E7BFF"/>'
            f'<stop offset="1" stop-color="#00C6CF"/></linearGradient>'
            f'<radialGradient id="blob" cx="0.25" cy="0.15" r="0.7">'
            f'<stop offset="0" stop-color="#fff" stop-opacity="0.28"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
            f'</defs>'
            f'<rect x="0" y="0" width="{W}" height="{H}" rx="{R}" fill="#0a0a0a"/>'
            f'<clipPath id="scr"><rect x="3" y="3" width="{W-6}" height="{H-6}" rx="{R-3}"/></clipPath>'
            f'<g clip-path="url(#scr)">{bg_inner}</g>')

def frame_close():
    return (f'<rect x="{W/2-52}" y="6" width="104" height="24" rx="12" fill="#000"/>'
            f'<rect x="{W/2-65}" y="{H-19}" width="130" height="5" rx="2.5" fill="#000" opacity="0.28"/></svg>')

def dots(cx, y, n, active):
    s = []
    for i in range(n):
        op = 1 if i == active else 0.45
        r = 3.2 if i == active else 2.6
        s.append(f'<circle cx="{cx-(n-1)*7/2+i*7}" cy="{y}" r="{r}" fill="#fff" opacity="{op}"/>')
    return "".join(s)

def dock(apps):
    y = H - 92
    s = [f'<path d="{rr(14, y, W-28, 78, 30)}" fill="#000" opacity="0.16"/>']
    for i, (lab, cat, gl) in enumerate(apps):
        cx = 14 + (W-28)*(i+0.5)/len(apps)
        col = ACC[cat] if cat in ACC else BLUE
        s.append(app_icon(cx, y+39, 54, col, gl))
    return "".join(s)

# ---------- HOME (One UI) ----------
def render_home():
    bg = (f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#wall)"/>'
          f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#blob)"/>')
    s = [frame(bg), statusbar()]
    # clock widget
    s.append(f'<text x="28" y="148" font-size="62" fill="#fff" font-weight="300" font-family="{FONT}" letter-spacing="-1">10:24</text>')
    s.append(f'<text x="30" y="178" font-size="16" fill="#fff" opacity="0.92" font-family="{FONT}" font-weight="500">Mon, 26 June</text>')
    s.append(f'<g transform="translate(30,196)">{gly(8,8,0.62,"sun")}</g>'
             f'<text x="48" y="203" font-size="14.5" fill="#fff" opacity="0.92" font-family="{FONT}">24°  Sunny · Pyrgos</text>')
    # favorites grid 5 cols x 2 rows
    favs = [("Phone","comms","phone"),("Group","comms","group"),("My Gang","gang","people"),
            ("Market","econ","cart"),("Housing","econ","house"),
            ("Wanted","crime","target"),("Quests","prop","check"),("Talents","prog","skill"),
            ("Keychain","prop","key"),("Settings","sys","gear")]
    for i,(lab,cat,gl) in enumerate(favs):
        r,c = divmod(i,COLS)
        cx = PAD + ICON/2 + c*((W - 2*PAD - ICON)/(COLS-1))
        cy = 308 + r*116
        s.append(app_icon(cx, cy, ICON, ACC[cat], gl, lab))
    s.append(dots(W/2, 632, 3, 0))
    s.append(dock([("Phone","comms","phone"),("My Gang","gang","people"),("Market","econ","cart"),
                   ("Camera","admin","camera"),("Apps","prop","apps")]))
    s.append(frame_close())
    return "".join(s)

# ---------- APP DRAWER (One UI, full parity) ----------
def render_drawer():
    bg = (f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#wall)"/>'
          f'<rect x="0" y="0" width="{W}" height="{H}" fill="#0A1424" opacity="0.55"/>')
    s = [frame(bg), statusbar()]
    # finder search pill
    sx,sy,sw,sh = 22,50,W-44,46
    s.append(f'<path d="{rr(sx,sy,sw,sh,23)}" fill="#fff" fill-opacity="0.16"/>')
    s.append(f'<circle cx="{sx+26}" cy="{sy+sh/2}" r="7" fill="none" stroke="#fff" stroke-opacity="0.8" stroke-width="2"/>')
    s.append(f'<path d="M{sx+31} {sy+sh/2+5} l6 6" stroke="#fff" stroke-opacity="0.8" stroke-width="2" stroke-linecap="round"/>')
    s.append(f'<text x="{sx+44}" y="{sy+sh/2+5}" font-size="15" fill="#fff" opacity="0.8" font-family="{FONT}">Search</text>')
    # full grid 5 cols
    for i,(lab,cat,gl) in enumerate(APPS[:20]):  # page 1 (Samsung pages the rest)
        r,c = divmod(i,COLS)
        cx = PAD + ICON/2 + c*((W - 2*PAD - ICON)/(COLS-1))
        cy = 168 + r*112
        s.append(app_icon(cx, cy, ICON, ACC[cat], gl, lab))
    s.append(dots(W/2, H-58, 2, 0))
    s.append(frame_close())
    return "".join(s)

# ---------- SETTINGS (One UI light) ----------
def toggle(x, y, on):
    bg = BLUE if on else TOFF
    kx = x+22 if on else x+11
    return (f'<rect x="{x}" y="{y}" width="44" height="26" rx="13" fill="{bg}"/>'
            f'<circle cx="{kx}" cy="{y+13}" r="10" fill="#fff"/>')

def srow(x, y, w, color, gl, title, sub, on, value, last=False):
    s = [f'<path d="{squircle(x+30, y+27, 19)}" fill="{color}"/>', gly(x+30, y+27, 0.62, gl)]
    s.append(f'<text x="{x+62}" y="{y+(31 if sub else 33)}" font-size="15.5" fill="{INK1}" font-family="{FONT}" font-weight="500">{esc(title)}</text>')
    if sub:
        s.append(f'<text x="{x+62}" y="{y+47}" font-size="12.5" fill="{INK2}" font-family="{FONT}">{esc(sub)}</text>')
    if on is not None:
        s.append(toggle(x+w-66, y+14, on))
    elif value is not None:
        s.append(f'<text x="{x+w-44}" y="{y+33}" font-size="14" fill="{INK2}" text-anchor="end" font-family="{FONT}">{esc(value)}</text>')
        s.append(f'<path d="M{x+w-34} {y+21} l6 6 -6 6" fill="none" stroke="{CHEV}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')
    else:
        s.append(f'<path d="M{x+w-34} {y+21} l6 6 -6 6" fill="none" stroke="{CHEV}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')
    if not last:
        s.append(f'<line x1="{x+62}" y1="{y+54}" x2="{x+w-20}" y2="{y+54}" stroke="{LINE}" stroke-width="1.4"/>')
    return "".join(s)

def set_theme(dark):
    global LBG, CARD, INK1, INK2, CHEV, LINE, TOFF, CHIP, AVBG
    if dark:
        LBG,CARD,INK1,INK2,CHEV,LINE,TOFF,CHIP,AVBG = "#0B0B0D","#1B1B1F","#F3F3F5","#9A9AA2","#5E5E66","#2B2B30","#3A3A40","#1F1F24","#14294A"
    else:
        LBG,CARD,INK1,INK2,CHEV,LINE,TOFF,CHIP,AVBG = "#F3F3F5","#FFFFFF","#161616","#86868B","#C2C2C7","#ECECEF","#C9C9CE","#E9E9EE","#E8EEFF"

def render_settings(dark=False):
    set_theme(dark)
    bg = f'<rect x="0" y="0" width="{W}" height="{H}" fill="{LBG}"/>'
    s = [frame(bg), statusbar(dark=not dark)]
    # big One UI header (bottom-aligned, lots of space above)
    s.append(f'<text x="{PAD}" y="118" font-size="30" fill="{INK1}" font-weight="700" font-family="{FONT}">Settings</text>')
    # search pill
    s.append(f'<path d="{rr(PAD,134,W-2*PAD,42,21)}" fill="{CHIP}"/>')
    s.append(f'<circle cx="{PAD+24}" cy="155" r="6.5" fill="none" stroke="{INK2}" stroke-width="2"/>')
    s.append(f'<path d="M{PAD+28} 159 l5 5" stroke="{INK2}" stroke-width="2" stroke-linecap="round"/>')
    s.append(f'<text x="{PAD+42}" y="160" font-size="14.5" fill="{INK2}" font-family="{FONT}">Search</text>')
    # profile card
    py=190
    s.append(f'<path d="{rr(PAD,py,W-2*PAD,80,26)}" fill="{CARD}"/>')
    s.append(f'<circle cx="{PAD+30}" cy="{py+40}" r="26" fill="{AVBG}"/>')
    s.append(f'<text x="{PAD+30}" y="{py+47}" font-size="22" fill="{BLUE}" text-anchor="middle" font-weight="700" font-family="{FONT}">D</text>')
    s.append(f'<text x="{PAD+70}" y="{py+36}" font-size="17" fill="{INK1}" font-weight="600" font-family="{FONT}">Doomba</text>')
    s.append(f'<text x="{PAD+70}" y="{py+56}" font-size="12.5" fill="{INK2}" font-family="{FONT}">Civilian · Lvl 24 · LooneyBin account</text>')
    # group 1: Display
    def card(y, rows):
        h = len(rows)*54+12
        out=[f'<path d="{rr(PAD,y,W-2*PAD,h,26)}" fill="{CARD}"/>']
        for i,r in enumerate(rows):
            out.append(srow(PAD, y+6+i*54, W-2*PAD, *r, last=(i==len(rows)-1)))
        return "".join(out), y+h
    s.append(f'<text x="30" y="296" font-size="13" fill="{INK2}" font-family="{FONT}" font-weight="600">Display &amp; HUD</text>')
    c1,y1 = card(306, [("#5E5E66","moon","Dark mode","Match the in-game night",dark,None),
                       ("#0F7BFF","sun","Show HUD","Status bars, money, hunger",True,None),
                       ("#34D399","flag","Map markers","Show cartels & jobs",True,None)])
    s.append(c1)
    s.append(f'<text x="30" y="{y1+30}" font-size="13" fill="{INK2}" font-family="{FONT}" font-weight="600">Notifications &amp; Sound</text>')
    c2,y2 = card(y1+40, [("#FB923C","bell","Kill / death feed",None,True,None),
                         ("#F472B6","sound","Voice chat (VON)","Direct + group",True,None),
                         ("#FBBF24","trophy","Achievement popups",None,False,None)])
    s.append(c2)
    s.append(f'<text x="30" y="{y2+30}" font-size="13" fill="{INK2}" font-family="{FONT}" font-weight="600">Personalization</text>')
    c3,_ = card(y2+40, [("#2DD4BF","image","Wallpaper",None,None,"Galaxy"),
                        ("#9AA7B8","gear","Advanced","Keybinds, performance",None,None)])
    s.append(c3)
    s.append(frame_close())
    return "".join(s)

def render_wallpaper(dark=False):
    BG = "#0B0B0D" if dark else "#F3F3F5"
    T1 = "#F3F3F5" if dark else "#161616"
    T2 = "#9A9AA2" if dark else "#86868B"
    grads = [("Galaxy",["#6D5BFF","#2E7BFF","#00C6CF"]),("Aurora",["#0EA5E9","#10B981","#84CC16"]),
             ("Sunset",["#F97316","#EF4444","#7C3AED"]),("Mint",["#34D399","#2DD4BF","#22D3EE"]),
             ("Mono",["#334155","#475569","#64748B"]),("Midnight",["#0B1220","#1E293B","#3B4A63"])]
    defs = "".join(f'<linearGradient id="wp{i}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{g[1][0]}"/><stop offset="0.5" stop-color="{g[1][1]}"/><stop offset="1" stop-color="{g[1][2]}"/></linearGradient>' for i,g in enumerate(grads))
    bg = f'<defs>{defs}</defs><rect x="0" y="0" width="{W}" height="{H}" fill="{BG}"/>'
    s = [frame(bg), statusbar(dark=not dark)]
    s.append(f'<path d="M30 56 l-8 8 8 8" fill="none" stroke="{BLUE}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    s.append(f'<text x="{PAD}" y="118" font-size="30" fill="{T1}" font-weight="700" font-family="{FONT}">Wallpaper</text>')
    s.append(f'<text x="{PAD}" y="146" font-size="13.5" fill="{T2}" font-family="{FONT}">Choose a background for your phone</text>')
    tw, th, gx = 108, 150, 25
    for i,(name,_g) in enumerate(grads):
        r,c = divmod(i,3); x = PAD + c*(tw+gx); y = 184 + r*(th+34)
        s.append(f'<clipPath id="tc{i}"><path d="{rr(x,y,tw,th,20)}"/></clipPath>')
        s.append(f'<g clip-path="url(#tc{i})"><rect x="{x}" y="{y}" width="{tw}" height="{th}" fill="url(#wp{i})"/><circle cx="{x+24}" cy="{y+28}" r="17" fill="#fff" opacity="0.16"/></g>')
        if i==0:
            s.append(f'<path d="{rr(x-3,y-3,tw+6,th+6,23)}" fill="none" stroke="{BLUE}" stroke-width="3"/>')
            s.append(f'<circle cx="{x+tw-16}" cy="{y+16}" r="11" fill="{BLUE}"/>')
            s.append(f'<path d="M{x+tw-21} {y+16} l3.4 3.4 6-6.4" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>')
        s.append(f'<text x="{x+tw/2}" y="{y+th+22}" font-size="13" fill="{T1}" text-anchor="middle" font-family="{FONT}" font-weight="500">{name}</text>')
    s.append(f'<path d="{rr(PAD,H-104,W-2*PAD,52,26)}" fill="{BLUE}"/>')
    s.append(f'<text x="{W/2}" y="{H-71}" font-size="16" fill="#fff" text-anchor="middle" font-weight="700" font-family="{FONT}">Apply Galaxy</text>')
    s.append(frame_close())
    return "".join(s)

def render_market(dark=False):
    set_theme(dark)
    s=[frame(f'<rect x="0" y="0" width="{W}" height="{H}" fill="{LBG}"/>'), statusbar(dark=not dark)]
    s.append(f'<path d="M30 56 l-8 8 8 8" fill="none" stroke="{BLUE}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    s.append(f'<text x="{PAD}" y="118" font-size="30" fill="{INK1}" font-weight="700" font-family="{FONT}">Market</text>')
    s.append(f'<text x="{PAD}" y="144" font-size="13" fill="{INK2}" font-family="{FONT}">Live sell prices &#183; updated 2m ago</text>')
    items=[("Heroin","#F87171","18,450","12%",1),("Smash","#FB7185","16,900","4%",1),
           ("Black Lace","#A78BFA","14,200","3%",-1),("Diamond","#5B9DFF","9,800","8%",1),
           ("Gold Bar","#FBBF24","78,375","",0),("Oil","#34D399","6,420","1%",-1),
           ("Marijuana","#22C55E","3,120","6%",1),("Copper","#9AA7B8","1,840","2%",1)]
    y0=168; rh=56; ch=len(items)*rh+12
    s.append(f'<path d="{rr(PAD,y0,W-2*PAD,ch,26)}" fill="{CARD}"/>')
    for i,(name,col,price,pv,d) in enumerate(items):
        y=y0+6+i*rh
        s.append(f'<path d="{squircle(PAD+30,y+27,18)}" fill="{col}"/>')
        s.append(f'<circle cx="{PAD+30}" cy="{y+27}" r="6.5" fill="#fff" opacity="0.92"/>')
        s.append(f'<text x="{PAD+60}" y="{y+25}" font-size="15" fill="{INK1}" font-weight="600" font-family="{FONT}">{name}</text>')
        s.append(f'<text x="{PAD+60}" y="{y+43}" font-size="11.5" fill="{INK2}" font-family="{FONT}">per unit</text>')
        s.append(f'<text x="{W-PAD-20}" y="{y+25}" font-size="15" fill="{INK1}" text-anchor="end" font-weight="700" font-family="{FONT}">${price}</text>')
        tc = "#16A34A" if d>0 else ("#EF4444" if d<0 else INK2)
        ar = "&#9650;" if d>0 else ("&#9660;" if d<0 else "&#8211;")
        lab = (ar+" "+pv) if pv else (ar+" steady")
        s.append(f'<text x="{W-PAD-20}" y="{y+43}" font-size="11.5" fill="{tc}" text-anchor="end" font-family="{FONT}">{lab}</text>')
        if i<len(items)-1:
            s.append(f'<line x1="{PAD+60}" y1="{y+50}" x2="{W-PAD-16}" y2="{y+50}" stroke="{LINE}" stroke-width="1.2"/>')
    s.append(frame_close()); return "".join(s)

def render_mygang(dark=False):
    set_theme(dark)
    s=[frame(f'<rect x="0" y="0" width="{W}" height="{H}" fill="{LBG}"/>'), statusbar(dark=not dark)]
    s.append(f'<path d="M30 56 l-8 8 8 8" fill="none" stroke="{BLUE}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    s.append(f'<text x="{PAD}" y="118" font-size="30" fill="{INK1}" font-weight="700" font-family="{FONT}">My Gang</text>')
    cy0=146; ch=112
    s.append(f'<path d="{rr(PAD,cy0,W-2*PAD,ch,26)}" fill="{CARD}"/>')
    s.append(f'<path d="{squircle(PAD+56,cy0+56,36)}" fill="{ACC["gang"]}"/>')
    s.append(gly(PAD+56,cy0+56,1.6,"people"))
    s.append(f'<text x="{PAD+106}" y="{cy0+44}" font-size="20" fill="{INK1}" font-weight="800" font-family="{FONT}">Drunk Squad</text>')
    s.append(f'<text x="{PAD+106}" y="{cy0+66}" font-size="12.5" fill="{INK2}" font-family="{FONT}">12 members &#183; Rank: Leader</text>')
    s.append(f'<text x="{PAD+106}" y="{cy0+94}" font-size="12.5" fill="{INK2}" font-family="{FONT}">Gang Bank</text>')
    s.append(f'<text x="{W-PAD-18}" y="{cy0+94}" font-size="17" fill="#16A34A" text-anchor="end" font-weight="700" font-family="{FONT}">$1,840,000</text>')
    chips=[("Bank","#16A34A"),("Perks","#D97706"),("Invite",BLUE),("Wars","#EF4444")]
    chy=cy0+ch+14; cw=(W-2*PAD-3*10)/4
    for i,(lab,col) in enumerate(chips):
        cx=PAD+i*(cw+10)
        s.append(f'<path d="{rr(cx,chy,cw,44,15)}" fill="{CARD}"/>')
        s.append(f'<path d="{rr(cx,chy,cw,44,15)}" fill="none" stroke="{col}" stroke-opacity="0.45"/>')
        s.append(f'<text x="{cx+cw/2}" y="{chy+28}" font-size="13" fill="{col}" text-anchor="middle" font-weight="600" font-family="{FONT}">{lab}</text>')
    s.append(f'<text x="{PAD+4}" y="{chy+78}" font-size="13" fill="{INK2}" font-family="{FONT}" font-weight="600">MEMBERS</text>')
    mem=[("Doomba","Leader",1),("player110","Officer",1),("player099","Officer",0),("player100","Member",1),("player107","Member",0),("player108","Recruit",1)]
    my0=chy+92; rh=54
    s.append(f'<path d="{rr(PAD,my0,W-2*PAD,len(mem)*rh+12,26)}" fill="{CARD}"/>')
    for i,(nm,rk,on) in enumerate(mem):
        y=my0+6+i*rh
        s.append(f'<circle cx="{PAD+32}" cy="{y+27}" r="17" fill="{CHIP}"/>')
        s.append(f'<text x="{PAD+32}" y="{y+32}" font-size="14" fill="{INK1}" text-anchor="middle" font-weight="700" font-family="{FONT}">{nm[0]}</text>')
        dot = "#16A34A" if on else "#B0B0B6"
        s.append(f'<circle cx="{PAD+44}" cy="{y+16}" r="5" fill="{dot}" stroke="{CARD}" stroke-width="2"/>')
        s.append(f'<text x="{PAD+62}" y="{y+25}" font-size="14.5" fill="{INK1}" font-weight="600" font-family="{FONT}">{nm}</text>')
        s.append(f'<text x="{PAD+62}" y="{y+42}" font-size="11.5" fill="{INK2}" font-family="{FONT}">{rk} &#183; {"online" if on else "offline"}</text>')
        if i<len(mem)-1:
            s.append(f'<line x1="{PAD+62}" y1="{y+48}" x2="{W-PAD-16}" y2="{y+48}" stroke="{LINE}" stroke-width="1.2"/>')
    s.append(frame_close()); return "".join(s)

if __name__ == "__main__":
    os.makedirs("/tmp/phone", exist_ok=True)
    for name, fn in [("oneui_home", render_home), ("oneui_drawer", render_drawer), ("oneui_settings", lambda: render_settings(False)), ("oneui_settings_dark", lambda: render_settings(True)), ("oneui_wallpaper", lambda: render_wallpaper(False)), ("oneui_market", render_market), ("oneui_mygang", render_mygang)]:
        svg = fn()
        open(f"/tmp/phone/{name}.svg", "w", encoding="utf-8").write(svg)
        subprocess.run(["rsvg-convert", "-w", str(W*SCALE), "-h", str(H*SCALE),
                        f"/tmp/phone/{name}.svg", "-o", f"/tmp/phone/{name}.png"], check=True)
        print("rendered", name)
    print("done")
