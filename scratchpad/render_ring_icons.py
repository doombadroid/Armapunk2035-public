#!/usr/bin/env python3
"""
render_ring_icons.py -- rebake the quick-hack rings for SWAPPABLE loadouts.

Why: the wedge icons used to be baked into ring_base/ring_hl_*. That hard-locked every tool to a wedge
position, so a player-chosen loadout would show the wrong glyph. Now:
  * ring bases + highlights are baked ICON-LESS (wedge geometry only)
  * every tool gets its own 128x128 icon PAA, drawn live into 8 picture controls by the ring driver

Outputs:
  images/cyberdeck/ring_base.paa       ring_hl_0..7.paa        (civ, iconless)
  images/cyberdeck/ring_pd_base.paa    ring_pd_hl_0..7.paa     (MaxSec, iconless)
  images/cyberdeck/icons/<tool>.paa    one per tool, tinted per state at runtime via colorText
"""
import os, sys, math
from PIL import Image, ImageDraw
SC = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SC)
sys.path.insert(0, os.path.join(SC, '..', 'tools'))
import render_ring as CIV
import render_ring_pd as PD
from make_paa import build_paa_dxt5, verify_paa

MIS  = os.path.join(SC, '..', 'mission', 'Armapunk2035.Malden')
OUT  = os.path.join(MIS, 'images', 'cyberdeck')
ICO  = os.path.join(OUT, 'icons')

