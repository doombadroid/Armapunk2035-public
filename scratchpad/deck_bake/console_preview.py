#!/usr/bin/env python3
"""
ICEBREAKER/TAL OS console PREVIEW. Composites the real baked deck chrome (deck_ice|tal.png, 2176x1350
= 32.237 x 20 grid cells, 67.5 px/cell, centre 1088,675) with simulated LIVE overlays at the exact
qh_console.hpp cell coords (QS cancels: it scales chrome and overlays alike in-game). Mirrors
fn_qhConsole fills so the console can be eyeballed BEFORE re-baking/deploying.

  python3 console_preview.py [--pal ice|tal] [--state current|v2] [--out preview.png]

--state v2      : the SHIPPED layout (NEARBY rows, footer strip, slot tags — all baked in deck_*.png
                  since 2026-07-22); this previewer draws only the LIVE overlays.
--state current : deprecated (pre-v2 coords, no longer match the baked art).
"""
import argparse, math
from PIL import Image, ImageDraw, ImageFont

HERE = "/home/timb/loonybin-doomba/scratchpad/deck_bake/"
FONT = "/home/timb/.local/share/fonts/JetBrainsMono/JetBrainsMonoNerdFontPropo-SemiBold.ttf"
PXC = 67.5          # px per grid cell in the 2176x1350 render
CXP, CYP = 1088, 675

PAL = {
  "ice": {"acc":(200,245,58),"util":(51,255,187),"danger":(255,90,60),"ink":(220,239,224),
          "dim":(127,147,138),"faint":(70,90,81),"panel":(9,18,14),"panel2":(12,24,19),"line":(38,66,50)},
  "tal": {"acc":(245,166,35),"util":(84,176,255),"danger":(255,77,77),"ink":(219,230,242),
          "dim":(125,139,158),"faint":(60,74,92),"panel":(10,15,22),"panel2":(13,20,29),"line":(40,56,76)},
}

TILES = [  # id, glyph, tone, name, blurb, foot
  ("ping","gping","acc","Ping.exe","Reveals the mark on your HUD for 20s.","2s up · 60s cd · 150m"),
  ("whiteout","gwhiteout","acc","Whiteout","Kills their HUD + chat for 25s.","3s up · 45s cd · 60m"),
  ("synapse","gsynapse","acc","Synapse Drag","Slows sprint to a jog for 20s.","3s up · 60s cd · 40m"),
  ("leech","gleech","util","Leech","Siphons $500-2k from their wallet.","4s up · 90s cd · 15m"),
  ("static","gstatic","acc","Static Burst","Earrape burst, flinches aim.","3s up · 45s cd · 60m"),
  ("distract","gjam","util","Distract.exe","Pops the mark's ringtone / car alarm.","1s up · 30s cd · 50m"),
]
LIB = ["Ping.exe","Whiteout","Synapse Drag","Leech","Static Burst","Distract.exe","Sticky Fingers",
       "Plate Ghost","Wiretap","Short Circuit","Eye Spy","Valet","Car Breach","House Breach","ATM Jackpot","Cuff Cracker"]
NEARBY = [("Hatchback (Sport)","veh",18),("D. Kessler","per",34),("Offroad","veh",52),("Quadbike","veh",71)]

