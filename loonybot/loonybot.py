#!/usr/bin/env python3
"""
LoonyBot -- LooneyBin Altis Life bug intake + admin console.

Bug intake (any user):
  * plain message in bug_channel_id, or "!bug <text>" anywhere  -> NEW entry in BUGS.md
  * !bugs / !resolve <id>
  * !report  -> DM wizard (Type / Date-Time / Description / Evidence) -> a message in the staff-only
    Bug/Exploit or Player-Report text channel (admins/owner see all; reporters get a DM confirm only).
  * !report staged <id> / !report live <id>  (owner) -> flip the bug's status; the status-watcher then
    auto-replies in that bug's reporter thread: "staged" (fix written, deploys next restart) or
    "live" (deployed, test again). Same mechanism that already pings on FIXED/NEEDINFO.

Admin console (admin_channel_id only, owner_ids only):
  * !info <pid> · !pid <name> · !whitelist <pid> <faction> <rank> · !comp <pid> <amount> [cash]
  * !srv <hardr|softr|msg|kick|ban> ...  · !help
See README / !help. Requires bot token + Message Content Intent.
"""
import json
import os
import re
import sys
import asyncio
import subprocess
import datetime
import pathlib

try:
    import discord
    from discord.ext import tasks
except ImportError:
    sys.exit("discord.py not installed. Run:  pip install -r requirements.txt")

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import admin  # local module: DB ops + rank maps + formatters

CONFIG_PATH = HERE / "config.json"


def load_config():
    if not CONFIG_PATH.exists():
        sys.exit(f"Missing {CONFIG_PATH}\n -> cp config.example.json config.json  and fill it in.")
    cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    token = (cfg.get("token") or os.environ.get("LOONYBOT_TOKEN") or "").strip()
    if not token or token.startswith("PUT_"):
        sys.exit("No bot token. Set 'token' in config.json (or the LOONYBOT_TOKEN env var).")
    cfg["token"] = token
    return cfg


CFG = load_config()
REPORT_FILE = pathlib.Path(CFG.get("report_file") or (HERE.parent / "BUGS.md"))
FEATURES_FILE = pathlib.Path(CFG.get("features_file") or (HERE.parent / "features.md"))
RICARDO_GIF = CFG.get("ricardo_gif") or "https://media.giphy.com/media/WoKqL8nGDJfFwGzrmR/giphy.gif"
BUG_CHANNEL_ID = int(CFG.get("bug_channel_id") or 0)
# !report (public DM wizard) drops each report as a PRIVATE THREAD in one of these text channels so a
# reporter sees only their own. Default the bug target to the existing intake channel.
REPORT_BUG_CHANNEL_ID = int(CFG.get("report_bug_channel_id") or BUG_CHANNEL_ID or 0)
REPORT_PLAYER_CHANNEL_ID = int(CFG.get("report_player_channel_id") or 0)
REPORT_STAFF_ROLE_ID = int(CFG.get("report_staff_role_id") or 0)   # single role id, pinged on every report (0 = off)
# Alt screening (owner 2026-07-25: throwaway accounts joining to mass-report players). A Discord
# snowflake ENCODES the creation time, so account age costs zero API calls and works even for a user
# object we could never fetch. 0 disables either check.
# !alts -- list young accounts in the server. Alts have been brigading members to Discord's own report
# system to farm TOS timeouts, so staff need to see who turned up recently. A Discord snowflake ENCODES
# the creation time in its top 42 bits, so account age costs zero API calls.
NEW_ACCOUNT_DAYS = float(CFG.get("new_account_days") or 120)     # ~4 months, the default !alts window
# guild.members is only fully populated with the PRIVILEGED Server Members Intent. Enabling it in code
# while it is off in the Developer Portal makes discord.py refuse to start, so it is opt-in here: flip
# the portal switch FIRST, then set "members_intent": true. Default false = bot keeps booting either way.
MEMBERS_INTENT = bool(CFG.get("members_intent") or False)
# owner 2026-06-26: extra role id(s) pinged ONLY on BUG/EXPLOIT reports (the wizard's type-1, posted to
# REPORT_BUG_CHANNEL_ID) -- not on player reports. List so more can be added later.
REPORT_BUG_ROLE_IDS = [int(r) for r in (CFG.get("report_bug_role_ids") or [])]
# role NAMES pinged on every report thread (resolved per-guild). owner request 2026-06-15: Admin/Owner/Mod/
# Senior Admin. Override via config.json "report_staff_roles". (Bot needs "Mention All Roles" or the roles set
# mentionable; _post_report sends with AllowedMentions(roles=True).)
REPORT_STAFF_ROLES = [str(r) for r in (CFG.get("report_staff_roles") or ["Admin", "Owner", "Mod", "Senior Admin"])]
LINKED_ROLE_ID = int(CFG.get("linked_role_id") or 0)        # !link grants this role (0 = resolve by name)
LINKED_ROLE_NAME = str(CFG.get("linked_role") or "Linked")  # role name if no id set
LINK_REWARD = int(CFG.get("link_reward") or 0)              # one-time bank incentive when the PID exists
# beta-tester perk: members with this role get the beta whitelist (clothing-shop shirt) + a one-time $1M on
# !link, and a retroactive sweep on startup catches anyone already linked. Match by id if set, else by name.
BETA_ROLE_ID = int(CFG.get("beta_role_id") or 0)
BETA_ROLE_NAME = str(CFG.get("beta_role") or "Beta Tester")
BETA_REWARD = int(CFG.get("beta_reward") or 1000000)
REPORT_TIMEOUT = 300        # seconds to wait for each wizard answer before giving up
STATUS_CHANNEL_ID = int(CFG.get("status_channel_id") or 0)
ADMIN_CHANNEL_ID = int(CFG.get("admin_channel_id") or STATUS_CHANNEL_ID or 0)
# dedicated whitelist channel: !whitelist/!wl/!help only, usable by the WL_ROLE_NAMES roles + owners
WHITELIST_CHANNEL_ID = int(CFG.get("whitelist_channel_id") or 100000000000000980)
# dedicated link channel: !link only works here (keeps the bind command out of every other channel)
LINK_CHANNEL_ID = int(CFG.get("link_channel_id") or 100000000000000206)
OWNER_IDS = {int(x) for x in CFG.get("owner_ids", [])}
PROTECTED_OWNERS = set(OWNER_IDS)   # founding owners from config.json -- can't be removed via !removeperms
PREFIX = CFG.get("prefix", "!")
SERVER_DIR = CFG.get("server_dir") or str(HERE.parent)
DBX = admin.DB(CFG["db"]) if CFG.get("db") else None

HEADER = (
    "<!-- LoonyBot bug queue. One entry per report. Status flow: NEW -> STAGED -> FIXED.\n"
    "     The bot appends NEW reports; the owner/Claude edit Status as work proceeds.\n"
    "     Never renumber existing #IDs. -->\n\n"
    "# LooneyBin Bug Queue\n\n"
)
ID_RE = re.compile(r"^### #(\d+)\b", re.M)
ENTRY_RE = re.compile(
    r"^### #(\d+) · (\w+) · [^\n]*\n- \*\*By:\*\* ([^·\n]+)[^\n]*\n\n(.*?)\n\n---", re.S | re.M)
# pulls the channel_id/message_id ref off the meta line (only entries logged since the ref feature)
REF_RE = re.compile(r"^### #(\d+) ·.*\n- \*\*By:\*\*[^\n]*\*\*ref:\*\* (\d+)/(\d+)", re.M)
STATUS_EMOJI = {"NEW": "\U0001F41B", "STAGED": "\U0001F6E0️", "FIXED": "✅", "NEEDINFO": "\U0001F50D"}
OPEN_STATES = ("NEW", "STAGED", "NEEDINFO")
DEFAULT_ASK = ("\U0001F50D Need more detail to reproduce this — please reply here with: exact steps, "
               "which key/action, your class & side, and how often it happens.")
# Posted in the reporter's thread by the status-watcher as a bug moves STAGED -> FIXED(live).
STAGED_MSG = ("\U0001F6E0️ The fix for this is **staged** — it's written and will go **live on the next "
              "server restart**. We'll ping you here again once it's deployed. Thanks for the report!")
LIVE_MSG = "✅ Fixed — please test again. Make a new report if it doesn't work."
ADMIN_CMDS = {"info", "pid", "dpid", "whitelist", "wl", "comp", "srv", "logs", "help", "addperms", "removeperms", "perms", "kick", "ban", "casinoban", "alts"}

# Discord caps a message at 2000 chars; the full help is ~2.1k, so it's split into parts that are each a
# self-contained code block. cmd_help sends them as separate messages (owner request 2026-06-16).
HELP_PARTS = (
    "**LoonyBot admin** (this channel, owners only) — players & whitelist  (1/2)\n"
    "```\n"
    "!info <pid>                      all known info on a player\n"
    "!pid <name>                      resolve a (last-synced) in-game name -> PID\n"
    "!dpid <@mention|id|name>         resolve a Discord account -> linked PID\n"
    "!whitelist <pid> <fac> <rank> [maxtac]  set whitelist (fac: cop|med|srv). 4th arg maxtac=on|off -> MaxTac whitelist\n"
    "      cop : chief captain lt sgt corp const cadet\n"
    "      med : chief asstchief para aemt emt emr\n"
    "      srv : owner dev admin mod trial none    (lvl 5>4>3>2>1>0; dev=4 is ABOVE admin=3; owner protected)\n"
    "      maxtac: on|off (optional 4th arg) -> players.ismaxtac, gates MaxTac Armory + MaxTac Garage\n"
    "!comp <pid> <amount> [cash]      add money (default BANK). player must be OFFLINE/softlogged\n"
    "!logs <pid>                      DM you the player's ENTIRE audit log (file attachment)\n"
    "!casinoban <pid> [on|off]        lift (default) or set a casino self-exclusion. Applies on next connect\n"
    "```",

    "**LoonyBot admin** — server, bugs & perms  (2/2)\n"
    "```\n"
    "!srv hardr <sec>                 hard restart: graceful save -> repack + boot (deploys code).  `hardr force` = no-save kill\n"
    "!srv softr <sec>                 SOFT restart: reload mission in place (players re-slot, trunks persist, no code deploy)\n"
    "!srv repacknext                  ship staged code at the NEXT natural restart (no double-restart). `cancelrepack` to undo\n"
    "!srv msg <text>                  broadcast in-game (~5s)\n"
    "!srv resetfed                    clear a stuck/cooling-down Federal Reserve so players can retry (no reboot)\n"
    "!srv kick <pid> [reason]         kick if online (~5s)\n"
    "!srv ban <pid> <days> <reason>   ban (0 days = perm); kicks if online, blocks on connect\n"
    "!bug <text> | !bugs | !resolve <id>\n"
    "!report staged <id>             owner — mark bug STAGED + auto-reply 'staged' in the reporter's thread\n"
    "!report live <id>               owner — mark bug FIXED/live + auto-reply 'live, test again' in the thread\n"
    "!report notifyfixed <fromId>    owner — post the Fixed notice on every solved (STAGED/FIXED) bug #fromId and up\n"
    "!report                          PUBLIC (any user, any channel) — DM wizard -> private report thread\n"
    "!alts [days]                    staff — list members whose Discord account is newer than N days (default 120)\n"
    "!link <playerID>                 PUBLIC, once per user — bind discord<->PID, grant Linked role + bank reward\n"
    "!accept   (owner; reply to a feature msg in ANY channel -> copies it + discussion to features.md)\n"
    "!addperms <id|@user>            grant bot perms.   !removeperms <id>   !perms (list)\n"
    "```\n"
    "_Not built yet: PID-by-discord-id, last-5-names, last-ban history._",
)


