"""
Latoya -- the IRS house-tax bot (LooneyBin, owner 2026-06-21).

A Discord-linked player who is OFFLINE can pay their overdue house taxes from Discord ("!tax" / "!irs"). Latoya is
a disinterested government clerk with a touch of sass. Per use she:
  * pulls every house the player OWNS that is payable (DATEDIFF(NOW(),tax_paid) >= 1 day),
  * computes the EXACT house tax the same way the game does (days * per-type upkeep * activity multiplier, +0.2 if
    >32 days overdue) -- needs houses.classname (the server boot loop writes it; see init.sqf),
  * adds a flat 0.15x PROCESSING FEE on the total tax,
  * charges (tax + fee) straight from the player's BANK (players.bankacc), refusing if it can't cover the whole bill,
  * resets tax_paid=NOW(), tax_playtime=0 on each paid house (identical to the in-game pay).
The money VANISHES (sink) -- same as paying in-game; no account is credited. The init.sqf tax tag-loop re-reads
tax_paid/tax_playtime from the DB every 5 min, so the house clears in-game without any bridge.

LIMIT (owner's rule): Latoya processes for a player at most ONCE PER 14 DAYS -- UNLESS the player has logged into the
game and paid a house tax MANUALLY since their last Latoya payment, which unlocks her again early. So you can't live
in Discord forever dodging the game; every cycle you must actually log in and pay one yourself to keep using her fast.
Derived purely from the `log` table (-HOUSETAXDISCORD- = Latoya pays; -HOUSETAX- = manual in-game pays). No new table.

DUPE/abuse-PROOF: pure DB ops, only while the player is OFFLINE (re-checked inside the write transaction with the bank
row FOR UPDATE), so no live client holds stale house/money state to clobber the write -- the project rule "DB is
authoritative for bank only when the player is OFFLINE". Separate Discord bot/token. Config: latoya.config.json
(token + channel_id; db block falls back to loonybot config.json). Run: cd loonybot && venv/bin/python latoya.py
(relaunch detached like clankr/enrique -- no supervisor).
"""
import json
import math
import pathlib
import time
import asyncio

import discord
import pymysql
import pymysql.cursors

import admin  # shared DB config / helpers

HERE = pathlib.Path(__file__).resolve().parent
CFG_PATH = HERE / "latoya.config.json"

DEFAULTS = {
    "token": "",
    "channel_id": 0,            # the #irs / #house-tax channel Latoya listens in -- set in latoya.config.json
    "unlimited_channel_id": 0,  # owner 2026-06-21: DONOR channel -- same offline/funds/real-tax checks, but NO 14-day cooldown
    "fee_rate": 0.15,           # processing fee = fee_rate * total tax owed (owner: 0.15x), straight from bank
    "cooldown_days": 14,        # Latoya processes at most once per this many days unless a manual pay happened since
    "nocooldown_ids": [],       # Discord user IDs exempt from the cooldown ANYWHERE (still offline + funds gated)
}
CFG = dict(DEFAULTS)
if CFG_PATH.exists():
    try:
        CFG.update(json.load(open(CFG_PATH, encoding="utf-8")))
    except Exception as e:
        print(f"[latoya] bad config: {e}", flush=True)
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
UNLIMITED_CHANNEL_ID = int(CFG.get("unlimited_channel_id") or 0)   # donor channel -- no 14-day cooldown
CHANNELS = {c for c in (CHANNEL_ID, UNLIMITED_CHANNEL_ID) if c}    # channels Latoya listens in
NOCOOLDOWN_IDS = set(int(x) for x in CFG.get("nocooldown_ids", []))
FEE_RATE = float(CFG.get("fee_rate", 0.15))
COOLDOWN_DAYS = int(CFG.get("cooldown_days", 14))

LAT_TAG = "-HOUSETAXDISCORD-"   # Latoya's audit/cooldown tag
MAN_TAG = "-HOUSETAX-"          # manual in-game pay tag (fn_manageHouseTax)

