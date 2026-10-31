#!/usr/bin/env python3
"""Seed the New Drachma price table at 6000:1 from the BM-reachable catalogues.
ND shops: rebelwep weapons (weaponShopCfg), rebcloth clothes (fn_clothing_reb), nd_car vehicles.
Emits SQF literal rows [\"key\",\"ndStr\"]. Dedup by key (first wins). Validates counts + spot-checks."""
import re, sys, math
from decimal import Decimal, ROUND_HALF_UP

BASE = "/home/timb/loonybin-doomba/mission/LooneyBin.Altis"

def nd(bm):
    # round(bm/6000, 4dp), min 0.0001 if >0
    v = (Decimal(bm) / Decimal(6000)).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
    if bm > 0 and v <= 0:
        v = Decimal("0.0001")
    return f"{v:.4f}"

def strip_comments(text):
    """Remove // and /* */ comments, string-aware (so // inside a string stays)."""
    out, i, n, instr, q = [], 0, len(text), False, ""
    while i < n:
        c = text[i]
        if instr:
            out.append(c)
            if c == q: instr = False
            i += 1; continue
        if c in "\"'": instr, q = True, c; out.append(c); i += 1; continue
        if c == "/" and i+1 < n and text[i+1] == "/":
            while i < n and text[i] != "\n": i += 1
            continue
        if c == "/" and i+1 < n and text[i+1] == "*":
            i += 2
            while i+1 < n and not (text[i] == "*" and text[i+1] == "/"): i += 1
            i += 2; continue
        out.append(c); i += 1
    return "".join(out)

def sqf_arrays(text, name):
    """Return the top-level [...] literal assigned to `name` (bracket-aware, string-aware).
    `name` is a regex; matching ends at the first '[' after the match."""
    m = re.search(name, text)
    if not m: return None
    i = text.index("[", m.end() - 1)
    depth, j, instr, q = 0, i, False, ""
    while j < len(text):
        c = text[j]
        if instr:
            if c == q: instr = False
        elif c in "\"'": instr, q = True, c
        elif c == "[": depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0: return text[i:j+1]
        j += 1
    return None

def split_top(arr):
    """Split a [...] literal into top-level element strings."""
    inner = arr[1:-1]
    out, depth, cur, instr, q = [], 0, "", False, ""
    for c in inner:
        if instr:
            cur += c
            if c == q: instr = False
            continue
        if c in "\"'": instr, q = True, c; cur += c; continue
        if c in "[({": depth += 1
        elif c in "])}": depth -= 1
        if c == "," and depth == 0:
            out.append(cur.strip()); cur = ""
        else:
            cur += c
    if cur.strip(): out.append(cur.strip())
    return out

def field(el, idx):
    return split_top(el)[idx].strip()

rows = {}   # key -> (ndStr, source, bm)
def add(key, bm, src):
    key = key.strip().strip('"').strip("'")
    if not key: return
    if key in rows: return          # first wins (rebelwep price already captured)
    rows[key] = (nd(int(bm)), src, int(bm))

# ---- 1) weapons: rebelwep-tagged 5-tuples in fn_weaponShopCfg _weaponList ----
wt = strip_comments(open(f"{BASE}/core/config/fn_weaponShopCfg.sqf", encoding="utf-8", errors="replace").read())
wl = sqf_arrays(wt, r"_weaponList\s*=\s*")
wcount = 0
if wl:
    for el in split_top(wl):
        f = split_top(el)
        if len(f) < 4: continue
        cls = f[0].strip().strip('"').strip("'")
        price_s = f[2].strip()
        shops = f[3]
        if "rebelwep" not in shops: continue
        if not re.fullmatch(r"\d+", price_s): continue   # skip non-literal prices
        add(cls, price_s, "wep"); wcount += 1
else:
    print("WARN: could not extract _weaponList", file=sys.stderr)

# ---- 2) clothes: every [class, x, price] in fn_clothing_reb (rebcloth) ----
ct = open(f"{BASE}/core/config/fn_clothing_reb.sqf", encoding="utf-8", errors="replace").read()
ccount = 0
for m in re.finditer(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*(?:nil|"[^"]*")\s*,\s*(\d+)\s*\]', ct):
    add(m.group(1), m.group(2), "cloth"); ccount += 1

# ---- 3) vehicles: nd_car rows in fn_vehicleConfig (civ-slot price) ----
vt = strip_comments(open(f"{BASE}/core/config/fn_vehicleConfig.sqf", encoding="utf-8", errors="replace").read())
vl = sqf_arrays(vt, r"(?:AP_vehConfigTable|\b_vt)\s*=\s*")   # the table is built into `private _vt` since r2items
vcount = 0
if vl:
    for el in split_top(vl):
        if "nd_car" not in el: continue
        f = split_top(el)
        if len(f) < 8: continue
        cls = f[0].strip().strip('"').strip("'")
        buy = f[7].strip()
        # buy is either a number or [civ,west,indep]; blood reads civ slot
        if buy.startswith("["):
            civ = split_top(buy)[0].strip()
        else:
            civ = buy
        if not re.fullmatch(r"\d+", civ): continue
        add(cls, civ, "veh"); vcount += 1
else:
    print("WARN: could not extract AP_vehConfigTable", file=sys.stderr)

# ---- emit ----
print(f"// seeded {len(rows)} rows: {wcount} wep, {ccount} cloth, {vcount} veh (6000:1)", file=sys.stderr)
# spot checks
for k, exp in [("launch_RPG7_F", None), ("I_LT_01_cannon_F", "33.3333")]:
    if k in rows:
        print(f"  CHECK {k}: {rows[k][0]} (bm {rows[k][2]})", file=sys.stderr)

lines = []
for k in sorted(rows):
    nds, src, bm = rows[k]
    lines.append(f'    ["{k}","{nds}"],   // {src} was {bm} BM')
open("/tmp/claude-1000/-home-timb/343b7a57-c02f-4e95-af21-95abcc8ffa2d/scratchpad/nd_rows.txt","w").write("\n".join(lines))
print("\n".join(lines[:8]))
print(f"... ({len(lines)} rows total) -> nd_rows.txt")
