#!/usr/bin/env python3
"""
scan_trunk_dupe.py  (LooneyBin, owner 2026-06-18)  — READ-ONLY forensic scan.

The vehicle-trunk store<->repull dupe: take items from a trunk at the instant of storing the vehicle; the
server reads the PRE-take trunk (the client's take broadcast hasn't landed) and persists it, so re-pulling the
SAME plate brings the items back — and you also kept the ones you took.

WHY NOT a simple "trunk grew since last visit" count: legit drug-gang trunks fill constantly (gangmates store,
you process + store) — that flags the whole server. So we use the PRECISE, low-false-positive signature:

  CONFIRMED DUPE EVENT =
    a -VEHINV- CLOSE with "Owner: NoVehData" (vehicle deleted DURING the session)
    AND a NEGATIVE "Virtual change" (you pulled items OUT as it stored)
    AND the SAME plate is RE-PULLED (-VEHICLEPULL-) afterwards
        (a vehicle that was *destroyed* mid-loot can't be re-pulled; a *stored* one can — this is what
         separates a real store-dupe from "my car blew up while I was looting it").

  Duped units = the items pulled out in those confirmed events. Plate comes from the OPEN just before the close.

Touches nothing. Run:  cd loonybot && ./venv/bin/python3 scan_trunk_dupe.py
"""
import os, re, json, sys
from collections import defaultdict
from datetime import timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
CFG = json.load(open(os.path.join(HERE, "config.json")))
import admin
DB = admin.DB(CFG["db"])

REPULL_WINDOW = 600          # seconds after a NoVehData-take to still count a re-pull as confirmation
NORMAL_WINDOW = 45           # seconds: normal-close-take -> same-plate re-pull = the normal-close dupe variant
PAIR  = re.compile(r"\[([A-Za-z]\w*),(-?\d+)\]")
PLATE = re.compile(r"Owner:\s*\[(\d+),(\d+)\]")

def items_between(msg, start_key, end_key=", Player Virtual Inventory:"):
    i = msg.find(start_key)
    if i < 0:
        return {}
    seg = msg[i + len(start_key):]
    j = seg.find(end_key)
    if j >= 0:
        seg = seg[:j]
    d = defaultdict(int)
    for name, qty in PAIR.findall(seg):
        d[name] += int(qty)
    return dict(d)

# ---- every -VEHICLEPULL-, indexed by plate -> sorted list of pull timestamps -------------------------
pulls = DB.q("SELECT ts, message FROM log WHERE tag='-VEHICLEPULL-' ORDER BY id ASC") or []
pull_by_plate = defaultdict(list)
for r in pulls:
    m = re.search(r"\((\d+)\)", r["message"] or "")
    if m:
        pull_by_plate[m.group(1)].append(r["ts"])
print(f"[scan] {len(pulls)} -VEHICLEPULL- rows, {len(pull_by_plate)} distinct plates", flush=True)

def repulled_after(plate, ts, window):
    for t in pull_by_plate.get(plate, ()):
        if ts < t <= ts + timedelta(seconds=window):
            return True
    return False

# pre-pass: every OPEN's trunk snapshot per plate, so we can confirm an item was RESURRECTED (still present
# when the plate was re-pulled+reopened, despite being taken out just before the store). This is the airtight
# discriminator vs a legit "stored a car I'd used, pulled it again" — in the legit case the item is GONE.
_opens_raw = DB.q("SELECT ts, message FROM log WHERE tag='-VEHINV-' AND message LIKE '%%opened vehicle trunk%%' ORDER BY id ASC") or []
opens_by_plate = defaultdict(list)
for r in _opens_raw:
    mm = PLATE.search(r["message"] or "")
    if mm:
        opens_by_plate[mm.group(2)].append((r["ts"], None, r["message"]))

def resurrected(plate, ts, took, window=180):
    """True iff the FIRST open of this plate after ts (within window) still holds >= the taken qty of >=1 item."""
    cand = None
    for (t, _, msg) in opens_by_plate.get(plate, ()):
        if ts < t <= ts + timedelta(seconds=window):
            cand = msg; break
    if cand is None:
        return False
    trunk = items_between(cand, "Virtual Inventory:")
    return any(trunk.get(it, 0) >= q for it, q in took.items())

# ---- walk -VEHINV-; pair each NoVehData-take close with the plate from the preceding open ------------
rows = DB.q("SELECT id, ts, playerid, name, message FROM log WHERE tag='-VEHINV-' ORDER BY id ASC") or []
print(f"[scan] {len(rows)} -VEHINV- rows", flush=True)

