"""
Enrique -- the offline gardener bot (LooneyBin, owner 2026-06-20).

A discord-linked player who is OFFLINE can `!enrique <sativa|indica>` in the gardener channel. Per use, for each
of their OWNED greenhouse houses (owner only -- NOT gang banks / keyholder houses), Enrique:
  * harvests every MATURE plant -> the bud item (cannas_3 Sativa / cannai_3 Indica) into the HOUSE inventory,
  * buys + plants the chosen strain to refill the greenhouse to capacity (capacity = house vcap / 10),
charges a flat $2500 fee + $100 per seed from the player's BANK (refuses if it can't cover fee + ALL seeds),
and pings the channel when the crop matures (2h Sativa / 3h Indica). Limit: 3 uses per ROLLING 24h.

DUPE-PROOF: pure DB ops, only while the player AND every keyholder of each target house are OFFLINE (re-checked
inside the write transaction), so no live client holds stale house/money state to clobber the write. Separate
Discord bot/token. Config: enrique.config.json (token + channel_id; db block falls back to loonybot config.json).
Run: cd loonybot && venv/bin/python enrique.py   (relaunch detached like clankr -- no supervisor).
"""
import json
import pathlib
import time
import asyncio

import discord
import pymysql
import pymysql.cursors

import admin  # shared DB config / helpers

HERE = pathlib.Path(__file__).resolve().parent
CFG_PATH = HERE / "enrique.config.json"

DEFAULTS = {
    "token": "",
    "channel_id": 100000000000000978,
    # owner 2026-06-21: a SECOND channel ("enrique-unlimited") where EVERYONE is exempt from the 3-per-24h cap.
    # Same offline/funds/dupe checks still apply -- only the daily count is waived (grow time still gates ~8-12/day).
    "unlimited_channel_id": 100000000000000979,
    "fee": 2500,
    "seed_cost": 100,
    "max_per_24h": 3,
    "epoch_offset": 1700000000,   # game clock = real_unix - this (matches AP_bootUnix epoch offset)
    "bud_weight": 1,
}
CFG = dict(DEFAULTS)
if CFG_PATH.exists():
    try:
        CFG.update(json.load(open(CFG_PATH, encoding="utf-8")))
    except Exception as e:
        print(f"[enrique] bad config: {e}", flush=True)
if not CFG.get("db"):
    lb = HERE / "config.json"
    if lb.exists():
        try:
            CFG["db"] = json.load(open(lb, encoding="utf-8")).get("db")
        except Exception:
            pass

DB = admin.DB(CFG["db"])
DBCFG = CFG["db"]
CHANNEL_ID = int(CFG.get("channel_id") or 0)
UNLIMITED_CHANNEL_ID = int(CFG.get("unlimited_channel_id") or 0)   # everyone exempt from the 24h cap here
CHANNELS = {c for c in (CHANNEL_ID, UNLIMITED_CHANNEL_ID) if c}    # channels Enrique listens in
FEE = int(CFG["fee"])
SEED_COST = int(CFG["seed_cost"])
MAX_24H = int(CFG["max_per_24h"])
# owner 2026-06-20: Discord user IDs EXEMPT from the 3-per-24h limit (owner is always exempt; add more via
# the optional "nocooldown_ids" config list). Still subject to offline + funds checks -- only the cooldown is waived.
NOCOOLDOWN_IDS = set(int(x) for x in CFG.get("nocooldown_ids", [])) | {100000000000000485}
EPOCH = int(CFG["epoch_offset"])
BUD_W = int(CFG["bud_weight"])

# strain key -> (code, grow_hours, bud_item)
STRAINS = {
    "sativa": ("s", 2, "cannas_3"), "s": ("s", 2, "cannas_3"),
    "indica": ("i", 3, "cannai_3"), "i": ("i", 3, "cannai_3"),
}
GROW = {"s": 2, "i": 3}
BUD = {"s": "cannas_3", "i": "cannai_3"}
# owner 2026-06-22: the SEED item (fn_virtItemCfg cannas_0/cannai_0). Enrique now uses seeds already STORED in the
# house before buying more -- count them in the house vinv, plant those first, only buy the shortfall ($100 each).
SEED = {"s": "cannas_0", "i": "cannai_0"}
SEED_W = int(CFG.get("seed_weight", 1))   # virtItemCfg weight of a seed (cannas_0/cannai_0 = 1)

