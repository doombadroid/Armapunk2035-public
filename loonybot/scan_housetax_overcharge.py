#!/usr/bin/env python3
"""
scan_housetax_overcharge.py  (LooneyBin, owner 2026-06-18, BUGS #374)  -- READ-ONLY.

House-tax payments never cleared (fn_houseTaxSRV paid `WHERE id=` but the client sends the house OID, not the
id PK), so every relog re-flagged the house overdue and the player was charged AGAIN. This quantifies the
over-charge from the -HOUSETAX- logs so the owner can approve refunds.

-HOUSETAX- message formats (from fn_manageHouseTax):
    "paid $40,000 house tax for house id: 1483522618"
    "paid $80,000 house tax for house ids: 1483522618, 2099113215"   (payAll -- total $ across the listed houses)

Refund bases reported (owner picks):
  TOTAL      = every dollar the player paid in house tax (system never worked -> arguably all of it).
  REDUNDANT  = TOTAL minus the FIRST payment per house (one legit charge per house kept; the rest = relog
               re-charges). The fair middle estimate.

Run:  cd loonybot && ./venv/bin/python3 scan_housetax_overcharge.py
"""
import os, re, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import json
CFG = json.load(open(os.path.join(HERE, "config.json")))
import admin
DB = admin.DB(CFG["db"])

AMT  = re.compile(r"paid \$([\d,]+) house tax")
IDS  = re.compile(r"house ids?:\s*([\d,\s]+)")

rows = DB.q("SELECT ts, playerid, name, message FROM log WHERE tag='-HOUSETAX-' ORDER BY id ASC") or []
print(f"[scan] {len(rows)} -HOUSETAX- payment rows", flush=True)

names      = {}
total_paid = defaultdict(int)                       # pid -> $ paid all-time
pay_count  = defaultdict(int)                       # pid -> # payment events
# per (pid, houseid): list of payments. For payAll the total is split evenly across its listed houses (approx).
house_pays = defaultdict(lambda: defaultdict(list)) # pid -> houseid -> [amounts]

for r in rows:
    pid = r["playerid"]; msg = r["message"] or ""; nm = r["name"]
    if not pid:
        continue
    names[pid] = nm
    m = AMT.search(msg)
    if not m:
        continue
    amt = int(m.group(1).replace(",", ""))
    total_paid[pid] += amt
    pay_count[pid]  += 1
    idm = IDS.search(msg)
    hids = [h.strip() for h in idm.group(1).split(",")] if idm else []
    hids = [h for h in hids if h]
    if not hids:
        continue
    share = amt // len(hids)
    for h in hids:
        house_pays[pid][h].append(share)

# redundant = total minus the first (smallest-time = first in list) payment per house
redundant = {}
for pid, houses in house_pays.items():
    keep_first = sum(pays[0] for pays in houses.values() if pays)   # one legit charge per house
    redundant[pid] = max(0, total_paid[pid] - keep_first)

ranked = sorted(total_paid, key=lambda p: redundant.get(p, 0), reverse=True)

out = []
def w(s=""):
    out.append(s); print(s, flush=True)

w("=" * 78)
w("LooneyBin  HOUSE-TAX OVER-CHARGE  (read-only)  -- #374")
w("  TOTAL = all house tax paid.  REDUNDANT = total minus one (first) charge per house = relog re-charges.")
w("=" * 78)
g_total = g_redund = 0
for pid in ranked:
    red = redundant.get(pid, 0)
    if red <= 0 and pay_count[pid] < 2:
        continue
    g_total += total_paid[pid]; g_redund += red
    nhouses = len(house_pays[pid])
    maxrep  = max((len(p) for p in house_pays[pid].values()), default=1)
    w(f"{names.get(pid,'?'):<22} ({pid})  total ${total_paid[pid]:>9,}  redundant ${red:>9,}  "
      f"({pay_count[pid]} pays, {nhouses} houses, max {maxrep}× same house)")
w("-" * 78)
w(f"GRAND TOTAL paid: ${sum(total_paid.values()):,}   |   REDUNDANT (refund estimate): ${g_redund:,}   "
  f"across {len(ranked)} players")

open(os.path.join(HERE, "scan_housetax_overcharge.txt"), "w").write("\n".join(out))
w("")
w("[scan] full report -> loonybot/scan_housetax_overcharge.txt")

# ---- REFUND (owner 2026-06-18: pay the REDUNDANT basis). `--apply` mails each player their redundant amount to
# the in-game mailbox (DB.comp). Idempotent: a marker file records who's been paid so a re-run never double-pays.
# MIN_REFUND skips the $1-2 rounding noise on single-payers (only real repeat-charges get refunded). ----
MIN_REFUND = 100
if "--apply" in sys.argv:
    done_path = os.path.join(HERE, "housetax_refund_done.json")
    already = {}
    if os.path.exists(done_path):
        try: already = json.load(open(done_path))
        except Exception: already = {}
    paid = dict(already); n = 0; tot = 0
    for pid, amt in sorted(redundant.items(), key=lambda kv: -kv[1]):
        if amt < MIN_REFUND:
            continue
        if pid in already:
            print(f"[refund] {names.get(pid,'?')} ({pid}) already refunded ${already[pid]:,} — skip", flush=True); continue
        ok, msg = DB.comp(pid, int(amt))
        print(f"[refund] {names.get(pid,'?')} ({pid}) ${int(amt):,} -> {'OK' if ok else 'FAIL'}: {msg}", flush=True)
        if ok:
            paid[pid] = int(amt); n += 1; tot += int(amt)
    json.dump(paid, open(done_path, "w"))
    print(f"[refund] DONE: mailed ${tot:,} to {n} player(s). marker -> housetax_refund_done.json (re-run won't double-pay)", flush=True)
else:
    elig = {p: a for p, a in redundant.items() if a >= MIN_REFUND}
    print(f"[refund] DRY RUN — {len(elig)} player(s) eligible for ${sum(elig.values()):,} (>= ${MIN_REFUND}). Re-run with --apply to mail.", flush=True)
