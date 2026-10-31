#!/usr/bin/env python3
"""
CLANKR  --  LooneyBin Altis Life dupe / exploit detector.

Watches the MariaDB `log` table (the in-game APS_fnc_logIt audit sink + the max-verbosity
ScriptError mirror) and runs heuristic rules over new rows. On a hit it drops a Discord alert
into loonybot/outbox/*.json, so LoonyBot posts it to the admin channel and pings the owners with
the offending log snippet.

  * Standalone process. Run it alongside loonybot (shares config.json + the venv -> pymysql).
  * Cursor (last processed log id) persisted in clankr_state.json -> survives restarts, no re-spam.
  * All thresholds live in config.json -> "clankr": { ... } (see DEFAULTS below). Tune freely.

Detection (v2 2026-06-12, keyed on tags REAL data carries; v1 rules kept):
  HIGH  anti-cheat / exploit tags (gear exploit, hack info, spyglass, mem-hack, tamper codes)
  HIGH  large player->player money WIRE (995)        + WIRE STRUCTURING (many sub-threshold wires)
  HIGH  money velocity (one player churning huge $ fast across money tags)
  HIGH  combat-log     (-DOWNED-/-KILLED- victim or -ADDCHARGE- then -DISCONNECT- fast)
  HIGH  disconnect-dupe window (item move/store then -DISCONNECT- within seconds = save-lag dupe)
  HIGH  vehicle-pull burst (-VEHICLEPULL- spam = garage/trunk dupe probing)
  HIGH  remote-exec watchdog burst (-WAC-)
  MED   sell velocity (-ITEMSOLD- $ fast), buy-sell churn, purchase velocity (post-dupe spending)
  MED   gather-rate macro (-GATHER- faster than human), item-shuffle burst, script-error burst
  MED   large/repeat cash on death, receive fan-in (many distinct senders -> one player = mule)
  LOW   relog cycling (-CONNECT- xN), multiple Steam accounts (-MULTIPLESTEAMS-)

Verbosity: "verbose": true -> log EVERY processed row to stdout. HIGH alerts attach the player's
last 8 log rows for instant context. "digest_mins": N>0 -> periodic activity digest to the channel.
Add rules in inspect(); add tags to the config sets. Nothing here mutates the game or the DB.
"""
import os, sys, json, time, re, subprocess
from collections import deque, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import admin  # reuse loonybot's pymysql DB wrapper
import bm     # BattleMetrics REST client (stdlib urllib) -- ban mirror

CFG = json.load(open(os.path.join(HERE, "config.json")))
DB = admin.DB(CFG["db"])
OUTBOX = os.path.join(HERE, "outbox")
STATE_FILE = os.path.join(HERE, "clankr_state.json")

CHANNEL = int(CFG.get("clankr_channel_id") or CFG.get("admin_channel_id") or CFG.get("status_channel_id") or 0)
# owner 2026-06-20: economy digest channel -- defaults to the clankr channel; set econ_channel_id in config.json to split it out.
ECON_CHANNEL = int(CFG.get("econ_channel_id") or CHANNEL)
# owner 2026-07-05: admin-action audit log channel (website admin tools -> web_admin_log). Defaults to the
# econ channel. Posted as a QUIET, no-ping, non-notification message (never @'s anyone).
ADMIN_LOG_CHANNEL = int(CFG.get("admin_log_channel_id") or ECON_CHANNEL or CHANNEL)
OWNER_IDS = [int(x) for x in (CFG.get("owner_ids") or [])]
# owner 2026-06-22: CLANKR pings ONLY clankr_ping_ids (default = owner only) -- separate from owner_ids (perms).
PING_IDS = [int(x) for x in (CFG.get("clankr_ping_ids") or OWNER_IDS)]
PING = " ".join(f"<@{u}>" for u in PING_IDS)

# ------------------------------------------------------------------ tunables
_C = CFG.get("clankr", {})
POLL_SECS      = int(_C.get("poll_secs", 20))
ECON_MINS      = int(_C.get("econ_digest_mins", 15))     # owner 2026-06-20: economy digest cadence in minutes (0 = off)
BACKFILL       = bool(_C.get("backfill", False))   # True = scan the whole existing log on first run
WIRE_BIG       = int(_C.get("wire_big", 250_000))      # single transfer that trips MED
WIRE_CRIT      = int(_C.get("wire_crit", 900_000))     # single transfer that trips HIGH + ping
DROP_BIG       = int(_C.get("drop_big", 300_000))      # cash carried on death
VEL_SUM        = int(_C.get("velocity_sum", 3_000_000))  # $ summed across money tags within...
VEL_SECS       = int(_C.get("velocity_secs", 120))       # ...this window
# owner 2026-07-05 (Casino blackjack): CASINO NET-GAIN watch. Blackjack is HOUSE-FAVORED (BJ pays 3:2, dealer
# stands on 17), so a legit player's summed net trends NEGATIVE over time. A large SUSTAINED net POSITIVE beyond
# CASINO_GAIN across the window is house-edge-impossible (client skipped the local bet debit / forged a win) ->
# REVIEW-ONLY alert (never auto-ban), same shape as the money-velocity rule. net is server-logged + signed (first
# $ figure in each -CASINOBJ- row), negative for losses/abandons, so the running sum self-corrects.
CASINO_GAIN    = int(_C.get("casino_net_gain", 3_000_000))  # sustained casino net POSITIVE beyond this...
CASINO_SECS    = int(_C.get("casino_net_secs", 3600))       # ...over this rolling window = house-edge-impossible
# owner 2026-07-07: every casino game logs one SIGNED net result row per resolved game -- blackjack -CASINOBJ-,
# and the five simple games (fn_casinoSRV): Coin Flip -CASINOCF-, Wheel -CASINOWH-, Slots -CASINOSL-, Roulette
# -CASINORL-, Hi-Lo -CASINOHL-. ALL are house-favored (aggressive edge), so a legit player trends NEGATIVE across
# them. -CASINOVEH- (owner 2026-07-08) carries the ASSESSED cash value of a wheel VEHICLE jackpot as a POSITIVE net
# so the mass-balance actually sees the faucet (the -CASINOWH- row only holds the cash side = -cost, which made a
# vehicle farmer read as a LOSER). The wager row -CASINOBET- and the self-exclusion row -CASINOBAN- are NOT results.
CASINO_RESULT_TAGS = ("-CASINOBJ-", "-CASINOCF-", "-CASINOWH-", "-CASINOSL-", "-CASINORL-", "-CASINOHL-", "-CASINOVEH-")
# owner 2026-07-08: the real-time net-gain WATCH must NOT include -CASINOVEH-. The wheel is a DESIGNED faucet -- a
# legit daily Blackfish jackpot books one +$5,000,000 row, which alone blows past CASINO_GAIN ($3M) and would page
# owners accusing a legit winner of forging (false positive). The resulting alarm fatigue would mask a REAL forge.
# The watch stays on the cash games that are genuinely house-favored per play; vehicle jackpots are capped server-
# side (3/uid/day) and still counted in the econ digest below via CASINO_RESULT_TAGS.
CASINO_WATCH_TAGS = tuple(t for t in CASINO_RESULT_TAGS if t != "-CASINOVEH-")
EGREGIOUS_MONEY = int(_C.get("egregious_money", 20_000_000))  # owner 2026-06-22: a SINGLE money event this big = unambiguous dupe -> standalone AUTO-ACT (no combo)
# owner 2026-06-23 (Nigbert APS_fnc_bankRobbery x168): SINGLE-FIRE remote-spam PERM auto-ban. Some server fns are
# fired by a ONE-CLICK action that hides itself after a single use (APS_fnc_bankRobbery <- the "Begin Drilling
# Vault" action, gated on AP_bank_robbed + hideOnUse + a 20-min cooldown), so a legit client calls them AT MOST
# ONCE. A client calling a WATCHED fn >= FNCALL_SPAM_N times in FNCALL_SPAM_SECS = a cheat menu remoteExec-spamming
# it = IMPOSSIBLE from a real client -> rock-solid standalone PERM ban. Add fns (lowercase substrings) as found.
FNCALL_SPAM_WATCH  = {x.lower() for x in (_C.get("fncall_spam_watch") or ["APS_fnc_bankRobbery"])}
FNCALL_SPAM_N      = int(_C.get("fncall_spam_n", 4))        # calls to a watched fn within...
FNCALL_SPAM_SECS   = int(_C.get("fncall_spam_secs", 120))   # ...this window = remoteExec spam -> ban
EXPLOIT_BAN_REASON = str(_C.get("fncall_spam_reason", "perm - lets talk - CLANKR"))
# critical-alert ping (exploit auto-bans) = owner + admins. A raw mention string (clankr_critical_ping, e.g. an
# admin ROLE) wins; else clankr_critical_ping_ids; else default to OWNER_IDS (= the owner + the 2 admins). This is
# SEPARATE from the narrowed clankr_ping_ids (owner-only) used for normal alerts -- owner wants @owner+@admins here.
CRITICAL_PING = (str(CFG.get("clankr_critical_ping", "")).strip()
                 or " ".join(f"<@{u}>" for u in ([int(x) for x in (CFG.get("clankr_critical_ping_ids") or [])] or OWNER_IDS)))
# owner 2026-06-23: OBSERVE / NO-BAN list. Pids here are still fully processed + FLAGGED (data keeps flowing to the
# log + channel) but are NEVER auto-banned -- keep a KNOWN cheater live and mine their behaviour for new exploit
# signatures (seed: Nigbert, the bankRobbery-spam case). For these pids the DISCOVERY rule flags ANY non-routine fn
# they remoteExec at an abnormal burst rate -> surfaces candidates to add to fncall_spam_watch. Everyone NOT on the
# list still auto-bans normally.
NOBAN          = {str(x) for x in (_C.get("noban") or [])}
DISCOVERY_N    = int(_C.get("discovery_n", 10))      # a non-routine fn called this many times within...
DISCOVERY_SECS = int(_C.get("discovery_secs", 60))   # ...this window (observe-listed pids only) = candidate exploit
DISCOVERY_SKIP = tuple(x.lower() for x in (_C.get("discovery_skip") or ["db_fnc_", "stattableupdate", "updateremotestat"]))
ITEM_BURST_N   = int(_C.get("item_burst_n", 14))         # item-move events within...
ITEM_BURST_SEC = int(_C.get("item_burst_secs", 30))      # ...this window (now only TRIGGERS a mass-balance)
BAL_RECHECK_SEC= int(_C.get("balance_recheck_secs", 600))# min seconds between (DB-heavy) mass-balance checks/pid
BAL_MARGIN     = float(_C.get("balance_margin", 1.25))   # disposed must exceed acquired*MARGIN + SLACK to flag
BAL_SLACK      = int(_C.get("balance_slack", 150))       # absolute slack for log gaps / unmapped sub-flows
ERR_BURST_N    = int(_C.get("err_burst_n", 8))           # script errors within...
ERR_BURST_SEC  = int(_C.get("err_burst_secs", 60))       # ...this window
# owner 2026-06-19 (ftdyn scripter case): code-INJECTION signature. Shipped SQF is pre-compiled in the PBO, so a
# PARSE error ("Missing }") in mission code is impossible from the real client -> it's running RE-DEFINED (cheat)
# functions. Escalate hard when a core money/exec fn is named. (fn_playSound is a GLOBAL runtime bug, not a parse
# error -> won't match.) ftdyn's errors were spread out (17:15 + 18:16) so the burst rule missed them.
INJECT_PARSE_ERR = tuple(x.lower() for x in _C.get("inject_parse_errs", ["missing }", "missing )", "missing ;", "missing ]"]))
INJECT_CORE_FNS  = tuple(x.lower() for x in _C.get("inject_core_fns", ["debitcard", "AP_fnc_MP", "fn_mp", "handleinv", "receivemoney", "addmoney", "buyitem", "wiretransfer"]))
# owner 2026-06-25 (player085 -- injected RCE console / cheat menu): substrings found in the CODE of an in-game exec-menu
# when its client SCRIPTERR is logged. Script-BUILT Rsc* controls (a text input + a RUN button) are the giveaway --
# the real mission opens UI via createDialog + config-defined controls, it never ctrlCreates these inside a script
# that errors. Match these (or the findDisplay-12 / call-compile combos in the rule) -> definitive scripting.
INJECT_EXEC_MENU = tuple(x.lower() for x in _C.get("inject_exec_menu", [
    "ctrlcreate[rscbutton", "ctrlcreate [rscbutton", "ctrlcreate[rscedit", "ctrlcreate [rscedit",
    "ctrlcreate[rsclistbox", "ctrlcreate [rsclistbox", "ctrlcreate[rscactivetext", "ctrlcreate [rscactivetext",
]))
EXECMENU_AUTOBAN = bool(_C.get("execmenu_autoban", True))   # exec-menu is unambiguous -> single-hit auto-ban (False = alert only)
# owner 2026-06-19: MULTI-SIGNAL combo AUTO-BAN. Each cheat signal alone can false-positive (inject=corrupt cache,
# script-kill=roadkill); TWO independent ones in a session can't. auto_ban=false -> alert only (dry run).
AUTO_BAN            = bool(_C.get("auto_ban", True))
COMBO_N             = int(_C.get("combo_signals", 2))           # distinct cheat signals to auto-ban
COMBO_WINDOW        = int(_C.get("combo_window_secs", 3600))    # ...within this window (1 session)
SCRIPTKILL_MIN_DIST = int(_C.get("scriptkill_min_dist", 12))    # no-weapon kill must be >this (excludes roadkills)
BAN_REASON          = str(_C.get("auto_ban_reason", "CLANKR: SCRIPTING PERM"))  # what the player sees on the ban
# owner 2026-06-22: BATTLEMETRICS BAN MIRROR. CLANKR pushes every NEW `bans` row (its own auto-bans + manual /
# in-game / bot bans) to a BattleMetrics org via REST -> dashboard record + BE-RCON live enforce + cross-server.
# Local bans-table + hardkick path is UNCHANGED and PRIMARY; BM is additive + NON-blocking (a BM outage never
# blocks a local ban). Token: secrets.json > env BM_TOKEN > config token (all gitignored). Org + ban-list ids
# auto-discovered from the token on first run and cached in clankr_state.json.
_BM = _C.get("battlemetrics", {})
try:
    _SECRETS = json.load(open(os.path.join(HERE, "secrets.json")))
except Exception:
    _SECRETS = {}
BM_TOKEN   = (_SECRETS.get("battlemetrics_token") or os.environ.get("BM_TOKEN") or str(_BM.get("token", ""))).strip()
BM_ENABLED = bool(_BM.get("enabled", False)) and bool(BM_TOKEN)   # inert until a token is present
BM_ORG     = str(_BM.get("org_id", "") or "")
BM_BANLIST = str(_BM.get("banlist_id", "") or "")
BM_NATIVE  = _BM.get("native", None)            # None = ban-list default; True/False forces native BE ban push
# gang-bank withdraw watch (the 2026-06-13 dupe class CLANKR missed: re-withdrawing a restored gang fund).
GW_SUM         = int(_C.get("gang_withdraw_sum", 2_000_000))  # $ withdrawn from gang bank by one player within...
GW_SECS        = int(_C.get("gang_withdraw_secs", 180))       # ...this window
GW_N           = int(_C.get("gang_withdraw_n", 5))            # OR this many gang withdrawals in the window
COOLDOWN_SECS  = int(_C.get("cooldown_secs", 300))       # per (player, rule) dedupe
NOTIFY_ONLY    = bool(_C.get("notify_only", True))       # BETA: post the alert to the channel but DON'T @ping owners
# UIDs CLANKR never flags. owner 2026-06-15: the owner UID is NO LONGER hardcoded-whitelisted -- owner wants to
# be FLAGGABLE to TEST the -SHEDSNOOP- exploit catch on themselves. Re-whitelist later by adding the UID to
# clankr.whitelist in config.json. Extra trusted UIDs still go there too.
WHITELIST      = {str(x) for x in (_C.get("whitelist") or [])}
# admins: legitimately open any shed + can admin-spawn items -> exempt from house-access + mass-balance
# (owner said treat admin-spawned as innocent for now). NOT whitelisted globally (still flagged for AC/money).
STATIC_ADMINS  = {str(x) for x in (_C.get("admins") or
                  ["76561190000000008", "76561190000000001", "76561190000000035"])}  # config/default fallback (player101, owner, Chase)
