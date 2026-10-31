#!/usr/bin/env python3
# LooneyBin phone-UI redesign mockup generator -> SVG -> PNG (rsvg-convert).
# Feature parity with AP_phone_buttons (25 apps). NOT in-game; mockups only.
import math, html

W, H = 430, 920           # logical phone screen
SCALE = 2                 # render scale
R = 60                    # phone corner radius

# ---- palette ---------------------------------------------------------------
ACC = {
    "comms":  "#5B9DFF",
    "gang":   "#B794F6",
    "econ":   "#34D399",
    "prop":   "#2DD4BF",
    "prog":   "#FBBF24",
    "crime":  "#F87171",
    "infamy": "#FB7185",
    "sys":    "#9AA7B8",
    "admin":  "#F472B6",
}
INK   = "#E8EEF6"
SUB   = "#8C9AAE"
CARD  = "#161E2B"
CARD2 = "#1E2838"

def esc(s): return html.escape(str(s), quote=True)

def squircle(x, y, w, h, r):
    # smooth rounded-rect (superellipse-ish via cubic corners)
    k = r * 0.55
    return (f"M{x+r},{y} H{x+w-r} C{x+w-k},{y} {x+w},{y+k} {x+w},{y+r} "
            f"V{y+h-r} C{x+w},{y+h-k} {x+w-k},{y+h} {x+w-r},{y+h} "
            f"H{x+r} C{x+k},{y+h} {x},{y+h-k} {x},{y+h-r} "
            f"V{y+r} C{x},{y+k} {x+k},{y} {x+r},{y} Z")

# ---- glyphs (drawn in a 24x24 box, white) ----------------------------------
# each returns inner SVG; transform places + scales it. stroke style is uniform.
def G(paths, fill=False):
    sw = "" if fill else 'fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'
    f  = 'fill="#fff"' if fill else ''
    return f'<g {sw} {f}>{paths}</g>'