# ---------------------------------------------------------------- the game's tax math (mirror of
# APS_fnc_houseTaxSRV._calcTax / fn_manageHouseTax "calculateTax"). Keep IN SYNC with those if they change.
# per-type upkeep = fn_houseConfig index 4.
UPKEEP = {
    "Land_i_House_Small_01_V1_F": 300, "Land_i_House_Small_01_V2_F": 300, "Land_i_House_Small_01_V3_F": 300,
    "Land_i_House_Small_02_V1_F": 300, "Land_i_House_Small_02_V2_F": 300, "Land_i_House_Small_02_V3_F": 300,
    "Land_i_House_Small_03_V1_F": 300,
    "Land_i_Shop_01_V1_F": 300, "Land_i_Shop_01_V2_F": 300, "Land_i_Shop_01_V3_F": 300,
    "Land_i_House_Big_01_V1_F": 675, "Land_i_House_Big_01_V2_F": 675, "Land_i_House_Big_01_V3_F": 675,
    "Land_i_House_Big_02_V1_F": 675, "Land_i_House_Big_02_V2_F": 675, "Land_i_House_Big_02_V3_F": 675,
    "Land_i_Stone_HouseSmall_V1_F": 500, "Land_i_Stone_HouseSmall_V2_F": 500, "Land_i_Stone_HouseSmall_V3_F": 500,
    "Land_i_Stone_Shed_V1_F": 275, "Land_i_Stone_Shed_V2_F": 275, "Land_i_Stone_Shed_V3_F": 275,
    "Land_i_Addon_02_V1_F": 275,
    "Land_i_Garage_V1_F": 275, "Land_i_Garage_V2_F": 275, "Land_i_Garage_V1_dam_F": 275, "Land_i_Garage_V2_dam_F": 275,
    "Land_i_Shed_Ind_F": 1375,
}
# activity multiplier table [houseCount 1..5][floor(playtime_min/60)]; past the row end -> 0.25. clamp [0.25, 2.0].
MULT_TABLE = [
    [1.0, 0.9, 0.8, 0.6, 0.4, 0.25],
    [1.2, 1.2, 1.1, 1.1, 1.0, 1.0, 0.8, 0.6, 0.5, 0.4, 0.25],
    [1.3, 1.3, 1.2, 1.2, 1.1, 1.1, 1.0, 0.9, 0.8, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25],
    [1.5, 1.5, 1.5, 1.4, 1.4, 1.4, 1.3, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25],
    [2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 1.9, 1.8, 1.7, 1.6, 1.5, 1.4, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25],
]

def _arma_round(x):
    """match SQF round (half away from zero) -- Python round() is banker's, off by 1 on exact .5."""
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))

def house_tax(days, playtime_min, house_count, classname):
    """Exact per-house tax, mirroring the game. Returns 0 if not payable / unknown type."""
    days = int(days or 0)
    if days < 1:
        return 0
    upkeep = UPKEEP.get(classname or "")
    if not upkeep:
        return None   # classname unknown / not yet synced -> signal "can't price this one"
    row = MULT_TABLE[min(max(int(house_count), 1), 5) - 1]
    idx = int(playtime_min or 0) // 60
    red = 0.25 if idx > (len(row) - 1) else row[idx]
    red = min(max(red, 0.25), 2.0)
    if days > 32:           # overdue(>14) AND >32 -> the +0.2 surcharge (days>32 implies overdue)
        red += 0.2
    return _arma_round(days * upkeep * red)

# ---------------------------------------------------------------- read helpers (admin.DB autocommit)
def link_pid(discord_id):
    r = DB.q("SELECT playerid FROM discord_links WHERE discord_id=%s LIMIT 1", (str(discord_id),), "one")
    return (r or {}).get("playerid")

def is_online(pid):
    r = DB.q("SELECT COUNT(*) c FROM online WHERE playerid=%s", (pid,), "one")
    return int((r or {}).get("c", 0)) > 0

def player_name(pid):
    r = DB.q("SELECT name FROM players WHERE playerid=%s LIMIT 1", (pid,), "one")
    return ((r or {}).get("name") or "Taxpayer")[:64]