def ensure_file():
    if not REPORT_FILE.exists():
        REPORT_FILE.parent.mkdir(parents=True, exist_ok=True)
        REPORT_FILE.write_text(HEADER, encoding="utf-8")


def next_id():
    ensure_file()
    ids = [int(x) for x in ID_RE.findall(REPORT_FILE.read_text(encoding="utf-8"))]
    return (max(ids) + 1) if ids else 1


def append_report(author, channel, content, msg_id, channel_id=0):
    ensure_file()
    bid = next_id()
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
    body = content.strip().replace("\r", "")
    # ref = <channel_id>/<message_id>: lets the watcher fetch + reply on the original report later
    with REPORT_FILE.open("a", encoding="utf-8") as f:
        f.write(f"### #{bid} · NEW · {ts}\n- **By:** {author}  ·  **Channel:** #{channel}  ·  "
                f"**ref:** {channel_id}/{msg_id}\n\n{body}\n\n---\n\n")
    return bid


def append_feature(acceptor, channel, feat_author, feat_text, discussion):
    # !accept: copy an accepted feature + its discussion into features.md
    FEATURES_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not FEATURES_FILE.exists():
        FEATURES_FILE.write_text("# LooneyBin — Feature / Requirements Backlog\n\n", encoding="utf-8")
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
    summary = ((feat_text or "").strip().splitlines() or ["(feature)"])[0][:80]
    out = [f"\n## [ACCEPTED {ts}] {summary}",
           f"- **Accepted by:** {acceptor}  ·  **From:** #{channel}",
           f"- **Feature** ({feat_author or 'n/a'}): {(feat_text or '').strip()}", ""]
    if discussion:
        out.append("**Discussion:**")
        out += [f"> {d}" for d in discussion]
        out.append("")
    out.append("---\n")
    with FEATURES_FILE.open("a", encoding="utf-8") as f:
        f.write("\n".join(out))


def scan_state():
    ensure_file()
    state = {}
    for bid, status, by, body in ENTRY_RE.findall(REPORT_FILE.read_text(encoding="utf-8")):
        first = (body.strip().splitlines() or ["(empty)"])[0][:140]
        state[int(bid)] = (status.upper(), by.strip(), first)
    return state


def scan_refs():
    # {bug_id: (channel_id, message_id)} for entries that carry a **ref:**
    ensure_file()
    out = {}
    for bid, cid, mid in REF_RE.findall(REPORT_FILE.read_text(encoding="utf-8")):
        out[int(bid)] = (int(cid), int(mid))
    return out


def scan_asks():
    # {bug_id: question} from any '> ask: ...' line in an entry body (custom NEEDINFO prompt)
    ensure_file()
    out = {}
    for bid, _status, _by, body in ENTRY_RE.findall(REPORT_FILE.read_text(encoding="utf-8")):
        m = re.search(r"^> ask: ?(.+)$", body, re.M)
        if m:
            out[int(bid)] = m.group(1).strip()
    return out


def list_open():
    return [f"#{b} [{s}] {by}: {first}"
            for b, (s, by, first) in sorted(scan_state().items()) if s in OPEN_STATES]


def set_status(bid, status):
    ensure_file()
    text = REPORT_FILE.read_text(encoding="utf-8")
    pat = re.compile(rf"^(### #{bid} · )(\w+)( · )", re.M)
    if not pat.search(text):
        return False
    REPORT_FILE.write_text(pat.sub(rf"\g<1>{status}\g<3>", text, count=1), encoding="utf-8")
    return True


intents = discord.Intents.default()
intents.message_content = True
if MEMBERS_INTENT:                 # see MEMBERS_INTENT above -- portal switch must be ON first
    intents.members = True
client = discord.Client(intents=intents)
_known = {}
_active_reports = set()      # discord user ids with a !report DM wizard in flight (one at a time each)


@tasks.loop(seconds=3.0)
async def watcher():
    # OUTBOX: generic file bridge -- any tool drops outbox/*.json {"channel_id": int, "content": str}
    # and the bot posts it then deletes the file (used by deploy/gen_patchnotes.py for per-pack notes).
    try:
        _outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "outbox")
        if os.path.isdir(_outdir):
            for _fn in sorted(os.listdir(_outdir)):
                if not _fn.endswith(".json"):
                    continue
                _p = os.path.join(_outdir, _fn)
                try:
                    with open(_p, "r", encoding="utf-8") as _fh:
                        _job = json.load(_fh)
                    # target: a user DM (user_id) takes precedence over a channel (channel_id). discord.User
                    # has .send() like a channel, so the rest of the code is unchanged.
                    _dm_uid = int(_job.get("user_id") or 0)
                    if _dm_uid:
                        _tgt = client.get_user(_dm_uid)
                        if _tgt is None:
                            try:
                                _tgt = await client.fetch_user(_dm_uid)
                            except Exception:
                                _tgt = None
                    else:
                        _tgt = client.get_channel(int(_job.get("channel_id") or 0))
                    _body = str(_job.get("content") or "").strip()
                    if _tgt is not None and _body:
                        # optional: delete the bot's own recent messages first (clean re-post)
                        _purge = int(_job.get("purge_bot") or 0)
                        if _purge > 0:
                            try:
                                async for _m in _tgt.history(limit=40):
                                    if _m.author.id == client.user.id:
                                        await _m.delete()
                                        _purge -= 1
                                        if _purge <= 0:
                                            break
                            except Exception:
                                pass
                        # optional: silent (SUPPRESS_NOTIFICATIONS push) + no_ping (never @-mention)
                        _kw = {"silent": bool(_job.get("silent"))}
                        if _job.get("no_ping"):
                            _kw["allowed_mentions"] = discord.AllowedMentions.none()
                        for _i in range(0, len(_body), 1900):
                            await _tgt.send(_body[_i:_i + 1900], **_kw)
                        os.remove(_p)
                    elif not _body:
                        os.remove(_p)
                    # unknown channel: leave the file, retried next tick (bot may still be caching)
                except Exception:
                    pass
    except Exception:
        pass
    chan = client.get_channel(STATUS_CHANNEL_ID) if STATUS_CHANNEL_ID else None
    try:
        state = scan_state()
    except Exception:
        return
    for bid, (status, by, first) in sorted(state.items()):
        prev = _known.get(bid)
        if prev == status:
            continue
        if chan is not None:
            if prev is None:
                await chan.send(f"\U0001F41B **Bug #{bid}** logged — {by}: {first}")
            else:
                await chan.send(f"{STATUS_EMOJI.get(status, '•')} **Bug #{bid}** → **{status}** — {by}: {first}")
        # auto-reply in the reporter's thread as the bug moves through the workflow (prev not None = we saw
        # it open first, so a logged-then-resolved-while-offline bug won't get a stale ping on restart):
        #   STAGED -> fix written, goes live next restart   |   FIXED -> deployed/live, ask them to re-test
        if status == "STAGED" and prev is not None:
            await _reply_on_report(bid, STAGED_MSG, ping=True)
        elif status == "FIXED" and prev is not None:
            await _reply_on_report(bid, LIVE_MSG, ping=True)
        # ask the reporter for more detail when a bug flips to NEEDINFO (custom '> ask:' text or default)
        elif status == "NEEDINFO" and prev is not None:
            await _reply_on_report(bid, scan_asks().get(bid) or DEFAULT_ASK, ping=True)
        _known[bid] = status


@watcher.before_loop
async def _snapshot():
    await client.wait_until_ready()
    global _known
    _known = {bid: v[0] for bid, v in scan_state().items()}


def _logged_msgids():
    return {mid for (_cid, mid) in scan_refs().values()}


def _report_text(title, body):
    # combine a forum post's title + starter-message body into one report line
    return " — ".join([p for p in ((title or "").strip(), (body or "").strip()) if p])


async def _forum_threads(ch):
    # active (gateway-synced) + archived forum posts, de-duplicated, as one flat list
    threads, seen = [], set()
    for t in list(getattr(ch, "threads", [])):
        if t.id not in seen:
            seen.add(t.id); threads.append(t)
    try:
        async for t in ch.archived_threads(limit=300):
            if t.id not in seen:
                seen.add(t.id); threads.append(t)
    except discord.DiscordException:
        pass
    return threads


async def _starter_of(thread):
    # a forum post's first message; its id == the thread id
    try:
        return thread.starter_message or await thread.fetch_message(thread.id)
    except discord.DiscordException:
        return None