GLYPHS = {
 "phone":  G('<path d="M6 4h4l2 5-3 2a11 11 0 0 0 5 5l2-3 5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 4 6a2 2 0 0 1 2-2z"/>'),
 "group":  G('<circle cx="8" cy="9" r="3"/><circle cx="16" cy="9" r="3"/><path d="M3 19c0-3 2.5-5 5-5s5 2 5 5M13.5 14.2c2.2-.2 4.5 1.7 4.5 4.8"/>'),
 "people": G('<circle cx="12" cy="8" r="3.2"/><path d="M5.5 19c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6"/>'),
 "globe":  G('<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.6 2.4 2.6 14.6 0 17M12 3.5c-2.6 2.4-2.6 14.6 0 17"/>'),
 "spark":  G('<path d="M12 3l2.3 5.2L20 10l-5.7 1.8L12 17l-2.3-5.2L4 10l5.7-1.8z"/><circle cx="18.5" cy="5.5" r="1.2" fill="#fff"/>'),
 "cart":   G('<circle cx="9.5" cy="20" r="1.4" fill="#fff"/><circle cx="17" cy="20" r="1.4" fill="#fff"/><path d="M3 4h2l2.2 11h11l2-7H6.5"/>'),
 "house":  G('<path d="M4 11l8-6 8 6"/><path d="M6 10.5V19h12v-8.5"/><path d="M10.5 19v-4.5h3V19"/>'),
 "key":    G('<circle cx="8" cy="9" r="3.6"/><path d="M10.4 11.4L20 21M16.5 17.5l2.2-2.2M14.3 15.3l2.2-2.2"/>'),
 "card":   G('<rect x="3.5" y="6" width="17" height="12" rx="2.5"/><path d="M3.5 10h17M6.5 14.5h5"/>'),
 "check":  G('<rect x="4.5" y="3.5" width="15" height="17" rx="2.5"/><path d="M8 9h8M8 13h8M8 17h5"/><path d="M7.5 6.2l1 1 1.6-1.8" stroke="#fff"/>'),
 "trophy": G('<path d="M8 4h8v4a4 4 0 0 1-8 0z"/><path d="M8 5H5v1a3 3 0 0 0 3 3M16 5h3v1a3 3 0 0 1-3 3M10 12.5h4M12 12.5V16M9 20h6M9.5 20l.6-4h3.8l.6 4"/>'),
 "ribbon": G('<circle cx="12" cy="9" r="5"/><path d="M9.5 13.3L8 21l4-2 4 2-1.5-7.7"/><path d="M12 6.5l.9 1.8 2 .3-1.4 1.4.3 2-1.8-1-1.8 1 .3-2L9.1 8.6l2-.3z" fill="#fff" stroke="none"/>'),
 "skill":  G('<circle cx="12" cy="5" r="2.4"/><circle cx="6" cy="18" r="2.4"/><circle cx="18" cy="18" r="2.4"/><path d="M12 7.4v4M12 11.4L6.8 16M12 11.4L17.2 16"/>'),
 "target": G('<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.4"/><path d="M12 1.5v3M12 19.5v3M1.5 12h3M19.5 12h3"/>'),
 "cross":  G('<circle cx="12" cy="12" r="8"/><path d="M12 7v10M7 12h10M12 1.5v2.5M12 20v2.5M1.5 12H4M20 12h2.5"/>'),
 "shieldstar": G('<path d="M12 3l7 2.5v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10v-5z"/><path d="M12 8.2l1 2 2.2.3-1.6 1.5.4 2.2-2-1-2 1 .4-2.2-1.6-1.5 2.2-.3z" fill="#fff" stroke="none"/>'),
 "skull":  G('<path d="M5 11a7 7 0 0 1 14 0v4l-1.5 1.5V19h-11v-2.5L5 15z"/><circle cx="9" cy="11.5" r="1.8" fill="#fff"/><circle cx="15" cy="11.5" r="1.8" fill="#fff"/><path d="M10.5 19v-2M13.5 19v-2"/>'),
 "medal":  G('<circle cx="12" cy="14.5" r="5"/><path d="M9 9.7L6.5 3.5M15 9.7L17.5 3.5M9.5 4.2h5"/><path d="M12 12l.8 1.6 1.7.2-1.3 1.2.3 1.7-1.5-.8-1.5.8.3-1.7-1.3-1.2 1.7-.2z" fill="#fff" stroke="none"/>'),
 "medplus":G('<circle cx="12" cy="14.5" r="5"/><path d="M9 9.7L6.5 3.5M15 9.7L17.5 3.5M9.5 4.2h5"/><path d="M12 12v5M9.5 14.5h5" stroke="#fff"/>'),
 "flag":   G('<path d="M6 21V4"/><path d="M6 5h11l-2 3 2 3H6"/>'),
 "gear":   G('<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M21.5 12h-3M5.5 12h-3M18.7 5.3l-2.1 2.1M7.4 16.6l-2.1 2.1M18.7 18.7l-2.1-2.1M7.4 7.4L5.3 5.3"/>'),
 "image":  G('<rect x="3.5" y="5" width="17" height="14" rx="2.5"/><circle cx="8.5" cy="10" r="1.8"/><path d="M4 17l5-4.5 4 3.5 3-2.5 4 3.5"/>'),
 "book":   G('<path d="M5 4h10a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M18 17H8a3 3 0 0 0-3 3"/><path d="M9 8h6M9 11h6" stroke="#fff"/>'),
 "shieldwr":G('<path d="M12 3l7 2.5v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10v-5z"/><path d="M13.5 9.2a2.3 2.3 0 0 0-3 3l-2 2 1.4 1.4 2-2a2.3 2.3 0 0 0 3-3l-1 1-1.2-.2-.2-1.2z" stroke="#fff"/>'),
 "camera": G('<rect x="3.5" y="7" width="17" height="12" rx="2.5"/><path d="M9 7l1.5-2.5h3L15 7"/><circle cx="12" cy="13" r="3.2"/>'),
}