# owner 2026-06-24: ADMINS is REBUILT each cycle as STATIC_ADMINS | (players_global.adminlevel>0) via
# refresh_db_admins(). The static list had drifted from reality (player097, player107 Fire, Payton, ... were missing), so a
# REAL admin force-opening an unowned shed -- the shed-exploit signature -- would have been auto-permabanned ("clankr
# not ban admins for the shed exploit lol"). DB adminlevel is authoritative + auto-tracks promotions/demotions.
ADMINS         = set(STATIC_ADMINS)
HEARTBEAT_HRS  = float(_C.get("heartbeat_hours", 12))     # proof-of-life ping (CLANKR is a hard boot prereq)
VERBOSE        = bool(_C.get("verbose", True))            # v2: print every processed row to stdout
DIGEST_MINS    = int(_C.get("digest_mins", 60))           # v2: periodic channel digest (0 = off)
CLOG_SECS      = int(_C.get("combatlog_secs", 60))        # death/charge -> disconnect within = combat log
DCDUPE_SECS    = int(_C.get("dcdupe_secs", 45))           # item move -> disconnect within = dupe window (owner 2026-06-17: 20->45; ebola alt+F4'd 37s after a store, past the old window. The open-at-DC rule 9b is the real fix; this just widens the generic net.)
PULL_BURST_N   = int(_C.get("pull_burst_n", 3))           # vehicle pulls within...
PULL_BURST_SEC = int(_C.get("pull_burst_secs", 120))      # ...this window
PULL_CYCLE_N   = int(_C.get("pull_cycle_n", 3))           # pulls of the SAME plate within...
PULL_CYCLE_SEC = int(_C.get("pull_cycle_secs", 300))      # ...this window = store<->repull trunk-dupe loop
HOUSECYCLE_N   = int(_C.get("house_cycle_n", 4))          # opens of the SAME house within...
HOUSECYCLE_SECS= int(_C.get("house_cycle_secs", 90))      # ...this window = live open<->take house-storage dupe
# owner 2026-06-23: UNAUTHORIZED-HOUSE-ACCESS auto-ban (the "free house keys" / AP_vinv-read exploit publicly
# bragged). The -HOUSEINV- access rule below already excludes owner / keyholder / admin / gangmate / point-in-time
# key, so a hit means the actor bypassed the LIVE client-side open-guard (impossible from a real client). Ban
# gating is FP-safe: a SINGLE un-correlated open only ALERTS (spares the rare since-removed keyholder with no
# -HOUSEKEY- audit row); a perm-ban needs the UNOWNED shed (definite), a CONFIRMED tent, or >=N DISTINCT houses.
HOUSE_UNAUTH_BAN      = bool(_C.get("house_unauth_ban", True))    # master toggle for this auto-ban
HOUSE_UNAUTH_BAN_N    = int(_C.get("house_unauth_ban_n", 2))      # distinct unauthorized houses within...
HOUSE_UNAUTH_BAN_SECS = int(_C.get("house_unauth_ban_secs", 900)) # ...this window = a looting spree -> ban
HOUSE_UNAUTH_BAN_REASON = str(_C.get("house_unauth_ban_reason", "perm - house exploit - lets talk - CLANKR"))
WAC_BURST_N    = int(_C.get("wac_burst_n", 5))            # -WAC- hits within...
WAC_BURST_SEC  = int(_C.get("wac_burst_secs", 120))       # ...this window
SELL_SUM       = int(_C.get("sell_sum", 1_500_000))       # -ITEMSOLD- $ within sell window
SELL_SECS      = int(_C.get("sell_secs", 180))
CHURN_N        = int(_C.get("churn_n", 10))               # buy+sell events within...
CHURN_SECS     = int(_C.get("churn_secs", 90))            # ...this window
GATHER_N       = int(_C.get("gather_n", 20))              # gathers within...
GATHER_SECS    = int(_C.get("gather_secs", 60))           # ...this window (macro speed)
BUY_SUM        = int(_C.get("buy_sum", 2_000_000))        # purchases $ within buy window
BUY_SECS       = int(_C.get("buy_secs", 180))
STRUCT_N       = int(_C.get("struct_n", 4))               # sub-threshold wires within...
STRUCT_SECS    = int(_C.get("struct_secs", 600))          # ...this window summing >= WIRE_BIG
FANIN_N        = int(_C.get("fanin_n", 5))                # distinct senders within...
FANIN_SECS     = int(_C.get("fanin_secs", 300))           # ...this window
RELOG_N        = int(_C.get("relog_n", 3))                # connects within...
RELOG_SECS     = int(_C.get("relog_secs", 600))           # ...this window
DEATHCASH_N    = int(_C.get("deathcash_n", 2))            # -MONEYWARNING- repeats within...
DEATHCASH_SECS = int(_C.get("deathcash_secs", 1800))      # ...this window

# tags that are an instant red flag (in-game anti-cheat / exploit detectors)
AC_TAGS = set(_C.get("ac_tags", [
    "-GEAREXPLOIT-", "-HACKINFO-", "-SpyG-", "-MEMHACK-", "-MEMHACKCASH-",
    "-DUPE-", "-SCRIPTINJECT-", "-ILLEGALSPAWN-", "913", "914",
]))
MONEY_TAGS = set(_C.get("money_tags", [
    "995", "-WITHDRAW-", "-DEPOSIT-", "-BANKRECEIVE-", "-CASHPICKUP2-", "-CASHDROPPED-",
]))
ITEM_TAGS = set(_C.get("item_tags", [
    "-ITEMDROPPED-", "-ITEMPICKUP-", "-TOOKITEM-", "-STOREDITEM-", "-CASHDROPPED-",
    "-CASHPICKUP2-", "-VEHINV-", "-HOUSEINV-",
]))

# owner 2026-06-18: STIMMY CHECKS support. When the owner turns Stimmy ON (admin menu -> server_control.stimmy=1),
# cartel-owning gang banks are credited 10x (money conjured from nothing, BY DESIGN, to re-float a low pop). The
# resulting cash churn legitimately trips the CASH-FLOW rules below -> we mute THOSE to stdout-only (no Discord
# ping) while stimmy is on, so the owner isn't spammed. The item-dupe / exploit / anti-cheat rules stay fully
# active (stimmy conjures BANK CASH, never items, so a real dupe still surfaces).
STIMMY_CHECK_SECS = int(_C.get("stimmy_check_secs", 30))   # refresh the server_control.stimmy flag at most this often
STIMMY_MUTED = set(_C.get("stimmy_muted_rules", [
    "Money velocity", "Large cash on death", "Gang-bank withdraw burst", "Sell velocity",
    "Purchase velocity", "Wire structuring", "Receive fan-in (mule)", "Repeat cash-on-death",
]))

# ------------------------------------------------------------------ helpers
def load_state():
    try:
        return json.load(open(STATE_FILE))
    except Exception:
        return {}

def save_state(s):
    tmp = STATE_FILE + ".tmp"
    json.dump(s, open(tmp, "w"))
    os.replace(tmp, STATE_FILE)

def money(s):
    m = re.search(r"\$([0-9][0-9,]*)", s or "")
    return int(m.group(1).replace(",", "")) if m else 0

def casino_net(s):
    """SIGNED net-dollar figure -- the FIRST $ number in a -CASINOBJ- row ("net $<net> (wagered ...)"), which is
    NEGATIVE for a losing / abandoned game. money() only matches positive $ (the '-' breaks its regex) so it can't
    be reused for a value that must be able to go negative."""
    m = re.search(r"\$(-?[0-9][0-9,]*)", s or "")
    return int(m.group(1).replace(",", "")) if m else 0

ICON = {"HIGH": "\U0001F534", "MED": "\U0001F7E0", "LOW": "\U0001F7E1"}

def recent_rows(pid, n=8):
    """last n log rows for a pid -- attached to HIGH alerts for instant context."""
    try:
        rows = DB.q("SELECT ts, tag, message FROM log WHERE playerid=%s ORDER BY id DESC LIMIT %s",
                    (pid, int(n)))
        return "\n".join(f"[{r['ts']}] {r['tag']} {(r['message'] or '')[:120]}" for r in reversed(rows or []))
    except Exception as e:
        return f"(history fetch failed: {e})"

_flags_total = defaultdict(int)             # severity -> count since boot (for heartbeat)
_flags_rules = defaultdict(int)             # rule -> count since boot

_stimmy_cache = {"on": False, "ts": 0.0}
def stimmy_active():
    """True if the owner has STIMMY CHECKS on (server_control.stimmy=1). Cached for STIMMY_CHECK_SECS to keep
    this off the hot path (called from emit on every flag)."""
    now = time.time()
    if now - _stimmy_cache["ts"] >= STIMMY_CHECK_SECS:
        _stimmy_cache["ts"] = now
        try:
            row = DB.q("SELECT stimmy FROM server_control WHERE id=1", (), "one")
            _stimmy_cache["on"] = bool(row and row.get("stimmy"))
        except Exception as e:
            print(f"[clankr] stimmy check err: {e}", flush=True)
    return _stimmy_cache["on"]

def emit(severity, rule, name, pid, detail, ts, snippet):
    """drop a Discord alert for LoonyBot's outbox watcher to post."""
    _flags_total[severity] += 1
    _flags_rules[rule] += 1
    # owner 2026-06-18: while STIMMY CHECKS is ON, mute the cash-flow rules (conjured gang-bank cash by design) to
    # stdout only -- no Discord ping. Dupe/exploit/anti-cheat rules are unaffected.
    if rule in STIMMY_MUTED and stimmy_active():
        print(f"[clankr] MUTED (stimmy on) {severity} {rule} | {name} ({pid})", flush=True)
        return
    if CHANNEL == 0:
        print(f"[clankr] no channel configured -- would alert: {rule} {name} {pid}", flush=True)
        return
    os.makedirs(OUTBOX, exist_ok=True)
    head = f"{ICON.get(severity,'⚪')} **CLANKR {severity}** — {rule}"
    body = (f"{head}\n**Player:** {name} `({pid})`\n{detail}\n"
            f"```\n[{ts}] {snippet[:900]}\n```")
    if severity == "HIGH":
        body += f"**Recent activity:**\n```\n{recent_rows(pid)[:900]}\n```"
    if severity == "HIGH" and PING and (not NOTIFY_ONLY or rule.startswith("AUTO-BAN") or rule.startswith("MOD-ALERT")):
        body += f"\n{PING}"
    job = {"channel_id": CHANNEL, "content": body}
    fn = os.path.join(OUTBOX, f"clankr_{int(time.time()*1000)}_{abs(hash((rule, pid))) % 100000}.json")
    tmp = fn + ".tmp"
    json.dump(job, open(tmp, "w"))
    os.replace(tmp, fn)
    print(f"[clankr] ALERT {severity} {rule} | {name} ({pid})", flush=True)



# ---------------------------------------------------------------------------------------------
# LT+ FACTION PLAYTIME -- daily DM to the owner (owner 2026-07-09).
# Every day (first poll at/after LT_REPORT_HOUR local; box TZ = America/Chicago) DM the faction-
# split playtime of everyone holding Lieutenant+ in MaxSec (coplevel >= 5: Lt/Captain/Chief) or
# Trauma Team (mediclevel >= 5: Lt/Commander/Marshal), faction heads included. Split comes
# from players_global.stats (17-slot A_stats): [11]=civ min, [14]=cop min, [15]=TT min. The state
# file keeps yesterday's snapshot so each report shows the last-24h delta per side plus the
# lifetime split; the first ever report is the baseline (lifetime only).
LT_REPORT_HOUR = int(CFG.get("lt_report_hour", 9))
LT_REPORT_DM   = [int(x) for x in (CFG.get("lt_report_dm_ids") or PING_IDS[:1])]
# owner 2026-07-10: weekly own-faction hours requirement -- rows under this in the 7D column get a "!" flag
# (config lt_min_weekly_hours, default 5.0). Set 0 to disable the flag. Threshold is on the 7D (weekly) hours.
LT_MIN_WEEK_H  = float(CFG.get("lt_min_weekly_hours", 5))
COP_RANK_NAMES = {5: "Lieutenant", 6: "Captain", 7: "Chief"}
TT_RANK_NAMES  = {5: "Lieutenant", 6: "Commander", 7: "Marshal"}

def _lt_playtime_rows():
    rows = DB.q(
        "SELECT g.playerid pid, CAST(g.coplevel AS SIGNED) cop, CAST(g.mediclevel AS SIGNED) med, "
        "g.stats stats, COALESCE(p.name,'?') name "
        "FROM players_global g LEFT JOIN players p ON p.playerid = g.playerid "
        "WHERE CAST(g.coplevel AS SIGNED) >= 5 OR CAST(g.mediclevel AS SIGNED) >= 5") or []
    out = []
    for r in rows:
        raw = (r.get("stats") or "").strip().strip('"')
        try:
            arr = json.loads(raw)
        except Exception:
            arr = []
        if not isinstance(arr, list):
            arr = []
        arr = arr + [0] * (17 - len(arr))
        out.append({"pid": str(r["pid"]), "name": r["name"], "cop": int(r["cop"] or 0),
                    "med": int(r["med"] or 0),
                    "mins": [int(arr[11] or 0), int(arr[14] or 0), int(arr[15] or 0)]})   # civ / cop / TT
    return out

def _lt_h(m):
    return f"{m / 60:.1f}h"

def _lt_dm(uid, content):
    os.makedirs(OUTBOX, exist_ok=True)
    fn = os.path.join(OUTBOX, f"ltreport_{uid}_{int(time.time()*1000)}.json")
    tmp = fn + ".tmp"
    json.dump({"user_id": int(uid), "content": content}, open(tmp, "w"))
    os.replace(tmp, fn)

