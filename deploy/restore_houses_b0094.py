#!/usr/bin/env python3
"""
Restore house storage damaged by TWO bugs:
  (A) b0092 CfgWeights STRIP -- pinv items not in the mission weight table (vests/helmets/optics/mags/launchers/
      bipods/suppressors) silently dropped on every close. House keeps other gear; specific classes vanish.
  (B) b0093 hydrate/dehydrate WIPE -- 2nd+ open showed empty (dehydrate set client var to [[],0], isNil trigger
      never re-fired), and closing the empty-looking house saved [[],0] over the whole column = full vinv/pinv wipe.

Unified per-column restore (a live DB trigger `houses_no_wipe` already blocks further wipes):
  VINV: if current non-empty -> keep (vinv was never stripped). If current EMPTY but a TODAY open-log snapshot had
        content -> restore that last-good snapshot (the contents right before the wipe). vinv fluctuates (drugs) so
        NO peak-union -- just the last-good snapshot.
  PINV: base = current pinv if non-empty, else the last-good TODAY snapshot (wipe restore). Then UNION back any
        STRIPPED items (class not in CfgWeights, peak qty seen, absent from base) -- covers the (A) strip on top of
        a (B) wipe. weight = max(base_wt, peak snapshot wt); self-heals exactly on next b0094 close.

DRY-RUN by default. --apply to write. --oid <id> to restrict.  TODAY = 2026-06-24 (UTC; b0093 deployed 16:56 UTC).
"""
import sys, re, json
sys.path.insert(0, "/home/timb/Documents/LooneyBin Altis Life/loonybot")
import admin

APPLY = "--apply" in sys.argv
ONLY_OID = sys.argv[sys.argv.index("--oid") + 1] if "--oid" in sys.argv else None
SCAN_START = "2026-06-23 00:00:00"      # peak/strip scan window (b0092 strip era)
# wipe-restore eligibility: a b0093 full-column WIPE can only have happened AFTER b0093 went live (11:56 CDT =
# 16:56 UTC). A house non-empty BEFORE that and empty now was emptied by the PLAYER under b0092 (legit) -- restoring
# it would dupe. So the last-good snapshot used for a wipe restore must be >= the deploy instant.
TODAY = "2026-06-24 16:56:00"           # b0093 deploy (UTC) -- wipe-restore source must be at/after this

cfg = json.load(open("/home/timb/Documents/LooneyBin Altis Life/loonybot/config.json"))
DB = admin.DB(cfg["db"])

# ---- mres (byte-identical to enrique.py / the game) ----------------------------------------------
def mres_decode(s):
    if s is None: return None
    s = s.replace("`", '"')
    if s.startswith('"') and s.endswith('"'): s = s[1:-1]
    s = s.replace('""', '"')
    try: return json.loads(s)
    except Exception: return None

def _sqf(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, str):  return '"' + v + '"'
    if isinstance(v, int):  return str(v)
    if isinstance(v, float):return str(int(v)) if v.is_integer() else repr(v)
    if isinstance(v, list): return "[" + ",".join(_sqf(x) for x in v) + "]"
    raise TypeError(v)

def mres_encode(arr):
    s = '"' + _sqf(arr).replace('"', '""') + '"'
    ch = list(s)
    for i in range(1, len(ch) - 1):
        if ch[i] == '"': ch[i] = "`"
    return "".join(ch)

# ---- CfgWeights KEEP set (classes the b0092 sanitize KEPT; absence => it was stripped) ------------
wtxt = open("/home/timb/Documents/LooneyBin Altis Life/mission/Armapunk2035.Malden/Config_physWeights.hpp").read()
KEEP = set(re.findall(r'class\s+([A-Za-z0-9_]+)', wtxt))

# ---- parse a raw log inventory field "[[[cn,qty],...],weight]" -> ({cn:qty}, weight) --------------
PAIR = re.compile(r'\[([A-Za-z0-9_]+),(\d+)\]')
def parse_field(msg, label, endlabel):
    i = msg.find(label)
    if i < 0: return None
    seg = msg[i + len(label):]
    j = seg.find(endlabel)
    if j >= 0: seg = seg[:j]
    items = {}
    for cn, q in PAIR.findall(seg):
        items[cn] = max(items.get(cn, 0), int(q))
    nums = re.findall(r'(\d+)', seg)
    wt = int(nums[-1]) if nums else 0
    return items, wt

def decode_col(raw):
    """DB col -> (dict items, weight, is_empty)."""
    dec = mres_decode(raw) if raw else None
    if not (isinstance(dec, list) and len(dec) == 2 and isinstance(dec[0], list)):
        return {}, 0, True
    items = {}
    for e in dec[0]:
        if isinstance(e, list) and len(e) >= 2 and isinstance(e[0], str):
            items[e[0]] = items.get(e[0], 0) + int(e[1])
    wt = dec[1] if isinstance(dec[1], (int, float)) else 0
    return items, int(wt), (len(items) == 0)

# ---- gather opened-logs per house ----------------------------------------------------------------
sql = ("SELECT ts, message FROM log WHERE tag='-HOUSEINV-' AND message LIKE 'opened%%' AND ts >= %s ")
params = [SCAN_START]
if ONLY_OID:
    sql += "AND message LIKE %s "; params.append(f"%ID: {ONLY_OID} %")
sql += "ORDER BY ts ASC"
rows = DB.q(sql, tuple(params), "all")