# --- extra glyphs so each side has more tools than slots (real choice, not a fake menu) ---
EXTRA = {
    # --- Tier 1 quickhacks (owner 2026-07-21) ---
    "qh_ping":      {"co": [((12,12),3.2), ((12,12),7.4)], "ci": [((12,12),1.3)]},
    "qh_distract":  {"pl": [[(9,17),(9,10),(15,10),(15,17)], [(7,17),(17,17)], [(11,19),(13,19)]],
                     "ar": [((12,10), 4.5, 200, 340)]},
    "qh_static":    {"rc": [(3,6,21,18)], "pl": [[(6,10),(10,10)], [(12,10),(18,10)], [(6,13),(13,13)],
                     [(15,13),(18,13)], [(6,16),(9,16)], [(11,16),(18,16)]]},
    "qh_whiteout":  {"ar": [((8,12), 5.5, 300, 60), ((8,12), 9, 300, 60)],
                     "pl": [[(4,4),(20,20)]], "ci": [((8,12),1.4)]},
    "qh_sticky":    {"pl": [[(4,10),(16,10),(16,14),(10,14)], [(8,14),(8,19)], [(16,10),(20,10)]],
                     "co": [((7,12),0)], "ci": [((6.5,12),1.1)]},
    "qh_pursuit":   {"co": [((12,12),7.4)], "pl": [[(12,2),(12,6)], [(12,18),(12,22)], [(2,12),(6,12)], [(18,12),(22,12)]],
                     "ci": [((12,12),1.6)]},
    "qh_pa":        {"pl": [[(5,9),(5,15),(9,15),(15,20),(15,4),(9,9),(5,9)]],
                     "ar": [((16,12), 4, 300, 60), ((16,12), 7, 300, 60)]},
    "qh_dazzle":    {"ci": [((12,12),2.6)],
                     "pl": [[(12,2),(12,6)], [(12,18),(12,22)], [(2,12),(6,12)], [(18,12),(22,12)],
                            [(5,5),(8,8)], [(19,5),(16,8)], [(5,19),(8,16)], [(19,19),(16,16)]]},
    "qh_silence":   {"pl": [[(4,9),(8,9),(13,4),(13,20),(8,15),(4,15),(4,9)], [(16,9),(21,15)], [(21,9),(16,15)]]},
    "qh_interlock": {"rc": [(6,11,18,20)], "ar": [((12,11), 4.2, 180, 360)], "pl": [[(9,15),(15,15)]]},
    # licence plate w/ chars, diagonal slash = spoofed readout
    "qh_plateghost": {"rc": [(3,8,21,16)], "pl": [[(6,12),(8,12)], [(10,12),(12,12)], [(14,12),(18,12)],
                      [(4,19),(20,5)]]},
    # --- TAL Captain+ wedges (owner 2026-07-21) ---
    # jammer: mast + broadcast arcs, struck through
    "jammer":   {"pl": [[(12,21),(12,9)], [(8,21),(16,21)], [(4,20),(20,6)]],
                 "ar": [((12,9), 5, 200, 340), ((12,9), 8.5, 200, 340)], "ci": [((12,8),1.2)]},
    # honeypot: ATM face with a bait drop below the slot
    "honeypot": {"rc": [(5,3,19,15)], "pl": [[(8,7),(16,7)], [(8,10),(13,10)]], "ci": [((12,19),2.3)]},
    # drone: quadcopter X-frame, four rotors
    "drone":    {"pl": [[(6,6),(18,18)], [(18,6),(6,18)]],
                 "co": [((6,6),2.4), ((18,6),2.4), ((6,18),2.4), ((18,18),2.4)], "ci": [((12,12),1.7)]},
    # --- Tier 2 MaxSec vehicle tools (owner 2026-07-21) ---
    # vehstop: car silhouette with a stop bar through it
    "vehstop":     {"pl": [[(3,15),(5,11),(19,11),(21,15),(21,18),(3,18),(3,15)], [(4,5),(20,21)]],
                    "co": [((7,18),1.8), ((17,18),1.8)]},
    # breachorder: document with a seal -- a warrant, not a crowbar
    "breachorder": {"rc": [(6,3,18,21)], "pl": [[(9,8),(15,8)], [(9,11),(15,11)]], "co": [((12,17),2.6)]},
    # --- Tier 3 comms (owner 2026-07-21) ---
    "qh_jam":      {"pl": [[(12,20),(12,10)], [(8,20),(16,20)], [(4,19),(20,5)]],
                    "ar": [((12,10), 5, 200, 340), ((12,10), 8.5, 200, 340)]},
    "qh_blackout": {"pl": [[(12,20),(12,10)], [(8,20),(16,20)], [(4,19),(20,5)]],
                    "ar": [((12,10), 5, 200, 340)], "ci": [((12,9),1.2)]},
    # wiretap: handset with a tap line running off it
    "qh_wiretap":  {"pl": [[(5,8),(9,8),(13,4),(13,18),(9,14),(5,14),(5,8)], [(16,11),(21,11)], [(21,11),(21,20)]],
                    "co": [((21,20),1.6)]},
    "qh_warranttap": {"pl": [[(5,8),(9,8),(13,4),(13,18),(9,14),(5,14),(5,8)], [(16,11),(21,11)], [(21,11),(21,20)]],
                      "ci": [((21,20),1.7)]},
    # crybaby: speech burst with an exclamation -- a call that isn't real
    "qh_crybaby":  {"pl": [[(4,5),(20,5),(20,16),(13,16),(9,20),(9,16),(4,16),(4,5)], [(12,8),(12,11)]],
                    "ci": [((12,13.4),0.8)]},
    "qh_decoy":    {"co": [((12,10),3.4)], "pl": [[(6,20),(6,17),(18,17),(18,20)], [(4,4),(20,20)]]},
    # --- Autopilot suite (owner 2026-07-21) ---
    # valet: car with a summon arc pulling it toward you
    "qh_valet":    {"pl": [[(5,14),(7,10),(17,10),(19,14),(19,17),(5,17),(5,14)]],
                    "co": [((8,17),1.7), ((16,17),1.7)], "ar": [((12,20), 6, 200, 340)]},
    "qh_recall":   {"pl": [[(5,14),(7,10),(17,10),(19,14),(19,17),(5,17),(5,14)], [(12,3),(12,8)], [(9,6),(12,3),(15,6)]],
                    "co": [((8,17),1.7), ((16,17),1.7)]},
    # synapse: leg/nerve bolt -- a limb with a lightning strike through it
    "qh_synapse":  {"pl": [[(9,3),(11,11),(9,15),(12,21)], [(15,6),(10,12),(14,12),(9,19)]]},
    # leech: a fuel droplet with a downward siphon arrow
    "qh_leech":    {"pl": [[(12,4),(7,12),(9,17),(15,17),(17,12),(12,4)]], "co": [((12,13),2.2)],
                    "ar": [((12,21), 3, 200, 340)]},
    # short: a lightning bolt hitting a small figure -- direct zap
    "qh_short":    {"pl": [[(14,3),(8,12),(12,12),(7,21)]], "co": [((17,8),2)], "ci": [((17,8),0.9)]},
    # asset freeze: a dollar in a snowflake -- frozen money
    "assetfreeze": {"pl": [[(12,4),(12,20)], [(4,12),(20,12)], [(6,6),(18,18)], [(18,6),(6,18)]], "co": [((12,12),3.4)], "ci": [((12,12),1.6)]},
    # grid priority: a lamp with power restored (bulb + rays)
    "gridpriority":{"ci": [((12,10),4)], "pl": [[(12,2),(12,4)], [(4,10),(6,10)], [(18,10),(20,10)], [(5,4),(7,6)], [(19,4),(17,6)], [(9,17),(15,17)], [(10,20),(14,20)]]},
    # black box: a box with a magnifier -- recovered recording
    "blackbox":    {"rc": [(3,6,15,18)], "pl": [[(6,10),(12,10)], [(6,13),(12,13)], [(19,19),(22,22)]], "co": [((17,17),3.2)]},
    # detain: a downed figure inside a targeting bracket
    "detain":      {"co": [((12,9),2.6)], "pl": [[(6,20),(12,15),(18,20)], [(4,4),(8,4),(8,8)], [(20,4),(16,4),(16,8)], [(4,20),(8,20),(8,16)], [(20,20),(16,20),(16,16)]]},
    # warrant: a document with a stamp seal
    "warrant":     {"rc": [(5,3,19,21)], "pl": [[(8,8),(16,8)], [(8,11),(16,11)], [(8,14),(13,14)]], "co": [((15,17),2.4)]},
    # eyespy: a camera on a mount, watching -- lens iris + housing
    "qh_eyespy":   {"rc": [(4,7,17,15)], "co": [((10.5,11),2.6)], "pl": [[(17,9),(21,7)], [(17,13),(21,15)], [(9,15),(9,20)], [(6,20),(12,20)]]},
    # chauffeur: a steering wheel with a hijack bolt through it -- someone else has the wheel
    "qh_chauffeur": {"co": [((12,12),8), ((12,12),2.4)], "pl": [[(12,4),(12,10)], [(4,12),(10,12)], [(20,12),(14,12)],
                     [(16,5),(9,13),(14,13),(7,20)]]},
    # --- Tier 4 (owner 2026-07-21) ---
    # puppet: a control-bar with strings down to a car below -- marionette driving
    "qh_puppet":   {"pl": [[(4,4),(20,4)], [(8,4),(8,11)], [(12,4),(12,9)], [(16,4),(16,11)],
                    [(6,13),(9,11),(15,11),(18,13),(18,17),(6,17),(6,13)]], "co": [((9,19),1.4), ((15,19),1.4)]},
    # gridout: a bulb gone dark, struck through
    "qh_gridout":  {"ci": [((12,10),4.6)], "pl": [[(9,16),(15,16)], [(10,19),(14,19)], [(4,4),(20,20)]]},
    # flatline: the flat ECG trace with one dying spike
    "qh_flatline": {"pl": [[(3,12),(8,12),(10,6),(13,18),(15,12),(21,12)]]},
    # memhole: head profile with a void punched out of it
    "qh_memhole":  {"co": [((12,12),7.2)], "ci": [((15,10),2.4)], "pl": [[(6,17),(11,20)]]},
    # detonate: a car silhouette going up -- blast rays above a low chassis
    "qh_detonate": {"pl": [[(3,19),(21,19)], [(5,19),(7,15),(17,15),(19,19)], [(12,13),(12,7)],
                    [(7,14),(4,9)], [(17,14),(20,9)], [(9.5,13),(8,6)], [(14.5,13),(16,6)]],
                    "ci": [((12,17),1.3)]},
    "turf":   {"pl": [[(7,21),(7,3)], [(7,4),(19,8),(7,12)]]},                       # flag
    "market": {"pl": [[(4,20),(20,20)], [(7,20),(7,13)], [(12,20),(12,8)], [(17,20),(17,4)]]},
    "bolo":   {"rc": [(6,4,18,20)], "pl": [[(12,8),(12,14)], [(12,16.6),(12,17.2)]]},  # notice + "!"
    "units":  {"co": [((8.5,8),2.8), ((15.5,8),2.8)],                                  # two officers
               "pl": [[(4,19),(4,16),(13,16),(13,19)], [(11,19),(11,15),(20,15),(20,19)]]},
}