def emit_lt_playtime_report(st):
    # owner 2026-07-10: v2 -- ONE compact monospace table per day (v1 chunked into 3 DMs) and a rolling
    # 7-day column: state keeps up to 9 daily snapshots (lt_pt_hist); weekly = now - the snapshot >= 7
    # days old (or the oldest available, column shows the real span until a full week of history exists).
    # Each person is measured in THEIR OWN faction: MaxSec rows count cop minutes, TT rows count TT minutes.
    rows = _lt_playtime_rows()
    hist = st.get("lt_pt_hist") or []
    if not hist and st.get("lt_pt_snap"):   # migrate the v1 single snapshot
        hist = [{"date": st.get("lt_pt_date") or time.strftime("%Y-%m-%d"), "snap": st["lt_pt_snap"]}]
    today = time.strftime("%Y-%m-%d")
    day_snap  = (hist[-1]["snap"] if hist else {})
    week_ref  = None
    week_days = 0
    week_is_prior = False   # True only when the 7D reference is a PRIOR-DAY snapshot (real tracked window)
    now_t = time.time()
    for h in hist:   # oldest-first; pick the OLDEST entry within/at the 7-day mark
        try:
            age = (now_t - time.mktime(time.strptime(h["date"], "%Y-%m-%d"))) / 86400.0
        except Exception:
            continue
        if week_ref is None or age >= 7:
            week_ref, week_days = h["snap"], min(7, round(age))
            week_is_prior = (h.get("date") != today)
        if age < 7:
            break
    week_ref = week_ref or {}
    def fh(m):
        return f"{m/60:.1f}"
    def table(entries, fac_idx, ranknames):
        # "!" flags a member whose WEEKLY (7D) own-faction hours are under LT_MIN_WEEK_H (0 = flag off).
        out = [f"{'':<2}{'NAME':<16}{'RANK':<11}{'24H':>6}{'7D':>7}{'LIFE':>7}"]
        low = 0
        for r in entries:
            mins = r["mins"][fac_idx]
            d1 = mins - int((day_snap.get(r["pid"]) or [0,0,0])[fac_idx] or 0) if day_snap.get(r["pid"]) else 0
            d7 = mins - int((week_ref.get(r["pid"]) or [0,0,0])[fac_idx] or 0) if week_ref.get(r["pid"]) else mins
            lvl = r["cop"] if fac_idx == 1 else r["med"]
            flag = LT_MIN_WEEK_H > 0 and week_is_prior and (max(0, d7) / 60.0) < LT_MIN_WEEK_H
            if flag:
                low += 1
            mark = "! " if flag else "  "
            out.append(f"{mark}{r['name'][:15]:<16}{ranknames.get(lvl, str(lvl))[:10]:<11}{fh(max(0,d1)):>6}{fh(max(0,d7)):>7}{fh(mins):>7}")
        return "\n".join(out), low
    maxsec = sorted([x for x in rows if x["cop"] >= 5], key=lambda x: (-x["cop"], x["name"].lower()))
    tt  = sorted([x for x in rows if x["med"] >= 5], key=lambda x: (-x["med"], x["name"].lower()))
    span = "baseline" if not week_is_prior else (f"{week_days}d" if week_days < 7 else "7d")
    maxsec_tbl, maxsec_low = table(maxsec, 1, COP_RANK_NAMES)
    tt_tbl,  tt_low  = table(tt, 2, TT_RANK_NAMES)
    legend = ""
    if LT_MIN_WEEK_H > 0:
        if not week_is_prior:
            legend = f"\n`! = under {LT_MIN_WEEK_H:g}h/week` on faction — flags begin tomorrow (7D history builds over the week)"
        else:
            note = f"  (7D span so far: {week_days}d)" if week_days < 7 else ""
            legend = f"\n`! = under {LT_MIN_WEEK_H:g}h this week` — MaxSec {maxsec_low}/{len(maxsec)} below, TT {tt_low}/{len(tt)} below{note}"
    msg = (f"**LT+ FACTION PLAYTIME** {today} (hours in own faction; weekly col = {span})\n"
           + "```\nMaxSec Lt+\n" + maxsec_tbl
           + "\n\nTRAUMA TEAM Lt+\n" + tt_tbl + "\n```" + legend)
    # safety chunker (the table fits ONE message for ~40 staff); fence-balance any split
    parts, rest = [], msg
    while len(rest) > 1900:
        nl = rest[:1900].rfind("\n")
        nl = nl if nl > 800 else 1900
        parts.append(rest[:nl])
        rest = rest[nl:].lstrip("\n")
    parts.append(rest)
    for i in range(len(parts)):
        if parts[i].count("```") % 2 == 1:
            parts[i] += "\n```"
            if i + 1 < len(parts):
                parts[i + 1] = "```\n" + parts[i + 1]
    for uid in LT_REPORT_DM:
        for c in parts:
            _lt_dm(uid, c)
    hist = [h for h in hist if h.get("date") != today]
    hist.append({"date": today, "snap": {r["pid"]: r["mins"] for r in rows}})
    st["lt_pt_hist"] = hist[-9:]
    st.pop("lt_pt_snap", None)
    st["lt_pt_date"] = today
    save_state(st)
    print(f"[clankr] LT+ playtime report: {len(maxsec)} MaxSec / {len(tt)} TT -> DM {LT_REPORT_DM} (weekly span {span})", flush=True)

def post_outbox(channel, content, silent=False, no_ping=True):
    """Drop a plain Discord message for LoonyBot's outbox watcher. no_ping (default) => never
    mentions/pings anyone; silent => posted with SUPPRESS_NOTIFICATIONS (no push notification)."""
    if not channel:
        return
    os.makedirs(OUTBOX, exist_ok=True)
    job = {"channel_id": int(channel), "content": str(content)[:1900],
           "no_ping": bool(no_ping), "silent": bool(silent)}
    fn = os.path.join(OUTBOX, f"clankr_alog_{int(time.time()*1000)}.json")
    tmp = fn + ".tmp"
    json.dump(job, open(tmp, "w"))
    os.replace(tmp, fn)

# owner 2026-07-05: mirror website admin actions (web_admin_log) to Discord as a QUIET, no-ping audit log.
# Only 'house_place' for now (the Admin+ place-item-in-house tool): "<admin> — Placed in house ... : <amounts>".
# Cursor 'last_web_id' advances past EVERY web_admin_log row (not just house_place) so the scan stays cheap.
def poll_admin_logs(st):
    last = int(st.get("last_web_id", 0))
    rows = DB.q("SELECT id, actor_name, target_id, action, detail FROM web_admin_log WHERE id > %s "
                "ORDER BY id ASC LIMIT 500", (last,))
    maxid = last
    for r in rows or []:
        maxid = max(maxid, int(r["id"]))
        if r.get("action") != "house_place":
            continue
        actor = str(r.get("actor_name") or "an admin")
        detail = str(r.get("detail") or "").strip()
        owner = str(r.get("target_id") or "")
        oname = ""
        if owner:
            nr = DB.q("SELECT name FROM players WHERE playerid=%s LIMIT 1", (owner,), "one")
            oname = str((nr or {}).get("name") or "")
        body = f"\U0001F3E0 **{actor}** — {detail}" + (f"  ·  owner **{oname}**" if oname else "")
        post_outbox(ADMIN_LOG_CHANNEL, body, silent=True, no_ping=True)
        print(f"[clankr] admin-log posted: {actor} | {detail[:80]}", flush=True)
    if maxid != last:
        st["last_web_id"] = maxid
        save_state(st)

# ------------------------------------------------------------------ rolling state
_cooldown = {}                              # (pid, rule) -> last fire ts
_money_win = defaultdict(deque)             # pid -> deque[(ts, amt)]
_casino_win = defaultdict(deque)            # pid -> deque[(ts, net)]   -CASINOBJ- signed net (house-edge watch)
_item_win = defaultdict(deque)              # pid -> deque[ts]
_err_win = defaultdict(deque)               # pid -> deque[ts]
_fncall_spam_win = defaultdict(deque)       # (pid,fn) -> deque[ts]   single-fire remote-spam (bankRobbery exploit)
_fncall_disc_win = defaultdict(deque)       # (pid,fn) -> deque[ts]   observe-list fn-rate discovery
# v2 windows
_last_combat = {}                           # pid -> (ts, what)   death/downed/charge for combat-log
_last_itemmove = {}                         # pid -> (ts, tag+msg) last item move for dc-dupe
_storage_open = {}                          # pid -> (ts, tag+msg) storage OPENED, not yet closed (alt+F4-dupe; #288)
_pull_win = defaultdict(deque)              # pid -> deque[ts]    -VEHICLEPULL-
_pull_plate_win = defaultdict(deque)        # (pid,plate) -> deque[ts]   store<->repull cycling (trunk dupe)
_house_cycle_win = defaultdict(deque)       # (pid,oid)   -> deque[ts]   same-house open cycling (house-storage dupe)
_house_unauth_win = defaultdict(deque)      # pid -> deque[(oid, ts)]   distinct UNAUTHORIZED house opens (loot spree)
_wac_win = defaultdict(deque)               # pid -> deque[ts]    -WAC-
_gw_win = defaultdict(deque)                # pid -> deque[(ts, amt)]   -GANGWITHDRAW-
_sell_win = defaultdict(deque)              # pid -> deque[(ts, amt)]
_buy_win = defaultdict(deque)               # pid -> deque[(ts, amt)]
_churn_win = defaultdict(deque)             # pid -> deque[ts]    buy/sell alternation
_gather_win = defaultdict(deque)            # pid -> deque[ts]
_wire_win = defaultdict(deque)              # pid -> deque[(ts, amt)]  all wires (structuring)
_fanin_win = defaultdict(deque)             # pid -> deque[(ts, sender)]
_relog_win = defaultdict(deque)             # pid -> deque[ts]    -CONNECT-
_deathcash_win = defaultdict(deque)         # pid -> deque[ts]    -MONEYWARNING-
_digest = defaultdict(int)                  # tag -> count since last digest
_digest_players = defaultdict(int)          # pid|name -> rowcount since last digest

def cooled(pid, rule):
    k = (pid, rule); now = time.time()
    if now - _cooldown.get(k, 0) < COOLDOWN_SECS:
        return True
    _cooldown[k] = now
    return False

def _roll(dq, now, window):
    while dq and (now - (dq[0][0] if isinstance(dq[0], tuple) else dq[0])) > window:
        dq.popleft()

def _pos(s):
    """pull the first [x, y(, z)] vector out of a log message -> (x, y) floats, else None."""
    m = re.search(r"\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)", s or "")
    return (float(m.group(1)), float(m.group(2))) if m else None

def _dist(a, b):
    if not a or not b:
        return None
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5

def _gang(pid):
    """player's gang0 id (players.playerid key), or None if gangless/unknown."""
    try:
        r = DB.q("SELECT gang0 FROM players WHERE playerid=%s LIMIT 1", (pid,), "one")
        return r.get("gang0") if r else None
    except Exception as e:
        print(f"[clankr] gang lookup err: {e}", flush=True)
        return None

def refresh_db_admins():
    """owner 2026-06-24: rebuild ADMINS = STATIC_ADMINS | (players_global.adminlevel>0). The authoritative DB admin
    set is exempt from the house/shed-access auto-ban + mass-balance -- admins legitimately force-open any shed/house
    (= the shed-exploit signature) and admin-spawn items. The static config list drifted, so real admins (player097 etc.)
    were at risk of a false permaban. On DB error keep the current set (fail-safe: never DROP an admin from exempt)."""
    global ADMINS
    try:
        rows = DB.q("SELECT playerid FROM players_global WHERE adminlevel > 0", ())
        db = {str(r["playerid"]) for r in (rows or [])}
        if db:
            ADMINS = STATIC_ADMINS | db
            return len(db)
    except Exception as e:
        print(f"[clankr] admin refresh err: {e}", flush=True)
    return -1

def held_key_at(oid, pid, ts):
    """True if `pid` held a key to house `oid` at time `ts`, per the -HOUSEKEY- audit trail. This is the
    point-in-time fix for the keyholders-SNAPSHOT false positive (a since-removed keyholder like player100 looked
    unauthorized). The newest -HOUSEKEY- at/just-before ts carries NewHolders = the authoritative roster
    then. No -HOUSEKEY- rows exist until b0065 ships -> returns False, so behaviour is unchanged until then."""
    try:
        r = DB.q("SELECT message FROM log WHERE tag='-HOUSEKEY-' AND message LIKE %s AND ts<=%s "
                 "ORDER BY id DESC LIMIT 1", (f"%HouseID: {oid}%", ts), "one")
        if r:
            parts = r["message"].split("NewHolders:", 1)
            return len(parts) > 1 and pid in parts[1]
    except Exception as e:
        print(f"[clankr] keyhist err: {e}", flush=True)
    return False

# ---- mass-balance dupe detector (owner 2026-06-15) -----------------------------------------------
# The OLD item-shuffle velocity rule false-positived on every legit truck<->shed unload (a farmer ferries
# a gather-device haul into his shed 48 at a time = constant "burst"). The ONLY sound dupe signal is a
# per-item mass balance: a meth precursor is ONLY gathered and ONLY consumed by processing, so if a player
# DISPOSED of more than they ever ACQUIRED, the surplus was conjured. Container shuffling nets zero.
# Precursors have clean chains (gathered in, processed out) -> highest signal, no double-count.
# (display name, class name). PRECURSORS ONLY -- deliberately. Precursors are GATHERED with unambiguous
# display names ("Hydrogen Sulfate" etc.), so IN (gather+device+pickup+received+bought) is fully captured.
# OUT (sold+dropped+manual-process-consumed) only UNDERcounts (bulk -PROCESSEDVEHICLE- consumption isn't
# quantified) -> the balance can only MISS a dupe, never false-flag. Finished/mid-chain goods are NOT
# balanced: the class names invert (cocaine=raw, cocainep=processed) and there are two processing paths
# (-PROCESSEDITEMSUCCESS- + -PROCESSEDVEHICLE-) -> too fragile, was false-flagging whole gangs in testing.
_BAL_ITEMS = {
    "hydro":    ("Hydrogen Sulfate", "hydro"),
    "phos":     ("Phosphorus",       "phos"),
    "ephedrau": ("Ephedra plant",    "ephedrau"),
}
_bal_last = {}   # pid -> monotonic ts of last balance check (rate-limit the DB hit)

def mass_balance(pid):
    """GANG-AGGREGATED precursor balance WITH per-player disposal attribution. Aggregating IN/OUT across the
    actor's whole gang handles division of labour (one member gathers, another processes/sells) so a legit
    gang never trips -- verified 0 false positives across every gang on the live DB. A violation = the GANG
    disposed of more precursor than it ever acquired = conjured matter (container shuffling never changes
    IN or OUT). owner 2026-06-17 (player071/player103 false positive): the gang balance is sound, but rule 5 used to
    blame whoever TRIPPED the item-burst -- an innocent gangmate gearing up at a supply crate ate FARMER's
    drop-dupe flag. So we now also return WHO disposed of each violating precursor (disposers = {pid:[name,
    qty]}); rule 5 names the actual top disposer, not the burst-tripper who touched none of it.
    Returns [(item, IN, OUT, disposers)]."""
    g = _gang(pid)
    pids = [pid]
    if g:
        try:
            roster = [r["playerid"] for r in (DB.q("SELECT playerid FROM players WHERE gang0=%s", (g,), "all") or [])]
            if roster:
                pids = roster
        except Exception as e:
            print(f"[clankr] roster err: {e}", flush=True)
    ph = ",".join(["%s"] * len(pids))
    rows = DB.q(f"SELECT playerid, name, tag, message FROM log WHERE playerid IN ({ph}) AND tag IN "
                "('-GATHER-','-GATHERDEVICE-','-ITEMPICKUP-','-ITEMRECEIVE-','-ITEMBOUGHT-',"
                "'-ITEMDROPPED-','-ITEMSOLD-','-PROCESSEDITEMSUCCESS-')", tuple(pids), "all") or []
    S = lambda pat, m: sum(int(x) for x in re.findall(pat, m))
    viol = []
    for item, (disp, cls) in _BAL_ITEMS.items():
        d_ = re.escape(disp); c_ = re.escape(cls); IN = OUT = 0
        disposers = {}   # pid -> [name, out_qty]  (who actually dropped/sold/processed the surplus)
        for r in rows:
            t, m = r["tag"], r["message"]; rp, rn = r["playerid"], r["name"]
            if   t == "-GATHER-":       IN  += S(rf"gathered (\d+) {d_} at", m)
            elif t == "-GATHERDEVICE-": IN  += S(rf"gathered (\d+) {d_} with", m)
            elif t == "-ITEMPICKUP-":   IN  += S(rf"picked up (\d+) out of \d+ {d_}", m)
            elif t == "-ITEMRECEIVE-":  IN  += S(rf"given (\d+) (?:{c_}|{d_}) from", m)
            elif t == "-ITEMBOUGHT-":   IN  += S(rf"purchased (\d+) (?:{c_}|{d_}) for", m)
            else:
                o = 0
                if   t == "-ITEMDROPPED-": o = S(rf"dropped (\d+) {d_}", m)
                elif t == "-ITEMSOLD-":    o = S(rf"sold (\d+) (?:{c_}|{d_}) for", m)
                elif t == "-PROCESSEDITEMSUCCESS-": o = S(rf"\((\d+) {d_}\)", m)
                if o:
                    OUT += o
                    e = disposers.setdefault(rp, [rn, 0]); e[1] += o
        if OUT > IN * BAL_MARGIN + BAL_SLACK:
            viol.append((item, IN, OUT, disposers))
    return viol