def house_count(pid):
    r = DB.q("SELECT COUNT(*) c FROM houses WHERE owners=%s", (pid,), "one")
    return int((r or {}).get("c", 0))

def payable_houses(pid):
    """player's houses that are at least 1 day unpaid, with the DB-computed days (NOW() = the game's clock)."""
    return DB.q("SELECT oid, COALESCE(classname,'') classname, tax_playtime, "
                "DATEDIFF(NOW(), tax_paid) AS days FROM houses "
                "WHERE owners=%s AND DATEDIFF(NOW(), tax_paid) >= 1", (pid,)) or []

def bank_of(pid):
    r = DB.q("SELECT COALESCE(bankacc,0) b FROM players WHERE playerid=%s LIMIT 1", (pid,), "one")
    return int((r or {}).get("b", 0))

def cooldown_state(pid):
    """Returns (allowed, days_left). allowed if never used, or >=COOLDOWN_DAYS since last Latoya pay, or a MANUAL
    in-game pay happened since the last Latoya pay."""
    r = DB.q(
        "SELECT (SELECT MAX(ts) FROM log WHERE tag=%s AND playerid=%s) AS last_lat, "
        "(SELECT MAX(ts) FROM log WHERE tag=%s AND playerid=%s) AS last_man, "
        "DATEDIFF(NOW(), (SELECT MAX(ts) FROM log WHERE tag=%s AND playerid=%s)) AS days_since",
        (LAT_TAG, pid, MAN_TAG, pid, LAT_TAG, pid), "one") or {}
    last_lat = r.get("last_lat")
    if last_lat is None:
        return (True, 0)
    days_since = int(r.get("days_since") or 0)
    if days_since >= COOLDOWN_DAYS:
        return (True, 0)
    last_man = r.get("last_man")
    if last_man is not None and last_man > last_lat:
        return (True, 0)
    return (False, max(COOLDOWN_DAYS - days_since, 0))

# ---------------------------------------------------------------- access-holder helpers (for the warn pings)
def mres_decode(s):
    """decode an mres/str2-encoded blob (keyholders) -- same routine as Enrique, validated vs the game."""
    if s is None:
        return None
    s = s.replace("`", '"')
    if s.startswith('"') and s.endswith('"'):
        s = s[1:-1]
    s = s.replace('""', '"')
    try:
        return json.loads(s)
    except Exception:
        return None

def access_uids(owner, keyholders_raw):
    """everyone with access to a house = owner + keyholders (keyholders entries are [uid, ...])."""
    out = [owner] if owner else []
    for e in (mres_decode(keyholders_raw) or []):
        if isinstance(e, list) and e and isinstance(e[0], str):
            out.append(e[0])
    seen = []
    for u in out:
        if u and u not in seen:
            seen.append(u)
    return seen

def linked_discord_ids(uids):
    """uid -> discord_id for the subset of uids that have linked their Discord."""
    uids = [u for u in uids if u]
    if not uids:
        return {}
    ph = ",".join(["%s"] * len(uids))
    rows = DB.q(f"SELECT playerid, discord_id FROM discord_links WHERE playerid IN ({ph})", tuple(uids)) or []
    return {r["playerid"]: r["discord_id"] for r in rows}