def cell(x): return CXP + x*PXC
def celly(y): return CYP + y*PXC

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pal", default="ice"); ap.add_argument("--state", default="current")
    ap.add_argument("--out", default=HERE+"console_preview.png")
    a = ap.parse_args(); P = PAL[a.pal]
    img = Image.open(HERE+f"deck_{a.pal}.png").convert("RGBA")
    dr = ImageDraw.Draw(img)
    def F(px): return ImageFont.truetype(FONT, int(px))
    def txt(xy, s, rgb, px, anchor="la"):
        f = F(px)
        dr.text((xy[0]+1.5, xy[1]+1.5), s, font=f, fill=(5,9,7,215), anchor=anchor)
        dr.text(xy, s, font=f, fill=rgb+(255,), anchor=anchor)
    def wraptxt(xy, sstr, rgb, px, maxw, maxlines=2):
        f = F(px); words = sstr.split(); lines = []; cur = ""
        for w in words:
            t = (cur+" "+w).strip()
            if f.getlength(t) <= maxw or not cur: cur = t
            else: lines.append(cur); cur = w
        lines.append(cur)
        for li, ln in enumerate(lines[:maxlines]):
            txt((xy[0], xy[1]+li*px*1.25), ln, rgb, px)
    def tint(png, rgb, box):
        im = Image.open(HERE+png).convert("RGBA"); al = im.split()[3]
        solid = Image.new("RGBA", im.size, rgb+(0,)); solid.putalpha(al)
        img.alpha_composite(solid.resize((int(box[2]),int(box[3]))), (int(box[0]),int(box[1])))

    # ---- status strip (right) ----
    gw = F(0.42*PXC).getlength("GHOST")
    txt((cell(6.92+6.858), celly(-9.052)), "GHOST", P["acc"], 0.42*PXC, anchor="ra")
    txt((cell(6.92+6.858)-gw-0.6*PXC, celly(-9.052)), "$14,200", P["ink"], 0.42*PXC, anchor="ra")

    # ---- target scope ----
    tint("ic_gkill.png", P["acc"], (cell(-11.467), celly(-5.037), 1.541*PXC, 1.541*PXC))
    if a.state == "current":
        txt((cell(-14.696), celly(-1.674)), "Hatchback (Sport)", P["ink"], 0.5*PXC)
        txt((cell(-10.929), celly(-1.62)+0.06*PXC), "vehicle", P["acc"], 0.32*PXC)   # collides w/ long names (real bug)
        txt((cell(-10.0), celly(-0.696)), "18 m", P["acc"], 0.38*PXC)
    else:
        txt((cell(-14.696), celly(-1.674)), "Hatchback (Sport)", P["ink"], 0.5*PXC)
        txt((cell(-14.696), celly(-0.85)), "vehicle · 18 m", P["acc"], 0.36*PXC)
    txt((cell(-14.696), celly(0.081)), "DRIVER", P["dim"], 0.38*PXC)
    txt((cell(-10.7), celly(0.081)), "empty", P["ink"], 0.38*PXC)
    txt((cell(-14.696), celly(0.919)), "[ line of sight ]  [ in range ]", P["util"], 0.33*PXC)

    if a.state == "current":
        # bottom 4-button switch bar labels (today's target switcher)
        for i,(nm,kd,ds) in enumerate(NEARBY):
            bx = [-15.111,-12.896,-10.681,-8.467][i]
            lab = nm if len(nm) <= 12 else nm[:11]+"…"
            txt((cell(bx+1.1), celly(8.044+0.474)), lab, (P["acc"] if i==0 else P["dim"]), 0.30*PXC, anchor="mm")
    else:
        # v2 live overlays over the BAKED row plates (rows x -14.756 w 8.119, y 2.230 + k*1.4515, h 1.244)
        ROWY = [2.230, 3.681, 5.133, 6.585]
        # selection wash (mirror fn_qhConsolePick: acc @ 10% over the whole row)
        si = 0
        swy = celly(ROWY[si])
        wash = Image.new("RGBA", (int(8.119*PXC), int(1.244*PXC)), P["acc"]+(26,))
        img.alpha_composite(wash, (int(cell(-14.756)), int(swy)))
        for i,(nm,kd,ds) in enumerate(NEARBY):
            sel = (i == si); top = celly(ROWY[i])
            g = "ic_gvalet.png" if kd == "veh" else "ic_gdetain.png"
            tint(g, (P["acc"] if sel else (140,158,148)), (cell(-14.46), top+0.237*PXC, 0.77*PXC, 0.77*PXC))
            txt((cell(-13.452), top+0.30*PXC), nm, (P["acc"] if sel else P["ink"]), 0.42*PXC)
            txt((cell(-6.933), top+0.33*PXC), f"{ds} m", (P["acc"] if sel else P["dim"]), 0.38*PXC, anchor="ra")
        txt((cell(-14.696), celly(8.09)), "UPLINK READY", P["util"], 0.38*PXC)
        txt((cell(-6.933), celly(8.09)), "TRACE CLEAR", P["dim"], 0.38*PXC, anchor="ra")

    # ---- 6 loadout tiles ----
    TX = [-5.067, 1.333, 7.733]; TY = [-6.119, -2.059]
    for i,(iid,glyph,tone,name,blurb,foot) in enumerate(TILES):
        gx, gy = TX[i%3], TY[i//3]
        tint(f"ic_{glyph}.png", P[tone], (cell(gx), celly(gy), 0.889*PXC, 0.889*PXC))
        txt((cell(gx+1.156), celly(gy)+0.05*PXC), name, P["ink"], 0.44*PXC)
        wraptxt((cell(gx), celly(gy+1.067)), blurb, P["dim"], 0.36*PXC, 5.393*PXC)
        txt((cell(gx), celly(gy+2.638)), foot, P["faint"], 0.32*PXC)
        txt((cell(gx+5.393), celly(gy+2.578)), "FIRE", P[tone], 0.34*PXC, anchor="ra")


    # ---- library chips (mirror fn_qhConsoleChips flow math) ----
    x0, y0 = -5.422, 3.259; right = -5.422+18.904
    cx, cy, pitch = x0, y0+0.55, 1.02
    for j,nm in enumerate(LIB):
        cw = max(0.86 + (F(0.38*PXC).getlength(nm))/PXC + 0.30, 2.2)   # mirror fn_qhConsoleChips ctrlTextWidth sizing
        if cx+cw > right: cx = x0; cy += pitch
        if cy+0.889 > y0+5.348+0.4: break
        loaded = j < 6
        top = celly(cy)
        fill = P["panel2"]+(90,) if loaded else P["panel2"]+(230,)
        dr.rounded_rectangle([cell(cx), top, cell(cx+cw), top+0.889*PXC], radius=8, fill=fill)
        g = TILES[j][1] if j < 6 else "gblank"
        tint(f"ic_{g}.png", (P["acc"] if loaded else P["dim"]), (cell(cx+0.16), top+0.19*PXC, 0.52*PXC, 0.52*PXC))
        txt((cell(cx+0.74), top+0.26*PXC), nm, (P["acc"] if loaded else (200,210,203)), 0.38*PXC)
        cx += cw + 0.24
    img.convert("RGB").save(a.out); print("wrote", a.out, a.state, a.pal)

main()