# ---------------- multi-signal combo AUTO-BAN (owner 2026-06-19) ----------------
# Each cheat signal alone false-positives (inject = corrupt mission cache; script-kill = a roadkill/explosive). Two
# INDEPENDENT signals from one player in a session is near-impossible to false-positive -- a corrupt cache doesn't
# also script-kill, a roadkiller doesn't also inject code. >= COMBO_N distinct signals within COMBO_WINDOW ->
# AUTO-BAN: INSERT bans (enforced on next connect via fn_insertRequest) + a live hardkick via bot_commands.
_cheat_sig   = defaultdict(dict)   # pid -> {signal_name: (ts, snippet)}
_banned_pids = set()               # auto-banned this run -- never repeat

def _observe_would_ban(pid, nm, ts, reason, what):
    """A no-ban-listed pid tripped an auto-ban: FLAG it (keep the data flowing) but DON'T ban -- keep the known
    cheater live to study. Cooldowned so it doesn't spam the channel."""
    if cooled(pid, "observe-wouldban"):
        return
    emit("MED", "OBSERVE — would auto-ban (no-ban list)", nm, pid,
         f"Tripped an auto-ban (`{reason}`) via **{what}** — but they're on `clankr.noban`, so NOT banned. Keeping "
         f"them live to collect exploit data. Remove from `noban` to enforce.", ts, what)

def _auto_ban(pid, nm, sigs, ts):
    if pid in NOBAN:
        _observe_would_ban(pid, nm, ts, BAN_REASON, "combo: " + ", ".join(sorted(sigs.keys())))
        return
    _banned_pids.add(pid)
    siglist = ", ".join(sorted(sigs.keys()))
    acted = False
    if AUTO_BAN:
        try:
            existing = DB.q("SELECT id FROM bans WHERE playerid=%s AND (until IS NULL OR until > NOW()) LIMIT 1", (pid,), "one")
            if not existing:
                DB.q("INSERT INTO bans (playerid, reason, banned_by, until) VALUES (%s,%s,'CLANKR-AUTO',NULL)", (pid, BAN_REASON))
            DB.q("INSERT INTO bot_commands (command, target, arg2, status) VALUES ('hardkick', %s, %s, 'pending')", (pid, BAN_REASON))
            acted = True
        except Exception as e:
            print(f"[clankr] AUTO-BAN db err: {e}", flush=True)
    if AUTO_BAN and acted:
        head = f"🔨 **AUTO-BANNED** (reason: `{BAN_REASON}`) -- ban written + live hardkick queued."
    elif AUTO_BAN:
        head = "⚠️ AUTO-BAN intended but the DB write FAILED -- ban this player MANUALLY."
    else:
        head = "🔕 AUTO-BAN is DISABLED (alert only) -- would have banned."
    emit("HIGH", "AUTO-BAN (multi-signal cheat)", nm, pid,
         f"{head} **{len(sigs)} independent cheat signals** in <{COMBO_WINDOW // 60}min: **{siglist}**. "
         f"Each alone can false-positive, but together they're conclusive.", ts,
         " | ".join(f"{k}: {v[1][:50]}" for k, v in sigs.items()))

def _auto_ban_exploit(pid, nm, ts, fn, calls):
    """Standalone PERM auto-ban for remoteExec-spam of a single-fire action (owner 2026-06-23). Writes the ban (the
    BattleMetrics mirror picks it up from the bans table) + a live hardkick, then posts a FULL human-readable
    writeup to the CLANKR channel and pings owner + admins (CRITICAL_PING)."""
    if pid in NOBAN:
        _observe_would_ban(pid, nm, ts, EXPLOIT_BAN_REASON, f"remoteExec spam: {fn} x{calls}")
        return
    _banned_pids.add(pid)
    acted = False
    if AUTO_BAN:
        try:
            existing = DB.q("SELECT id FROM bans WHERE playerid=%s AND (until IS NULL OR until > NOW()) LIMIT 1", (pid,), "one")
            if not existing:
                DB.q("INSERT INTO bans (playerid, reason, banned_by, until) VALUES (%s,%s,'CLANKR-AUTO',NULL)", (pid, EXPLOIT_BAN_REASON))
            DB.q("INSERT INTO bot_commands (command, target, arg2, status) VALUES ('hardkick', %s, %s, 'pending')", (pid, EXPLOIT_BAN_REASON))
            acted = True
        except Exception as e:
            print(f"[clankr] exploit auto-ban db err: {e}", flush=True)
    if AUTO_BAN and acted:
        verdict = (f"🔨 **PERMANENTLY BANNED** — reason `{EXPLOIT_BAN_REASON}`. Ban row written + live hardkick "
                   f"queued + mirrored to BattleMetrics.")
    elif AUTO_BAN:
        verdict = "⚠️ Ban intended but the DB write **FAILED** — ban this player MANUALLY."
    else:
        verdict = "🔕 auto_ban is OFF — would have permabanned."
    body = (
        f"🚨 **EXPLOIT DETECTED — remoteExec spam** 🚨\n"
        f"**Player:** {nm} `({pid})`\n"
        f"**What happened:** their client remote-called the server function **`{fn}`** **{calls}×** in the last "
        f"{FNCALL_SPAM_SECS}s.\n"
        f"**Why it's an exploit:** `{fn}` is triggered by a **single-click action that hides itself after one use** "
        f"(gated server-side + on a cooldown), so a real client can fire it **at most once**. Calling it **{calls}×** "
        f"is impossible in normal play — it's a **cheat menu remoteExec-spamming** the function (usually to multiply "
        f"a payout). Every `-FNCALL-` row is logged on the offender's OWN machine at the call site, so this is their "
        f"client — not the server, not another player.\n"
        f"**When:** {ts}\n"
        f"**Action taken:** {verdict}\n\n"
        f"{CRITICAL_PING}"
    )
    if CHANNEL:
        os.makedirs(OUTBOX, exist_ok=True)
        out = os.path.join(OUTBOX, f"clankr_{int(time.time()*1000)}_exploit_{abs(hash(pid)) % 100000}.json")
        tmp = out + ".tmp"
        json.dump({"channel_id": CHANNEL, "content": body}, open(tmp, "w"))
        os.replace(tmp, out)
    print(f"[clankr] EXPLOIT AUTO-BAN {nm} ({pid}) fn={fn} calls={calls}", flush=True)

def _auto_ban_house(pid, nm, ts, what, detail):
    """Standalone PERM auto-ban for the unauthorized-house-access / 'free house keys' exploit (owner 2026-06-23).
    The CALLER does the confirmation gating (unowned shed / confirmed tent / multi-house spree) AND the admin
    exclusion -- this just enforces. Mirrors _auto_ban_exploit: ban row (-> BattleMetrics mirror) + live hardkick
    + full writeup + owner/admin ping. Respects the HOUSE_UNAUTH_BAN toggle, NOBAN, and the global AUTO_BAN."""
    if not HOUSE_UNAUTH_BAN:
        if not cooled(pid, "house-wouldban"):
            emit("HIGH", "Unauthorized house access (ban OFF)", nm, pid,
                 f"{detail}\nAuto-ban for this rule is DISABLED (`house_unauth_ban`) — alert only.", ts, what)
        return
    if pid in NOBAN:
        _observe_would_ban(pid, nm, ts, HOUSE_UNAUTH_BAN_REASON, what)
        return
    _banned_pids.add(pid)
    acted = False
    if AUTO_BAN:
        try:
            existing = DB.q("SELECT id FROM bans WHERE playerid=%s AND (until IS NULL OR until > NOW()) LIMIT 1", (pid,), "one")
            if not existing:
                DB.q("INSERT INTO bans (playerid, reason, banned_by, until) VALUES (%s,%s,'CLANKR-AUTO',NULL)", (pid, HOUSE_UNAUTH_BAN_REASON))
            DB.q("INSERT INTO bot_commands (command, target, arg2, status) VALUES ('hardkick', %s, %s, 'pending')", (pid, HOUSE_UNAUTH_BAN_REASON))
            acted = True
        except Exception as e:
            print(f"[clankr] house auto-ban db err: {e}", flush=True)
    if AUTO_BAN and acted:
        verdict = (f"🔨 **PERMANENTLY BANNED** — reason `{HOUSE_UNAUTH_BAN_REASON}`. Ban row written + live hardkick "
                   f"queued + mirrored to BattleMetrics.")
    elif AUTO_BAN:
        verdict = "⚠️ Ban intended but the DB write **FAILED** — ban this player MANUALLY."
    else:
        verdict = "🔕 auto_ban is OFF — would have permabanned."
    body = (
        f"🚨 **EXPLOIT DETECTED — unauthorized house access ('free house keys')** 🚨\n"
        f"**Player:** {nm} `({pid})`\n"
        f"**What happened:** {detail}\n"
        f"**Why it's an exploit:** opening storage of a house/shed they don't OWN, hold a KEY to, or share a GANG "
        f"with requires bypassing the client-side access guard (`fn_openInventory`). The server broadcasts house "
        f"contents (`AP_vinv`), so a scripter reads + self-copies another player's stash. No real client can reach "
        f"this.\n"
        f"**When:** {ts}\n"
        f"**Action taken:** {verdict}\n\n"
        f"{CRITICAL_PING}"
    )
    if CHANNEL:
        os.makedirs(OUTBOX, exist_ok=True)
        out = os.path.join(OUTBOX, f"clankr_{int(time.time()*1000)}_house_{abs(hash(pid)) % 100000}.json")
        tmp = out + ".tmp"
        json.dump({"channel_id": CHANNEL, "content": body}, open(tmp, "w"))
        os.replace(tmp, out)
    print(f"[clankr] HOUSE-ACCESS AUTO-BAN {nm} ({pid}) {what}", flush=True)

# owner 2026-06-22: ROCK-SOLID-ONLY auto-ban. Only these HARD signals count toward a ban combo. Soft signals
# (scriptkill = roadkill/explosive/desync) are still recorded for context + still emit their own alert, but can
# NEVER push a combo to an actual BAN on their own -- they were the main false-positive-ban source. The egregious
# -money standalone auto-ban (single >= $20M event) is unaffected (it calls _auto_ban directly) -- still rock solid.
BAN_SIGNALS = {x.lower() for x in (_C.get("ban_signals") or ["anticheat", "inject-core", "sec-block", "dong-tamper", "exec-menu"])}
# owner 2026-06-24: KNOWN over-tight authz FALSE-BLOCKS (verified). The server fns are being loosened for b0093
# (updateHouseTrunk -> allow GANGMATES of a gang house; setJail/handleJail -> allow civ BOUNTY HUNTERS + self-turn-in).
# Until that ships, these -SEC- rows are FALSE POSITIVES: downgrade to MED + do NOT record the `sec-block` ban signal
# (a legit gangmate/BH must not accumulate a ban-combo signal). owner 2026-06-24: ADD copSplit + house-inv hydrate --
# both are FALSE POSITIVES, not exploits. #528 proved "BLOCKED copSplit" is the CIVILIAN ticket-payer: fn_ticketPay
# calls copSplit from the PAYER's client, so a civ trips the cop-gate on every paid ticket (legit; fixed in b0095).
# "BLOCKED house-inv hydrate" + "BLOCKED updateHouseTrunk" are plain ACCESS-DENIALS -- a player opened/closed a house
# they don't own or hold a key to; the gate correctly refused and NOTHING was exploited (e.g. stian hit it 18x on a
# house that isn't his). owner 2026-06-25: ADD evidenceAppend -- ALSO a FALSE POSITIVE, not an exploit. Every legit
# seizure runs evidenceAppend from the SEIZED civ's OWN client (fn_jailMe self-seize / the cop seize remoteExec'd TO
# the suspect), so the old west-gate -SEC-'d everyone who got arrested (one civ tripped it 5x just from being jailed
# repeatedly). Gate dropped + payload-capped server-side (b0098). The NEW "oversized evidenceAppend" message is real
# abuse and is NOT in this list -> stays HIGH. wantedRemoveCharge / "createItem TIMBER" also stay HIGH (real).
# These FP rows downgrade to a cooled MED note + NO ban-combo signal. owner 2026-09-26 (AUDIT A6): ADD "copsplit over
# budget" -- the server already paid only what was left of the caller's 10-min copSplit budget, and a legit busy cop (3 big
# seizes) or a civ paying a 3rd max ticket can hit it, so it must not feed a ban combo. "throttled copSplit" stays HIGH.
SEC_FP_PATTERNS = tuple(s.lower() for s in (_C.get("sec_fp_patterns") or
    ["blocked updatehousetrunk", "blocked house-inv hydrate", "blocked copsplit", "blocked setjail", "blocked handlejail", "blocked evidenceappend",
     "blocked victimsrv",
     "copsplit over budget"]))   # 2026-09-26: new relay, range/state checks untuned -- a lag near-miss must not feed an auto-ban
# owner 2026-06-23: DONG×SEC correlation. A lone client-side DONG tripwire or a single server-side -SEC- block
# never auto-bans (each can false-positive early — see CLANKR.md). Two sets:
#   DONG_ALERT_CODES -> emit a MED alert (visibility only).
#   DONG_HARD_CODES  -> ALSO record the ban-eligible "dong-tamper" hard signal; combined with a -SEC- block (or any
#                       other hard signal) on the same pid within COMBO_WINDOW = 2 distinct hard signals = auto-ban.
# Start the AUTO-BAN set NARROW to the lowest-FP codes (51 admin-level-changed, 56 admin-display-while-non-admin --
# these ~never false-positive). 50 (MAIN_RE) + 52 (bad scroll action) ALERT but do NOT auto-ban yet: 50 trips on
# stale profile signatures, 52 on legit actions whose code uses BIS_fnc_MP/ctrlCreate. Widen `dong_hard_codes`
# once the watch window proves them clean. Noisy codes (3/69/71/75-78/60/61/62) are digest-only -- never alert/ban.
DONG_ALERT_CODES = set(int(c) for c in (_C.get("dong_alert_codes", [50, 51, 52, 56])))
DONG_HARD_CODES  = set(int(c) for c in (_C.get("dong_hard_codes",  [51, 56])))

def _record_cheat_signal(pid, signame, nm, ts, snippet):
    if not pid or pid == "SERVER":
        return
    nowt = time.time()
    sigs = _cheat_sig[pid]
    sigs[signame] = (nowt, snippet)
    for k in [k for k, (t, _) in list(sigs.items()) if nowt - t > COMBO_WINDOW]:
        del sigs[k]
    hard = {k: v for k, v in sigs.items() if k in BAN_SIGNALS}   # only HARD signals are ban-eligible
    if len(hard) >= COMBO_N and pid not in _banned_pids:
        _auto_ban(pid, nm, hard, ts)