# ---------------------------------------------------------------- the transactional collection (dupe-proof)
def collect_tax(pid, name, skip_cd=False):
    """Returns (ok, message_kind, payload). Does the affordability check + all writes in one transaction, re-checking
    offline + cooldown inside with the bank row locked FOR UPDATE. skip_cd=True (donor channel / NOCOOLDOWN_IDS)
    waives the 14-day cooldown but NOT the offline/funds checks."""
    houses = payable_houses(pid)
    if not houses:
        return (False, "nothing_owed", None)
    cnt = house_count(pid)
    # price every payable house; collect any we can't price (classname not synced yet)
    priced, unpriced = [], 0
    total_tax = 0
    for h in houses:
        t = house_tax(h["days"], h["tax_playtime"], cnt, h["classname"])
        if t is None:
            unpriced += 1
            continue
        if t > 0:
            priced.append((str(h["oid"]), t, int(h["days"])))
            total_tax += t
    if not priced:
        if unpriced:
            return (False, "not_synced", None)   # houses exist but type not written yet (pre-deploy)
        return (False, "nothing_owed", None)
    fee = _arma_round(total_tax * FEE_RATE)
    debit = total_tax + fee

    bank = bank_of(pid)
    if bank < debit:
        return (False, "broke", {"tax": total_tax, "fee": fee, "debit": debit, "bank": bank})

    con = pymysql.connect(host=DBCFG.get("host", "127.0.0.1"), port=int(DBCFG.get("port", 3306)),
                          user=DBCFG["user"], password=DBCFG["password"], database=DBCFG["database"],
                          autocommit=False, charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
                          connect_timeout=8)
    try:
        with con.cursor() as cur:
            # RE-CHECK offline inside the txn -- abort if the player just came online (anti-race / live-clobber guard)
            cur.execute("SELECT COUNT(*) c FROM online WHERE playerid=%s", (pid,))
            if int(cur.fetchone()["c"]) > 0:
                con.rollback()
                return (False, "came_online", None)
            # RE-CHECK the cooldown under the lock (stop a double-spend from two fast commands). Donor channel skips it.
            if not skip_cd:
                cur.execute("SELECT (SELECT MAX(ts) FROM log WHERE tag=%s AND playerid=%s) AS last_lat, "
                            "(SELECT MAX(ts) FROM log WHERE tag=%s AND playerid=%s) AS last_man, "
                            "DATEDIFF(NOW(), (SELECT MAX(ts) FROM log WHERE tag=%s AND playerid=%s)) AS days_since",
                            (LAT_TAG, pid, MAN_TAG, pid, LAT_TAG, pid))
                cr = cur.fetchone()
                if cr["last_lat"] is not None and int(cr["days_since"] or 0) < COOLDOWN_DAYS \
                        and not (cr["last_man"] is not None and cr["last_man"] > cr["last_lat"]):
                    con.rollback()
                    return (False, "cooldown", {"days_left": max(COOLDOWN_DAYS - int(cr["days_since"] or 0), 0)})
            # lock + re-verify bank
            cur.execute("SELECT COALESCE(bankacc,0) b FROM players WHERE playerid=%s FOR UPDATE", (pid,))
            bank_now = int(cur.fetchone()["b"])
            if bank_now < debit:
                con.rollback()
                return (False, "broke", {"tax": total_tax, "fee": fee, "debit": debit, "bank": bank_now})
            # charge bank (tax + fee both vanish -- sink, nothing credited)
            cur.execute("UPDATE players SET bankacc = bankacc - %s WHERE playerid=%s", (debit, pid))
            # clear each paid house exactly like the in-game pay (tax_paid=NOW(), tax_playtime=0)
            for oid, _t, _d in priced:
                cur.execute("UPDATE houses SET tax_paid=NOW(), tax_playtime=0 WHERE oid=%s", (oid,))
            # audit row -- drives the 14-day cooldown + shows in CLANKR / the overcharge scanner
            ids = ", ".join(oid for oid, _t, _d in priced)
            msg = (f"Latoya processed ${total_tax:,} house tax + ${fee:,} processing fee "
                   f"(${debit:,} from bank) for {len(priced)} house(s), ids: {ids}")
            cur.execute("INSERT INTO log (tag, playerid, name, message) VALUES (%s,%s,%s,%s)",
                        (LAT_TAG, pid, name, msg))
        con.commit()
    except Exception as e:
        try:
            con.rollback()
        except Exception:
            pass
        print(f"[latoya] txn error pid={pid}: {e}", flush=True)
        return (False, "db_error", None)
    finally:
        con.close()
    return (True, "paid", {"tax": total_tax, "fee": fee, "debit": debit, "houses": len(priced), "unpriced": unpriced})

# ---------------------------------------------------------------- Discord
intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