# ---- apps (feature parity with AP_phone_buttons) -------------------------
APPS = [
 ("Phone","comms","phone"),   ("Group","comms","group"),
 ("My Gang","gang","people"), ("Perks","gang","spark"), ("Gangs","gang","globe"),
 ("Market","econ","cart"),    ("Housing","econ","house"),
 ("Keychain","prop","key"),   ("Licenses","prop","card"),  ("Quests","prop","check"),
 ("Talents","prog","skill"),  ("Awards","prog","trophy"), ("Titles","prog","ribbon"),
 ("Prestige","prog","medal"), ("TT","prog","medplus"),
 ("Wanted","crime","target"), ("Bounty","crime","cross"), ("Honor","crime","shieldstar"),
 ("Infamy","infamy","skull"),
 ("Captures","sys","flag"),   ("Settings","sys","gear"),   ("Wallpaper","sys","image"),
 ("Tutorial","sys","book"),
 ("Admin","admin","shieldwr"),("Camera","admin","camera"),
]
DOCK = [("Phone","comms","phone"),("My Gang","gang","people"),("Market","econ","cart"),("Settings","sys","gear")]

def tile(cx, cy, size, color, glyph, label=None, lab_dy=0):
    out = []
    out.append(f'<defs><linearGradient id="g{id(color)}{glyph}{int(cx)}{int(cy)}" x1="0" y1="0" x2="0" y2="1">'
               f'<stop offset="0" stop-color="{color}" stop-opacity="0.95"/>'
               f'<stop offset="1" stop-color="{color}" stop-opacity="0.62"/></linearGradient></defs>')
    grad = f"g{id(color)}{glyph}{int(cx)}{int(cy)}"
    out.append(f'<path d="{squircle(cx-size/2, cy-size/2, size, size, size*0.30)}" fill="url(#{grad})"/>')
    out.append(f'<path d="{squircle(cx-size/2, cy-size/2, size, size, size*0.30)}" fill="none" stroke="#fff" stroke-opacity="0.10"/>')
    gs = size/24*0.62
    out.append(f'<g transform="translate({cx-12*gs},{cy-12*gs}) scale({gs})">{GLYPHS[glyph]}</g>')
    if label is not None:
        out.append(f'<text x="{cx}" y="{cy+size/2+16+lab_dy}" font-size="11" fill="{INK}" text-anchor="middle" '
                   f'font-family="Inter,Segoe UI,Helvetica,Arial,sans-serif" opacity="0.92">{esc(label)}</text>')
    return "".join(out)

def status_bar(t="10:24"):
    # time left; signal/wifi/battery right
    bars = "".join(f'<rect x="{352+i*5}" y="{20-i*3-2}" width="3.2" height="{6+i*3}" rx="1" fill="{INK}"/>' for i in range(4))
    wifi = ('<path d="M372 12a10 10 0 0 1 14 0M375 16a6 6 0 0 1 8 0" fill="none" stroke="'+INK+'" stroke-width="2" '
            'stroke-linecap="round"/><circle cx="379" cy="20" r="1.5" fill="'+INK+'"/>')
    batt = (f'<rect x="392" y="11" width="22" height="11" rx="3" fill="none" stroke="{INK}" stroke-opacity="0.6"/>'
            f'<rect x="394" y="13" width="15" height="7" rx="1.5" fill="{INK}"/>'
            f'<rect x="414.5" y="14" width="2" height="5" rx="1" fill="{INK}" opacity="0.6"/>')
    return (f'<text x="28" y="24" font-size="15" fill="{INK}" font-weight="600" '
            f'font-family="Inter,Segoe UI,Helvetica,Arial,sans-serif">{t}</text>{bars}{wifi}{batt}')

def home_indicator():
    return f'<rect x="{W/2-65}" y="{H-20}" width="130" height="5" rx="2.5" fill="#fff" opacity="0.5"/>'

def frame_open(bg_id):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*SCALE}" height="{H*SCALE}" viewBox="0 0 {W} {H}">'
            f'<defs>'
            f'<radialGradient id="wall" cx="0.5" cy="0.0" r="1.2">'
            f'<stop offset="0" stop-color="#1B3A4B"/><stop offset="0.45" stop-color="#122130"/>'
            f'<stop offset="1" stop-color="#0A1019"/></radialGradient>'
            f'<linearGradient id="hb" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{CARD2}"/>'
            f'<stop offset="1" stop-color="{CARD}"/></linearGradient>'
            f'</defs>'
            f'<rect x="0" y="0" width="{W}" height="{H}" rx="{R}" fill="#000"/>'
            f'<rect x="3" y="3" width="{W-6}" height="{H-6}" rx="{R-3}" fill="url(#{bg_id})"/>'
            # soft accent glow
            f'<circle cx="{W*0.2}" cy="70" r="120" fill="#2DD4BF" opacity="0.10"/>'
            f'<circle cx="{W*0.85}" cy="40" r="100" fill="#5B9DFF" opacity="0.10"/>')