def house_authorized(pid, oid, owner_uid, ts):
    """True if pid legitimately accesses house `oid`: the owner, a current keyholder/owner-list member, a
    point-in-time keyholder (-HOUSEKEY- audit), a gangmate of the house owner, or an admin. Mirrors the access
    -exploit rule's checks so the cycle/dupe HEURISTICS don't flag legit storage use (owner in his own house)."""
    if pid == owner_uid or pid in ADMINS:
        return True
    try:
        r = DB.q("SELECT COALESCE(keyholders,'') AS kh, COALESCE(owners,'') AS ow FROM houses WHERE oid=%s", (oid,), "one")
        if r and (pid in str(r.get("kh", "")) or pid in str(r.get("ow", ""))):
            return True
    except Exception as e:
        print(f"[clankr] house_authorized lookup err: {e}", flush=True)
    try:
        if held_key_at(oid, pid, ts):
            return True
    except Exception:
        pass
    ag = _gang(pid)
    if ag is not None and ag == _gang(owner_uid):
        return True
    return False

# ------------------------------------------------------------------ the rules
def inspect(row):
    rid = row["id"]; ts = row["ts"]; tag = row["tag"]
    pid = row["playerid"]; name = row["name"]; msg = row["message"] or ""
    now = time.time()

    if VERBOSE:
        print(f"[clankr] #{rid} [{ts}] {tag} {name}({pid}) :: {msg[:160]}", flush=True)
    if pid in WHITELIST:
        if VERBOSE:
            print(f"[clankr] #{rid} whitelisted pid {pid} -> skip", flush=True)
        return
    _digest[tag] += 1
    if pid and pid != "SERVER":
        _digest_players[f"{name}|{pid}"] += 1

    # 0) GPS AUTOPILOT crash log (owner 2026-07-12). The mission logs -APCRASH- on every autopilot
    # collision -- object hit + full telemetry (speed / corner / heading error / route position) --
    # so crash spots can be pulled and tuned. NOT a cheat: a LOW note (throttled per player) and it
    # counts in the digest. Query the raw data: SELECT * FROM log WHERE tag='-APCRASH-' ORDER BY ts DESC;
    if tag == "-APCRASH-":
        if not cooled(pid or "srv", "apcrash"):
            emit("LOW", "Autopilot crash", name, pid, msg, ts, tag)
        return

    # 1) hard anti-cheat / exploit detectors -> HIGH + ping
    if tag in AC_TAGS:
        if not cooled(pid, "ac:" + tag):
            emit("HIGH", f"Anti-cheat flag `{tag}`", name, pid,
                 "An in-game anti-cheat / exploit detector tripped.", ts, f"{tag} {msg}")
        _record_cheat_signal(pid, "anticheat", name, ts, f"{tag} {msg}")   # combo signal
        return

    # 1b) SERVER-BLOCKED EXPLOIT (-SEC-, owner 2026-06-23). The §2 audit's authz layer logs -SEC- when it BLOCKS a
    # privileged action by an unauthorized client (jail-anyone, gangBank drain, toggleNewbieRoles, etc.). The server
    # already STOPPED it -> near-certain exploit ATTEMPT. Surface HIGH + record a distinct "sec-block" HARD signal so
    # a -SEC- paired with a DONG tamper (or any other hard signal) on the same pid auto-bans via the combo rule.
    # A single -SEC- alone does NOT ban (early on it could be an over-tight authz false-block to fix).
    if tag == "-SEC-":
        # owner 2026-06-24: KNOWN over-tight authz false-blocks (gangmate gang-house save / civ bounty-hunter or
        # self jail) -> MED note + NO sec-block ban signal, until the b0093 fn fixes deploy. Everything else (the
        # real ones: copSplit/evidenceAppend/gangBank/etc) falls through to HIGH + the ban-combo signal as before.
        if any(p in msg.lower() for p in SEC_FP_PATTERNS):
            if not cooled(pid, "sec-fp"):
                emit("MED", "Server -SEC- block (known false-positive / access-denial)", name, pid,
                     f"Known FP / access-denial -- civ ticket-pay copSplit (#528), or a non-owner open/close of a house "
                     f"they don't key. The gate correctly refused; nothing was exploited: `{msg[:140]}`.", ts, msg)
            return
        if not cooled(pid, "sec-block"):
            emit("HIGH", "Server BLOCKED an exploit (-SEC-)", name, pid,
                 f"The authz layer blocked a privileged action by this player: `{msg[:140]}`. "
                 f"A real exploit attempt (or, early on, a false-block to fix).", ts, msg)
        _record_cheat_signal(pid, "sec-block", name, ts, f"SEC {msg[:80]}")
        return

    # 1c) MODERATION FLAG -- the "Rape" containment charge (id 110), owner 2026-06-21. Cops are LooneyBin's
    # first-line moderators with NO server power; this charge max-jails a suspect ($50k bail, capped 25-min
    # sentence) and is re-sendable while staff review footage. A cop applying it must pull an admin in NOW ->
    # HIGH + force the owner ping (the MOD-ALERT prefix bypasses NOTIFY_ONLY in emit). This is NOT a cheat
    # signal (no auto-ban / combo) -- it's a human-moderation escalation. Cooldown keyed on the SUSPECT uid so
    # a cop's rapid re-clicks coalesce, but a genuine re-send after the sentence (>COOLDOWN_SECS later) re-pings.
    if tag == "-MODFLAG-RAPE-":
        _sm = re.search(r"\((\d{17})\)", msg)
        _suspect = _sm.group(1) if _sm else pid
        if not cooled(_suspect, "modflag-rape"):
            emit("HIGH", "MOD-ALERT: Rape containment charge", name, pid,
                 "🚨 A cop applied the **Rape** containment charge — the suspect (see snippet) is now MAX-jailed "
                 "pending review. An admin needs to pull the footage and decide (clear / hold / ban) ASAP. The cop "
                 "can re-send it until staff act.", ts, msg)
        return

    # 1a) UNIVERSAL CALL AUDIT (-FNCALL-, owner 2026-06-15 "log every function"): fn_MP logs every remote
    # call a client makes. Legit client->server TON calls are normal & high-volume, so DON'T alert on those
    # -- only the genuinely impossible ones: a CLIENT invoking a server-only DB/exec primitive = raw SQL
    # injection / remoteExec RCE. Tight danger set keeps this signal-only. Everything else is just audit trail.
    if tag == "-FNCALL-":
        # Match the CALLED FUNCTION NAME only (not the whole msg -> don't match args). Flag only genuinely
        # never-legit-from-client primitives. IMPORTANT: this codebase's clients DO legitimately remote-call
        # the DB request wrappers (DB_fnc_updatePartial/updateRequest/queryRequest/insertRequest = stat/house
        # saves) -- a broad "db_fnc_" match false-spammed HIGH (12 times) and is REMOVED. Raw asyncQuery /
        # callExtension / execVM / compile / BIS_fnc_MP stay flagged = real SQL-injection / RCE tripwire.
        fnm = re.search(r"MP call (\S+)", msg)
        fnl = (fnm.group(1).lower() if fnm else msg.lower())
        DANGER = ("asyncquery", "callextension", "execvm", "bis_fnc_mp", "_fnc_compile", "preprocessfile")
        if any(d in fnl for d in DANGER) and not cooled(pid, "fncall-rce"):
            emit("HIGH", "Client invoked a code-exec / raw-SQL primitive", name, pid,
                 "Client remote-called a function it never legitimately invokes (raw SQL exec / compiled code "
                 "/ cross-machine exec) — injection or RCE attempt.", ts, msg)
        # owner 2026-06-23: SINGLE-FIRE remote spam -> standalone PERM auto-ban (Nigbert APS_fnc_bankRobbery x168).
        # A WATCHED fn is one a legit client fires AT MOST ONCE (self-hiding one-click action). >= FNCALL_SPAM_N
        # of them in FNCALL_SPAM_SECS = a cheat menu remoteExec-spamming it = impossible from a real client.
        if pid and pid != "SERVER" and pid not in _banned_pids and any(w in fnl for w in FNCALL_SPAM_WATCH):
            _fsq = _fncall_spam_win[(pid, fnl)]; _fsq.append(now); _roll(_fsq, now, FNCALL_SPAM_SECS)
            if len(_fsq) >= FNCALL_SPAM_N:
                _auto_ban_exploit(pid, name, ts, (fnm.group(1) if fnm else fnl), len(_fsq))
        # owner 2026-06-23: DISCOVERY (observe-list pids only) -- mine a KNOWN cheater for NEW exploits. Any
        # non-routine fn they remoteExec at an abnormal burst (>= DISCOVERY_N / DISCOVERY_SECS) = a candidate to add
        # to fncall_spam_watch. Skips the watched fns (already caught) + routine high-volume saves (DISCOVERY_SKIP).
        if pid in NOBAN and not any(w in fnl for w in FNCALL_SPAM_WATCH) and not any(s in fnl for s in DISCOVERY_SKIP):
            _ddq = _fncall_disc_win[(pid, fnl)]; _ddq.append(now); _roll(_ddq, now, DISCOVERY_SECS)
            if len(_ddq) >= DISCOVERY_N and not cooled(pid, "disc:" + fnl):
                emit("MED", "OBSERVE — abnormal fn-call rate (candidate exploit)", name, pid,
                     f"Observe-listed player called **{fnm.group(1) if fnm else fnl}** **{len(_ddq)}×** in "
                     f"{DISCOVERY_SECS}s — abnormal burst for a non-routine function. Candidate exploit; consider "
                     f"adding it to `fncall_spam_watch`.", ts, msg)
        return

    # 1a2) ATM SKIMMER SELF-REMOVAL (owner 2026-07-16): the $50k rebel ATM Skimmer pays cops a $200k bounty to
    # pull it. A cop can plant one WHILE PLAYING CIVILIAN (same Steam account), then respawn/relog as cop and
    # "remove" their own device -> +$150k every cycle, self-dealt. The remove log carries the ORIGINAL owner
    # UID ("(was <uid>)"); if it equals the removing cop's own playerid, the same account planted AND collected.
    # (Separate-Steam alt farming can't be proven from logs -- discord_links is 1:1 -- so we flag the provable
    # same-account case; a colluding second account still shows as the planter UID in the message for eyeballing.)
    if tag == "-ATMSKIMMER-" and msg.lower().startswith("cop removed skimmer"):
        m = re.search(r"\(was (\d+)\)", msg)
        owner_uid = m.group(1) if m else ""
        if owner_uid and owner_uid == pid and not cooled(pid, "atmskim-self"):
            emit("HIGH", "Cop removed their OWN ATM skimmer ($200k self-deal)", name, pid,
                 f"A cop pulled an ATM skimmer they had planted themselves — owner UID = the removing cop's own "
                 f"UID `{pid}` — and collected the $200,000 bounty. Plant $50k as civ, switch to cop, remove for "
                 f"$200k = a $150k self-dealt farm. Verify the civ→cop side-switch timing and consider clawing "
                 f"back the reward / a talk.", ts, msg)
        return

    # 1b) UNAUTHORIZED HOUSE/SHED ACCESS -- NO mission patch needed. owner 2026-06-15: the existing -HOUSEINV-
    # "opened house storage" log already carries the house oid + Owner UID; cross-ref the live `houses` table
    # (owners + keyholders) to skip legit owner / rank-1-2 keyholder / gang access. Anyone else opening a shed
    # they don't own = the tent+cursorObject shed-access exploit -> instant HIGH. This catches the WHOLE class
    # of access exploits purely from logs the game already writes, so no server file ever has to change.
    if tag == "-HOUSEINV-" and ("opened house" in msg.lower()) and pid and pid != "SERVER":
        # owner 2026-06-19 (HOUSE-STORAGE DUPE -- Jeff Stall): the live open->take->close->REOPEN dupe. The mission
        # patch (AP_trunkLock + 1.25s settle on close, fn_openInventory) closes the hole; this catches anyone still
        # hammering it (or a regression). Flag a player opening the SAME house oid HOUSECYCLE_N+ times within
        # HOUSECYCLE_SECS -- legit use never re-opens one house that fast. The disconnect/alt+F4 rules below MISS
        # this (no DC involved) and guns aren't precursors so mass-balance is blind to it = why it went unseen.
        # owner 2026-06-23: gate on AUTHORIZATION + demote HIGH->MED. The old rule fired HIGH on raw open-count for
        # ANYONE, so a house OWNER grabbing stacks from his OWN storage 4x/90s = 30 false HIGH pings (errm's weed
        # house). The open->take->reopen dupe is (a) patched (AP_trunkLock+settle) and (b) shows in mass-balance /
        # sells anyway. So only an UNAUTHORIZED rapid-cycler is worth a MED review note -- and an unauthorized opener
        # ALREADY trips the HIGH access alert below. Requires a numeric Owner (unowned sheds handled by their own rule).
        _hm = re.search(r"ID:\s*(-?\d+)\s*\|\s*Owner:\s*(\d+)", msg)
        if _hm:
            _hoid, _howner = _hm.group(1), _hm.group(2)
            _hq = _house_cycle_win[(pid, _hoid)]; _hq.append(now); _roll(_hq, now, HOUSECYCLE_SECS)
            if (len(_hq) >= HOUSECYCLE_N and not cooled(pid, "housecycle")
                    and not house_authorized(pid, _hoid, _howner, ts)):
                emit("MED", "House-storage cycling (review)", name, pid,
                     f"NON-owner/keyholder opened house `{_hoid}` (owner {_howner}) storage **{len(_hq)}x** in "
                     f"<{HOUSECYCLE_SECS}s — possible open->take->reopen probing. Cross-check the close deltas: gear "
                     f"GAINING an item the house didn't lose (non-conservation) = confirmed dupe.", ts, msg)
        # *** THE ACTUAL TENT EXPLOIT (owner 2026-06-16, caught it live) *** the exploit opens an UNOWNED
        # INDUSTRIAL/MAP shed (Land_i_Shed_Ind_F), which logs "ID: -1 | Owner: NoPidVar" -- there is NO owner
        # UID to cross-ref, so the player-house rule below (which requires a numeric Owner) NEVER matched it.
        # No legit player can ever open an unowned shed's storage, so this log line *is* the exploit, full stop.
        # NOT admin-exempt: an admin (incl. the owner testing) doing it is still the exploit. Fire immediately.
        if ("Owner: NoPidVar" in msg) or re.search(r"\bID:\s*-1\b", msg):
            if not cooled(pid, "shed-unowned"):
                tent_note = ""
                try:
                    tr = DB.q("SELECT message FROM log WHERE playerid=%s AND tag='-TENTDEPLOY-' "
                              "AND ts <= %s AND ts >= (%s - INTERVAL 600 SECOND) ORDER BY id DESC LIMIT 1",
                              (pid, ts, ts), "one")
                    if tr:
                        d = _dist(_pos(msg), _pos(tr.get("message", "")))
                        tent_note = (f" CONFIRMED tent: pitched a tent {d:.0f}m away within 10min."
                                     if (d is not None and d <= 40) else " (deployed a tent in the last 10min.)")
                except Exception as e:
                    print(f"[clankr] tent-corr err: {e}", flush=True)
                if (pid not in ADMINS) and (pid not in _banned_pids):
                    # the unowned-shed open IS the exploit, full stop (existing rule) -> standalone PERM ban.
                    _auto_ban_house(pid, name, ts, "unowned-shed access",
                        f"Opened the storage of an UNOWNED industrial/map shed (ID -1 / NoPidVar) — only reachable "
                        f"via the tent+cursorObject access exploit, not possible in normal play.{tent_note}")
                else:
                    emit("HIGH", "Tent-shed exploit (unowned shed access)", name, pid,
                         f"Opened the storage of an UNOWNED industrial/map shed (ID -1 / NoPidVar) — only reachable "
                         f"via the tent+cursorObject access exploit. Not possible in normal play. (actor is an ADMIN "
                         f"→ NOT banned){tent_note}", ts, msg)
            return
        m = re.search(r"ID:\s*(\d+).*?Owner:\s*(\d+)", msg)
        if m:
            house_oid, owner_uid = m.group(1), m.group(2)
            if pid != owner_uid:
                kh = ow = ""
                try:
                    r = DB.q("SELECT COALESCE(keyholders,'') AS kh, COALESCE(owners,'') AS ow FROM houses WHERE oid=%s",
                             (house_oid,), "one")
                    if r:
                        kh, ow = str(r.get("kh", "")), str(r.get("ow", ""))
                except Exception as e:
                    print(f"[clankr] house-owner lookup err: {e}", flush=True)
                if (pid not in kh) and (pid not in ow):
                    # admins legitimately open any shed (admin powers / comps) -> never the exploit.
                    if pid in ADMINS:
                        return
                    # POINT-IN-TIME KEY (owner 2026-06-15): houses.keyholders is only the CURRENT snapshot, so a
                    # since-removed keyholder reads as unauthorized (the player100 false positive). The -HOUSEKEY- audit
                    # trail says who held a key AT the moment of the open -> if they did, it's legit. Skip.
                    if held_key_at(house_oid, pid, ts):
                        if VERBOSE:
                            print(f"[clankr] house-access {pid} held a key to {house_oid} at {ts} -> skip", flush=True)
                        return
                    # GANG-AWARE (owner 2026-06-15): gangmates share each other's sheds, but the houses.keyholders
                    # snapshot never lists them -> ~90% of "unauthorized" hits were just gang-internal access
                    # (player106/player096=DAP, player102=Excel, player032=PMC). If actor's gang == owner's gang it's NOT
                    # the exploit. Skip. Genuine outsider access (e.g. Drunk Squad -> gangless player110) still fires.
                    _ag = _gang(pid)
                    if _ag is not None and _ag == _gang(owner_uid):
                        if VERBOSE:
                            print(f"[clankr] house-access {pid}->owner {owner_uid} same gang {_ag} -> skip", flush=True)
                        return
                    # tent-deploy correlation: did the same actor pitch a tent near this house just before?
                    tent_note = ""
                    try:
                        tr = DB.q("SELECT message FROM log WHERE playerid=%s AND tag='-TENTDEPLOY-' "
                                  "AND ts <= %s AND ts >= (%s - INTERVAL 600 SECOND) ORDER BY id DESC LIMIT 1",
                                  (pid, ts, ts), "one")
                        if tr:
                            d = _dist(_pos(msg), _pos(tr.get("message", "")))
                            if d is not None and d <= 40:
                                tent_note = f" CONFIRMED tent exploit: pitched a tent {d:.0f}m away within 10min."
                            else:
                                tent_note = " (same actor deployed a tent in the last 10min.)"
                    except Exception as e:
                        print(f"[clankr] tent-corr err: {e}", flush=True)
                    # owner 2026-06-23: track DISTINCT unauthorized houses for the ban decision. A single open only
                    # ALERTS (spares the rare since-removed keyholder with no -HOUSEKEY- audit row); a CONFIRMED tent
                    # or >=N distinct unauthorized houses in the window = an unmistakable loot spree -> PERM ban.
                    _uq = _house_unauth_win[pid]
                    if house_oid not in [o for (o, _t) in _uq]:
                        _uq.append((house_oid, now))
                    while _uq and _uq[0][1] < now - HOUSE_UNAUTH_BAN_SECS:
                        _uq.popleft()
                    _distinct = len({o for (o, _t) in _uq})
                    _tent_confirmed = "CONFIRMED tent exploit" in tent_note
                    if (pid not in ADMINS) and (pid not in _banned_pids) and (_tent_confirmed or _distinct >= HOUSE_UNAUTH_BAN_N):
                        _auto_ban_house(pid, name, ts, f"unauthorized house access x{_distinct}",
                            f"Opened storage of house `{house_oid}` (owner `{owner_uid}`) with NO owner/key/gang "
                            f"rights — **{_distinct}** distinct unauthorized house(s) in <{HOUSE_UNAUTH_BAN_SECS}s.{tent_note}")
                    elif not cooled(pid, "house-unauth"):
                        emit("HIGH", "Unauthorized house access", name, pid,
                             f"Opened storage of house `{house_oid}` (owner `{owner_uid}`) — actor is NOT the owner "
                             f"or a keyholder. Tent+cursorObject shed-access exploit.{tent_note}", ts, msg)
                    return

    # 2) large player->player money transfer (995 = "WIRE $X from A -> B")
    if tag == "995" and msg.upper().startswith("WIRE"):
        amt = money(msg)
        if amt >= WIRE_BIG and not cooled(pid, "bigwire"):
            sev = "HIGH" if amt >= WIRE_CRIT else "MED"
            emit(sev, "Large money transfer (WIRE)", name, pid,
                 f"Wired **${amt:,}** to another player — dupe-laundering / RMT signal.", ts, msg)

    # 3) money velocity -- one player churning huge $ across money tags fast
    if tag in MONEY_TAGS:
        amt = money(msg)
        if amt > 0:
            dq = _money_win[pid]; dq.append((now, amt)); _roll(dq, now, VEL_SECS)
            total = sum(a for _, a in dq)
            if total >= VEL_SUM and not cooled(pid, "velocity"):
                emit("HIGH", "Money velocity", name, pid,
                     f"Moved **${total:,}** across {len(dq)} money events in <{VEL_SECS}s.", ts, msg)

    # 3a) CASINO net-gain -- blackjack is HOUSE-FAVORED (BJ pays 3:2, dealer stands 17), so a legit player's summed
    # net trends NEGATIVE. A large SUSTAINED net POSITIVE beyond CASINO_GAIN in the window is house-edge-impossible
    # (the client skipped its local bet debit or forged a win) -> REVIEW-ONLY (never auto-ban; the server owns every
    # payout). The server logs one signed -CASINOBJ- row per resolved game (net is FIRST + can be negative), so the
    # running sum self-corrects on losses/abandons. NOT in MONEY_TAGS on purpose -- it's a dedicated house-edge test,
    # not generic churn, and casino payouts don't scale with Stimmy so it's deliberately NOT in STIMMY_MUTED.
    if tag in CASINO_WATCH_TAGS and pid and pid != "SERVER":   # cash games only -- vehicle jackpots (-CASINOVEH-) are a designed faucet, excluded to avoid false positives
        dq = _casino_win[pid]; dq.append((now, casino_net(msg))); _roll(dq, now, CASINO_SECS)
        total = sum(a for _, a in dq)
        if total >= CASINO_GAIN and not cooled(pid, "casino-netgain"):
            emit("HIGH", "Casino net-gain", name, pid,
                 f"Net **+${total:,}** across the casino ({len(dq)} games) in <{CASINO_SECS}s. Every game is "
                 f"house-favored (aggressive edge), so a legit player trends NEGATIVE — a large sustained "
                 f"positive is house-edge-impossible (client skipped the bet debit / forged a win). Review only.",
                 ts, msg)

    # 3b) owner 2026-06-22 (Israels 100k-meth $280M dupe): STANDALONE egregious single money event -> AUTO-ACT,
    # no 2-signal combo needed. One sale / wire / deposit / receive this large is unambiguous cheating -- the
    # biggest LEGIT single sale is ~70 fed gold bars (~$5.5M), so $20M can't false-positive. This is the exact
    # gap that let the meth dupe through: the SALE (-ITEMSOLD-) isn't in MONEY_TAGS so the velocity rule never
    # saw it, and the laundering used structured sub-$1M wires. Whitelisted pids already returned up top.
    if tag in ("-ITEMSOLD-", "995", "-DEPOSIT-", "-BANKRECEIVE-") and pid and pid != "SERVER" and pid not in _banned_pids:
        _huge = money(msg)
        if _huge >= EGREGIOUS_MONEY:
            _auto_ban(pid, name, {"egregious money": (time.time(), f"{tag} = ${_huge:,.0f}")}, ts)

    # 4) large cash carried on death (-MONEYWARNING- = "dropped $X on death...")
    if tag == "-MONEYWARNING-":
        amt = money(msg)
        if amt >= DROP_BIG and not cooled(pid, "bigdrop"):
            emit("MED", "Large cash on death", name, pid,
                 f"Dropped **${amt:,}** on death (carrying abnormal cash).", ts, msg)

    # 5) item-shuffle burst -> TRIGGER ONLY (owner 2026-06-15). A burst of container moves is NOT an alert
    # by itself -- legit farmers unload a gather-device haul truck->shed in 48-unit chunks, tripping any
    # velocity rule all day (this was the all-day spam). Instead the burst kicks off a rigorous per-item
    # mass-balance; we alert HIGH only if a precursor's disposed (sold+dropped+processed) exceeds everything
    # ever acquired (gather+device+recv+bought) = matter conjured from nowhere. Shuffling nets zero -> silent.
    if tag in ITEM_TAGS:
        dq = _item_win[pid]; dq.append(now); _roll(dq, now, ITEM_BURST_SEC)
        if len(dq) >= ITEM_BURST_N and pid and pid != "SERVER" and pid not in ADMINS and (now - _bal_last.get(pid, 0) > BAL_RECHECK_SEC):
            _bal_last[pid] = now
            try:
                viol = mass_balance(pid)
            except Exception as e:
                viol = []; print(f"[clankr] mass_balance err: {e}", flush=True)
            if viol:
                # The GANG conjured matter -- proven. But attribute to the ACTUAL disposer(s), NOT whoever
                # tripped the item-burst. owner 2026-06-17: player071 + player103 each geared up at a supply crate
                # (14+ ammo TOOKITEM/STOREDITEM in 30s = burst) and ate gangmate FARMER's hydro drop-dupe flag
                # -- their recent activity was 100% ammo, zero hydro. Rank gang members by how much of the
                # VIOLATING precursor THEY personally dropped/sold/processed; only name members over a material
                # share. The burst-tripper who disposed ~none is never named. Cooldown on the CULPRIT, so a
                # gang's dupe alerts once even when several innocent gangmates trip the burst.
                det = ", ".join(f"{it}: disposed {d:,} vs acquired {a:,}" for it, a, d, _ in viol)
                culprit_out = {}; gang_out = 0   # pid -> [name, total_disposed_across_violating_items]
                for it, a, d, disp in viol:
                    for cp, (cn, q) in disp.items():
                        gang_out += q
                        e = culprit_out.setdefault(cp, [cn, 0]); e[1] += q
                flagged_any = False
                for cp, (cn, q) in sorted(culprit_out.items(), key=lambda kv: -kv[1][1]):
                    if cp in WHITELIST or cp in ADMINS:
                        continue
                    # material share = >=25% of the gang's violating disposal OR >= BAL_SLACK absolute units.
                    # An innocent gangmate who disposed ~none of the precursor never crosses this.
                    if q <= 0 or (q < 0.25 * gang_out and q < BAL_SLACK):
                        continue
                    flagged_any = True
                    if not cooled(cp, "dupebalance"):
                        emit("HIGH", "Confirmed dupe (mass-balance)", cn, cp,
                             f"This player's GANG disposed of more precursor (sold+dropped+processed) than the "
                             f"gang ever acquired (gather+device+recv) — conjured matter, not container shuffling. "
                             f"**This member personally disposed {q:,} of the surplus** (top disposer of the gang). {det}",
                             ts, f"{tag} {msg}")
                # nobody crossed the per-player bar (disposal may predate the queryable log window) -> still
                # surface the gang once, but flagged as ROSTER-REVIEW so no single innocent is accused.
                if not flagged_any and not cooled(pid, "dupebalance-gang"):
                    emit("HIGH", "Possible dupe (mass-balance, gang — review roster)", name, pid,
                         f"This GANG disposed of more precursor than it ever acquired = conjured matter, but no "
                         f"single member crossed the per-player attribution bar (the disposal may predate the log "
                         f"window). `{name}` merely TRIGGERED the check — review the whole gang roster, don't assume "
                         f"this player. {det}", ts, f"{tag} {msg}")

    # 6) script-error burst -- one client erroring fast = exploit probing / injected script
    if tag == "-SCRIPTERR-":
        dq = _err_win[pid]; dq.append(now); _roll(dq, now, ERR_BURST_SEC)
        if len(dq) >= ERR_BURST_N and not cooled(pid, "errburst"):
            emit("MED", "Script-error burst", name, pid,
                 f"{len(dq)} script errors in <{ERR_BURST_SEC}s — exploit probing?", ts, msg)
        # 6b) CODE INJECTION (owner 2026-06-19, ftdyn case): a PARSE error in pre-compiled mission code = a client
        # running RE-DEFINED functions (cheat menu). A single one is damning. Escalate if a CORE money/exec fn named.
        _low = msg.lower()
        if any(p in _low for p in INJECT_PARSE_ERR) and not cooled(pid, "inject"):
            _sevfn = next((f for f in INJECT_CORE_FNS if f in _low), "")
            emit("HIGH", "Code injection (tampered client)", name, pid,
                 ("SQF **parse error** in pre-compiled mission code — the client is running re-defined functions "
                  "(cheat menu)" + (f", incl. the CORE function `{_sevfn}`" if _sevfn else "") + ". Impossible from "
                  "the real PBO. Cross-check: FREE purchases (item bought, no balance drop), CONJURED cash (gave "
                  "more than withdrawn), NO-WEAPON kills."), ts, msg)
            # combo signal: ONLY count a parse error in a CORE money/exec fn (a generic parse error = a corrupt
            # cache, which mustn't auto-ban alone). ftdyn hit debitCard + AP_fnc_MP -> counts.
            if _sevfn:
                _record_cheat_signal(pid, "inject-core", name, ts, msg)

        # 6c) INJECTED EXEC-MENU / RCE CONSOLE (owner 2026-06-25, player085 case). The SCRIPTERR carries the cheat
        # menu's own code: it BUILDS Rsc* controls AT RUNTIME on the map display (findDisplay 12) -- an RscEdit input
        # + an RscButton that `call compile`s the typed text = arbitrary code execution. No legit mission code does
        # this in a script that errors (real UI = createDialog + config controls). Whitespace-collapsed so spacing
        # tricks can't dodge it. Unambiguous -> single-hit auto-ban (execmenu_autoban) + a hard combo signal.
        _n = " ".join(_low.split())
        _execmenu = (any(p in _n for p in INJECT_EXEC_MENU)
                     or ("finddisplay 12" in _n and "ctrlcreate" in _n)
                     or ("call compile" in _n and ("ctrladdeventhandler" in _n or "displayaddeventhandler" in _n or "ctrlcreate" in _n))
                     or ("visiblemap" in _n and "finddisplay 12" in _n))
        if _execmenu and not cooled(pid, "execmenu"):
            emit("HIGH", "AUTO-BAN: injected exec-menu (RCE console)", name, pid,
                 "Client SCRIPTERR contains injected cheat-menu code — building an RscEdit/RscButton console on the "
                 "map (findDisplay 12) that `call compile`s typed SQF = arbitrary code execution. No legit source "
                 "(real UI uses createDialog + config controls). This is the player085 (76561190000000036) signature.", ts, msg)
            _record_cheat_signal(pid, "exec-menu", name, ts, msg)
            if EXECMENU_AUTOBAN:
                _auto_ban(pid, name, {"injected exec-menu": (time.time(), msg[:120])}, ts)

    # 7) gang-bank withdraw burst -- re-withdrawing a restored gang fund (the 2026-06-13 dupe CLANKR missed).
    # message: "attempted to withdraw $X from their GANG bank account. GANG ACCOUNT BAL: $Y ..." -> money() = $X.
    if tag == "-GANGWITHDRAW-":
        amt = money(msg)
        if amt > 0:
            dq = _gw_win[pid]; dq.append((now, amt)); _roll(dq, now, GW_SECS)
            total = sum(a for _, a in dq)
            if (total >= GW_SUM or len(dq) >= GW_N) and not cooled(pid, "gangwithdraw"):
                emit("HIGH", "Gang-bank withdraw burst", name, pid,
                     f"Withdrew **${total:,}** across {len(dq)} gang-bank withdrawals in <{GW_SECS}s — possible gang-bank dupe.", ts, msg)

    # 7) multiple Steam accounts on one profile -> possible alts (low priority)
    if tag == "-MULTIPLESTEAMS-":
        if not cooled(pid, "alts"):
            emit("LOW", "Multiple Steam accounts", name, pid,
                 "Profile carries multiple Steam IDs (possible alts / shared account).", ts, msg)

    # ---------------- v2 rules (2026-06-12) ----------------
    # 8) combat-log: downed/killed-victim/charged then disconnect within CLOG_SECS
    if tag in ("-DOWNED-", "-KILLED-", "-ADDCHARGE-"):
        _last_combat[pid] = (now, f"{tag} {msg[:80]}")
        # 8b) SCRIPT-KILL (owner 2026-06-19, ftdyn case): a kill logged with an EMPTY weapon ("...with a , Ammo:
        # 0/0...") = no round fired -> the kill was FORCED by script (remote setDamage via the hooked AP_fnc_MP).
        # Real kills always carry a weapon name. Killer-side log only ("killed <name>").
        # TIGHTENED (owner 2026-06-19): require killer ON FOOT (veh=foot) + DIST > SCRIPTKILL_MIN_DIST so a ROADKILL
        # (in-vehicle, point-blank, also logs empty weapon) can't false-positive. ftdyn (on foot, 55m) still fires.
        _kdm = re.search(r"DIST:\s*(\d+)", msg)
        # owner 2026-06-23 FP FIX (andyr 76561190000000037): EXCLUDE a kill where the KILLER was DEAD
        # ("Killer Health: 0" / @CTX dmg=1.00). That's a MUTUAL / post-death kill -- the kill-log reads the killer's
        # currentWeapon/ammo at the victim's death, and a CORPSE has no weapon (Ammo 0/0), so the empty-weapon is a
        # LOGGING ARTIFACT, not a script-kill. (andyr & a cop traded DMR shots at 131m, both died -> his side logged
        # empty + Killer Health 0; the cop's own -KILLED- log shows he killed andyr with a Mk-I EMR the same second.)
        _khm = re.search(r"Killer Health:\s*([0-9.]+)", msg)
        _killer_dead = (_khm is not None and float(_khm.group(1)) <= 0) or (re.search(r"\bdmg=1\.0+\b", msg) is not None)
        if (tag == "-KILLED-" and "killed" in msg and re.search(r"with a\s*,\s*Ammo", msg)
                and "veh=foot" in msg and _kdm and int(_kdm.group(1)) > SCRIPTKILL_MIN_DIST
                and not _killer_dead
                and not cooled(pid, "scriptkill")):
            # owner 2026-06-22: MED not HIGH -- scriptkill is SOFT (no longer a ban signal); MED = no owner ping,
            # no recent-activity block. Cuts the HIGH false-positive noise the owner flagged, stays visible for review.
            emit("MED", "Script-kill (no weapon)", name, pid,
                 f"Killed a player with NO weapon (empty weapon, Ammo 0/0) at **{_kdm.group(1)}m on foot** — no shot "
                 f"fired and not a roadkill, so the kill was FORCED by script (remote setDamage). Review for combat cheat.", ts, msg)
            _record_cheat_signal(pid, "scriptkill", name, ts, msg)
    if tag == "-DISCONNECT-":
        lc = _last_combat.get(pid)
        if lc and (now - lc[0]) <= CLOG_SECS and not cooled(pid, "combatlog"):
            emit("HIGH", "Combat log", name, pid,
                 f"Disconnected **{int(now - lc[0])}s** after `{lc[1]}` — combat logging.", ts, msg)
        # 9) disconnect-dupe: item move then disconnect within DCDUPE_SECS (save-lag dupe window)
        li = _last_itemmove.get(pid)
        if li and (now - li[0]) <= DCDUPE_SECS and not cooled(pid, "dcdupe"):
            # owner 2026-06-23: HIGH->MED. "item move then DC within 45s" = normal end-of-session logoff after using
            # storage (big FP source); the save-lag payoff is largely closed by the b0078 gear-save patches. The
            # rock-solid vector is 9b below (DC with a container still OPEN), which stays HIGH.
            emit("MED", "Disconnect-dupe window", name, pid,
                 f"Disconnected **{int(now - li[0])}s** after an item move — possible save-lag dupe (heuristic, "
                 f"largely patched). Review only if paired with other signals.",
                 ts, li[1])
        # 9b) alt+F4 WITH A CONTAINER STILL OPEN (#288 delayed-dc dupe). owner 2026-06-17: ebola opened house
        # storage, waited 37s (PAST the 20s dc-dupe window), then alt+F4'd -> stored gear was kept (b0069 has
        # no store-time gear save) = dupe, and the timed rule above missed it. This signal is TIME-INDEPENDENT:
        # a legit player CLOSES the container before leaving, so "opened, never closed, then disconnect" is the
        # store-then-alt+F4 vector regardless of how long they stalled.
        so = _storage_open.get(pid)
        if so and not cooled(pid, "dcstorage"):
            emit("HIGH", "Alt+F4 w/ storage open", name, pid,
                 f"Disconnected with a container still OPEN ({int(now - so[0])}s after opening, never closed) — store-then-alt+F4 dupe vector (#288).",
                 ts, so[1])
        _storage_open.pop(pid, None)   # clear on disconnect (reconnect starts fresh)
    # track container open/close so 9b can see an open-at-disconnect (msg: "opened ..." vs "closed ...")
    if tag in ("-HOUSEINV-", "-VEHINV-"):
        _ml = msg.lower()
        if "opened" in _ml:
            _storage_open[pid] = (now, f"{tag} {msg[:120]}")
        elif "closed" in _ml:
            _storage_open.pop(pid, None)
    if tag in ITEM_TAGS:
        _last_itemmove[pid] = (now, f"{tag} {msg[:120]}")

    # 10) vehicle-pull burst -> per-PID count stays alert-DISABLED (owner 2026-06-16: pulling a few cars in 2min
    # is normal play). But per-PLATE cycling IS the trunk dupe the old comment predicted: pull -> take from the
    # trunk at the moment of storing -> the stored row keeps the PRE-take trunk -> re-pull the SAME plate -> the
    # items are back. owner 2026-06-18 (player099/player100, plate 179067 ~7× in 2min): nobody re-pulls ONE car 3+ times
    # in 5min legitimately, so per-plate cycling is a specific, low-false-positive signal. Fires on the LOOP even
    # after the server settle-fix neutralizes the payoff (so we still SEE attempts). Plate = the (NNNNN) in msg.
    if tag == "-VEHICLEPULL-":
        dq = _pull_win[pid]; dq.append(now); _roll(dq, now, PULL_BURST_SEC)
        mp = re.search(r"\((\d+)\)", msg)
        if mp:
            plate = mp.group(1)
            pdq = _pull_plate_win[(pid, plate)]; pdq.append(now); _roll(pdq, now, PULL_CYCLE_SEC)
            if len(pdq) >= PULL_CYCLE_N and not cooled(pid, "trunkcycle:" + plate):
                emit("HIGH", "Vehicle store↔repull cycling (trunk-dupe pattern)", name, pid,
                     f"Pulled the SAME vehicle (plate {plate}) **{len(pdq)}×** in <{PULL_CYCLE_SEC}s — the store↔"
                     f"repull loop that dupes a vehicle's trunk (take items mid-store, re-pull, trunk refills). "
                     f"Cross-check this player's -VEHINV- closes for `Owner: NoVehData`.", ts, msg)

    # 11) DONG in-game anti-cheat tamper reports (-DONG-, was -WAC-). owner 2026-06-23: renamed WAC->DONG; match
    # BOTH tags (live b0091 still logs -WAC- until the rename PBO deploys). Two rules: (a) BURST = many tamper
    # reports fast = remote-exec probing; (b) PER-CODE = a HIGH-confidence code (DONG_HARD_CODES) records a distinct
    # "dong-tamper" HARD signal -> auto-bans ONLY when paired with a -SEC- block / another hard signal (combo rule).
    # Noisy codes (3 item-count / 69 explosions / 75-78 money) are alert-only here and never feed a ban.
    if tag in ("-WAC-", "-DONG-"):
        _dm = re.search(r"\[(\d+)\]", msg) or re.search(r"code=(\d+)", msg)   # labeled "[50] ..." or legacy "code=50"
        _code = int(_dm.group(1)) if _dm else -1
        # owner 2026-07-19: code 3 (inventory item-count) is a known FALSE-POSITIVE source -- it fires in bursts on
        # LEGIT item gains the virtual monitor hasn't caught up to yet (login-bonus weapon/mag rewards granted via
        # addWeapon/dropPhysicalItem bypass AP_invMonitor; 8/8 of GrimReaper's code-3 DONGs followed a login bonus
        # within 60s). It's already alert-only + never bans -- keep it OUT of the remote-exec BURST tally too, so a
        # legit reward can't escalate a HIGH. Real remote-exec probing still trips the burst via its other codes.
        # 2026-09-26: codes 60 (handleMessage), 64/65 (netSetVar) and 76-78 (receiveMoney) are filed by the RECEIVER
        # of another client's remoteExec, and dongClient takes the subject from the reporter -- so the pid here
        # is the victim. One `remoteExec [..., -2]` makes every online player file one; keep them out of the burst too.
        # 53/55 likewise: any client can `setVariable ["AP_invisOn", <x>, true]` on another unit, and the victim's 5 s
        # tripwire (initPlayerLocal) then files one every loop -- 24 in the burst window.
        if _code not in (3, 53, 55, 60, 64, 65, 76, 77, 78):
            dq = _wac_win[pid]; dq.append(now); _roll(dq, now, WAC_BURST_SEC)
            if len(dq) >= WAC_BURST_N and not cooled(pid, "wacburst"):
                emit("HIGH", "RemoteExec watchdog burst", name, pid,
                     f"{len(dq)} DONG/WAC hits in <{WAC_BURST_SEC}s — tamper-report burst.", ts, msg)
        if _dm:
            if _code in DONG_ALERT_CODES and not cooled(pid, f"dong:{_code}"):
                _ce = (" Correlation-eligible (auto-bans only if paired with a -SEC- block / another hard signal)."
                       if _code in DONG_HARD_CODES else " Alert-only (not auto-ban-eligible yet).")
                emit("MED", f"DONG tamper (code {_code})", name, pid,
                     f"In-game anti-cheat tripped: `{msg[:120]}`.{_ce}", ts, msg)
            if _code in DONG_HARD_CODES:
                _record_cheat_signal(pid, "dong-tamper", name, ts, f"DONG {msg[:80]}")

    # 12) sell velocity + buy velocity + buy/sell churn
    if tag == "-ITEMSOLD-":
        amt = money(msg)
        if amt > 0:
            dq = _sell_win[pid]; dq.append((now, amt)); _roll(dq, now, SELL_SECS)
            tot = sum(a for _, a in dq)
            if tot >= SELL_SUM and not cooled(pid, "sellvel"):
                emit("MED", "Sell velocity", name, pid,
                     f"Sold **${tot:,}** across {len(dq)} sales in <{SELL_SECS}s — dupe cash-out signal.", ts, msg)
    if tag in ("-ITEMBOUGHT-", "-WEAPONBOUGHT-", "-CLOTHESBOUGHT-"):
        amt = money(msg)
        if amt > 0:
            dq = _buy_win[pid]; dq.append((now, amt)); _roll(dq, now, BUY_SECS)
            tot = sum(a for _, a in dq)
            if tot >= BUY_SUM and not cooled(pid, "buyvel"):
                emit("MED", "Purchase velocity", name, pid,
                     f"Spent **${tot:,}** in <{BUY_SECS}s — post-dupe spending spree?", ts, msg)
    # buy/sell churn -> ALERT DISABLED (owner 2026-06-16: count-based with no value gate, so buying 10 cheap
    # seeds at a shop tripped it = pure noise). Real laundering shows up in the $-gated sell/purchase velocity
    # above + the mass-balance, not in raw event count. Window kept; no emit.
    if tag in ("-ITEMSOLD-", "-ITEMBOUGHT-"):
        dq = _churn_win[pid]; dq.append(now); _roll(dq, now, CHURN_SECS)

    # 13) gather-rate macro
    if tag == "-GATHER-":
        dq = _gather_win[pid]; dq.append(now); _roll(dq, now, GATHER_SECS)
        if len(dq) >= GATHER_N and not cooled(pid, "gathermacro"):
            emit("MED", "Gather-rate macro", name, pid,
                 f"{len(dq)} gathers in <{GATHER_SECS}s — autoclicker/macro speed.", ts, msg)

    # 14) wire structuring: many sub-threshold wires summing big (dodges the single-wire alarm)
    if tag == "995" and msg.upper().startswith("WIRE"):
        amt = money(msg)
        if 0 < amt < WIRE_BIG:
            dq = _wire_win[pid]; dq.append((now, amt)); _roll(dq, now, STRUCT_SECS)
            tot = sum(a for _, a in dq)
            if len(dq) >= STRUCT_N and tot >= WIRE_BIG and not cooled(pid, "structuring"):
                emit("HIGH", "Wire structuring", name, pid,
                     f"{len(dq)} wires totalling **${tot:,}** in <{STRUCT_SECS}s — split to dodge the big-wire alarm.",
                     ts, msg)

    # 15) receive fan-in: one player collecting from many distinct senders (mule)
    if tag in ("-BANKRECEIVE-", "-ITEMRECEIVE-"):
        m = re.search(r"from\s+(.+?)(?:\s*\(|\s*$|\s*\|)", msg, re.I)
        sender = (m.group(1).strip() if m else "?")
        dq = _fanin_win[pid]; dq.append((now, sender))
        while dq and (now - dq[0][0]) > FANIN_SECS:
            dq.popleft()
        senders = {s for _, s in dq}
        if len(senders) >= FANIN_N and not cooled(pid, "fanin"):
            emit("MED", "Receive fan-in (mule)", name, pid,
                 f"Received from **{len(senders)} distinct players** in <{FANIN_SECS}s — collection mule pattern.",
                 ts, msg)

    # 16) repeat large-cash deaths
    if tag == "-MONEYWARNING-":
        dq = _deathcash_win[pid]; dq.append(now); _roll(dq, now, DEATHCASH_SECS)
        if len(dq) >= DEATHCASH_N and not cooled(pid, "deathcashrep"):
            emit("MED", "Repeat cash-on-death", name, pid,
                 f"{len(dq)} large-cash deaths in <{DEATHCASH_SECS//60}min — cash-mule handoffs via death?",
                 ts, msg)

    # 17) relog cycling
    if tag == "-CONNECT-":
        dq = _relog_win[pid]; dq.append(now); _roll(dq, now, RELOG_SECS)
        if len(dq) >= RELOG_N and not cooled(pid, "relog"):
            emit("LOW", "Relog cycling", name, pid,
                 f"{len(dq)} connects in <{RELOG_SECS//60}min — relog dupe / ghosting attempt.", ts, msg)