INTRO = (
    "🗂️ **Internal Revenue Service — Altis Field Office.** Latoya speaking.\n\n"
    "I process house tax from this window so you don't have to drag yourself in-game to do it. Type **`!tax`** "
    "and I'll pull your file, total what you owe, add my processing fee, and take it out of your bank. That's it. "
    "I don't make the rules, I just collect.\n\n"
    "**The fine print:**\n"
    "• You must be **offline** — I don't process for people already standing on the floor. Use the phone.\n"
    "• I bill **every house you OWN** that's a day or more past due (not gang houses, not houses you just hold keys to).\n"
    "• **Processing fee: 0.15× the tax owed**, on top, straight from your bank. Convenience isn't free.\n"
    "• The money's **gone** — paid to the Realtor, same as in-game. I don't hand out receipts that matter.\n"
    f"• I do this **once every {COOLDOWN_DAYS} days** per person. Want me sooner? Log in and pay one **yourself** "
    "like a grown adult — that resets me.\n\n"
    "**`!tax`** — pay it. **`!tax check`** — see what you owe without paying.\n\n"
    "Have your account information ready. Next."
)

# donor "latoya-unlimited" channel -- no 14-day wait. Sassy thank-you for donating (owner 2026-06-21).
UNLIMITED_INTRO = (
    "💼 **IRS — Premium Window.** Well, well. Look who *donated to Project Loony Bin*.\n\n"
    "Don't let it go to your head, but you've earned yourself the VIP treatment at this window: I'll process your "
    "house tax **as many times as you need**, no two-week wait, no \"go log in and pay it yourself.\" You owe, you "
    "type **`!tax`**, I collect. Over and over. As often as your properties fall behind.\n\n"
    "**Still applies, baby — I'm not a charity (you are):**\n"
    "• You must be **offline** — I don't process for people on the floor.\n"
    "• **Real tax + my 0.15× processing fee**, straight from your bank. The fee doesn't get a discount just because you tip.\n"
    "• Same money still **vanishes** to the Realtor. Donating buys you my *time*, not your tax back.\n\n"
    "**`!tax`** to pay · **`!tax check`** to see the damage.\n\n"
    "And... mm. *Thank you* for the donation, sugar. Keeps the lights on in this miserable little office. Now don't "
    "make me say something nice twice. Next."
)

def _fmt_paid(p):
    extra = f" ({p['unpriced']} house(s) skipped — type not on file yet)" if p.get("unpriced") else ""
    return (f"Filed. **${p['tax']:,}** house tax + **${p['fee']:,}** processing fee — "
            f"**${p['debit']:,}** out of your bank, {p['houses']} house(s){extra}. Gone. "
            f"The Realtor thanks you for your contribution to nothing. Have a blessed day. Next.")

@client.event
async def on_ready():
    print(f"[latoya] online as {client.user} | channel={CHANNEL_ID}", flush=True)
    try:
        marker = HERE / "latoya.intro_posted"
        if not marker.exists() and CHANNEL_ID:
            ch = client.get_channel(CHANNEL_ID)
            if ch:
                await ch.send(INTRO)
                marker.touch()
                print("[latoya] posted intro", flush=True)
    except Exception as e:
        print(f"[latoya] intro post failed: {e}", flush=True)
    # donor "unlimited" channel intro -- separate marker so it posts once. Delete latoya.intro_posted_unlimited to re-post.
    try:
        if UNLIMITED_CHANNEL_ID:
            marker_u = HERE / "latoya.intro_posted_unlimited"
            if not marker_u.exists():
                chu = client.get_channel(UNLIMITED_CHANNEL_ID)
                if chu:
                    await chu.send(UNLIMITED_INTRO)
                    marker_u.touch()
                    print("[latoya] posted unlimited intro", flush=True)
                else:
                    print("[latoya] unlimited channel not found (bot lacks access?) -- intro not posted", flush=True)
    except Exception as e:
        print(f"[latoya] unlimited intro post failed: {e}", flush=True)
    # start the "about to lock" warn loop (donor channel pings to access-holders)
    if UNLIMITED_CHANNEL_ID:
        client.loop.create_task(warn_loop())
        print("[latoya] warn loop started", flush=True)