# tool -> (which icon table, key) ; civ + cop catalogues
CIV_ICONS = {"wardrive":0, "unlock":1, "ignition":2, "atm":3, "house":4, "rig":5, "proxy":6, "breachkit":7}
PD_ICONS  = {"records":0, "plate":1, "field":2, "firmware":3, "reset":4, "sweep":5, "dispatch":6, "backup":7}


def bake_ring(mod, base_name, hl_prefix):
    """Re-render a ring with the icon pass suppressed."""
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r0, r1 = mod.geometry(size)
    for i in range(mod.N):
        a0, a1 = mod.wedge_angles(i)
        mod.poly_wedge(d, cx, cy, r0, r1, a0, a1, mod.FILL + (232,), mod.STROKE + (255,), 3)
    hr = r0 - 12
    hub = (5, 10, 8, 246) if mod is CIV else (8, 13, 20, 248)
    ring = (27, 42, 36, 255) if mod is CIV else (42, 60, 82, 255)
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=hub, outline=ring, width=3)
    p = f"/tmp/{base_name}.png"; img.save(p)
    build_paa_dxt5(p, os.path.join(OUT, f"{base_name}.paa"))

    col = CIV.ACID if mod is CIV else PD.AMBER
    for i in range(mod.N):
        h = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        hd = ImageDraw.Draw(h)
        hcx, hcy, hr0, hr1 = mod.geometry(512)
        a0, a1 = mod.wedge_angles(i)
        mod.poly_wedge(hd, hcx, hcy, hr0, hr1, a0, a1, col + (76,), col + (255,), 4)
        hp = f"/tmp/{hl_prefix}{i}.png"; h.save(hp)
        build_paa_dxt5(hp, os.path.join(OUT, f"{hl_prefix}{i}.paa"))
    print(f"{base_name} + 8 highlights baked (iconless)")