# ------------------------------------------------------------------ economy digest (owner 2026-06-20)
def _server_uptime_secs():
    """elapsed seconds since arma3server_x64 started = the 'current restart' anchor. None if the
    server is down / mid-restart (caller falls back to a fixed window)."""
    try:
        out = subprocess.run(["ps", "-o", "etimes=", "-C", "arma3server_x64"],
                             capture_output=True, text=True, timeout=5).stdout.split()
        vals = [int(x) for x in out if x.strip().isdigit()]
        return max(vals) if vals else None   # longest-running match = the server (not a just-spawned dupe)
    except Exception:
        return None

_money     = lambda n: f"${n:,}"
_SELL_RE   = re.compile(r"sold\s+([\d,]+)\s+(.+?)\s+for\s+\$([\d,]+)", re.I)   # -ITEMSOLD-: "sold 48 Heisenberg Meth for $199,277"
_BUY_RE    = re.compile(r"for\s+\$([\d,]+)", re.I)                              # -ITEM/WEAPON/CLOTHESBOUGHT-: "purchased ... for $5,184"

def emit_economy_digest():
    """owner 2026-06-20: every ECON_MINS, post an economy snapshot for the CURRENT RESTART --
    top 3 items sold (by $ value), money created (NPC vendor SALES = the faucet) vs spent (NPC
    PURCHASES = the sink), and the top earners. Reads `log` directly; 'this restart' is anchored to
    the arma process uptime so it resets cleanly on every reboot. Bank deposit/withdraw are excluded
    (cash<->bank shuffle, neither creates nor destroys money)."""
    if ECON_CHANNEL == 0 or ECON_MINS <= 0:
        return
    up = _server_uptime_secs()
    if up and up > 45:
        where, params = "ts > NOW() - INTERVAL %s SECOND", (int(up),)
        span = f"this restart — {up // 3600}h{(up % 3600) // 60:02d}m"
    else:
        where, params = "ts > NOW() - INTERVAL 4 HOUR", ()     # mid-restart / unknown -> ~one restart cycle
        span = "last 4h"
    try:
        item_qty, item_val, earner = defaultdict(int), defaultdict(int), defaultdict(int)
        created = 0
        for r in (DB.q(f"SELECT name, message FROM log WHERE tag='-ITEMSOLD-' AND {where}", params) or []):
            m = _SELL_RE.search(r.get("message") or "")
            if not m:
                continue
            qty = int(m.group(1).replace(",", "")); item = m.group(2).strip(); amt = int(m.group(3).replace(",", ""))
            item_qty[item] += qty; item_val[item] += amt; created += amt; earner[r["name"]] += amt
        spent = 0
        for r in (DB.q(f"SELECT message FROM log WHERE tag IN ('-ITEMBOUGHT-','-WEAPONBOUGHT-','-CLOTHESBOUGHT-') AND {where}", params) or []):
            m = _BUY_RE.search(r.get("message") or "")
            if m:
                spent += int(m.group(1).replace(",", ""))
    except Exception as e:
        print(f"[clankr] econ digest query err: {e}", flush=True)
        return

    top_sold = sorted(item_val.items(), key=lambda x: -x[1])[:3]
    top_earn = sorted(earner.items(), key=lambda x: -x[1])[:5]
    net = created - spent

    L = [f"\U0001F4B0 **Economy digest** — {span}", "__Top 3 sold__"]
    if top_sold:
        for item, val in top_sold:
            L.append(f"  • **{item}** — {item_qty[item]:,}× = {_money(val)}")
    else:
        L.append("  • _no vendor sales yet_")
    L += ["__Money flow__",
          f"  \U0001F4B5 created (vendor sales): {_money(created)}",
          f"  \U0001F6D2 spent (vendor buys): {_money(spent)}",
          f"  ⚖️ net into economy: {'+' if net >= 0 else '-'}{_money(abs(net))}",
          "__Top earners (this restart)__"]
    if top_earn:
        L += [f"  • {nm} — {_money(val)}" for nm, val in top_earn]
    else:
        L.append("  • _none yet_")

    # owner 2026-07-07: casino ledger this restart -- biggest losers/winners + net economy DELETED across ALL games
    # (blackjack + Coin Flip/Wheel/Slots/Roulette/Hi-Lo). casino_net() = the SIGNED net $ per result row; summed per
    # player. Total < 0 => the casino DELETED money (a sink, house winning); total > 0 => it MINTED (house losing =
    # house-edge-impossible => exploit flag). Uses the same CASINO_RESULT_TAGS set the net-gain watch does.
    casino = defaultdict(int)
    _cas_in = "','".join(CASINO_RESULT_TAGS)
    try:
        for r in (DB.q(f"SELECT name, message FROM log WHERE tag IN ('{_cas_in}') AND {where}", params) or []):
            casino[r["name"]] += casino_net(r.get("message") or "")
    except Exception as e:
        print(f"[clankr] econ digest casino query err: {e}", flush=True)
    if casino:
        casino_total = sum(casino.values())
        losers  = [(nm, net) for nm, net in sorted(casino.items(), key=lambda x: x[1])  if net < 0][:3]
        winners = [(nm, net) for nm, net in sorted(casino.items(), key=lambda x: -x[1]) if net > 0][:3]
        L.append("__\U0001F3B0 Casino (this restart)__")
        if casino_total <= 0:
            L.append(f"  \U0001F525 economy deleted (net player losses): {_money(-casino_total)}")
        else:
            L.append(f"  ⚠️ economy MINTED — players net AHEAD by {_money(casino_total)} (house should win; check for exploits)")
        L.append("  __Biggest losers__")
        L += ([f"  • {nm} — -{_money(-net)}" for nm, net in losers] or ["  • _none_"])
        L.append("  __Biggest winners__")
        L += ([f"  • {nm} — +{_money(net)}" for nm, net in winners] or ["  • _none_"])

    body = "\n".join(L)

    os.makedirs(OUTBOX, exist_ok=True)
    fn = os.path.join(OUTBOX, f"clankr_econ_{int(time.time())}.json")
    tmp = fn + ".tmp"
    json.dump({"channel_id": ECON_CHANNEL, "content": body}, open(tmp, "w"))
    os.replace(tmp, fn)
    print(f"[clankr] economy digest posted (created={created} spent={spent} earners={len(earner)})", flush=True)