def frame_close():
    # notch + indicator
    return (f'<rect x="{W/2-58}" y="6" width="116" height="26" rx="13" fill="#000"/>'
            f'{home_indicator()}</svg>')

def header_card():
    x,y,w,h = 20, 50, W-40, 92
    out = [f'<path d="{squircle(x,y,w,h,26)}" fill="url(#hb)"/>',
           f'<path d="{squircle(x,y,w,h,26)}" fill="none" stroke="#fff" stroke-opacity="0.06"/>']
    # avatar
    out.append(f'<circle cx="{x+44}" cy="{y+h/2}" r="26" fill="#0E1622"/>')
    out.append(f'<circle cx="{x+44}" cy="{y+h/2}" r="26" fill="none" stroke="{ACC["prop"]}" stroke-opacity="0.7" stroke-width="2"/>')
    out.append(f'<text x="{x+44}" y="{y+h/2+6}" font-size="20" fill="{INK}" text-anchor="middle" font-weight="700" '
               f'font-family="Inter,Segoe UI,sans-serif">D</text>')
    out.append(f'<text x="{x+82}" y="{y+34}" font-size="18" fill="{INK}" font-weight="700" font-family="Inter,Segoe UI,sans-serif">Doomba</text>')
    out.append(f'<text x="{x+82}" y="{y+54}" font-size="12.5" fill="{SUB}" font-family="Inter,Segoe UI,sans-serif">Civilian · Pyrgos · Lvl 24</text>')
    # money pills
    out.append(f'<text x="{x+w-18}" y="{y+34}" font-size="16" fill="{ACC["econ"]}" text-anchor="end" font-weight="700" font-family="Inter,Segoe UI,sans-serif">$124,500</text>')
    out.append(f'<text x="{x+w-18}" y="{y+54}" font-size="12.5" fill="{SUB}" text-anchor="end" font-family="Inter,Segoe UI,sans-serif">Bank  $2.41M</text>')
    return "".join(out)

def render_home():
    s = [frame_open("wall"), status_bar(), header_card()]
    # search pill
    sx,sy,sw,sh = 20, 158, W-40, 36
    s.append(f'<path d="{squircle(sx,sy,sw,sh,18)}" fill="#0E1622" stroke="#fff" stroke-opacity="0.05"/>')
    s.append(f'<circle cx="{sx+20}" cy="{sy+sh/2}" r="6" fill="none" stroke="{SUB}" stroke-width="2"/>')
    s.append(f'<path d="M{sx+24} {sy+sh/2+4} l5 5" stroke="{SUB}" stroke-width="2" stroke-linecap="round"/>')
    s.append(f'<text x="{sx+38}" y="{sy+sh/2+5}" font-size="13.5" fill="{SUB}" font-family="Inter,Segoe UI,sans-serif">Search apps</text>')
    # grid
    cols = 5
    gx0, gy0 = 38, 230
    cw = (W - 2*38) / cols
    rh = 90
    size = 54
    for i,(label,cat,gl) in enumerate(APPS):
        r,c = divmod(i, cols)
        cx = gx0 + c*cw + cw/2 - 38 + 38
        cx = 28 + c*((W-56)/ (cols-1)) if cols>1 else W/2
        cy = gy0 + r*rh
        s.append(tile(cx, cy, size, ACC[cat], gl, label))
    # dock
    dy = H-96
    s.append(f'<path d="{squircle(16, dy-32, W-32, 84, 30)}" fill="#0C1320" fill-opacity="0.7"/>')
    s.append(f'<path d="{squircle(16, dy-32, W-32, 84, 30)}" fill="none" stroke="#fff" stroke-opacity="0.06"/>')
    for i,(label,cat,gl) in enumerate(DOCK):
        cx = 16 + (W-32)*(i+0.5)/4
        s.append(tile(cx, dy+2, 52, ACC[cat], gl, None))
    s.append(frame_close())
    return "".join(s)