names = {}
last_open = {}                                            # pid -> (plate, ts)
duped       = defaultdict(lambda: defaultdict(int))       # pid -> item -> confirmed duped units
events      = defaultdict(int)                            # pid -> confirmed dupe events
unconf_evt  = defaultdict(int)                            # pid -> NoVehData-take with NO re-pull (lost veh, not dupe)
plates_hit  = defaultdict(lambda: defaultdict(int))       # pid -> plate -> confirmed events
susp_evt    = defaultdict(int)                            # pid -> normal-close-variant suspected events
susp_units  = defaultdict(lambda: defaultdict(int))       # pid -> item -> suspected units (normal-close variant)

for r in rows:
    pid = r["playerid"]; msg = r["message"] or ""; ts = r["ts"]
    if pid:
        names[pid] = r["name"]
    low = msg.lower()
    if "opened" in low:
        m = PLATE.search(msg)
        last_open[pid] = (m.group(2) if m else "?", ts)
    elif "closed" in low:
        change = items_between(msg, "Virtual change:")
        took = {it: -q for it, q in change.items() if q < 0}
        if not took:
            continue
        plate, _ = last_open.get(pid, ("?", ts))
        if "NoVehData" in msg:
            # PRIMARY signal: vehicle deleted DURING the take. Confirmed iff same plate re-pulled after.
            if plate != "?" and repulled_after(plate, ts, REPULL_WINDOW):
                events[pid] += 1
                plates_hit[pid][plate] += 1
                for it, q in took.items():
                    duped[pid][it] += q
            else:
                unconf_evt[pid] += 1
        else:
            # SECONDARY (normal-close variant): dialog closed before the 1s-delayed delete, so no NoVehData.
            # Confirm only if you took items, the SAME plate is re-pulled within a TIGHT window, AND the taken
            # item is STILL in the trunk at re-pull (resurrected) -> airtight, drops legit "used+repulled" cars.
            if plate != "?" and repulled_after(plate, ts, NORMAL_WINDOW) and resurrected(plate, ts, took):
                susp_evt[pid] += 1
                for it, q in took.items():
                    susp_units[pid][it] += q

# ---- report -----------------------------------------------------------------------------------------
def total(d): return sum(d.values())
ranked = sorted((p for p in duped if total(duped[p]) > 0), key=lambda p: total(duped[p]), reverse=True)

out = []
def w(s=""):
    out.append(s); print(s, flush=True)

w("=" * 78)
w("LooneyBin  TRUNK STORE<->REPULL DUPE  — CONFIRMED events (read-only)")
w("  confirmed = NoVehData close + items pulled out + the SAME plate re-pulled within "
  f"{REPULL_WINDOW//60}min")
w("  (legit trunk restocking is NOT counted — only the store<->repull dupe signature)")
w("=" * 78)
if not ranked:
    w("No CONFIRMED trunk-dupe events in -VEHINV- history.")
for pid in ranked:
    d = duped[pid]
    pl = ", ".join(f"{p}×{n}" for p, n in sorted(plates_hit[pid].items(), key=lambda x: -x[1]))
    w("")
    w(f"### {names.get(pid,'?')}  ({pid})")
    w(f"    confirmed dupe events: {events[pid]}   (unconfirmed NoVehData-takes, likely lost/destroyed veh: {unconf_evt[pid]})")
    w(f"    duped: {total(d)} units  ::  " + ", ".join(f"{it}×{q}" for it, q in sorted(d.items(), key=lambda x: -x[1])))
    w(f"    plates: {pl}")

# secondary: normal-close variant (lower confidence — no NoVehData, but take + tight same-plate re-pull)
susp_ranked = sorted((p for p in susp_units if total(susp_units[p]) > 0),
                     key=lambda p: total(susp_units[p]), reverse=True)
w("")
w("-" * 78)
w(f"SECONDARY — normal-close variant (take + same-plate re-pull <{NORMAL_WINDOW}s, no NoVehData). Lower")
w("confidence; a few may be legit 'stored a car I'd just used, pulled it again'. Cross-check the big ones.")
if not susp_ranked:
    w("  none")
for pid in susp_ranked[:15]:
    s = susp_units[pid]
    w(f"  {names.get(pid,'?')} ({pid}): {susp_evt[pid]} events, {total(s)} units :: "
      + ", ".join(f"{it}×{q}" for it, q in sorted(s.items(), key=lambda x: -x[1])[:12]))

w("")
w("-" * 78)
w("NAMED: player099 (76561190000000038) + player100 (76561190000000039)")
for pid in ("76561190000000038", "76561190000000039"):
    d = duped[pid]
    w(f"  {names.get(pid,'?')} ({pid}): {events[pid]} confirmed events, {total(d)} units"
      + ((" :: " + ", ".join(f"{it}×{q}" for it, q in sorted(d.items(), key=lambda x: -x[1]))) if d else "")
      + f"   (+{unconf_evt[pid]} unconfirmed)")

open(os.path.join(HERE, "scan_trunk_dupe.txt"), "w").write("\n".join(out))
w("")
w("[scan] full report -> loonybot/scan_trunk_dupe.txt")