# ------------------------------------------------------------------ digest
def emit_digest():
    """periodic activity summary to the channel (verbosity without alert spam)."""
    if CHANNEL == 0 or not _digest:
        _digest.clear(); _digest_players.clear(); return
    total = sum(_digest.values())
    tags = ", ".join(f"`{t}`×{n}" for t, n in sorted(_digest.items(), key=lambda x: -x[1])[:12])
    movers = "\n".join(f"  {k.split('|')[0]} `({k.split('|')[1]})` — {n} events"
                       for k, n in sorted(_digest_players.items(), key=lambda x: -x[1])[:5])
    body = (f"\U0001F4CA **CLANKR digest** — {total} log rows / last {DIGEST_MINS}min\n"
            f"**Tags:** {tags}\n**Most active:**\n{movers or '  (none)'}")
    os.makedirs(OUTBOX, exist_ok=True)
    fn = os.path.join(OUTBOX, f"clankr_digest_{int(time.time())}.json")
    tmp = fn + ".tmp"
    json.dump({"channel_id": CHANNEL, "content": body}, open(tmp, "w"))
    os.replace(tmp, fn)
    print(f"[clankr] digest posted ({total} rows)", flush=True)
    _digest.clear(); _digest_players.clear()

# ------------------------------------------------------------------ heartbeat
def emit_heartbeat(boot_ts, last_id):
    """proof-of-life: CLANKR is now a hard boot prerequisite, so silence must mean 'healthy', not 'dead'.
    Posts uptime + cursor + flag tally even when nothing's wrong."""
    if CHANNEL == 0:
        return
    up = (time.time() - boot_ts) / 3600.0
    hi, me, lo = _flags_total.get("HIGH", 0), _flags_total.get("MED", 0), _flags_total.get("LOW", 0)
    top = ", ".join(f"{r}×{n}" for r, n in sorted(_flags_rules.items(), key=lambda x: -x[1])[:5]) or "none"
    body = (f"\U0001F49A **CLANKR heartbeat** — alive {up:.1f}h | cursor #{last_id}\n"
            f"flags since boot: **{hi} HIGH / {me} MED / {lo} LOW** | top rules: {top}")
    os.makedirs(OUTBOX, exist_ok=True)
    fn = os.path.join(OUTBOX, f"clankr_hb_{int(time.time())}.json")
    tmp = fn + ".tmp"
    json.dump({"channel_id": CHANNEL, "content": body}, open(tmp, "w"))
    os.replace(tmp, fn)
    print(f"[clankr] heartbeat posted (up {up:.1f}h, {hi}/{me}/{lo})", flush=True)