# ---------------------------------------------------------------- mres (VALIDATED byte-identical to the game's
# DB_fnc_mresArray / DB_fnc_mresToArray on real houses.vinv -- round-trip == original). Used for vinv + keyholders.
def mres_decode(s):
    if s is None:
        return None
    s = s.replace("`", '"')                       # backtick -> quote (all)
    if s.startswith('"') and s.endswith('"'):
        s = s[1:-1]                                # strip the outer str() wrap
    s = s.replace('""', '"')                       # un-double interior quotes
    try:
        return json.loads(s)                       # SQF array string == JSON for this data
    except Exception:
        return None

def _sqf(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else repr(v)
    if isinstance(v, list):
        return "[" + ",".join(_sqf(x) for x in v) + "]"
    raise TypeError(v)

def mres_encode(arr):
    s = '"' + _sqf(arr).replace('"', '""') + '"'   # str(str(arr))
    ch = list(s)
    for i in range(1, len(ch) - 1):                # interior 34 -> 96 only (index 0/last stay ")
        if ch[i] == '"':
            ch[i] = "`"
    return "".join(ch)

def now_game_unix():
    return int(time.time()) - EPOCH

# ---------------------------------------------------------------- read helpers (admin.DB autocommit)
def link_pid(discord_id):
    r = DB.q("SELECT playerid FROM discord_links WHERE discord_id=%s LIMIT 1", (str(discord_id),), "one")
    return (r or {}).get("playerid")

def is_online(pid):
    r = DB.q("SELECT COUNT(*) c FROM online WHERE playerid=%s", (pid,), "one")
    return int((r or {}).get("c", 0)) > 0

def uses_last_24h(pid):
    r = DB.q("SELECT COUNT(*) c FROM enrique_log WHERE playerid=%s AND used_at > (UTC_TIMESTAMP() - INTERVAL 24 HOUR)",
             (pid,), "one")
    return int((r or {}).get("c", 0))

def owned_greenhouses(pid):
    return DB.q("SELECT oid, COALESCE(vcap,0) vcap, vinv, greenhouse_crop, keyholders, worldspace "
                "FROM houses WHERE owners=%s AND greenhouse=1", (pid,)) or []

def online_uids(uids):
    """subset of uids currently online."""
    uids = [u for u in uids if u]
    if not uids:
        return set()
    ph = ",".join(["%s"] * len(uids))
    rows = DB.q(f"SELECT DISTINCT playerid FROM online WHERE playerid IN ({ph})", tuple(uids)) or []
    return {r["playerid"] for r in rows}

def house_keyholder_uids(keyholders_raw):
    dec = mres_decode(keyholders_raw) or []
    out = []
    for e in dec:
        if isinstance(e, list) and e and isinstance(e[0], str):
            out.append(e[0])
    return out

# ---------------------------------------------------------------- per-house plan
def plan_house(h, strain_code):
    """Return a dict plan for one house, or None to skip. Pure compute (no writes)."""
    oid = str(h["oid"])
    vcap = int(h.get("vcap") or 0)
    max_plants = vcap // 10
    if max_plants <= 0:
        return None
    crop = []
    raw = h.get("greenhouse_crop")
    if raw:
        try:
            crop = json.loads(raw)   # plain array string (NOT mres): [[strain, plantedUnix, count], ...]
        except Exception:
            crop = []
    now = now_game_unix()
    # tally mature buds per strain (oldest-first consume), keep immature
    buds = {"s": 0, "i": 0}
    immature = []
    for ent in crop:
        if not (isinstance(ent, list) and len(ent) >= 3):
            continue
        st, pt, cnt = ent[0], float(ent[1]), int(ent[2])
        if pt > 1000000000:        # normalize PRE-#248 full-unix times (mirror the SQF)
            pt -= 1700000000
        need = GROW.get(st, 3)
        if int(max((now - pt), 0) // 3600) >= need:
            buds[st] = buds.get(st, 0) + cnt
        else:
            immature.append([st, ent[1], cnt])
    # vinv: cap the bud deposit at the house's free virtual weight (vcap - current weight)
    vinv = mres_decode(h.get("vinv")) or [[], 0]
    if not (isinstance(vinv, list) and len(vinv) == 2 and isinstance(vinv[0], list)):
        vinv = [[], 0]
    cur_w = int(vinv[1]) if isinstance(vinv[1], (int, float)) else 0
    free_w = max(vcap - cur_w, 0)
    # deposit Sativa buds then Indica, limited by free weight; un-harvested mature stays as crop (harvest later)
    deposit = {"s": 0, "i": 0}
    room_w = free_w
    for st in ("s", "i"):
        take = min(buds[st], room_w // BUD_W) if BUD_W > 0 else buds[st]
        deposit[st] = take
        room_w -= take * BUD_W
    # any mature not deposited (no vinv room) -> keep it in the crop as a mature batch so it isn't lost, and tally
    # the OVERFLOW: that bud is mature but the house storage is FULL (owner 2026-06-23: notify, don't spam).
    overflow = 0
    for st in ("s", "i"):
        leftover = buds[st] - deposit[st]
        if leftover > 0:
            overflow += leftover
            mat_pt = now - (GROW[st] * 3600)   # stamp as just-matured so status still reads MATURE
            immature.append([st, mat_pt, leftover])
    # refill to capacity with the chosen strain -- BUT if the house storage is FULL (mature bud overflowed with
    # nowhere to go), do NOT replant: more plants -> more bud the full house can't hold = the "spam bud" the owner
    # flagged. Replant only when the harvest actually fit (overflow == 0); a full house just gets the FULL notice.
    used_after = sum(int(e[2]) for e in immature)
    room = 0 if overflow > 0 else max(max_plants - used_after, 0)
    new_crop = list(immature)
    if room > 0:
        new_crop.append([strain_code, now, room])
    # owner 2026-06-22: use seeds already STORED in the house before buying. Count the seed item in the house vinv,
    # take from there first, only BUY the remainder. (vinv[0] = the [class, qty] item list.)
    seed_item = SEED[strain_code]
    seeds_in_house = 0
    for it in vinv[0]:
        if isinstance(it, list) and len(it) >= 2 and it[0] == seed_item:
            seeds_in_house = int(it[1]); break
    seeds_from_inv = min(room, max(seeds_in_house, 0))
    seeds_buy = room - seeds_from_inv
    return {
        "oid": oid, "vcap": vcap, "vinv": vinv, "deposit": deposit,
        "seeds": room, "seeds_buy": seeds_buy, "seeds_from_inv": seeds_from_inv, "seed_item": seed_item,
        "new_crop": new_crop,
        "harvested": deposit["s"] + deposit["i"],
        "overflow": overflow,
        "ws": h.get("worldspace"),
    }

def build_vinv_update(vinv, deposit, consume_item=None, consume_qty=0):
    """Return the new mres-encoded vinv string: bud deposits merged in, and (optionally) `consume_qty` of
    `consume_item` (house-stored seeds) removed first -- Enrique plants those before buying."""
    items, weight = list(vinv[0]), int(vinv[1]) if isinstance(vinv[1], (int, float)) else 0
    # index existing items
    idx = {}
    for i, it in enumerate(items):
        if isinstance(it, list) and len(it) >= 2 and isinstance(it[0], str):
            idx[it[0]] = i
    # consume house-stored seeds FIRST (matches the count plan_house planted from inventory)
    if consume_item and consume_qty > 0 and consume_item in idx:
        ci = idx[consume_item]
        take = min(int(items[ci][1]), consume_qty)
        items[ci][1] = int(items[ci][1]) - take
        weight -= take * SEED_W
    added_w = 0
    for st in ("s", "i"):
        n = deposit.get(st, 0)
        if n <= 0:
            continue
        item = BUD[st]
        if item in idx:
            items[idx[item]][1] = int(items[idx[item]][1]) + n
        else:
            items.append([item, n])
            idx[item] = len(items) - 1
        added_w += n * BUD_W
    # drop any item that hit 0 (e.g. fully-consumed seeds) so the vinv stays clean
    items = [it for it in items if not (isinstance(it, list) and len(it) >= 2 and int(it[1]) <= 0)]
    return mres_encode([items, max(weight + added_w, 0)])

# ---------------------------------------------------------------- the transactional garden op (dupe-proof)
def run_garden(pid, strain_code, skip_cd=False, channel_id=None):
    """Returns (ok, message, ready_hours, summary). Does ALL writes in one transaction, re-checking offline inside.
    skip_cd=True (owner / NOCOOLDOWN_IDS / unlimited channel) waives the 24h limit but NOT the offline/funds checks.
    channel_id = the Discord channel the command came from (drives where the ready-ping is sent)."""
    houses = owned_greenhouses(pid)
    if not houses:
        return (False, "You don't own any houses with a greenhouse.", 0, None)
    # only houses where EVERY keyholder is offline (owner = the commanding player, already offline)
    eligible, skipped = [], []
    for h in houses:
        khs = house_keyholder_uids(h.get("keyholders"))
        if online_uids(khs):
            skipped.append(str(h["oid"]))
        else:
            eligible.append(h)
    if not eligible:
        return (False, "A keyholder of your greenhouse house(s) is online -- everyone with keys must be offline.", 0, None)
    all_plans = [p for p in (plan_house(h, strain_code) for h in eligible) if p]
    total_overflow = sum(p.get("overflow", 0) for p in all_plans)        # mature bud that didn't fit = house FULL
    plans = [p for p in all_plans if p["seeds"] > 0 or p["harvested"] > 0]
    if not plans:
        if total_overflow > 0:
            return (False, f"🌿 ¡Ay, jefe! You **casa está llena** — **{total_overflow}** mature bud(s) are waiting "
                    f"but you house storage is **FULL**, no room to put them. Log in, empty you house, then call "
                    f"Enrique back. **No charge** — Enrique he no take you money for nothing, eh? 🌵", 0, None)
        return (False, "Nothing to do -- greenhouses are full of still-growing plants and none are mature yet.", 0, None)
    total_seeds = sum(p["seeds"] for p in plans)          # total planted (for the summary)
    total_buy = sum(p["seeds_buy"] for p in plans)        # only the shortfall is bought ($100 each)
    total_from_inv = sum(p["seeds_from_inv"] for p in plans)   # used from house-stored seeds first
    # owner 2026-06-23: a pure-harvest run (no replant -- every house was FULL) costs nothing. Only charge the $2500
    # fee when Enrique actually replants (the real service); a full house gets a free top-off + the FULL notice.
    cost = (FEE + total_buy * SEED_COST) if total_seeds > 0 else 0
    bank_row = DB.q("SELECT COALESCE(bankacc,0) b FROM players WHERE playerid=%s LIMIT 1", (pid,), "one")
    bank = int((bank_row or {}).get("b", 0))
    if bank < cost:
        return (False, f"Not enough in the bank. Enrique needs ${cost:,} ($2,500 fee + {total_buy} seed(s) bought, {total_from_inv} taken from your house) -- you have ${bank:,}.", 0, None)

    ready_h = GROW[strain_code]
    # all keyholder uids across eligible houses + the player, for the in-transaction offline re-check
    recheck = {pid}
    for h in eligible:
        recheck.update(house_keyholder_uids(h.get("keyholders")))

    con = pymysql.connect(host=DBCFG.get("host", "127.0.0.1"), port=int(DBCFG.get("port", 3306)),
                          user=DBCFG["user"], password=DBCFG["password"], database=DBCFG["database"],
                          autocommit=False, charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
                          connect_timeout=8)
    try:
        with con.cursor() as cur:
            # RE-CHECK offline inside the txn -- abort if the player or any keyholder is now online (anti-race)
            ph = ",".join(["%s"] * len(recheck))
            cur.execute(f"SELECT COUNT(*) c FROM online WHERE playerid IN ({ph})", tuple(recheck))
            if int(cur.fetchone()["c"]) > 0:
                con.rollback()
                return (False, "Someone (you or a keyholder) just came online -- try again once everyone's offline.", 0, None)
            # re-check the 24h limit + bank under the lock (cheap; avoids a double-spend from two fast commands)
            if not skip_cd:
                cur.execute("SELECT COUNT(*) c FROM enrique_log WHERE playerid=%s AND used_at > (UTC_TIMESTAMP() - INTERVAL 24 HOUR)", (pid,))
                if int(cur.fetchone()["c"]) >= MAX_24H:
                    con.rollback()
                    return (False, f"😴 I'm sleeping homes try again later ese (you've used {MAX_24H}x in 24h)", 0, None)
            cur.execute("SELECT COALESCE(bankacc,0) b FROM players WHERE playerid=%s FOR UPDATE", (pid,))
            bank_now = int(cur.fetchone()["b"])
            if bank_now < cost:
                con.rollback()
                return (False, f"Not enough in the bank (${bank_now:,} < ${cost:,}).", 0, None)
            # charge bank
            cur.execute("UPDATE players SET bankacc=bankacc-%s WHERE playerid=%s", (cost, pid))
            # per house: write vinv (buds) + greenhouse_crop (harvest + replant)
            done = []
            for p in plans:
                if p["harvested"] > 0 or p["seeds_from_inv"] > 0:
                    new_vinv = build_vinv_update(p["vinv"], p["deposit"], p["seed_item"], p["seeds_from_inv"])
                    cur.execute("UPDATE houses SET vinv=%s WHERE oid=%s", (new_vinv, p["oid"]))
                # greenhouse_crop: plain str of the array; NULL when empty
                if p["new_crop"]:
                    crop_str = _sqf([[e[0], int(e[1]) if float(e[1]).is_integer() else e[1], int(e[2])] for e in p["new_crop"]])
                    cur.execute("UPDATE houses SET greenhouse_crop=%s WHERE oid=%s", (crop_str, p["oid"]))
                else:
                    cur.execute("UPDATE houses SET greenhouse_crop=NULL WHERE oid=%s", (p["oid"],))
                # owner 2026-06-20: the LIVE server caches each house's vinv/crop in RAM (loaded at boot), so a raw DB
                # write is invisible in-game AND gets clobbered when the house is next saved. Queue a `ghrefresh` on the
                # bot_commands bridge -- the server re-reads this house's vinv+crop from the DB onto the running house
                # object (~5s) so Enrique's harvest/replant actually takes effect. ws = worldspace (server nearestObjects it).
                cur.execute("INSERT INTO bot_commands (command, target, arg1, issued_by, status, created) "
                            "VALUES ('ghrefresh', %s, %s, 'enrique', 'pending', UTC_TIMESTAMP())",
                            (p["oid"], p.get("ws") or ""))
                done.append(p)
            # record the use (drives the 24h limit + the ready ping). Only schedule a ready-ping when we actually
            # PLANTED new crop; a pure harvest (full house, no replant) has nothing maturing -> ready_at NULL, pinged=1.
            detail = f"strain={strain_code} houses={len(done)} planted={total_seeds} bought={total_buy} fromhouse={total_from_inv} harvested={sum(d['harvested'] for d in done)} overflow={total_overflow} cost={cost}"
            if total_seeds > 0:
                cur.execute("INSERT INTO enrique_log (playerid, used_at, ready_at, pinged, detail, channel_id) "
                            "VALUES (%s, UTC_TIMESTAMP(), UTC_TIMESTAMP() + INTERVAL %s HOUR, 0, %s, %s)",
                            (pid, ready_h, detail, channel_id))
            else:
                cur.execute("INSERT INTO enrique_log (playerid, used_at, ready_at, pinged, detail, channel_id) "
                            "VALUES (%s, UTC_TIMESTAMP(), NULL, 1, %s, %s)",
                            (pid, detail, channel_id))
        con.commit()
    except Exception as e:
        try:
            con.rollback()
        except Exception:
            pass
        print(f"[enrique] txn error pid={pid}: {e}", flush=True)
        return (False, "Garden failed -- a database hiccup. Nothing was charged. Try again.", 0, None)
    finally:
        con.close()

    harvested = sum(p["harvested"] for p in plans)
    strain_name = "Sativa" if strain_code == "s" else "Indica"
    if total_seeds > 0:
        seed_note = (f" ({total_from_inv} from your house stock, {total_buy} bought)" if total_from_inv > 0 else "")
        summary = (f"harvested **{harvested}** bud(s) into your house(s), planted **{total_seeds}** {strain_name} "
                   f"seed(s){seed_note} across **{len(plans)}** greenhouse(s), charged **${cost:,}**.")
    else:
        summary = (f"harvested **{harvested}** bud(s) into your house(s) across **{len(plans)}** greenhouse(s) — "
                   f"**no charge** (Enrique no replant a full casa).")
    if skipped:
        summary += f" (skipped {len(skipped)} house(s) -- a keyholder was online)"
    if total_overflow > 0:
        summary += (f"\n⚠️ **¡Tu casa está llena!** **{total_overflow}** bud(s) no fit — that storage is **FULL** so "
                    f"Enrique no plant more there (or it just pile up). Empty you house, amigo, then call me back. 🌿")
    return (True, summary, ready_h if total_seeds > 0 else 0, summary)

# ---------------------------------------------------------------- ensure the log table exists
def ensure_table():
    DB.q("""CREATE TABLE IF NOT EXISTS enrique_log (
              id INT AUTO_INCREMENT PRIMARY KEY,
              playerid VARCHAR(17) NOT NULL,
              used_at DATETIME NOT NULL,
              ready_at DATETIME NULL,
              pinged TINYINT NOT NULL DEFAULT 0,
              detail TEXT NULL,
              channel_id BIGINT NULL,
              KEY k_pid_used (playerid, used_at),
              KEY k_ready (pinged, ready_at)
            )""", (), "none")
    # owner 2026-06-21: record which channel a use came from so the ready-ping goes back to THAT channel
    # (unlimited-channel users may not have access to the original gardener channel). Idempotent for live tables.
    DB.q("ALTER TABLE enrique_log ADD COLUMN IF NOT EXISTS channel_id BIGINT NULL", (), "none")

# ---------------------------------------------------------------- Discord
intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

INTRO = (
    "🌿 ¡Hola amigos! Me llamo **Enrique**, I am you gardener, sí?\n\n"
    "I no have de green card — shhh, no tell la policía, eh? — but Enrique he work *hard* for you. You go offline, "
    "you go sleep, you go do de crime... and Enrique, he stay and take care of you weed plant like they his own little "
    "niños. I pick you grown plant, I put in you casa, then I buy de seed and plant more so you greenhouse never empty. "
    "All for you, jefe. 🌱\n\n"
    "**What Enrique do for you:**\n"
    "`!enrique indica` — harvest + replant all you house with Indica *(ready in 3 hour)*\n"
    "`!enrique sativa` — harvest + replant with Sativa *(ready in 2 hour)*\n\n"
    "**De rules, amigo:**\n"
    "• You must be **offline** — Enrique no work while you watch, is weird\n"
    "• Only de house **you own** — no de gang, no de friend house, and everybody with de key must be offline too\n"
    "• Cost **$2,500** + **$100 each seed** from you bank — no money, no garden, lo siento\n"
    "• **3 time** every 24 hour only — Enrique need de siesta too\n"
    "• I ping you right here when you plant is ready to pick\n\n"
    "Now go, leave Enrique to his garden. ¡Vámonos! 🌵"
)
USAGE = INTRO

# intro for the donor "enrique-unlimited" channel -- cousin Héctor works the night shift, so no 3/24h siesta cap (owner 2026-06-21)
UNLIMITED_INTRO = (
    "🌿 ¡Hola amigos! Me llamo **Enrique**, you gardener, sí? You already know me — I take care of you weed plant "
    "while you go offline, go sleep, go do de crime. I harvest, I put in you casa, I buy de seed and replant so you "
    "greenhouse never empty. 🌱\n\n"
    "But listen — because you **donate to Project Loony Bin**, I tell you a family secret: my cousin **Héctor**. 🌙 "
    "Héctor he work de *night shift*, he no sleep, he no need de siesta like me. So between me and Héctor, somebody "
    "always awake for you garden — no more \"3 time a day\" límite, eh? You come back **every 3 hour**, all day, all "
    "night, **same price**. De familia, we got you. 🌵\n\n"
    "**What me and Héctor do for you:**\n"
    "`!enrique indica` — harvest + replant all you house with Indica *(ready in 3 hour)*\n"
    "`!enrique sativa` — harvest + replant with Sativa *(ready in 2 hour)*\n\n"
    "**De rules, amigo:**\n"
    "• You must be **offline** — we no work while you watch, is weird\n"
    "• Only de house **you own** — no de gang, no de friend house, and everybody with de key must be offline too\n"
    "• Cost **$2,500** + **$100 each seed** from you bank — same price as always, no money no garden, lo siento\n"
    "• **No siesta límite here** — me and Héctor we trade de shift, so come back **every 3 hour** 🌙☀️\n"
    "• We ping you right here when you plant is ready to pick\n\n"
    "**¡Gracias for donating to Project Loony Bin Altis Life!** Without you, Héctor he no eat, eh? 🙏 Now go, leave "
    "de garden to la familia. ¡Vámonos! 🌵"
)

@client.event
async def on_ready():
    try:
        ensure_table()
    except Exception as e:
        print(f"[enrique] ensure_table failed: {e}", flush=True)
    print(f"[enrique] online as {client.user} | channel={CHANNEL_ID}", flush=True)
    client.loop.create_task(ping_loop())
    # one-time self-introduction -- marker-guarded so he doesn't re-introduce on every restart. To make Enrique say
    # hello again, delete loonybot/enrique.intro_posted.
    try:
        marker = HERE / "enrique.intro_posted"
        if not marker.exists():
            ch = client.get_channel(CHANNEL_ID)
            if ch:
                await ch.send(INTRO)
                marker.touch()
                print("[enrique] posted intro", flush=True)
    except Exception as e:
        print(f"[enrique] intro post failed: {e}", flush=True)
    # donor "enrique-unlimited" channel intro (cousin Héctor / night shift). Separate marker so each posts once.
    # To re-introduce in that channel, delete loonybot/enrique.intro_posted_unlimited.
    try:
        if UNLIMITED_CHANNEL_ID:
            marker_u = HERE / "enrique.intro_posted_unlimited"
            if not marker_u.exists():
                chu = client.get_channel(UNLIMITED_CHANNEL_ID)
                if chu:
                    await chu.send(UNLIMITED_INTRO)
                    marker_u.touch()
                    print("[enrique] posted unlimited intro", flush=True)
                else:
                    print("[enrique] unlimited channel not found (bot lacks access?) -- intro not posted", flush=True)
    except Exception as e:
        print(f"[enrique] unlimited intro post failed: {e}", flush=True)

@client.event
async def on_message(message):
    if message.author.bot or message.channel.id not in CHANNELS:
        return
    content = message.content.strip()
    low = content.lower()
    if not (low.startswith("!enrique") or low.startswith("!garden")):
        return
    parts = content.split()
    if len(parts) < 2 or parts[1].lower() not in STRAINS:
        await message.channel.send(f"{message.author.mention} 🌿 ¡Oye! tell Enrique which one — `!enrique indica` or `!enrique sativa`, amigo.")
        return
    strain_code = STRAINS[parts[1].lower()][0]

    pid = await asyncio.to_thread(link_pid, message.author.id)
    if not pid:
        await message.channel.send(f"{message.author.mention} you're not linked. Link your Discord to your in-game account first.")
        return
    if await asyncio.to_thread(is_online, pid):
        await message.channel.send(f"{message.author.mention} Enrique only works while you're **offline** — log out first.")
        return
    # unlimited channel: EVERYONE skips the 24h cap (still must be offline + have funds). Elsewhere: owner/NOCOOLDOWN only.
    _nocd = (message.channel.id == UNLIMITED_CHANNEL_ID) or (message.author.id in NOCOOLDOWN_IDS)
    if not _nocd and await asyncio.to_thread(uses_last_24h, pid) >= MAX_24H:
        await message.channel.send(f"{message.author.mention} 😴 I'm sleeping homes try again later ese (you've used {MAX_24H}x in 24h)")
        return

    ok, msg, ready_h, _ = await asyncio.to_thread(run_garden, pid, strain_code, _nocd, message.channel.id)
    if not ok:
        await message.channel.send(f"{message.author.mention} {msg}")
        return
    reply = f"{message.author.mention} ✅ Enrique {msg}"
    if ready_h > 0:
        reply += f"\n🌱 Your **{'Sativa' if strain_code=='s' else 'Indica'}** will be ready in **{ready_h}h** — I'll ping you here."
    await message.channel.send(reply)

# ---------------------------------------------------------------- ready-ping loop (DB-backed, survives a restart)
async def ping_loop():
    await client.wait_until_ready()
    ch = client.get_channel(CHANNEL_ID)
    while not client.is_closed():
        try:
            due = await asyncio.to_thread(
                lambda: DB.q("SELECT id, playerid, channel_id FROM enrique_log WHERE pinged=0 AND ready_at IS NOT NULL "
                             "AND ready_at <= UTC_TIMESTAMP()") or [])
            for row in due:
                link = await asyncio.to_thread(
                    lambda p=row["playerid"]: DB.q("SELECT discord_id FROM discord_links WHERE playerid=%s LIMIT 1", (p,), "one"))
                did = (link or {}).get("discord_id")
                # ping back to the channel they used (fall back to the main gardener channel for old/null rows)
                target = client.get_channel(int(row["channel_id"])) if row.get("channel_id") else None
                target = target or ch
                if target and did:
                    try:
                        await target.send(f"<@{did}> 🌿 your weed is **ready to harvest** — Enrique's crop has matured. Log in and collect it from your house.")
                    except Exception as e:
                        print(f"[enrique] ping send failed: {e}", flush=True)
                await asyncio.to_thread(lambda i=row["id"]: DB.q("UPDATE enrique_log SET pinged=1 WHERE id=%s", (i,), "none"))
        except Exception as e:
            print(f"[enrique] ping_loop error: {e}", flush=True)
        await asyncio.sleep(60)

if __name__ == "__main__":
    # owner 2026-06-24 (#529 DOUBLE-CHARGE): enrique is launched detached with no supervisor, so an accidental
    # second launch left TWO instances both handling every !enrique -> players double-charged + double-planted.
    # Single-instance flock guard: a 2nd process can't acquire the lock and exits. The OS releases the lock when
    # the holder dies, so a clean relaunch always works.
    import fcntl
    _LOCK_FH = open("/tmp/enrique.lock", "w")
    try:
        fcntl.flock(_LOCK_FH, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("[enrique] another instance is already running -- refusing to start (single-instance guard).", flush=True)
        raise SystemExit(0)
    if not CFG.get("token"):
        print("[enrique] no token in enrique.config.json -- set it to go live.", flush=True)
    else:
        client.run(CFG["token"])