async def _backfill_intake():
    # On startup, ingest pre-existing reports in the intake channel that aren't logged yet. Dedup on
    # stored msg-id refs (safe every boot). Backfilled reports get a quiet ✅ (no per-message "received"
    # reply); the watcher snapshot suppresses per-bug status spam (we post one summary). Refs ARE stored,
    # so "fixed please test again" still works. Handles a FORUM channel (each post = a thread, report =
    # title + starter body) and a plain text channel (each message = a report).
    if not BUG_CHANNEL_ID:
        return
    ch = client.get_channel(BUG_CHANNEL_ID)
    if ch is None:
        try:
            ch = await client.fetch_channel(BUG_CHANNEL_ID)
        except discord.DiscordException:
            return
    logged = _logged_msgids()
    cname = getattr(ch, "name", "intake")
    new_bids = []

    if isinstance(ch, discord.ForumChannel):
        for t in await _forum_threads(ch):
            if t.id in logged:                  # a post's stored msg_id == its thread id
                continue
            starter = await _starter_of(t)
            author = str(getattr(t, "owner", None) or (starter.author if starter else "unknown"))
            text = _report_text(t.name, starter.content if starter else "") or "(no text)"
            bid = append_report(author, cname, text, t.id, t.id)
            new_bids.append(bid)
            if starter is not None:
                try:
                    await starter.add_reaction("✅")
                except discord.DiscordException:
                    pass
    else:
        try:
            history = [m async for m in ch.history(limit=500, oldest_first=True)]
        except (discord.DiscordException, AttributeError) as e:
            print(f"backfill: cannot read {BUG_CHANNEL_ID} ({e})")
            return
        for m in history:
            if m.author.bot or m.id in logged:
                continue
            body = (m.content or "").strip()
            if not body or body.startswith(PREFIX):   # skip empties + commands
                continue
            bid = append_report(str(m.author), cname, body, m.id, ch.id)
            new_bids.append(bid)
            try:
                await m.add_reaction("✅")
            except discord.DiscordException:
                pass

    if new_bids:
        rng = f"#{new_bids[0]}" if len(new_bids) == 1 else f"#{new_bids[0]}–#{new_bids[-1]}"
        print(f"backfill: logged {len(new_bids)} existing report(s) {rng}")
        st = client.get_channel(STATUS_CHANNEL_ID) if STATUS_CHANNEL_ID else None
        if st is not None:
            await st.send(f"\U0001F4E5 Backfilled **{len(new_bids)}** existing report(s) from "
                          f"#{cname} ({rng}). Use `!bugs` to list.")


@client.event
async def on_ready():
    print(f"LoonyBot online as {client.user} | intake {BUG_CHANNEL_ID} | admin {ADMIN_CHANNEL_ID} | "
          f"db {'on' if DBX else 'off'} | owners {len(OWNER_IDS)}")
    # backfill BEFORE the watcher starts: its before_loop snapshot then sees the backfilled bugs as
    # already-known, so they don't each spam the status channel as "newly logged".
    try:
        await _backfill_intake()
    except Exception as e:
        print(f"backfill error: {type(e).__name__}: {e}")
    try:
        await _sweep_beta_links()
    except Exception as e:
        print(f"beta-sweep error: {type(e).__name__}: {e}")
    if not watcher.is_running():
        watcher.start()
    if not ticket_notifier.is_running():
        ticket_notifier.start()


@client.event
async def on_thread_create(thread):
    # a new forum post in the intake channel = a new bug report. Forum starter messages live on the
    # THREAD (channel.id != BUG_CHANNEL_ID), so they don't hit on_message's text-channel intake branch —
    # capture them here. Fires only while online; older posts are handled by _backfill_intake on startup.
    if not BUG_CHANNEL_ID or getattr(thread, "parent_id", None) != BUG_CHANNEL_ID:
        return
    if getattr(thread, "type", None) == discord.ChannelType.private_thread:
        return                                   # a !report private thread, not a manual bug post — skip
    if thread.id in _logged_msgids():            # already logged (e.g. by an earlier backfill)
        return
    starter = await _starter_of(thread)
    if starter is None:                          # starter can lag the thread-create event; brief retry
        await asyncio.sleep(2)
        starter = await _starter_of(thread)
    author = str(getattr(thread, "owner", None) or (starter.author if starter else "unknown"))
    text = _report_text(thread.name, starter.content if starter else "")
    if not text:
        return
    bid = append_report(author, getattr(thread, "name", "post"), text, thread.id, thread.id)
    if starter is not None:
        await _ack(starter, bid)                 # ✅ + "received" reply in-thread
    else:
        try:
            await thread.send(f"received — bug #{bid}")
        except discord.DiscordException:
            pass


def is_admin(uid):
    return uid in OWNER_IDS

# Discord roles allowed to use JUST !whitelist/!wl (owner request 2026-06-12): high-command MaxSec/TT.
# Case-insensitive match on role NAME; override list via config.json "whitelist_role_names".
# ("Seargant" kept as alias in case the guild role carries the misspelling.)
WL_ROLE_NAMES = {r.strip().lower() for r in CFG.get("whitelist_role_names",
    ["Captain", "Lieutenant", "Sergeant", "Seargant", "Paramedic Assistant Chief"])}

def can_whitelist(member):
    """owners always; otherwise any guild role whose name is in WL_ROLE_NAMES."""
    if is_admin(member.id):
        return True
    roles = getattr(member, "roles", None) or []
    return any((getattr(r, "name", "") or "").lower() in WL_ROLE_NAMES for r in roles)

# Discord roles allowed to use the general admin commands (incl. !comp) without being in owner_ids
# (owner request 2026-06-13: "Admin role can't issue !comp"). Owner-only commands below stay restricted.
# Override the role list via config.json "admin_role_names".
ADMIN_ROLE_NAMES = {r.strip().lower() for r in CFG.get("admin_role_names",
    ["Admin", "Senior Admin", "Head Admin", "Owner"])}
OWNER_ONLY_CMDS = {"addperms", "removeperms", "perms", "srv"}   # bot-perm mgmt + server control: owners only

def is_staff(member):
    """owners always; otherwise any guild role whose name is in ADMIN_ROLE_NAMES."""
    if is_admin(getattr(member, "id", 0)):
        return True
    roles = getattr(member, "roles", None) or []
    return any((getattr(r, "name", "") or "").lower() in ADMIN_ROLE_NAMES for r in roles)

# FULL loonybot perms (owner request 2026-06-16): a guild ROLE that grants the SAME access as owner_ids --
# every command incl. the owner-only ones (srv / perms / bug+feature mgmt). By ROLE ID (survives a rename).
FULL_ROLE_IDS = {int(x) for x in CFG.get("full_role_ids", [100000000000000981])}

def is_full(member):
    """True for config owners OR anyone holding a FULL_ROLE_IDS role = full owner-tier perms. Safe on a bare
    DM User (no .roles) -> falls back to the owner_ids check; use a resolved Member for role-based access."""
    if is_admin(getattr(member, "id", 0)):
        return True
    return any(getattr(r, "id", 0) in FULL_ROLE_IDS for r in (getattr(member, "roles", None) or []))

# Discord MOD roles (owner request 2026-06-15): a tier below admin. Mods may run MOD_CMDS only
# (moderation + lookups), NOT srv/perms/whitelist. Override via config.json "mod_role_names" (by NAME) and/or
# "mod_role_ids" (by ROLE ID -- survives a role rename). Owner request 2026-06-15: role 100000000000000982.
MOD_ROLE_NAMES = {r.strip().lower() for r in CFG.get("mod_role_names", ["Mod", "Moderator"])}
MOD_ROLE_IDS = {int(x) for x in CFG.get("mod_role_ids", [100000000000000982])}
MOD_CMDS = {"kick", "ban", "comp", "pid", "dpid", "alts"}   # the commands a Mod-role member may use

def is_mod(member):
    """owners + admins (is_staff) always; otherwise any guild role whose NAME is in MOD_ROLE_NAMES or whose
    ID is in MOD_ROLE_IDS."""
    if is_staff(member):
        return True
    roles = getattr(member, "roles", None) or []
    return any(((getattr(r, "name", "") or "").lower() in MOD_ROLE_NAMES) or (getattr(r, "id", 0) in MOD_ROLE_IDS) for r in roles)


async def _resolve_member(uid):
    """In a DM `message.author` is a plain User (no `.roles`) -> role-based gating (is_staff/can_whitelist)
    can't see the user's server roles. Find the Member across the bot's guilds so DM admins resolve.
    `fetch_member` is an HTTP API call -> works WITHOUT the privileged members intent (get_member needs cache)."""
    for g in client.guilds:
        m = g.get_member(uid)
        if m is not None:
            return m
        try:
            return await g.fetch_member(uid)
        except discord.DiscordException:
            continue
    return None


def save_owner_ids():
    """Persist OWNER_IDS to config.json, preserving the rest of the file. Re-reads from disk so we
    never rewrite the env-resolved token over a placeholder."""
    try:
        cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except Exception:
        return False
    cfg["owner_ids"] = sorted(OWNER_IDS)
    try:
        CONFIG_PATH.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
        return True
    except Exception:
        return False


def parse_discord_id(s):
    """Accept a raw snowflake or a <@id> / <@!id> mention -> digit string, else None."""
    s = (s or "").strip().lstrip("<@!").rstrip(">")
    return s if (s.isdigit() and 15 <= len(s) <= 21) else None


async def _ack(message, bid):
    # tick + a "received" reply on the report itself (no ping — just an ack)
    try:
        await message.add_reaction("✅")
    except discord.DiscordException:
        pass
    try:
        await message.reply(f"received — bug #{bid}", mention_author=False)
    except discord.DiscordException:
        await message.channel.send(f"received — bug #{bid}")


async def _reply_on_report(bid, text, ping=False):
    # Reply on the bug's report thread/message via its stored ref. The ref is `channel_id/message_id`, but
    # for a FORUM post (the #loonybot-bug-reports forum, parent 100000000000000099) the report lives in a
    # THREAD whose id == the post's starter message id, while the stored channel_id is the forum PARENT --
    # which has NO fetchable message, so the old `parent.fetch_message(mid)` always failed and the staged/
    # live notice never posted. Resolve the thread instead: try `mid` (forum post id == thread id), then
    # `cid` (wizard threads store the thread as channel_id); reply IN the thread to the report message,
    # falling back to the thread starter, then a plain send. Plain text channels still work via the last leg.
    ref = scan_refs().get(bid)
    if not ref:
        return False
    cid, mid = ref
    for tid in (mid, cid):
        ch = client.get_channel(tid)
        if ch is None:
            try:
                ch = await client.fetch_channel(tid)
            except discord.DiscordException:
                continue
        if ch is None:
            continue
        if isinstance(ch, discord.Thread):
            target = None
            for m_id in (mid, ch.id):          # prefer the actual report msg, else the thread starter
                try:
                    target = await ch.fetch_message(m_id)
                    break
                except discord.DiscordException:
                    target = None
            try:
                if target is not None:
                    await target.reply(text, mention_author=ping)
                else:
                    await ch.send(text)
                return True
            except discord.DiscordException:
                continue
        # plain text channel: the stored message lives directly here
        try:
            msg = await ch.fetch_message(mid)
            await msg.reply(text, mention_author=ping)
            return True
        except discord.DiscordException:
            continue
    return False