OID_RE = re.compile(r'ID:\s*(\d+)\s*\|\s*Owner:\s*(\d+)')
houses = {}
for r in rows:
    msg, ts = r["message"], str(r["ts"])
    m = OID_RE.search(msg)
    if not m: continue
    oid, owner = m.group(1), m.group(2)
    vf = parse_field(msg, "House Virtual Inventory:", ", House Physical Inventory:")
    pf = parse_field(msg, "House Physical Inventory:", ", Player Virtual Inventory:")
    if vf is None or pf is None: continue
    vit, vwt = vf; pit, pwt = pf
    h = houses.setdefault(oid, {"owner": owner, "peak": {}, "maxwt": 0,
                                "lg_v": None, "lg_p": None})
    h["owner"] = owner
    if pwt > h["maxwt"]: h["maxwt"] = pwt
    for cn, q in pit.items():
        if q > h["peak"].get(cn, 0): h["peak"][cn] = q
    # last-good snapshots (most recent non-empty, today only -> wipe restore source)
    if vit and ts >= TODAY: h["lg_v"] = (vit, vwt, ts)
    if pit and ts >= TODAY: h["lg_p"] = (pit, pwt, ts)

# ---- compute restores ----------------------------------------------------------------------------
updates = []
for oid, h in houses.items():
    row = DB.q("SELECT vinv, pinv FROM houses WHERE oid=%s", (oid,), "one")
    if not row: continue
    cv_items, cv_wt, cv_empty = decode_col(row["vinv"])
    cp_items, cp_wt, cp_empty = decode_col(row["pinv"])

    # ---- VINV decision ----
    new_v_items, new_v_wt, v_reason = dict(cv_items), cv_wt, None
    if cv_empty and h["lg_v"]:
        lv_items, lv_wt, lv_ts = h["lg_v"]
        new_v_items, new_v_wt, v_reason = dict(lv_items), lv_wt, f"WIPE-restore vinv from {lv_ts}"

    # ---- PINV decision ----
    if not cp_empty:
        base_items, base_wt = dict(cp_items), cp_wt
    elif h["lg_p"]:
        lp_items, lp_wt, lp_ts = h["lg_p"]
        base_items, base_wt = dict(lp_items), lp_wt
    else:
        base_items, base_wt = None, 0
    new_p_items, new_p_wt, p_reason, stripped = base_items, base_wt, None, {}
    if base_items is not None:
        stripped = {cn: pk for cn, pk in h["peak"].items()
                    if pk > 0 and cn not in KEEP and base_items.get(cn, 0) == 0}
        new_p_items = dict(base_items)
        for cn, q in stripped.items():
            new_p_items[cn] = q
        new_p_wt = max(int(base_wt), int(h["maxwt"]))
        if cp_empty and h["lg_p"]:
            p_reason = f"WIPE-restore pinv from {h['lg_p'][2]}" + (f" + {len(stripped)} stripped" if stripped else "")
        elif stripped:
            p_reason = f"STRIP-merge {len(stripped)} items"

    if v_reason is None and p_reason is None:
        continue

    # build encoded payloads (only for columns that changed)
    upd = {"oid": oid, "owner": h["owner"], "v_reason": v_reason, "p_reason": p_reason,
           "stripped": stripped, "v_n": len(new_v_items), "p_n": (len(new_p_items) if new_p_items else 0)}
    if v_reason is not None:
        vlist = [[cn, int(q)] for cn, q in new_v_items.items()]
        enc = mres_encode([vlist, int(new_v_wt)])
        assert mres_decode(enc) == [vlist, int(new_v_wt)], f"vinv round-trip fail {oid}"
        upd["vinv_enc"] = enc
    if p_reason is not None:
        plist = [[cn, int(q)] for cn, q in new_p_items.items()]
        enc = mres_encode([plist, int(new_p_wt)])
        assert mres_decode(enc) == [plist, int(new_p_wt)], f"pinv round-trip fail {oid}"
        upd["pinv_enc"] = enc
    updates.append(upd)

# ---- report --------------------------------------------------------------------------------------
def pname(uid):
    r = DB.q("SELECT name FROM players WHERE playerid=%s LIMIT 1", (uid,), "one")
    return (r or {}).get("name", "?")

wipes = [u for u in updates if (u["v_reason"] and "WIPE" in u["v_reason"]) or (u["p_reason"] and "WIPE" in (u["p_reason"] or ""))]
strips = [u for u in updates if u not in wipes]
print(f"==== {len(updates)} houses to restore  ({len(wipes)} wipe-restores, {len(strips)} strip-only) ====\n")
for u in sorted(updates, key=lambda x: (0 if x in wipes else 1, x["oid"])):
    nm = pname(u["owner"])
    print(f"  oid {u['oid']:>12}  {nm[:18]:18} ({u['owner']})")
    if u["v_reason"]: print(f"      V: {u['v_reason']}  -> {u['v_n']} items")
    if u["p_reason"]:
        sd = ", ".join(f"{cn}x{q}" for cn, q in sorted(u['stripped'].items(), key=lambda kv:-kv[1])) if u['stripped'] else ""
        print(f"      P: {u['p_reason']}  -> {u['p_n']} items" + (f"   [{sd}]" if sd else ""))

print()
if not APPLY:
    print("DRY-RUN. Re-run with --apply to write. (live trigger houses_no_wipe protects against re-wipe.)")
    sys.exit(0)

n = 0
for u in updates:
    sets, vals = [], []
    if "vinv_enc" in u: sets.append("vinv=%s"); vals.append(u["vinv_enc"])
    if "pinv_enc" in u: sets.append("pinv=%s"); vals.append(u["pinv_enc"])
    vals.append(u["oid"])
    DB.q(f"UPDATE houses SET {', '.join(sets)} WHERE oid=%s", tuple(vals), None)
    n += 1
print(f"APPLIED {n} house restores.")
