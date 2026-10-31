#!/usr/bin/env python3
"""
Visor-dock in-game PREVIEW. Mirrors core/items/fn_qhDockFill.sqf layout math exactly and composites the real
baked assets (vrdock_bar/card, vr_visor, vrtile, qicons glyphs) over a game background, so the dock can be
eyeballed BEFORE deploying. Keep the constants below in sync with the SQF driver.

  python3 dock_preview.py [--res 2560x1080] [--pal ice|tal] [--cursor 0.46] [--bg path] [--out preview.png]
"""
import sys, math, argparse
from PIL import Image, ImageDraw, ImageFont

HERE = "/home/timb/loonybin-doomba/scratchpad/deck_bake/"
FONT = "/home/timb/.local/share/fonts/JetBrainsMono/JetBrainsMonoNerdFontPropo-SemiBold.ttf"

# ---- palette (mirror fn_qhDockFill) ----
PAL = {
  "ice": {"acc":(200,245,58),"util":(51,255,187),"danger":(255,90,60),"ink":(228,242,230),"dim":(133,144,137),"faint":(74,90,81)},
  "tal": {"acc":(245,166,35),"util":(84,176,255),"danger":(255,77,77),"ink":(226,236,246),"dim":(128,144,160),"faint":(66,80,95)},
}
# id -> glyph, tone, name, "Us cd Rm" stat  (mirror AP_qhIcon / AP_qhTone / qhCfg)
CAT = {
  "ping":("gping","acc","Ping.exe","2s up · 60s cd · 150m"),
  "whiteout":("gwhiteout","acc","Whiteout","3s up · 45s cd · 60m"),
  "synapse":("gsynapse","acc","Synapse Drag","3s up · 60s cd · 40m"),
  "leech":("gleech","util","Leech","4s up · 90s cd · 15m"),
  "static":("gstatic","acc","Static Burst","3s up · 45s cd · 60m"),
  "distract":("gjam","util","Distract.exe","1s up · 30s cd · 50m"),
  "sticky":("gsticky","acc","Sticky Fingers","2s up · 45s cd · 40m"),
  "unlock":("gcarlock","util","Car Breach","breach tool · free"),
  "house":("ghouse","util","House Breach","breach tool · free"),
  "atm":("gatm","util","ATM Jackpot","breach tool · free"),
  "cuffs":("gcuffs","danger","Cuff Cracker","breach tool · free"),
  "firewall":("gshield","util","Firewall: 2/2","firewall chips"),
}

def tint(png, rgb, k=1.0, am=1.0):
    im = Image.open(png).convert("RGBA"); a = im.split()[3]
    if am != 1.0: a = a.point(lambda v: int(v*am))
    c = tuple(min(255,int(v*k)) for v in rgb)
    solid = Image.new("RGBA", im.size, c+(0,)); solid.putalpha(a); return solid

def game_bg(W,H):
    bg = Image.new("RGB",(W,H)); d=ImageDraw.Draw(bg)
    for y in range(H):                                   # bright daytime: sky -> hazy bright concrete
        t=y/H
        if t<0.5: c=(int(120+95*t),int(150+70*t),int(190+50*t))
        else: u=(t-0.5)/0.5; c=(int(206+10*u),int(201+7*u),int(192+5*u))
        d.line([(0,y),(W,y)],fill=c)
    cx=W//2                                              # rough player silhouette (dock sits below the feet)
    d.ellipse([cx-int(0.028*W),int(0.5*H),cx+int(0.028*W),int(0.8*H)],fill=(74,76,58))
    d.ellipse([cx-int(0.011*W),int(0.44*H),cx+int(0.011*W),int(0.52*H)],fill=(150,112,86))
    return bg