async def handle_admin(cmd, arg, message):
    send = message.channel.send
    a = arg.split()

    if cmd == "help":
        for _part in HELP_PARTS:
            await send(_part)
        return

    if cmd in ("addperms", "removeperms"):
        if not a:
            await send(f"Usage: `{PREFIX}{cmd} <discord id or @mention>`"); return
        uid = parse_discord_id(a[0])
        if uid is None:
            await send("Not a valid Discord ID (17–19 digit number or an @mention)."); return
        uid = int(uid)
        if cmd == "addperms":
            if uid in OWNER_IDS:
                await send(f"`{uid}` already has bot perms."); return
            OWNER_IDS.add(uid)
            if not save_owner_ids():
                OWNER_IDS.discard(uid)
                await send("⛔ Couldn't write config.json — not added."); return
            await send(f"✅ Granted bot perms to `{uid}`. They can use admin commands in this channel.")
        else:  # removeperms
            if uid not in OWNER_IDS:
                await send(f"`{uid}` doesn't have bot perms."); return
            if uid == message.author.id:
                await send("⛔ Refusing to remove your own perms."); return
            if uid in PROTECTED_OWNERS:
                await send(f"⛔ `{uid}` is a founding owner (config.json) — can't be removed here."); return
            OWNER_IDS.discard(uid)
            if not save_owner_ids():
                OWNER_IDS.add(uid)
                await send("⛔ Couldn't write config.json — not removed."); return
            await send(f"✅ Removed bot perms from `{uid}`.")
        return

    if cmd == "perms":
        if not OWNER_IDS:
            await send("No one has bot perms."); return
        lst = "\n".join(f"  {u}{' (founder)' if u in PROTECTED_OWNERS else ''}" for u in sorted(OWNER_IDS))
        await send(f"**Bot perms ({len(OWNER_IDS)}):**\n```\n{lst}\n```"); return

    if DBX is None and cmd in ("info", "pid", "whitelist", "wl", "comp", "logs", "casinoban"):
        await send("DB not configured."); return

    if cmd == "info":
        if not a or not admin.valid_pid(a[0]):
            await send("Usage: `!info <17-digit pid>`"); return
        d = await asyncio.to_thread(DBX.info, a[0])
        await send(admin.fmt_info(d) if d else "No such player.")
        return

    if cmd == "pid":
        if not a:
            await send("Usage: `!pid <in-game name>`  (Discord lookup: `!dpid <@mention|id|name>`)"); return
        if a[0].isdigit() and len(a[0]) >= 17:
            await send("That's a PID already. For a Discord account use `!dpid <@mention|id|name>`."); return
        rows = await asyncio.to_thread(DBX.pid_by_name, arg.strip())
        await send(admin.fmt_pid(rows))
        return

    if cmd == "alts":
        # List members whose Discord ACCOUNT is younger than N days (default ~4 months). Alts have been
        # brigading members to Discord's report system for TOS timeouts, so staff need to see who is new.
        # Join date is shown alongside because a brigade usually arrives in a cluster -- five 2-month-old
        # accounts that all joined the same afternoon is the pattern, not the ages on their own.
        days = NEW_ACCOUNT_DAYS
        if a:
            try:
                days = float(a[0])
            except ValueError:
                await send(f"Usage: `{PREFIX}alts [days]` — default {NEW_ACCOUNT_DAYS:g} (~4 months)."); return
        g = message.guild
        if g is None:
            await send("Run this in the server, not a DM."); return

        members = [m for m in g.members if not getattr(m, "bot", False)]
        total = g.member_count or 0
        # Without the privileged Members intent guild.members is just whoever the bot has happened to
        # see. Reporting "none found" off a partial cache would be worse than useless here, so say it.
        partial = (not MEMBERS_INTENT) or (total > len(members) + 5)

        rows = []
        for m in members:
            try:
                age = account_age_days(m.id)
            except Exception:
                continue
            if age < days:
                rows.append((age, m))
        rows.sort(key=lambda r: r[0])                     # newest account first

        head = f"**{len(rows)}** account(s) newer than **{days:g} d** — scanned {len(members)}"
        head += f" of {total} members." if total else " members."
        out = [head]
        for age, m in rows[:30]:
            j = getattr(m, "joined_at", None)
            jtxt = f" · joined {j:%Y-%m-%d}" if j else ""
            out.append(f"• `{m}` — account **{_fmt_age(age)}** old "
                       f"({account_created_at(m.id):%Y-%m-%d}){jtxt} · `{m.id}`")
        if len(rows) > 30:
            out.append(f"… and {len(rows)-30} more — narrow it with `{PREFIX}alts <days>`.")
        if partial:
            out.append("\n⚠️ **Incomplete scan.** The Server Members Intent is off, so this only covered "
                       "members the bot has already seen — the real number is probably higher. Fix: enable "
                       "*Server Members Intent* in the Discord Developer Portal (Bot → Privileged Gateway "
                       "Intents), then set `\"members_intent\": true` in config.json and restart. Do the "
                       "portal switch FIRST or the bot will refuse to start.")
        msg = "\n".join(out)
        for i in range(0, len(msg), 1900):
            await send(msg[i:i+1900])
        return

    if cmd == "dpid":
        # PID from a Discord identity: @mention, raw discord id, or name/nick.
        target_id = None
        if message.mentions:
            target_id = message.mentions[0].id
        elif a and a[0].isdigit() and len(a[0]) >= 17:
            target_id = int(a[0])
        elif arg.strip() and message.guild is not None:
            q = arg.strip().lstrip("@")
            try:
                found = await message.guild.query_members(query=q, limit=5)
            except Exception:
                found = []
            if len(found) == 1:
                target_id = found[0].id
            elif len(found) > 1:
                await send("Multiple matches — narrow it or use the id/@mention:\n" +
                           "\n".join(f"• {m.display_name} (`{m.id}`)" for m in found)); return
            else:
                await send(f"No Discord member matching `{q}`."); return
        if target_id is None:
            await send("Usage: `!dpid <@mention | discord-id | name>`"); return
        row = await asyncio.to_thread(DBX.link_by_discord, target_id)
        if row:
            await send(f"<@{target_id}> → PID `{row['playerid']}`")
        else:
            await send(f"<@{target_id}> isn't linked (no `!link` on record).")
        return

    if cmd in ("whitelist", "wl"):
        if len(a) < 3 or not admin.valid_pid(a[0]):
            await send("Usage: `!whitelist <pid> <cop|med|srv> <rank> [maxtac:on|off]`  (`!help` for ranks)"); return
        pid, fac, rank = a[0], a[1].lower(), a[2].lower()
        if fac not in admin.FACTIONS:
            await send("Faction must be `cop`, `med`, or `srv`."); return
        # owner 2026-06-18: cop whitelisting MOVED to Officer Maggot (channel-locked + MaxSec-role-gated). med/srv stay here.
        if fac == "cop":
            await send("🚔 Cop whitelisting moved to **Officer Maggot** — use `!whitelist <pid> <rank>` / `!unwhitelist <pid>` in the MaxSec whitelist channel. (LoonyBot still handles `med`/`srv`.)"); return
        if fac == "srv" and not is_full(message.author):
            await send("⛔ `srv` (staff) whitelisting is owner-only. You can set `cop`/`med` ranks + maxtac."); return
        if rank not in admin.FACTIONS[fac][1]:
            await send(f"Bad rank for {fac}. Valid: {', '.join(admin.FACTIONS[fac][1])}"); return
        ok, msg = await asyncio.to_thread(DBX.set_whitelist, pid, fac, rank)
        # optional 4th arg -> MaxTac whitelist (players.ismaxtac). on/off (forgiving aliases).
        if ok and len(a) > 3:
            tok = a[3].lower()
            if tok in ("on", "1", "true", "yes", "maxtac", "add"):
                _, smsg = await asyncio.to_thread(DBX.set_maxtac, pid, True);  msg += "  ·  " + smsg
            elif tok in ("off", "0", "false", "no", "remove"):
                _, smsg = await asyncio.to_thread(DBX.set_maxtac, pid, False); msg += "  ·  " + smsg
            else:
                msg += f"  ·  ⚠️ ignored maxtac arg `{a[3]}` (use on/off)"
        if ok and await asyncio.to_thread(DBX.is_online, pid):
            msg += "  ⚠️ player is online — they must **relog** to load it."
        await send(("✅ " if ok else "⛔ ") + msg)
        return

    if cmd == "comp":
        if len(a) < 2 or not admin.valid_pid(a[0]) or not a[1].lstrip("+").isdigit():
            await send("Usage: `!comp <pid> <amount>`  (delivered to their in-game mailbox — works online)"); return
        pid, amount = a[0], int(a[1].lstrip("+"))
        # mailbox delivery -> no online check needed; player collects via "Check Mailbox" at the Exchange NPC
        ok, res = await asyncio.to_thread(DBX.comp, pid, amount)
        await send(f"✅ Comp **{admin.fmt_money(amount)}** — {res}" if ok else f"⛔ {res}")
        return

    if cmd == "casinoban":
        # Players self-exclude in-game (phone Settings -> "Casino Ban"). This is the ADMIN undo (+ optional manual ban).
        # `!casinoban <pid>` or `... off` lifts it; `... on` bans. Applies on the player's next connect.
        if not a or not admin.valid_pid(a[0]):
            await send("Usage: `!casinoban <pid> [on|off]`  — lifts a casino self-exclusion (default `off`); `on` bans."); return
        pid = a[0]
        tok = (a[1].lower() if len(a) > 1 else "off")
        on = tok in ("on", "1", "true", "yes", "ban", "add")
        ok, msg = await asyncio.to_thread(DBX.set_casino_ban, pid, on)
        if ok and await asyncio.to_thread(DBX.is_online, pid):
            msg += "  ⚠️ player is online — it applies on their next **relog**."
        await send(("✅ " if ok else "⛔ ") + msg)
        return

    if cmd == "logs":
        if not a or not admin.valid_pid(a[0]):
            await send("Usage: `!logs <17-digit pid>` — DMs you the player's full audit log"); return
        pid = a[0]
        rows = await asyncio.to_thread(DBX.player_logs, pid)
        if not rows:
            await send(f"No log rows for `{pid}`."); return
        lines = [f"LoonyBin audit log — player {pid} — {len(rows)} rows — generated {datetime.datetime.utcnow():%Y-%m-%d %H:%M}Z", "=" * 100]
        for r in rows:
            lines.append(f"#{r['id']:<8} [{r['ts']}] {r['tag']:<18} {r['name']:<24} {r['message'] or ''}")
        path = pathlib.Path(f"/tmp/lb_logs_{pid}.txt")
        path.write_text("\n".join(lines), encoding="utf-8")
        try:
            dm = await message.author.create_dm()
            await dm.send(f"📜 Full audit log for `{pid}` — {len(rows)} rows:",
                          file=discord.File(str(path), filename=f"logs_{pid}.txt"))
            await send(f"✅ DM'd you `{pid}`'s full log ({len(rows)} rows).")
        except discord.DiscordException as e:
            await send(f"⛔ Couldn't DM you (DMs closed?): {e}")
        finally:
            try: path.unlink()
            except OSError: pass
        return

    if cmd in ("kick", "ban"):
        # standalone aliases for `!srv kick|ban` so Mods (no srv access) can moderate. Routes straight to
        # handle_srv's kick/ban path -> never reaches hardr/softr (those need sub == hardr/softr).
        await handle_srv([cmd] + a, message); return

    if cmd == "srv":
        await handle_srv(a, message)
        return