@client.event
async def on_message(message):
    if message.author.bot or message.channel.id not in CHANNELS:
        return
    low = message.content.strip().lower()
    if not (low.startswith("!tax") or low.startswith("!irs") or low.startswith("!latoya")):
        return
    check_only = ("check" in low.split()) or ("balance" in low.split())
    me = message.author.mention
    # donor channel (or a whitelisted user) waives the 14-day cooldown -- offline + funds + real tax still apply
    nocd = (message.channel.id == UNLIMITED_CHANNEL_ID) or (message.author.id in NOCOOLDOWN_IDS)

    pid = await asyncio.to_thread(link_pid, message.author.id)
    if not pid:
        await message.channel.send(f"{me} I don't have you in the system. Link your Discord to your game account, then come see me.")
        return
    if await asyncio.to_thread(is_online, pid):
        await message.channel.send(f"{me} You're logged in — I can see you on the floor. Walk to a phone and pay it yourself. I don't process for people who're already home.")
        return

    # --- check-only: price it without charging or touching the cooldown ---
    if check_only:
        houses = await asyncio.to_thread(payable_houses, pid)
        if not houses:
            await message.channel.send(f"{me} Pulled your file. You don't owe a dime. Don't waste my time. Next.")
            return
        cnt = await asyncio.to_thread(house_count, pid)
        total_tax, unpriced = 0, 0
        for h in houses:
            t = house_tax(h["days"], h["tax_playtime"], cnt, h["classname"])
            if t is None:
                unpriced += 1
            elif t > 0:
                total_tax += t
        if total_tax <= 0:
            await message.channel.send(f"{me} Nothing I can bill you for right now{' (some house types aren’t on file yet — check back after the next server restart)' if unpriced else ''}. Next.")
            return
        fee = _arma_round(total_tax * FEE_RATE)
        if nocd:
            gate = ""
        else:
            allowed, days_left = await asyncio.to_thread(cooldown_state, pid)
            gate = "" if allowed else f" But you've used me recently — I won't process again for **{days_left} day(s)** unless you log in and pay one yourself."
        extra = f" ({unpriced} house(s) not yet priced — type not on file)" if unpriced else ""
        await message.channel.send(
            f"{me} You owe **${total_tax:,}** in house tax across {len(houses)} house(s), plus my **${fee:,}** processing fee = **${total_tax+fee:,}** from your bank{extra}.{gate}\nType `!tax` to pay it.")
        return

    # --- pay path: cooldown gate (skipped in the donor channel), then the transactional collect (re-checks inside) ---
    if not nocd:
        allowed, days_left = await asyncio.to_thread(cooldown_state, pid)
        if not allowed:
            await message.channel.send(f"{me} Mm-mm. You came to my window already this cycle. I do this once every {COOLDOWN_DAYS} days unless you log in and pay one yourself like a grown adult. Come back in **{days_left} day(s)**.")
            return

    ok, kind, p = await asyncio.to_thread(collect_tax, pid, await asyncio.to_thread(player_name, pid), nocd)
    if ok:
        await message.channel.send(f"{me} {_fmt_paid(p)}")
        return
    # failure messages, in Latoya's voice
    if kind == "nothing_owed":
        await message.channel.send(f"{me} Pulled your file. You don't owe a dime. Don't waste my time. Next.")
    elif kind == "not_synced":
        await message.channel.send(f"{me} Your houses are on file but their assessments aren't in the system yet. Check back after the next server restart.")
    elif kind == "broke":
        await message.channel.send(f"{me} Your bill is **${p['debit']:,}** (${p['tax']:,} tax + ${p['fee']:,} fee). You've got **${p['bank']:,}** in the bank. The math doesn't math. Come back with the money.")
    elif kind == "cooldown":
        await message.channel.send(f"{me} Mm-mm. Already processed you this cycle. **{p['days_left']} day(s)**, or log in and pay one yourself.")
    elif kind == "came_online":
        await message.channel.send(f"{me} You logged in mid-transaction. I voided it — nothing charged. Get back off the floor and try again.")
    else:
        await message.channel.send(f"{me} The system's down. Nothing was charged. Come back later. *(sips coffee)*")