def bake_icon(name, spec, drawer):
    """One tool icon, white on transparent -- the dialog tints it per state with colorText."""
    S = 128
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sc = (S - 24) / 24.0
    drawer(d, spec, 12, 12, sc, (255, 255, 255, 255), 7)
    p = f"/tmp/icon_{name}.png"; im.save(p)
    build_paa_dxt5(p, os.path.join(ICO, f"{name}.paa"))


def draw_from_spec(d, spec, ox, oy, scale, col, w):
    T = lambda p: (ox + p[0] * scale, oy + p[1] * scale)
    for pl in spec.get("pl", []):
        d.line([T(p) for p in pl], fill=col, width=w, joint="curve")
    for (x0, y0, x1, y1) in spec.get("rc", []):
        d.rectangle([T((x0, y0)), T((x1, y1))], outline=col, width=w)
    for (c, r, a0, a1) in spec.get("ar", []):
        cx0, cy0 = T(c); rr = r * scale
        d.arc([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], a0, a1, fill=col, width=w)
    for (c, r) in spec.get("co", []):
        cx0, cy0 = T(c); rr = r * scale
        d.ellipse([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], outline=col, width=w)
    for (c, r) in spec.get("ci", []):
        cx0, cy0 = T(c); rr = r * scale
        d.ellipse([cx0 - rr, cy0 - rr, cx0 + rr, cy0 + rr], fill=col)


if __name__ == "__main__":
    os.makedirs(ICO, exist_ok=True)
    bake_ring(CIV, "ring_base", "ring_hl_")
    bake_ring(PD,  "ring_pd_base", "ring_pd_hl_")

    n = 0
    for name, idx in CIV_ICONS.items():
        bake_icon(name, CIV.ICONS[idx], draw_from_spec); n += 1
    for name, idx in PD_ICONS.items():
        bake_icon(name, PD.ICONS[idx], draw_from_spec); n += 1
    for name, spec in EXTRA.items():
        bake_icon(name, spec, draw_from_spec); n += 1
    print(f"{n} tool icons baked -> images/cyberdeck/icons/")
    print("verify:", verify_paa(os.path.join(OUT, "ring_base.paa"))[1])