def _server_reboot():
    # Restarts the ARMA SERVER process (not the bot, not the host machine):
    # kill arma3server_x64, then repack PBOs + relaunch via deploy/run-boot2.sh.
    subprocess.Popen(
        ["bash", "-c",
         f'cd "{SERVER_DIR}"; pkill -x arma3server_x64; sleep 1; '
         f'bash deploy/run-boot2.sh > /tmp/lb_boot.log 2>&1'],
        start_new_session=True)


async def handle_srv(a, message):
    send = message.channel.send
    if not a:
        await send("Usage: `!srv <hardr|softr|msg|kick|ban> ...`  (`!help`)"); return
    sub = a[0].lower()
    by = str(message.author)

    if sub == "hardr":
        # owner 2026-06-13: hardr now GRACEFUL-SAVES before the kill (same as softr) so a code-deploy restart
        # no longer loses vehicle positions / live trunks / the last <7min of player progress. Difference vs
        # softr: hardr defaults to no player-warning countdown (immediate). `hardr force` = old behaviour:
        # instant pkill with NO save (emergency only -- use when the server is wedged and a save would hang).
        force = len(a) > 1 and a[1].lower() == "force"
        secs = int(a[1]) if (len(a) > 1 and a[1].isdigit()) else 0
        if force or DBX is None:
            await send("⚠️ **Hard restart (NO SAVE)** — immediate kill + repack + boot. Use only if wedged.")
            _server_reboot()
            await send("🔁 Restarting now."); return
        await send(f"⚠️ **Hard restart** in {secs}s — graceful save (vehicles/positions/players) → repack + boot.")
        if secs > 0:
            await asyncio.to_thread(DBX.queue, "msg", None,
                                    f"SERVER RESTART in {secs}s -- finish up. Progress + vehicles ARE saved.", None, by)
            await asyncio.sleep(secs)
        await asyncio.to_thread(DBX.queue, "gracefulsave", None, None, None, by)
        await send("💾 Saving server state (vehicles, positions, players, storage)...")
        await asyncio.sleep(75)   # save script + 35s extDB3 flush + margin (server marks the row 'saved')
        _server_reboot()
        await send("🔁 Restarting now (state saved). ~READY in a couple minutes.")
        return

    if sub == "softr":
        # owner 2026-06-13: DETERMINISTIC soft restart. Sequence: warn players -> trigger an in-game GRACEFUL
        # SAVE (vehicle_mem incl. trunks + flushAllPlayers + storage) -> wait for the save+flush -> clean
        # process restart (repack + relaunch). On boot, restoreVehicles rebuilds the world so NOTHING is lost.
        # This replaced an endMission/in-place-reload attempt that depended on config-specific dedi mission
        # cycling (unreliable on this headless box: -autoInit, no admin/RCON). Players reconnect from the
        # browser, but their data is fully persisted. (Difference vs `hardr`: softr SAVES first; hardr does not.)
        secs = int(a[1]) if len(a) > 1 and a[1].isdigit() else 60
        if DBX is None:
            await send("DB off — soft restart needs the DB bridge. Use `!srv hardr` instead."); return
        await send(f"🟢 **Soft restart**: warning players {secs}s, then graceful save + clean restart. "
                   f"All data (vehicles incl. trunks, players, houses) persists; players reconnect.")
        await asyncio.to_thread(DBX.queue, "msg", None,
                                f"SERVER RESTART in {secs}s -- finish up. Your progress + vehicles ARE saved.", None, by)
        await asyncio.sleep(secs)
        await asyncio.to_thread(DBX.queue, "gracefulsave", None, None, None, by)
        await send("💾 Saving server state (vehicles, players, storage)...")
        # The server picks up gracefulsave within ~5-10s, runs saveVehicles (the script queues all writes in
        # seconds) + a 35s extDB3 flush, then marks the bot_commands row 'saved'. Worst case (busy server, many
        # vehicles/players) the queue still flushes well inside ~50s. Wait 75s before killing the process so
        # every async write has COMMITTED -- generous margin over the engine's own 35s save-buffer pattern.
        await asyncio.sleep(75)
        _server_reboot()
        await send("🔁 Restarting now (state saved). ~READY in a couple minutes.")
        return

    if sub in ("repacknext", "shipnext", "deploynext"):
        # owner 2026-06-20: ship the staged code at the NEXT NATURAL restart (scheduled 4h / in-game HARD) instead of
        # firing a SEPARATE FORCE_DEPLOY restart on top of it -- no double-restart. Drops the deploy/.repack_on_restart
        # one-shot flag; run-boot2 sees it and repacks that restart (respecting the nightly window + .deploy_freeze, so
        # it waits for the next un-frozen restart rather than surprise-deploying overnight). Bump the version +
        # set deploy/patchnote_override.txt BEFORE the restart, same as any deploy.
        flag = HERE.parent / "deploy" / ".repack_on_restart"
        try:
            flag.touch()
        except Exception as e:
            await send(f"⚠️ couldn't queue repack: `{e}`"); return
        await send("✅ **Repack queued for the next natural restart** — the next scheduled/HARD restart will repack the "
                   "staged code (no separate deploy restart). One-shot; respects the nightly freeze + manual hold.\n"
                   "⚠️ Make sure the version is bumped + `patchnote_override.txt` is set, or it ships the same version with no notes. "
                   "Cancel with `!srv cancelrepack`.")
        return

    if sub in ("cancelrepack", "unrepacknext"):
        flag = HERE.parent / "deploy" / ".repack_on_restart"
        existed = flag.exists()
        flag.unlink(missing_ok=True)
        await send("✅ Cancelled — the next natural restart will reload as-is (no repack)." if existed
                   else "ℹ️ No repack was queued.")
        return

    if DBX is None:
        await send("DB off — `msg/kick/ban` unavailable."); return

    if sub == "msg":
        text = " ".join(a[1:]).strip()
        if not text:
            await send("Usage: `!srv msg <text>`"); return
        await asyncio.to_thread(DBX.queue, "msg", None, text, None, by)
        await send(f"📢 Queued broadcast: _{text}_  (in-game within ~5s)")
        return

    if sub == "kick":
        if len(a) < 2 or not admin.valid_pid(a[1]):
            await send("Usage: `!srv kick <pid>`"); return
        await asyncio.to_thread(DBX.queue, "kick", a[1], None, "Kicked by an admin.", by)
        await send(f"👢 Kick queued for `{a[1]}` — runs within ~5s if online.")
        return

    if sub == "resetfed":
        # owner 2026-06-16: clear a stuck/cooling-down Federal Reserve so players can retry without a reboot.
        await asyncio.to_thread(DBX.queue, "resetfed", None, None, None, by)
        await send("🏦 Federal Reserve lockout reset queued — clears in-game within ~5s (no reboot).")
        return

    if sub == "ban":
        if len(a) < 3 or not admin.valid_pid(a[1]) or not a[2].isdigit():
            await send("Usage: `!srv ban <pid> <days> <reason>`  (0 days = permanent)"); return
        pid, days = a[1], int(a[2])
        reason = " ".join(a[3:]).strip() or "No reason"
        await asyncio.to_thread(DBX.ban, pid, days, reason, by)
        await send(f"🔨 Banned `{pid}` ({'permanent' if days <= 0 else str(days) + 'd'}) — "
                   f"_{reason}_. Kicked if online; blocked on connect.")
        return

    await send("Unknown `!srv` subcommand. See `!help`.")


# ---------------------------------------------------------------------------
# !report — public DM wizard -> PRIVATE thread (each reporter sees only their own)
# ---------------------------------------------------------------------------
class _Cancelled(Exception):
    pass


async def _safe_send(target, text):
    try:
        return await target.send(text)
    except discord.DiscordException:
        return None


async def _ask_dm(dm, user, prompt):
    # post a prompt in the DM, wait for that user's next DM reply. 'cancel' aborts the whole wizard.
    await dm.send(prompt)

    def _chk(m):
        return m.author.id == user.id and m.channel.id == dm.id

    m = await client.wait_for("message", check=_chk, timeout=REPORT_TIMEOUT)
    if (m.content or "").strip().lower() in ("cancel", "!cancel", "stop", "abort"):
        raise _Cancelled
    return m


DISCORD_EPOCH_MS = 1420070400000     # 2015-01-01, the zero point every snowflake counts from


def account_created_at(uid):
    """When a Discord account was made, straight out of its ID. No API call, no intent, no cache --
    the top 42 bits of a snowflake are milliseconds since the Discord epoch."""
    return datetime.datetime.fromtimestamp(
        ((int(uid) >> 22) + DISCORD_EPOCH_MS) / 1000, datetime.timezone.utc)


def account_age_days(uid):
    now = datetime.datetime.now(datetime.timezone.utc)
    return (now - account_created_at(uid)).total_seconds() / 86400.0


def _fmt_age(days):
    if days < 1/24:  return f"{days*1440:.0f} min"
    if days < 1:     return f"{days*24:.1f} h"
    if days < 60:    return f"{days:.1f} d"
    if days < 365:   return f"{days/30.44:.1f} mo"
    return f"{days/365.25:.1f} y"