# ---- detail: Market --------------------------------------------------------
def nav_header(title, accent):
    s=[f'<text x="28" y="86" font-size="26" fill="{INK}" font-weight="800" font-family="Inter,Segoe UI,sans-serif">{esc(title)}</text>']
    # back chevron
    s.append(f'<path d="M30 56 l-8 8 8 8" fill="none" stroke="{accent}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    s.append(f'<text x="44" y="64" font-size="14" fill="{accent}" font-family="Inter,Segoe UI,sans-serif">Home</text>')
    return "".join(s)

def render_market():
    s=[frame_open("wall"), status_bar(), nav_header("Market", ACC["econ"])]
    items=[("Heroin","#F87171",18450,"+12%",True),("Smash","#FB7185",16900,"+4%",True),
           ("Black Lace","#A78BFA",14200,"-3%",False),("Diamond","#5B9DFF",9800,"+8%",True),
           ("Gold Bar","#FBBF24",78375,"steady",None),("Oil","#34D399",6420,"-1%",False),
           ("Marijuana","#34D399",3120,"+6%",True),("Copper","#9AA7B8",1840,"+2%",True)]
    y=120
    for name,col,price,trend,up in items:
        s.append(f'<path d="{squircle(20,y,W-40,58,18)}" fill="{CARD}"/>')
        s.append(f'<path d="{squircle(28,y+11,36,36,11)}" fill="{col}" fill-opacity="0.85"/>')
        s.append(f'<circle cx="46" cy="{y+29}" r="6" fill="#fff" opacity="0.9"/>')
        s.append(f'<text x="78" y="{y+27}" font-size="15.5" fill="{INK}" font-weight="600" font-family="Inter,Segoe UI,sans-serif">{esc(name)}</text>')
        s.append(f'<text x="78" y="{y+45}" font-size="11.5" fill="{SUB}" font-family="Inter,Segoe UI,sans-serif">per unit</text>')
        s.append(f'<text x="{W-30}" y="{y+27}" font-size="15.5" fill="{INK}" text-anchor="end" font-weight="700" font-family="Inter,Segoe UI,sans-serif">${price:,}</text>')
        tc = ACC["econ"] if up else (SUB if up is None else ACC["crime"])
        arrow = "▲" if up else ("–" if up is None else "▼")
        s.append(f'<text x="{W-30}" y="{y+45}" font-size="11.5" fill="{tc}" text-anchor="end" font-family="Inter,Segoe UI,sans-serif">{arrow} {esc(trend)}</text>')
        y+=68
    # tab bar
    s.append(tabbar("Market"))
    s.append(frame_close()); return "".join(s)

def render_gang():
    s=[frame_open("wall"), status_bar(), nav_header("My Gang", ACC["gang"])]
    # crest card
    cx,cy,cw,ch=20,108,W-40,118
    s.append(f'<path d="{squircle(cx,cy,cw,ch,24)}" fill="url(#hb)"/>')
    s.append(f'<path d="{squircle(cx+18,cy+22,74,74,22)}" fill="{ACC["gang"]}" fill-opacity="0.85"/>')
    s.append(f'<g transform="translate({cx+18+37-18},{cy+22+37-18}) scale(1.5)">{GLYPHS["people"]}</g>')
    s.append(f'<text x="{cx+108}" y="{cy+44}" font-size="20" fill="{INK}" font-weight="800" font-family="Inter,Segoe UI,sans-serif">Drunk Squad</text>')
    s.append(f'<text x="{cx+108}" y="{cy+66}" font-size="12.5" fill="{SUB}" font-family="Inter,Segoe UI,sans-serif">12 members · Rank: Leader</text>')
    s.append(f'<text x="{cx+108}" y="{cy+96}" font-size="12.5" fill="{SUB}" font-family="Inter,Segoe UI,sans-serif">Gang Bank</text>')
    s.append(f'<text x="{cx+cw-18}" y="{cy+96}" font-size="18" fill="{ACC["econ"]}" text-anchor="end" font-weight="700" font-family="Inter,Segoe UI,sans-serif">$1,840,000</text>')
    # action chips
    chips=[("Bank",ACC["econ"]),("Perks",ACC["prog"]),("Invite",ACC["comms"]),("Wars",ACC["crime"])]
    chx=20
    for lab,col in chips:
        cwid=(W-40-3*10)/4
        s.append(f'<path d="{squircle(chx,238,cwid,42,14)}" fill="{CARD}"/>')
        s.append(f'<path d="{squircle(chx,238,cwid,42,14)}" fill="none" stroke="{col}" stroke-opacity="0.5"/>')
        s.append(f'<text x="{chx+cwid/2}" y="{238+27}" font-size="12.5" fill="{col}" text-anchor="middle" font-weight="600" font-family="Inter,Segoe UI,sans-serif">{lab}</text>')
        chx+=cwid+10
    s.append(f'<text x="28" y="312" font-size="12" fill="{SUB}" letter-spacing="1.5" font-family="Inter,Segoe UI,sans-serif">MEMBERS</text>')
    mem=[("Doomba","Leader",True),("player110","Officer",True),("player099","Officer",False),
         ("player100","Member",True),("player107","Member",False),("player108","Recruit",True)]
    y=326
    for name,rank,online in mem:
        s.append(f'<path d="{squircle(20,y,W-40,50,16)}" fill="{CARD}"/>')
        s.append(f'<circle cx="46" cy="{y+25}" r="15" fill="#0E1622"/>')
        s.append(f'<text x="46" y="{y+30}" font-size="13" fill="{INK}" text-anchor="middle" font-weight="700" font-family="Inter,Segoe UI,sans-serif">{esc(name[0])}</text>')
        dot = ACC["econ"] if online else SUB
        s.append(f'<circle cx="57" cy="{y+15}" r="4.5" fill="{dot}" stroke="{CARD}" stroke-width="2"/>')
        s.append(f'<text x="72" y="{y+24}" font-size="14.5" fill="{INK}" font-weight="600" font-family="Inter,Segoe UI,sans-serif">{esc(name)}</text>')
        s.append(f'<text x="72" y="{y+40}" font-size="11.5" fill="{SUB}" font-family="Inter,Segoe UI,sans-serif">{esc(rank)} · {"online" if online else "offline"}</text>')
        y+=58
    s.append(tabbar("Gang"))
    s.append(frame_close()); return "".join(s)

def tabbar(active):
    y=H-78
    s=[f'<path d="{squircle(16,y,W-32,62,26)}" fill="#0C1320" fill-opacity="0.85"/>',
       f'<path d="{squircle(16,y,W-32,62,26)}" fill="none" stroke="#fff" stroke-opacity="0.06"/>']
    tabs=[("Home","house"),("Market","cart"),("Gang","people"),("Settings","gear")]
    for i,(lab,gl) in enumerate(tabs):
        cx=16+(W-32)*(i+0.5)/4
        col = ACC["prop"] if lab==active else SUB
        s.append(f'<g transform="translate({cx-9},{y+12}) scale(0.78)"><g fill="none" stroke="{col}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{strip_white(GLYPHS[gl])}</g></g>')
        s.append(f'<text x="{cx}" y="{y+52}" font-size="10.5" fill="{col}" text-anchor="middle" font-family="Inter,Segoe UI,sans-serif">{lab}</text>')
    return "".join(s)

def strip_white(g):
    import re
    return re.sub(r'(fill|stroke)="#fff"','',g)

import subprocess, os
if __name__ == "__main__":
 os.makedirs("/tmp/phone", exist_ok=True)
 for name, fn in [("home",render_home),("market",render_market),("gang",render_gang)]:
    svg = fn()
    open(f"/tmp/phone/{name}.svg","w",encoding="utf-8").write(svg)
    subprocess.run(["rsvg-convert","-w",str(W*SCALE),"-h",str(H*SCALE),
                    f"/tmp/phone/{name}.svg","-o",f"/tmp/phone/phone_{name}.png"], check=True)
    print("rendered", name)
print("done")