def build_items(pal, cop=False):
    load=["ping","whiteout","synapse","leech","static","distract"]
    items=[(i,0) for i in load if i not in ("unlock","house","atm","cuffs")]
    if not cop: items += [(i,1) for i in ("unlock","house","atm","cuffs")]
    items += [("firewall",2)]
    return items

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--res",default="2560x1080"); ap.add_argument("--pal",default="ice")
    ap.add_argument("--cursor",type=float,default=0.455); ap.add_argument("--bg",default="")
    ap.add_argument("--out",default=HERE+"dock_preview.png")
    a=ap.parse_args()
    W,H=[int(x) for x in a.res.split("x")]; P=PAL[a.pal]
    img=(Image.open(a.bg).convert("RGB").resize((W,H)) if a.bg else game_bg(W,H)).convert("RGBA")

    # visor overlay (scanlines + vignette), under the UI
    vis=Image.open(HERE+"vr_visor.png").convert("RGBA").resize((W,H)); img.alpha_composite(vis)

    items=build_items(P)
    iconSize=0.0385*H    # owner: dock smaller (was 0.048)
    spacing=iconSize*1.15; divGap=iconSize*0.72; pad=iconSize*0.85
    span=0.0
    for k in range(1,len(items)):
        span+=spacing
        if items[k][1]!=items[k-1][1]: span+=divGap
    barH=iconSize*1.8
    barCx=0.5*W; barBottom=0.985*H; barTop=barBottom-barH; iconBottom=barBottom-barH*0.28

    # rest centres
    cx=barCx-span/2; rest=[]
    for k,(iid,grp) in enumerate(items):
        if k>0 and grp!=items[k-1][1]: cx+=divGap
        rest.append(cx); cx+=spacing

    cursorPx=a.cursor*W
    boosts=[]; widths=[]
    for k in range(len(items)):
        dist=abs(cursorPx-rest[k])/iconSize
        b=0.9*math.exp(-(dist*dist)/(2*1.3*1.3))
        boosts.append(b); widths.append(iconSize*(1+b))
    # macOS push-apart: each growing icon shoves every other icon by half its growth, away from itself
    centres=[]
    for k in range(len(items)):
        d=0.0
        for j in range(len(items)):
            if j!=k: d+=(widths[j]-iconSize)/2*(1 if rest[k]>rest[j] else -1)
        centres.append(rest[k]+d)
    liveL=min(centres[k]-widths[k]/2 for k in range(len(items)))
    liveR=max(centres[k]+widths[k]/2 for k in range(len(items)))
    barW=(liveR-liveL)+2*pad; barX=liveL-pad; barMid=(liveL+liveR)/2

    # floor glow under the bar (render signature)
    glowW=int(barW*1.1); glowH=int(iconSize*1.25)
    glow=tint(HERE+"vrglow.png",P["acc"],am=0.55).resize((glowW,glowH))
    img.alpha_composite(glow,(int(barMid-glowW/2),int(barBottom-glowH*0.5)))
    # bar chrome hugs the displaced row (stretches during magnify).
    # The baked art carries halo margins: solid body = x[170,1722] y[45,184] of 1890x184.
    # Expand the control rect so the VISIBLE band lands exactly on [barX,barW]x[barTop,barH].
    BI_L,BI_R,BI_T,BI_B=190/1890,188/1890,47/184,0/184
    cw=barW/(1-BI_L-BI_R); cx0=barX-cw*BI_L
    ch=barH/(1-BI_T-BI_B); cy0=barTop-ch*BI_T
    bar=Image.open(HERE+f"vrdock_bar_{a.pal}.png").convert("RGBA").resize((int(cw),int(ch)))
    img.alpha_composite(bar,(int(cx0),int(cy0)))

    best=(-1,-1.0)
    for k,(iid,grp) in enumerate(items):
        cxk=centres[k]; boost=boosts[k]; w=widths[k]; tone=CAT[iid][1]
        rise=boost*iconSize*0.5                                    # magnified icons lift out of the bar
        cy=(iconBottom-w/2)-rise                                     # icon centre y
        x=cxk-w/2; y=cy-w/2
        img.alpha_composite(Image.open(HERE+"vrtile_dark.png").convert("RGBA").resize((int(w),int(w))),(int(x),int(y)))
        gw=w*0.56; gx=cxk-gw/2; gy=cy-gw/2
        img.alpha_composite(tint(HERE+f"ic_{CAT[iid][0]}.png",P[tone],1+boost*0.4).resize((int(gw),int(gw))),(int(gx),int(gy)))
        # running-indicator dot (base position, does not magnify)
        dR=iconSize*0.03; dcy=iconBottom+iconSize*0.055
        ImageDraw.Draw(img).ellipse([cxk-dR,dcy-dR,cxk+dR,dcy+dR],fill=P[tone]+(230,))
        if boost>best[1]: best=(k,boost)

    # divider ticks (midway between displaced neighbours' edges)
    dr=ImageDraw.Draw(img)
    for k in range(1,len(items)):
        if items[k][1]!=items[k-1][1]:
            bx=((centres[k-1]+widths[k-1]/2)+(centres[k]-widths[k]/2))/2
            dr.rectangle([bx-1,iconBottom-iconSize*0.82,bx+1,iconBottom-iconSize*0.12],fill=(128,153,140,90))

    def F(px): return ImageFont.truetype(FONT,int(px))
    def txt(xy,s,rgb,px,anchor="la"):
        f=F(px); off=max(1,px*0.07)                               # Arma shadow=1 equivalent
        dr.text((xy[0]+off,xy[1]+off),s,font=f,fill=(6,8,7,215),anchor=anchor)
        dr.text(xy,s,font=f,fill=rgb+(255,),anchor=anchor)

    # HUD
    txt((0.012*W,0.014*H),"NEON AEGEAN",P["acc"],0.021*H)
    bw=F(0.021*H).getlength("NEON AEGEAN ")
    txt((0.012*W+bw,0.016*H),("TAL OS" if a.pal=="tal" else "ICEBREAKER OS")+"   // QUICKHACK",P["util"],0.016*H)
    txt((0.988*W,0.016*H),"$14,200      TRACE CLEAR      DECK 64%",P["ink"],0.016*H,anchor="ra")

    # lock card (sample locked vehicle).
    # Card art halo margins: solid body = x[99,589] y[0,468] of 589x526 (glow left+bottom).
    # Lay out against the VISIBLE panel rect; expand the control rect by the insets.
    CI_L,CI_R,CI_T,CI_B=118/589,0/589,0/526,105/526
    # H-sized so text (also H-sized) always fits; right-edge anchored with an H-based margin.
    vw=0.320*H; vh=0.198*H; vx=W-0.152*H-vw; vy=0.19*H         # visible panel rect
    ccw=vw/(1-CI_L-CI_R); cch=vh/(1-CI_T-CI_B)
    ccx=vx-ccw*CI_L; ccy=vy-cch*CI_T
    card=Image.open(HERE+f"vrdock_card_{a.pal}.png").convert("RGBA").resize((int(ccw),int(cch)))
    img.alpha_composite(card,(int(ccx),int(ccy)))
    lx=vx+0.031*H; rx=vx+vw-0.031*H                            # inner left / right edges
    txt((lx,vy+0.022*H),"GAZE LOCK",P["dim"],0.016*H)
    img.alpha_composite(tint(HERE+"ic_gkill.png",P["acc"]).resize((int(0.036*H),int(0.036*H))),(int(lx),int(vy+0.050*H)))
    txt((lx+0.062*H,vy+0.052*H),"Hatchback (Sport)",P["ink"],0.021*H)
    txt((lx+0.062*H,vy+0.090*H),"vehicle · 18 m",P["acc"],0.016*H)
    txt((lx,vy+0.122*H),"DRIVER",P["dim"],0.016*H)
    txt((rx,vy+0.122*H),"empty",P["ink"],0.016*H,anchor="ra")
    txt((lx,vy+vh-0.042*H),"[ no LOS ]  [ in range ]",P["util"],0.014*H)   # bottom-anchored

    # tooltip above magnified icon — anchored to the RISEN tile top, never behind it
    if best[0]>=0 and best[1]>0.06:
        k=best[0]; iid=items[k][0]; nm=CAT[iid][2]; st=CAT[iid][3]; tone=CAT[iid][1]
        tcx=centres[k]
        rise=boosts[k]*iconSize*0.5; tileTop=(iconBottom-widths[k])-rise
        txt((tcx,tileTop-0.049*H),nm,P[tone],0.024*H,anchor="ma")
        txt((tcx,tileTop-0.023*H),st,P["dim"],0.015*H,anchor="ma")
    else:
        txt((barCx,barTop-0.03*H),"SLIDE TO MAGNIFY  ·  CLICK TO UPLOAD",P["faint"],0.013*H,anchor="ma")

    img.convert("RGB").save(a.out); print("wrote",a.out,f"{W}x{H} pal={a.pal}")

main()