async def _post_report(channel_id, title, body, user):
    """Post a report into a TEXT channel as its OWN PRIVATE thread. Only the reporter (added below) and
    staff (Manage Threads, + the config owners added below) can see it — other reporters can't see each
    other's threads. The reporter sees their thread even with the channel hidden from @everyone (private-
    thread membership overrides channel visibility).
    Returns (posted_ok:bool, error|None, ref:(channel_id,msg_id)|None) -- the ref lets the status-watcher
    reply 'fixed please test again' back onto the reporter's thread when the bug is later marked FIXED."""
    if not channel_id:
        return False, "no channel configured", None
    ch = client.get_channel(channel_id)
    if ch is None:
        try:
            ch = await client.fetch_channel(channel_id)
        except discord.DiscordException as e:
            return False, f"channel unreachable ({type(e).__name__})", None
    title = (title or "Report")[:200]
    # owner 2026-06-15: attach the reporter's LINKED player id (PID) to the report so staff can comp without
    # a separate !dpid lookup. Same resolve the !dpid command uses; silent if DB is down or they never !link'd.
    pid_line = ""
    try:
        if DBX is not None:
            _lk = await asyncio.to_thread(DBX.link_by_discord, getattr(user, "id", 0))
            if _lk and _lk.get("playerid"):
                pid_line = f"**Reporter PID:** `{_lk['playerid']}`\n"
            else:
                pid_line = "**Reporter PID:** _not linked (no `!link` on record)_\n"
    except Exception:
        pid_line = ""
    body = f"{pid_line}{body}"
    # staff ping: resolve configured role NAMES against this guild + any single role id. Bot needs
    # "Mention @everyone, @here and All Roles" (or the roles set mentionable) to actually ping them.
    pings = []
    g = getattr(ch, "guild", None)
    if g is not None:
        for nm in REPORT_STAFF_ROLES:
            r = discord.utils.get(g.roles, name=nm)
            if r is not None:
                pings.append(r.mention)
    if REPORT_STAFF_ROLE_ID:
        pings.append(f"<@&{REPORT_STAFF_ROLE_ID}>")
    # bug-only extra ping(s): only when this report is going to the bug/exploit channel
    if channel_id == REPORT_BUG_CHANNEL_ID:
        for _rid in REPORT_BUG_ROLE_IDS:
            pings.append(f"<@&{_rid}>")
    head = (" ".join(pings) + "\n") if pings else ""
    am = discord.AllowedMentions(roles=True, users=False)
    try:
        if isinstance(ch, discord.ForumChannel):          # forum: each report = a forum post
            _tm = await ch.create_thread(name=title[:100], content=f"{head}{body}"[:1990])
            _t = getattr(_tm, "thread", None); _m = getattr(_tm, "message", None)
            return True, None, ((_t.id, _m.id) if (_t and _m) else None)
        if isinstance(ch, discord.TextChannel):           # text: each report = a PRIVATE thread
            thread = await ch.create_thread(
                name=title[:100], type=discord.ChannelType.private_thread,
                invitable=False, auto_archive_duration=10080)
            # reporter -> sees ONLY their own thread (membership works even though the channel is hidden FROM
            # them by a thread invite). owner 2026-06-15: but a thread member must be able to VIEW the parent
            # channel -- on a STAFF-ONLY channel (e.g. player-reports, @everyone denied View) the reporter
            # can't be added -> 403 "Missing Access" which used to ABORT the whole post. Make it NON-FATAL: the
            # report still lands in the staff thread; the reporter just isn't added (correct for a channel they
            # aren't meant to see). On the bug-reports channel the add still succeeds, so they see their thread.
            try:
                await thread.add_user(user)
            except discord.DiscordException:
                try:
                    await thread.add_user(discord.Object(id=getattr(user, "id", 0)))
                except discord.DiscordException:
                    pass
            # config owners always added (guaranteed visibility); broader staff roles see all private
            # threads via the Manage Threads permission (a role can't be added to a thread).
            for _oid in OWNER_IDS:
                if _oid != getattr(user, "id", 0):
                    try:
                        await thread.add_user(discord.Object(id=_oid))
                    except discord.DiscordException:
                        pass
            _rm = await thread.send(f"{head}{body}"[:1990], allowed_mentions=am)
            return True, None, (thread.id, _rm.id)
        _rm = await ch.send(f"{head}**{title}**\n{body}"[:1990], allowed_mentions=am)   # fallback
        return True, None, (ch.id, _rm.id)
    except discord.DiscordException as e:
        return False, f"{type(e).__name__}: {e}", None


async def _report_flow(user, dm):
    # 1/4 — report type
    prompt = ("**LooneyBin Report — Step 1 of 4: Report Type**\n"
              "> Reply **1** for `Bug / Exploit`\n"
              "> Reply **2** for `Player Report`")
    picked = None
    for _ in range(3):
        sel = (await _ask_dm(dm, user, prompt)).content.strip().lower()
        if sel in ("1", "bug", "exploit", "bug/exploit", "bug / exploit"):
            picked = ("bug", "Bug / Exploit", REPORT_BUG_CHANNEL_ID); break
        if sel in ("2", "player", "player report", "report"):
            picked = ("player", "Player Report", REPORT_PLAYER_CHANNEL_ID); break
        prompt = "Didn't catch that — reply **1** (Bug/Exploit) or **2** (Player Report). `cancel` to stop."
    if picked is None:
        raise _Cancelled
    code, rlabel, channel_id = picked

    # 2/4 — date/time
    when = (await _ask_dm(dm, user,
            "**Step 2 of 4: Date / Time**\n> When did it happen? (e.g. `2026-06-09 21:30 UTC`, or `just now`)")
            ).content.strip()
    # 3/4 — description
    desc = (await _ask_dm(dm, user,
            "**Step 3 of 4: Description**\n"
            + ("> Describe the exploit / bug and exactly how to trigger it — be specific."
               if code == "bug" else
               "> Who are you reporting, what rule did they break, and what happened?"))
            ).content.strip()
    # 4/4 — evidence (text + any attachments dropped in the DM)
    ev_msg = await _ask_dm(dm, user,
             "**Step 4 of 4: Evidence**\n> Paste links (clips / screenshots) or describe what you have — "
             "you can also attach images here. Reply `none` if you have nothing.")
    evidence = ev_msg.content.strip()
    if ev_msg.attachments:
        evidence = (evidence + "\n" + "\n".join(a.url for a in ev_msg.attachments)).strip()
    if evidence.lower() in ("none", "n/a", "na", ""):
        evidence = "_none provided_"

    # build + post
    tag = "BUG/EXPLOIT" if code == "bug" else "PLAYER REPORT"
    dname = getattr(user, "display_name", None) or getattr(user, "name", "player")
    short = re.sub(r"\s+", " ", desc)[:50].strip()
    title = f"[{tag}] {dname}" + (f" — {short}" if short else "")
    body = (
        f"**Report Type:** {rlabel}\n"
        f"**Reporter:** {getattr(user, 'mention', dname)} (`{user}` · `{user.id}`)\n"
        f"**Date / Time:** {when or 'n/a'}\n\n"
        f"**Description of event / rule broken:**\n{desc or 'n/a'}\n\n"
        f"**Evidence:**\n{evidence}\n")

    ok, err, ref = await _post_report(channel_id, title, body, user)
    # ALSO log BUG/EXPLOIT reports into BUGS.md. The wizard previously only posted to Discord -> bugs filed
    # through !report never reached the tracker (the shed-transfer bug got lost this way). Record the posted
    # thread's ref (channel_id/msg_id) so the status-watcher can reply "fixed please test again" straight back
    # into the reporter's thread when the bug is marked FIXED in BUGS.md. If the post failed (ref None) we
    # still log it (ref 0/<dm-evidence-id>) so the bug is never lost -- it just won't get the auto-reply.
    # Player reports stay Discord-only (not code bugs).
    if code == "bug":
        try:
            _cid, _mid = ref if ref else (0, getattr(ev_msg, "id", 0))
            _bid = append_report(str(user), "report", body, _mid, _cid)
            print(f"[report] logged BUGS.md #{_bid} from {user} ref={_cid}/{_mid}")
        except Exception as e:
            print(f"[report] BUGS.md append FAILED: {type(e).__name__}: {e}")

    if ok:
        await _safe_send(dm, f"✅ Your **{rlabel}** report was submitted — staff will review it. Thank you.")
    else:
        # posting failed -> don't lose the report: route it to the staff/status channel
        await _safe_send(dm, f"✅ Got your **{rlabel}** report — staff have been notified.")
        st = client.get_channel(STATUS_CHANNEL_ID) if STATUS_CHANNEL_ID else None
        if st:
            await _safe_send(st, f"⚠️ **{rlabel}** from `{user}` couldn't post to <#{channel_id}> ({err}). "
                                 f"Raw report:\n>>> {body[:1700]}")
        else:
            print(f"report post failed, no status channel: {err}\n{body}")


async def start_report(message):
    user = message.author
    if user.id in _active_reports:
        await _safe_send(message.channel, f"{user.mention} you already have a report open — check your DMs.")
        return
    # open the DM first so closed-DM users are caught before we ack in-channel
    try:
        dm = user.dm_channel or await user.create_dm()
        await dm.send("📋 **LooneyBin Report** — I'll ask 4 quick questions. Reply `cancel` anytime to stop.")
    except discord.DiscordException:
        await _safe_send(message.channel,
                         f"{user.mention} I can't DM you. Enable **Direct Messages** for this server "
                         f"(Privacy & Safety settings), then run `{PREFIX}report` again.")
        return
    if not isinstance(message.channel, discord.DMChannel):
        await _safe_send(message.channel, f"📬 {user.mention} check your DMs — I'll walk you through it.")
    _active_reports.add(user.id)
    try:
        await _report_flow(user, dm)
    except asyncio.TimeoutError:
        await _safe_send(dm, "⏳ Timed out — no reply for 5 minutes. Run `!report` again to restart.")
    except _Cancelled:
        await _safe_send(dm, "❌ Report cancelled. Run `!report` to start over.")
    except Exception as e:
        print(f"report wizard error: {type(e).__name__}: {e}")
        await _safe_send(dm, f"⚠️ Something went wrong building your report (`{type(e).__name__}`). "
                             f"Try `{PREFIX}report` again.")
    finally:
        _active_reports.discard(user.id)


# ---------------------------------------------------------------------------
# Support tickets over Discord (owner 2026-07-05): DM the linked owner when staff
# reply on the website, and let a linked owner reply to their ticket by DMing the bot.
# ---------------------------------------------------------------------------
_TICKET_STATE = str(HERE / "ticket_notify_state.json")

def _ticket_cursor():
    try:
        return int(json.load(open(_TICKET_STATE)).get("last_msg_id", 0))
    except Exception:
        return 0

def _save_ticket_cursor(v):
    try:
        json.dump({"last_msg_id": int(v)}, open(_TICKET_STATE, "w"))
    except Exception:
        pass

async def _dm_user(did, content):
    try:
        u = client.get_user(int(did)) or await client.fetch_user(int(did))
        if not u:
            return False
        for i in range(0, len(content), 1900):
            await u.send(content[i:i + 1900])
        return True
    except Exception as e:
        print(f"[ticket-notify] DM to {did} failed: {type(e).__name__}: {e}", flush=True)
        return False