# ------------------------------------------------------------------ BattleMetrics ban mirror
def _iso_utc(dt):
    """pymysql datetime (DB container is UTC) -> BM ISO8601 'Z'. None -> None (= permanent)."""
    if not dt:
        return None
    try:
        return dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    except Exception:
        return None

def mirror_bans_to_bm(st):
    """Push every NEW `bans` row to BattleMetrics. Cursor st['last_ban_id'] (0 on first enable = backfill all)."""
    global BM_ORG, BM_BANLIST
    if not (BM_ORG and BM_BANLIST):                      # resolve org + ban-list once: config -> cached -> discover
        BM_ORG     = BM_ORG or st.get("bm_org", "")
        BM_BANLIST = BM_BANLIST or st.get("bm_banlist", "")
    if not (BM_ORG and BM_BANLIST):
        org, bl, err = bm.discover_ids(BM_TOKEN)
        if not (org and bl):
            print(f"[clankr] BM discover failed ({err}) -- set org_id/banlist_id in config; mirror idle", flush=True)
            return
        BM_ORG, BM_BANLIST = org, bl
        st["bm_org"], st["bm_banlist"] = org, bl
        save_state(st)
        print(f"[clankr] BM ready: org={org} banlist={bl}", flush=True)
    if "last_ban_id" not in st:
        st["last_ban_id"] = 0                            # owner: "All DB bans" -> backfill every existing ban once
    rows = DB.q("SELECT id, playerid, reason, banned_by, until, created FROM bans WHERE id > %s ORDER BY id ASC LIMIT 200",
                (st["last_ban_id"],))
    for r in rows or []:
        bid = int(r["id"]); pid = (r["playerid"] or "").strip()
        if not (pid.isdigit() and len(pid) >= 16):       # skip SERVER / malformed playerids
            st["last_ban_id"] = bid; save_state(st); continue
        reason = r["reason"] or BAN_REASON
        note = f"CLANKR mirror | LooneyBin bans.id={bid} | banned_by={r['banned_by']} | {r['created']}"
        ok, info = bm.create_ban(BM_TOKEN, BM_ORG, BM_BANLIST, pid, reason,
                                 expires_iso=_iso_utc(r["until"]), timestamp_iso=_iso_utc(r["created"]),
                                 note=note, uid=f"clb-{bid}", native=BM_NATIVE)  # BM uid maxLength=14
        if ok:
            st["last_ban_id"] = bid; save_state(st)
            print(f"[clankr] BM ban OK row={bid} pid={pid} -> {info}", flush=True)
            emit("MED", "BattleMetrics mirror", "", pid,
                 f"⛓️ Ban mirrored to **BattleMetrics** (BM ban `{info}`) -- RCON enforces on next connect. "
                 f"Source: `bans.id={bid}` ({r['banned_by']}). Reason: `{reason[:120]}`.",
                 str(r["created"]), f"bans.id={bid}")
        else:
            transient = info.startswith(("HTTP 0", "HTTP 5", "HTTP 429"))
            print(f"[clankr] BM ban FAIL row={bid} pid={pid}: {info}{' (retry)' if transient else ' (skip)'}", flush=True)
            if transient:
                return                                   # network/5xx/429 -> stop, retry this row next poll (cursor stays)
            emit("HIGH", "MOD-ALERT (BattleMetrics)", "", pid,                # hard 4xx -> alert owners, skip the row
                 f"⚠️ Could NOT mirror ban to BattleMetrics (`{info}`). Player **is** banned locally "
                 f"(hardkick queued); add them in BM manually. Source: `bans.id={bid}`.",
                 str(r["created"]), f"bans.id={bid}")
            st["last_ban_id"] = bid; save_state(st)

# ------------------------------------------------------------------ main loop
def main():
    st = load_state()
    if "last_id" not in st:
        if BACKFILL:
            st["last_id"] = 0
        else:
            row = DB.q("SELECT COALESCE(MAX(id),0) AS m FROM log", (), "one")
            st["last_id"] = int((row or {}).get("m", 0))
        save_state(st)
    if "last_web_id" not in st:   # admin-audit-log cursor: start at HEAD (don't backfill history)
        try:
            wr = DB.q("SELECT COALESCE(MAX(id),0) AS m FROM web_admin_log", (), "one")
            st["last_web_id"] = int((wr or {}).get("m", 0))
        except Exception:
            st["last_web_id"] = 0
        save_state(st)
    print(f"[clankr] online. channel={CHANNEL} owners={len(OWNER_IDS)} start_id={st['last_id']} poll={POLL_SECS}s verbose={VERBOSE} digest={DIGEST_MINS}m econ={ECON_MINS}m", flush=True)
    boot_ts = time.time()
    next_digest = time.time() + DIGEST_MINS * 60 if DIGEST_MINS > 0 else None
    next_hb = time.time() + HEARTBEAT_HRS * 3600 if HEARTBEAT_HRS > 0 else None
    next_econ = time.time() + 90 if ECON_MINS > 0 else None   # first economy digest ~90s after start (quick confirm), then every ECON_MINS
    _na = refresh_db_admins()   # owner 2026-06-24: load the authoritative DB admin exemption BEFORE the first row
    print(f"[clankr] admin exemption: {len(ADMINS)} UIDs ({_na} from DB)" if _na >= 0 else f"[clankr] admin exemption: DB load failed -> static {len(ADMINS)} only", flush=True)
    next_admins = time.time() + 300   # refresh DB admin set every 5 min (tracks promotions/demotions)
    while True:
        try:
            if next_digest and time.time() >= next_digest:
                emit_digest()
                next_digest = time.time() + DIGEST_MINS * 60
            if next_econ and time.time() >= next_econ:
                emit_economy_digest()
                next_econ = time.time() + ECON_MINS * 60
            if next_hb and time.time() >= next_hb:
                emit_heartbeat(boot_ts, st["last_id"])
                next_hb = time.time() + HEARTBEAT_HRS * 3600
            if time.time() >= next_admins:
                refresh_db_admins()
                next_admins = time.time() + 300
            # daily LT+ faction-playtime DM (fires on the first poll at/after LT_REPORT_HOUR, once per day)
            if LT_REPORT_DM and st.get("lt_pt_date") != time.strftime("%Y-%m-%d") and time.localtime().tm_hour >= LT_REPORT_HOUR:
                try:
                    emit_lt_playtime_report(st)
                except Exception as e:
                    print(f"[clankr] LT report error: {e}", flush=True)
            rows = DB.q(
                "SELECT id, ts, tag, playerid, name, message FROM log WHERE id > %s ORDER BY id ASC LIMIT 1000",
                (st["last_id"],))
            for row in rows or []:
                try:
                    inspect(row)
                except Exception as e:
                    print(f"[clankr] rule error on id {row.get('id')}: {e}", flush=True)
                st["last_id"] = int(row["id"])
            if rows:
                save_state(st)
            try:
                poll_admin_logs(st)   # quiet Discord audit log for website admin actions
            except Exception as e:
                print(f"[clankr] admin-log poll error: {e}", flush=True)
            if BM_ENABLED:
                try:
                    mirror_bans_to_bm(st)
                except Exception as e:
                    print(f"[clankr] BM mirror error: {e}", flush=True)
        except Exception as e:
            print(f"[clankr] poll error: {e}", flush=True)
        time.sleep(POLL_SECS)

if __name__ == "__main__":
    main()