# ---------------------------------------------------------------- "house about to lock" warn loop (donor channel)
# owner 2026-06-21: in the donor/unlimited channel, ping everyone with ACCESS (owner + keyholders, if Discord-linked)
# a couple days before their house tax LOCKS (init.sqf: days > LOCK_OVERDUE_DAYS -> overdue -> storage access locks).
# Independent of tax pricing (classname) -- only needs days + access -- so it works before the deploy too. Deduped via
# a small JSON state: each house pings ONCE when it enters the pre-lock window; the mark clears when it drops out (paid).
# ("about to return to bank" is NOT wired -- no house-reclaim mechanism exists in the game yet; pending owner decision.)
LOCK_OVERDUE_DAYS = int(CFG.get("lock_overdue_days", 14))    # init.sqf threshold: days > this -> overdue (locked)
LOCK_WARN_LEAD    = int(CFG.get("lock_warn_lead_days", 2))   # start warning this many days before the lock
WARN_SCAN_SECS    = int(CFG.get("warn_scan_secs", 1800))     # how often to scan (tax days tick once/day -> 30min is plenty)
WARN_STATE = HERE / "latoya_warn_state.json"

def _load_warn():
    try:
        return json.load(open(WARN_STATE))
    except Exception:
        return {}

def _save_warn(d):
    try:
        json.dump(d, open(WARN_STATE, "w"))
    except Exception as e:
        print(f"[latoya] warn state save: {e}", flush=True)

def scan_warn_houses(warn_from):
    return DB.q("SELECT oid, owners, keyholders, DATEDIFF(NOW(), tax_paid) AS days FROM houses "
                "WHERE DATEDIFF(NOW(), tax_paid) >= %s", (warn_from,)) or []

async def warn_loop():
    await client.wait_until_ready()
    chu = client.get_channel(UNLIMITED_CHANNEL_ID)
    warn_from = max(LOCK_OVERDUE_DAYS - LOCK_WARN_LEAD + 1, 1)
    while not client.is_closed():
        try:
            rows = await asyncio.to_thread(scan_warn_houses, warn_from)
            state = _load_warn()
            current = set()
            changed = False
            for h in rows:
                oid = str(h["oid"]); days = int(h["days"] or 0)
                current.add(oid)
                if days < warn_from or days > LOCK_OVERDUE_DAYS:
                    continue   # already locked, or not yet in the 1-2-day pre-lock window
                if state.get(oid) == "lock":
                    continue   # already warned this house for this lock
                left = (LOCK_OVERDUE_DAYS + 1) - days
                links = await asyncio.to_thread(linked_discord_ids, access_uids(h["owners"], h.get("keyholders")))
                if links and chu:
                    mentions = " ".join(f"<@{d}>" for d in links.values())
                    try:
                        await chu.send(f"{mentions} 🔒 Latoya here. Your house tax is **{days} days** overdue — "
                                       f"storage **locks in {left} day(s)**. Pay it (`!tax`) or log in before it locks. "
                                       f"Don't say I didn't warn you.")
                    except Exception as e:
                        print(f"[latoya] warn send: {e}", flush=True)
                state[oid] = "lock"; changed = True
            for oid in [o for o in state if o not in current]:   # paid / reset -> allow a future re-warn
                del state[oid]; changed = True
            if changed:
                _save_warn(state)
        except Exception as e:
            print(f"[latoya] warn_loop error: {e}", flush=True)
        await asyncio.sleep(WARN_SCAN_SECS)

if __name__ == "__main__":
    if not CFG.get("token"):
        print("[latoya] no token in latoya.config.json -- set token + channel_id to go live.", flush=True)
    else:
        client.run(CFG["token"])