@tasks.loop(seconds=15.0)
async def ticket_notifier():
    if DBX is None:
        return
    try:
        last = _ticket_cursor()
        rows = await asyncio.to_thread(DBX.ticket_new_staff_replies, last)
        for r in rows:
            link = await asyncio.to_thread(DBX.link_by_pid, r["playerid"])
            did = (link or {}).get("discord_id")
            if did:
                snippet = re.sub(r"\s+", " ", (r["body"] or "")).strip()[:280]
                body = (f":envelope_with_arrow: **Staff replied to your ticket #{r['ticket_id']}** — {str(r['subject'])[:80]}\n"
                        f"> {snippet}\n\nReply here to respond, or `{PREFIX}reply {r['ticket_id']} <message>`.")
                await _dm_user(did, body)
            _save_ticket_cursor(r["id"])
    except Exception as e:
        print(f"[ticket-notify] poll error: {type(e).__name__}: {e}", flush=True)

@ticket_notifier.before_loop
async def _ticket_before():
    await client.wait_until_ready()
    if not os.path.exists(_TICKET_STATE) and DBX is not None:
        try:
            _save_ticket_cursor(await asyncio.to_thread(DBX.ticket_max_msg_id))
        except Exception:
            pass

# A Discord-LINKED player can reply to their own website support ticket by DMing the bot.
#   !tickets  -> list open tickets ; !reply <id> <msg> -> reply ; <plain DM> -> single open ticket.
# Returns True if handled (on_message stops), False to fall through (unlinked non-ticket DMs, bot cmds).
async def handle_ticket_dm(message, content):
    if DBX is None:
        return False
    low = content.lower()
    is_ticket_cmd = low.startswith((PREFIX + "reply", PREFIX + "ticket", PREFIX + "tickets", PREFIX + "mytickets"))
    if content.startswith(PREFIX) and not is_ticket_cmd:
        return False
    if not content:
        return False

    link = await asyncio.to_thread(DBX.link_by_discord, message.author.id)
    pid = (link or {}).get("playerid")
    if not pid:
        if is_ticket_cmd:
            await message.channel.send(f"Your Discord isn't linked yet — use `{PREFIX}link` in the server first, then you can reply to tickets here.")
            return True
        return False

    name = await asyncio.to_thread(DBX.ticket_player_name, pid)

    if low.startswith((PREFIX + "tickets", PREFIX + "mytickets")) or low.strip() == PREFIX + "ticket":
        rows = await asyncio.to_thread(DBX.ticket_open_for, pid)
        if not rows:
            await message.channel.send("You have no open tickets. Open one on the website.")
        else:
            lst = "\n".join(f"• **#{r['id']}** ({r['status']}) — {r['subject'][:70]}" for r in rows[:15])
            await message.channel.send(f"Your open tickets:\n{lst}\n\nReply with `{PREFIX}reply <id> <message>`.")
        return True

    if low.startswith(PREFIX + "reply"):
        rest = content[len(PREFIX) + 5:].strip()
        m = re.match(r"(\d+)\s+(.+)", rest, re.S)
        if not m:
            await message.channel.send(f"Usage: `{PREFIX}reply <ticketId> <message>`  (list yours with `{PREFIX}tickets`)")
            return True
        tid, body = int(m.group(1)), m.group(2).strip()
        res = await asyncio.to_thread(DBX.ticket_add_reply, tid, pid, name, body)
        if res is None:
            await message.channel.send(f"Ticket #{tid} isn't one of yours (or doesn't exist).")
        elif res == "closed":
            await message.channel.send(f"Ticket #{tid} is closed — reopen it on the website to reply.")
        else:
            await message.channel.send(f"✅ Reply posted to ticket **#{tid}**. Staff will see it on the website.")
        return True

    rows = await asyncio.to_thread(DBX.ticket_open_for, pid)
    if not rows:
        return False
    if len(rows) == 1:
        tid = rows[0]["id"]
        res = await asyncio.to_thread(DBX.ticket_add_reply, tid, pid, name, content)
        if res == "closed":
            await message.channel.send(f"Ticket #{tid} is closed.")
        else:
            await message.channel.send(f"✅ Reply posted to ticket **#{tid}** — {rows[0]['subject'][:60]}.  (Use `{PREFIX}reply <id>` for a specific one.)")
        return True
    lst = "\n".join(f"• **#{r['id']}** — {r['subject'][:70]}" for r in rows[:15])
    await message.channel.send(f"You have {len(rows)} open tickets — which one?  Reply with `{PREFIX}reply <id> <message>`:\n{lst}")
    return True


# ---------------------------------------------------------------------------
# !link — public: bind a Discord account to an in-game player ID (once each)
# ---------------------------------------------------------------------------
async def handle_link(message, arg):
    # LooneyBin (owner 2026-06-12): the Steam64 UID must never sit in the public channel. Delete the trigger,
    # then collect the UID inside a PRIVATE THREAD only the linker (+ staff/bot) can see.
    user = message.author
    if DBX is None:
        await message.channel.send("Linking is unavailable right now (DB off).", delete_after=15); return
    # role grant needs guild membership -> must be run in a server channel, not a DM
    if message.guild is None or not isinstance(user, discord.Member):
        await message.channel.send(f"Run `{PREFIX}link` in the link channel, not a DM.", delete_after=15); return
    # kill the trigger message so a UID typed inline never lingers where others can read it
    try:
        await message.delete()
    except discord.DiscordException:
        pass
    # already linked? short-circuit before opening a thread (no UID involved)
    existing = await asyncio.to_thread(DBX.link_by_discord, user.id)
    if existing:
        await message.channel.send(f"{user.mention} ⛔ you're already linked. `{PREFIX}link` is one-time.",
                                   delete_after=15); return
    # open a private thread, add only the linker
    try:
        thread = await message.channel.create_thread(
            name=f"link-{user.display_name}"[:90],
            type=discord.ChannelType.private_thread,
            invitable=False,
            auto_archive_duration=60,
        )
        await thread.add_user(user)
    except discord.DiscordException as e:
        await message.channel.send(
            f"{user.mention} couldn't open a private link thread ({type(e).__name__}) — bot needs "
            f"**Create Private Threads** + **Send Messages in Threads**.", delete_after=20)
        return
    # resolve the UID: inline arg if valid, else prompt + wait for it inside the thread
    pid = ((arg or "").split() or [""])[0].strip()
    if not admin.valid_pid(pid):
        await thread.send(
            f"{user.mention} paste your **17-digit Steam64 / player ID** here (just the number).\n"
            f"Find yours at <https://steamid.io> (the *steamID64*). You have 2 minutes.")
        def _chk(m):
            return m.channel.id == thread.id and m.author.id == user.id
        try:
            reply = await client.wait_for("message", check=_chk, timeout=120)
        except asyncio.TimeoutError:
            await thread.send("⏱️ Timed out — run `!link` again when ready.")
            await _close_thread(thread); return
        pid = ((reply.content or "").split() or [""])[0].strip().lstrip("!").strip()
        if not admin.valid_pid(pid):
            await thread.send("⛔ That's not a valid 17-digit Steam64. Run `!link` again.")
            await _close_thread(thread); return
    await _finish_link(thread, user, message.guild, pid)


async def _close_thread(thread):
    try:
        await thread.edit(archived=True, locked=True)
    except discord.DiscordException:
        pass


async def _finish_link(thread, user, guild, pid):
    send = thread.send
    # one Discord per player ID
    other = await asyncio.to_thread(DBX.link_by_pid, pid)
    if other:
        await send("⛔ That player ID is already linked to another Discord account. Ping staff if that's wrong.")
        await _close_thread(thread); return
    has_char = await asyncio.to_thread(DBX.player_exists, pid)
    # LooneyBin (owner 2026-06-12): reward_pending=1 ALWAYS, even for never-joined UIDs. The server grants on
    # first connect (insertRequest creates the players row before queryRequest's reward UPDATE), so pre-join
    # linkers get the incentive too. Limits stay: one link per Discord acct, one Discord per UID.
    ok, err = await asyncio.to_thread(DBX.create_link, user.id, pid, True)
    if not ok:
        await send("⛔ Couldn't save the link (a race with another link?). Try again, or ping staff.")
        await _close_thread(thread); return
    # grant the linked role (by id, else by name)
    role = guild.get_role(LINKED_ROLE_ID) if LINKED_ROLE_ID else None
    if role is None:
        role = discord.utils.get(guild.roles, name=LINKED_ROLE_NAME)
    if role is not None:
        try:
            await user.add_roles(role, reason="Discord <-> playerID link")
            role_note = f" Role **{role.name}** granted."
        except discord.DiscordException as e:
            role_note = f" (couldn't grant the role — {type(e).__name__}; check bot Manage Roles + role order)"
    else:
        role_note = f" (linked role `{LINKED_ROLE_NAME}` not found — set `linked_role`/`linked_role_id` in config)"
    # bank incentive: applied by the server on next connect (or first-ever connect for a never-joined UID)
    if LINK_REWARD > 0 and has_char:
        reward_note = (f"\n💰 **${LINK_REWARD:,}** will land in your bank the **next time you connect** "
                       f"in-game (relog if you're online).")
    elif LINK_REWARD > 0:
        reward_note = (f"\n💰 **${LINK_REWARD:,}** will land in your bank the **first time you join** "
                       f"in-game with that ID.")
    else:
        reward_note = ""
    # beta-tester perk: whitelist flag + one-time $1M (server grants on next connect). Only if not already in.
    beta_note = ""
    if _has_beta_role(user) and not await asyncio.to_thread(DBX.is_betatester, pid):
        await asyncio.to_thread(DBX.grant_betatester, pid)
        beta_note = (f"\n🧪 **Beta Tester** unlocked — whitelist + **${BETA_REWARD:,}** on your next connect, "
                     f"and the Beta Tester Shirt is now in your clothing shop.")
    await send(f"✅ Linked to {user.mention}.{role_note}{reward_note}{beta_note}\n_This thread closes automatically._")
    await _close_thread(thread)


def _has_beta_role(member):
    """True if the Discord member carries the beta-tester role (by id if configured, else by name)."""
    try:
        roles = member.roles
    except AttributeError:
        return False
    if BETA_ROLE_ID and any(r.id == BETA_ROLE_ID for r in roles):
        return True
    return any((r.name or "").lower() == BETA_ROLE_NAME.lower() for r in roles)


async def _sweep_beta_links():
    """Retroactive: grant beta perks to anyone already linked who holds the beta role (run on startup)."""
    if DBX is None:
        return
    ch = client.get_channel(LINK_CHANNEL_ID)
    guild = ch.guild if ch is not None else (client.guilds[0] if client.guilds else None)
    if guild is None:
        print("[beta-sweep] no guild resolved; skipping"); return
    try:
        links = await asyncio.to_thread(DBX.all_links)
    except Exception as e:
        print(f"[beta-sweep] db error: {type(e).__name__}: {e}"); return
    granted = 0
    for row in links:
        pid = row.get("playerid"); did = row.get("discord_id")
        if not pid or not did:
            continue
        if await asyncio.to_thread(DBX.is_betatester, pid):
            continue   # already a beta tester -> don't re-grant the $1M
        try:
            member = guild.get_member(int(did)) or await guild.fetch_member(int(did))
        except discord.DiscordException:
            continue   # left the server / not fetchable
        if member and _has_beta_role(member):
            await asyncio.to_thread(DBX.grant_betatester, pid)
            granted += 1
    print(f"[beta-sweep] granted beta perks to {granted} already-linked member(s)")


@client.event
async def on_message(message):
    if message.author.bot:
        return
    content = (message.content or "").strip()
    chan = getattr(message.channel, "name", "dm")

    # ---- whitelist channel: LoonyBot stays SILENT here (owner 2026-06-18). Cop whitelisting moved to Officer
    # Maggot, which OWNS this channel now -> LoonyBot ignores it entirely (no whitelist, no admin cmds, no intake). ----
    if getattr(message.channel, "id", 0) == WHITELIST_CHANNEL_ID:
        return

    # ---- admin console: ANY guild channel, permission-gated (owner request 2026-06-15: admins can run loonybot
    # commands in any channel, not just the admin channel). Still gated by is_admin/is_staff/can_whitelist (so a
    # non-admin in a public channel gets "Not authorized"); DMs handled by the branch below. A non-ADMIN_CMDS
    # prefix (e.g. !report, !bug) isn't matched here -> falls through to the public bug commands. ----
    if message.guild is not None and content.startswith(PREFIX):
        parts = content[len(PREFIX):].split(maxsplit=1)
        cmd = parts[0].lower() if parts else ""
        arg = parts[1].strip() if len(parts) > 1 else ""
        if cmd in ADMIN_CMDS:
            if not OWNER_IDS:
                await message.channel.send("⛔ Admin commands locked — set `owner_ids` in config.json.")
            elif not (is_full(message.author)
                      or (cmd not in OWNER_ONLY_CMDS and is_staff(message.author))
                      or (cmd in MOD_CMDS and is_mod(message.author))
                      or (cmd in ("whitelist", "wl", "help") and can_whitelist(message.author))):
                await message.channel.send("⛔ Not authorized.")
            else:
                try:
                    await handle_admin(cmd, arg, message)
                except Exception as e:
                    await message.channel.send(f"⛔ Error: `{type(e).__name__}: {e}`")
            return

    # ---- admin console via DM: admins/owners can run the admin commands privately (owner request 2026-06-14).
    # Same gating as the admin channel, but resolve the author to a guild Member first (a DM author is a bare
    # User with no roles). Owner-only cmds (srv/perms) still owners-only; guild-needing cmds self-report. ----
    if message.guild is None and isinstance(message.channel, discord.DMChannel) and content.startswith(PREFIX):
        parts = content[len(PREFIX):].split(maxsplit=1)
        cmd = parts[0].lower() if parts else ""
        arg = parts[1].strip() if len(parts) > 1 else ""
        if cmd in ADMIN_CMDS:
            if not OWNER_IDS:
                await message.channel.send("⛔ Admin commands locked — set `owner_ids` in config.json.")
                return
            member = await _resolve_member(message.author.id) or message.author
            if not (is_full(member)
                    or (cmd not in OWNER_ONLY_CMDS and is_staff(member))
                    or (cmd in MOD_CMDS and is_mod(member))
                    or (cmd in ("whitelist", "wl", "help") and can_whitelist(member))):
                await message.channel.send("⛔ Not authorized.")
            else:
                try:
                    await handle_admin(cmd, arg, message)
                except Exception as e:
                    await message.channel.send(f"⛔ Error: `{type(e).__name__}: {e}`")
            return

    # ---- support-ticket replies via DM (linked players reply to their own web tickets) ----
    if message.guild is None and isinstance(message.channel, discord.DMChannel):
        try:
            if await handle_ticket_dm(message, content):
                return
        except Exception as e:
            print(f"[ticket-dm] error: {type(e).__name__}: {e}", flush=True)

    # ---- bug commands (any channel) ----
    if content.startswith(PREFIX):
        parts = content[len(PREFIX):].split(maxsplit=1)
        cmd = parts[0].lower() if parts else ""
        arg = parts[1].strip() if len(parts) > 1 else ""
        if cmd == "report":                       # public — anyone can file a report (DM wizard)
            sub = arg.split(maxsplit=1)
            if sub and sub[0].lower() in ("staged", "live", "notifyfixed"):
                # owner-only. staged=STAGED / live=FIXED flip a single bug's status (the 3s watcher then
                # auto-replies in its thread). notifyfixed = BULK: post the Fixed notice on every already-solved
                # bug thread from <fromId> onward (solved = STAGED, which is deployed in this workflow, or FIXED).
                if OWNER_IDS and not is_full(message.author):
                    await message.channel.send("Only the owner can update bug status."); return
                kind = sub[0].lower()
                if kind == "notifyfixed":
                    rest = (sub[1] if len(sub) > 1 else "").strip().lstrip("#")
                    if not rest.isdigit():
                        # a starting bug# is REQUIRED so this can't blast every ancient closed bug
                        await message.channel.send(
                            f"Usage: `{PREFIX}report notifyfixed <fromBugId>`  (e.g. `{PREFIX}report notifyfixed 149` "
                            "= post the Fixed notice on every solved bug #149 and up)."); return
                    frm = int(rest)
                    targets = sorted(b for b, (s, _, _) in scan_state().items() if b >= frm and s in ("STAGED", "FIXED"))
                    await message.channel.send(
                        f"Posting the Fixed notice on **{len(targets)}** solved bug thread(s) (#{frm}+). This takes a moment...")
                    ok = 0
                    for b in targets:
                        if await _reply_on_report(b, LIVE_MSG, ping=False):
                            ok += 1
                        await asyncio.sleep(1.3)          # gentle rate-limit for the Discord API
                    await message.channel.send(
                        f"Done — posted to **{ok}/{len(targets)}** thread(s). (Misses = no stored ref or deleted thread.)")
                    return
                rest = (sub[1] if len(sub) > 1 else "").split(maxsplit=1)
                if not rest or not rest[0].lstrip("#").isdigit():
                    await message.channel.send(f"Usage: `{PREFIX}report {kind} <id>`"); return
                bid = int(rest[0].lstrip("#"))
                newstatus = "STAGED" if kind == "staged" else "FIXED"
                if set_status(bid, newstatus):
                    await message.channel.send(
                        f"Bug **#{bid}** → **{newstatus}**{' (live)' if kind == 'live' else ''} — notifying the reporter.")
                else:
                    await message.channel.send(f"No bug #{bid}.")
                return
            asyncio.create_task(start_report(message))
            return
        if cmd == "link":                         # public — bind discord <-> player ID (once each), link channel only
            if message.channel.id != LINK_CHANNEL_ID:
                await message.channel.send(f"Use `{PREFIX}link` in <#{LINK_CHANNEL_ID}>."); return
            await handle_link(message, arg)
            return
        if cmd == "bug":
            if not arg:
                await message.channel.send(f"Usage: `{PREFIX}bug <what broke>`"); return
            bid = append_report(str(message.author), chan, arg, message.id, message.channel.id)
            await _ack(message, bid)
            return
        if cmd == "bugs":
            rows = list_open()
            await message.channel.send(("**Open bugs:**\n```\n" + "\n".join(rows[:25]) + "\n```")
                                       if rows else "No open bugs. \U0001F389")
            return
        if cmd == "resolve":
            if OWNER_IDS and not is_full(message.author):
                await message.channel.send("Only the owner can resolve bugs."); return
            a = arg.split(maxsplit=1)
            if not a or not a[0].lstrip("#").isdigit():
                await message.channel.send(f"Usage: `{PREFIX}resolve <id>`"); return
            bid = int(a[0].lstrip("#"))
            await message.channel.send(f"Bug **#{bid}** → FIXED." if set_status(bid, "FIXED") else f"No bug #{bid}.")
            return
        if cmd == "accept":
            if OWNER_IDS and not is_full(message.author):
                await message.channel.send("Only the owner can accept features."); return
            # feature source: 1) replied-to message  2) the forum-post starter when run inside its thread
            #                 3) !accept <text>
            ref = message.reference
            ref_id = ref.message_id if ref is not None else None
            feat_author = None
            feat_text = arg.strip()
            src = None
            if ref is not None:
                try:
                    src = ref.resolved if isinstance(ref.resolved, discord.Message) else await message.channel.fetch_message(ref_id)
                except Exception:
                    src = None
            if src is None and not feat_text and getattr(message.channel, "parent_id", None) is not None:
                try:                                                   # forum post: starter msg id == thread id
                    src = await message.channel.fetch_message(message.channel.id)
                    feat_text = (getattr(message.channel, "name", "") or "").strip()   # the post title
                except Exception:
                    src = None
            if src is not None:
                ref_id = src.id
                feat_author = str(src.author)
                _body = (src.content or "").strip()
                feat_text = " — ".join([p for p in (feat_text, _body) if p]) or feat_text
            # discussion = recent non-command messages in this channel/thread (chronological)
            discussion = []
            try:
                async for m in message.channel.history(limit=30):
                    if m.id in (message.id, ref_id):
                        continue
                    c = (m.content or "").strip()
                    if not c or c.startswith(PREFIX):
                        continue
                    discussion.append(f"{m.author}: {c}")
                    if len(discussion) >= 15:
                        break
            except discord.DiscordException:
                pass
            discussion.reverse()
            logged = bool(feat_text)
            if logged:
                append_feature(str(message.author), getattr(message.channel, "name", "dm"), feat_author, feat_text, discussion)
            note = "📋 logged to `features.md`" if logged else "(reply to a feature, run it inside the feature's post, or `!accept <text>`)"
            await message.channel.send(f"**Yes Daddy** — {note}\n{RICARDO_GIF}")
            return

    # ---- plain message in intake channel = a report ----
    if BUG_CHANNEL_ID and message.channel.id == BUG_CHANNEL_ID and content:
        bid = append_report(str(message.author), chan, content, message.id, message.channel.id)
        await _ack(message, bid)


if __name__ == "__main__":
    client.run(CFG["token"])
