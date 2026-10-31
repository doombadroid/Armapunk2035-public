#!/usr/bin/env python3
"""
Officer Maggot -- LooneyBin MaxSec cop-whitelist application bot.

Flow:
  1. A persistent "Apply for MaxSec" button (post it with `!join` in any channel, owner-only) -> on click the
     bot DMs the applicant a 7-question wizard (Name / PID / DOB / time on server / cop experience / why /
     disciplinary history).
  2. On completion the application is stored (maxsec_applications table) and posted as an embed to the review
     channel with Accept / Deny buttons.
  3. MaxSec command (the reviewer roles -- LTs & Cpts -- or an owner) clicks Accept -> the applicant's PID is
     whitelisted as a Cadet (players_global.coplevel = 1, via the shared admin.DB.set_whitelist), or Deny ->
     a reason modal. Either way the embed is updated and the applicant gets a DM.

Reuses loonybot's admin.py (DB layer + rank maps). Separate Discord bot / token from LoonyBot.
Config: officer_maggot.config.json next to this file (see DEFAULTS below). Run: venv/bin/python officer_maggot.py
"""
import json
import os
import random
import re
import pathlib
import datetime

import discord
from discord import ui

import admin  # shared local module: admin.DB (pymysql) + valid_pid + rank maps

HERE = pathlib.Path(__file__).resolve().parent

# Officer Maggot character GIFs (in the project root, one level up from loonybot/). maggot3-dm = the DM look;
# maggot 1/2/4 = picked for public messages (the !join panel) + application/whitelist embeds.
GIF_DIR = HERE.parent
DM_GIF = GIF_DIR / "maggot3-dm.gif"
PUBLIC_GIFS = [GIF_DIR / "maggot1.gif", GIF_DIR / "maggot2.gif", GIF_DIR / "maggot4.gif"]
ALL_GIFS = PUBLIC_GIFS + [DM_GIF]   # owner 2026-06-18: every whitelist-cmd reply gets a random one of his gifs


def _gif_attach(path):
    """Return (discord.File, 'attachment://<name>') for an embed image, or (None, None) if the file's missing."""
    try:
        if path and path.exists():
            return discord.File(str(path), filename=path.name), f"attachment://{path.name}"
    except Exception:
        pass
    return None, None
CFG_PATH = HERE / "officer_maggot.config.json"

DEFAULTS = {
    "token": "",
    "db": {"host": "127.0.0.1", "port": 3306, "user": "looneybin",
           "password": "looneybin", "database": "looneybin"},
    "command_channel_id": 0,       # channel the bot listens in for !join (0 = any channel). DMs always work.
    "threads_channel_id": 0,       # parent channel where a PRIVATE thread is opened per application
    "thread_view_role_ids": [],    # roles added to (can view) each application's private thread
    "review_channel_id": 0,        # fallback: if threads_channel_id is 0, post applications here instead
    "log_channel_id": 0,           # optional: audit line on each decision (0 = off)
    "reviewer_role_ids": [],       # roles allowed to accept/deny (defaults to thread_view_role_ids if empty)
    # owner 2026-06-23: roles PINGED on a NEW application -- the MaxSec reviewers (Chief/Captain/Lieutenant). Kept
    # separate from thread_view_role_ids so staff (Owner/Senior Admin/Admin) aren't @-pinged on every routine app.
    # Empty -> falls back to thread_view_role_ids (old behavior).
    "application_ping_role_ids": [],
    "owner_ids": [],               # full access (always allowed)
    "accept_rank": "cadet",        # cop rank granted on accept (COP_RANKS key)
    "apply_button_label": "Apply for MaxSec",
    # owner 2026-06-18: manual cop whitelist/unwhitelist moved here from loonybot. These commands ONLY work in
    # whitelist_channel_id, gated to whitelist_role_ids (high-command MaxSec). 0 channel = disabled (no any-channel).
    "whitelist_channel_id": 100000000000000980,
    "whitelist_role_ids": [100000000000000983, 100000000000000984, 100000000000000981,
                           100000000000000985, 100000000000000986, 100000000000000987,
                           100000000000000988],
    # owner 2026-06-23: voice channels where a cop's nick is prefixed with their in-game MaxSec rank on JOIN,
    # restored on LEAVE. (cop voice channels.)
    "rank_voice_channel_ids": [
        100000000000000989, 100000000000000990, 100000000000000991,
        100000000000000992, 100000000000000993, 100000000000000994,
        100000000000000995, 100000000000000996, 100000000000000997,
    ],
}


def load_cfg():
    cfg = dict(DEFAULTS)
    if CFG_PATH.exists():
        try:
            cfg.update(json.load(open(CFG_PATH, encoding="utf-8")))
        except Exception as e:
            print(f"[officer_maggot] bad config: {e}")
    # let loonybot's config.json supply the db block if this one didn't
    if not cfg.get("db") or not cfg["db"].get("password"):
        lb = HERE / "config.json"
        if lb.exists():
            try:
                cfg["db"] = json.load(open(lb, encoding="utf-8")).get("db", cfg.get("db"))
            except Exception:
                pass
    return cfg


CFG = load_cfg()
DBX = admin.DB(CFG["db"])
ACCEPT_RANK = (CFG.get("accept_rank") or "cadet").lower()
THREAD_VIEW_ROLE_IDS = [int(r) for r in (CFG.get("thread_view_role_ids") or [])]
# owner 2026-06-23: who gets PINGED on a new app -- MaxSec command only (Chief/Captain/Lieutenant). Staff (Owner/Senior
# Admin/Admin) were pinged on every routine application; they still SEE the threads via Discord admin perms.
APPLICATION_PING_ROLE_IDS = [int(r) for r in (CFG.get("application_ping_role_ids") or [])] or THREAD_VIEW_ROLE_IDS
# accept/deny gating: explicit reviewer_role_ids, or fall back to whoever can view the thread
REVIEWER_ROLE_IDS = {int(r) for r in (CFG.get("reviewer_role_ids") or [])} or set(THREAD_VIEW_ROLE_IDS)
OWNER_IDS = {int(o) for o in (CFG.get("owner_ids") or [])}
# manual cop whitelist/unwhitelist (moved off loonybot): channel-locked + role-gated
WHITELIST_CHANNEL_ID = int(CFG.get("whitelist_channel_id") or 0)
WHITELIST_ROLE_IDS = {int(r) for r in (CFG.get("whitelist_role_ids") or [])}
RANK_VC_IDS = {int(c) for c in (CFG.get("rank_voice_channel_ids") or [])}   # cop voice channels -> rank-nick

# the wizard: (column key, prompt). Order = order asked in the DM.
QUESTIONS = [
    ("ig_name",        "**1/7 — In-game Name?**"),
    ("pid",            "**2/7 — PID (your 17-digit Steam64)?**"),
    ("dob",            "**3/7 — Date of Birth?**"),
    ("time_on_server", "**4/7 — How long have you been on the server?**"),
    ("cop_experience", "**5/7 — What cop experience do you have?**"),
    ("why",            "**6/7 — Why do you want to be a Cop?**"),
    ("disciplinary",   "**7/7 — Have you ever had disciplinary action taken against you on this or any "
                       "other server? (explain, or say 'No')**"),
]

intents = discord.Intents.default()
intents.message_content = True
intents.members = True
intents.voice_states = True   # on_voice_state_update (cop voice-channel rank nicks) -- non-privileged
client = discord.Client(intents=intents)

_in_wizard = set()   # discord user ids with a DM wizard in flight (one at a time)


def is_reviewer(member_or_user):
    uid = getattr(member_or_user, "id", 0)
    if uid in OWNER_IDS:
        return True
    roles = getattr(member_or_user, "roles", None)
    if not roles:
        return False
    return any(r.id in REVIEWER_ROLE_IDS for r in roles)


def is_whitelister(member_or_user):
    """owners always; otherwise any role in WHITELIST_ROLE_IDS (the 7 high-command roles)."""
    if getattr(member_or_user, "id", 0) in OWNER_IDS:
        return True
    roles = getattr(member_or_user, "roles", None)
    if not roles:
        return False
    return any(r.id in WHITELIST_ROLE_IDS for r in roles)


async def reply_gif(channel, text):
    """Reply with a random maggot gif attached (owner: every whitelist-cmd reply gets a gif)."""
    f, _ = _gif_attach(random.choice(ALL_GIFS))
    try:
        await channel.send(text, file=f if f else discord.utils.MISSING)
    except Exception as e:
        print(f"[officer_maggot] reply failed: {e}")


def app_gif(app):
    # deterministic per-application pick (1/2/4) so the same image survives later embed edits (the original
    # attachment stays on the message; the embed keeps referencing it by the same filename).
    return PUBLIC_GIFS[int(app["id"]) % len(PUBLIC_GIFS)]


def app_embed(app):
    status = app["status"]
    color = {"pending": 0xF1C40F, "accepted": 0x2ECC71, "denied": 0xE74C3C}.get(status, 0x95A5A6)
    e = discord.Embed(
        title=f"MaxSec Application #{app['id']} — {status.upper()}",
        color=color,
        timestamp=datetime.datetime.utcnow(),
    )
    e.set_thumbnail(url=f"attachment://{app_gif(app).name}")
    e.add_field(name="Discord", value=f"<@{app['discord_id']}> (`{app['discord_id']}`)", inline=False)
    e.add_field(name="In-game Name", value=app.get("ig_name") or "—", inline=True)
    e.add_field(name="PID", value=f"`{app.get('pid') or '—'}`", inline=True)
    e.add_field(name="DOB", value=app.get("dob") or "—", inline=True)
    e.add_field(name="Time on server", value=app.get("time_on_server") or "—", inline=False)
    e.add_field(name="Cop experience", value=(app.get("cop_experience") or "—")[:1024], inline=False)
    e.add_field(name="Why be a cop", value=(app.get("why") or "—")[:1024], inline=False)
    e.add_field(name="Disciplinary history", value=(app.get("disciplinary") or "—")[:1024], inline=False)
    if status != "pending":
        note = f" — _{app['decision_note']}_" if app.get("decision_note") else ""
        e.add_field(name="Decision",
                    value=f"**{status}** by {app.get('reviewer_name') or '?'}{note}", inline=False)
    e.set_footer(text=f"Application #{app['id']}")
    return e


# ------------------------------------------------------------------ persistent views
class ApplyView(ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @ui.button(label=CFG.get("apply_button_label", "Apply for MaxSec"),
               style=discord.ButtonStyle.primary, custom_id="maxsec_apply")
    async def apply(self, interaction: discord.Interaction, button: ui.Button):
        await interaction.response.send_message(
            "📨 Check your DMs — I'll walk you through the application.", ephemeral=True)
        await run_wizard(interaction.user)


class DenyReasonModal(ui.Modal, title="Deny application"):
    reason = ui.TextInput(label="Reason (shown to the applicant)", style=discord.TextStyle.paragraph,
                          required=True, max_length=480)

    def __init__(self, app_id):
        super().__init__()
        self.app_id = app_id

    async def on_submit(self, interaction: discord.Interaction):
        await finalize(interaction, self.app_id, "denied", str(self.reason))


class ReviewView(ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    def _app_id(self, interaction):
        # app id lives in the embed footer ("Application #N") -> survives restarts, static custom_ids
        try:
            return int(interaction.message.embeds[0].footer.text.split("#")[1])
        except Exception:
            return None

    # Accept = pick the starting rank (the responding officer decides, capped at Sergeant). Selecting a rank
    # accepts the application AND whitelists at that level.
    @ui.select(custom_id="maxsec_accept_rank", placeholder="Accept as… (pick a rank)", min_values=1, max_values=1,
               options=[
                   discord.SelectOption(label="Cadet",          value="cadet", description="coplevel 1"),
                   discord.SelectOption(label="Patrol Officer",  value="patrol", description="coplevel 2"),
                   discord.SelectOption(label="Corporal",        value="corp",  description="coplevel 3"),
                   discord.SelectOption(label="Sergeant",        value="sgt",   description="coplevel 4"),
               ])
    async def accept_rank(self, interaction: discord.Interaction, select: ui.Select):
        if not is_reviewer(interaction.user):
            await interaction.response.send_message("⛔ MaxSec command only.", ephemeral=True); return
        app_id = self._app_id(interaction)
        if app_id is None:
            await interaction.response.send_message("Couldn't read the application id.", ephemeral=True); return
        await finalize(interaction, app_id, "accepted", None, rank=select.values[0])

    @ui.button(label="Deny", style=discord.ButtonStyle.danger, custom_id="maxsec_deny")
    async def deny(self, interaction: discord.Interaction, button: ui.Button):
        if not is_reviewer(interaction.user):
            await interaction.response.send_message("⛔ MaxSec command only.", ephemeral=True); return
        app_id = self._app_id(interaction)
        if app_id is None:
            await interaction.response.send_message("Couldn't read the application id.", ephemeral=True); return
        await interaction.response.send_modal(DenyReasonModal(app_id))


# ------------------------------------------------------------------ core actions
async def run_wizard(user):
    if user.id in _in_wizard:
        return
    _in_wizard.add(user.id)
    try:
        if DBX.maxsec_pending_for(user.id):
            await user.send("You already have a **pending** MaxSec application — please wait for it to be "
                            "reviewed before submitting another.")
            return
        try:
            dm = await user.create_dm()
            _intro = discord.Embed(
                title="👮 MaxSec Application",
                description="Answer each question below. Type `cancel` anytime to stop. You have 5 minutes "
                            "per answer.",
                color=0x3498DB)
            _f, _u = _gif_attach(DM_GIF)   # maggot3 = the DM look
            if _u:
                _intro.set_image(url=_u)
                await dm.send(embed=_intro, file=_f)
            else:
                await dm.send(embed=_intro)
        except discord.Forbidden:
            return  # DMs closed; the ephemeral reply already told them to check DMs

        answers = {}
        for key, prompt in QUESTIONS:
            await dm.send(prompt)
            while True:
                def check(m):
                    return m.author.id == user.id and isinstance(m.channel, discord.DMChannel)
                try:
                    msg = await client.wait_for("message", check=check, timeout=300)
                except Exception:
                    await dm.send("⌛ Timed out — application cancelled. Click the button again to restart.")
                    return
                text = msg.content.strip()
                if text.lower() == "cancel":
                    await dm.send("❌ Application cancelled.")
                    return
                if key == "pid" and not admin.valid_pid(text):
                    await dm.send("That doesn't look like a 17-digit Steam64 PID. Try again (or `cancel`).")
                    continue
                answers[key] = text[:1000]
                break

        app_id = DBX.maxsec_insert(
            user.id, str(user), answers["ig_name"], answers["pid"], answers["dob"],
            answers["time_on_server"], answers["cop_experience"], answers["why"], answers["disciplinary"])
        app = DBX.maxsec_get(app_id)

        parent_id = int(CFG.get("threads_channel_id") or 0)
        parent = client.get_channel(parent_id) if parent_id else None
        if parent is not None:
            # one PRIVATE thread per application: only the applicant + the pinged roles can see it. invitable=False
            # so non-mods can't pull others in. NOTE: a member only actually SEES the thread if they can View the
            # parent channel -> #100000000000000980 must let the applicant + MaxSec command see the channel. Staff
            # (Owner/Senior Admin/Admin) aren't @-pinged here (owner 2026-06-23) but still see threads via admin perms.
            thread = await parent.create_thread(
                name=f"MaxSec App #{app_id} — {answers['ig_name'][:60]}",
                type=discord.ChannelType.private_thread, invitable=False)
            mention = " ".join([f"<@{user.id}>"] + [f"<@&{r}>" for r in APPLICATION_PING_ROLE_IDS])
            _af, _ = _gif_attach(app_gif(app))   # random 1/2/4 (deterministic by app id) for the embed thumbnail
            sent = await thread.send(
                content=f"📨 New MaxSec application from <@{user.id}>. {mention}",
                embed=app_embed(app), view=ReviewView(),
                file=_af if _af else discord.utils.MISSING,
                allowed_mentions=discord.AllowedMentions(users=True, roles=True))
            # make sure the applicant is a thread member even if the mention didn't add them
            try:
                await thread.add_user(user)
            except Exception:
                pass
            DBX.maxsec_set_msg(app_id, thread.id, sent.id)
            await dm.send("✅ **Application submitted!** A private review thread was opened — MaxSec command will "
                          "review it and you'll get a DM with the decision. Good luck.")
            return

        # fallback: no threads channel configured -> plain post in review_channel_id
        chan = client.get_channel(int(CFG.get("review_channel_id") or 0))
        if chan is None:
            await dm.send("✅ Application submitted, but the review channel isn't configured — ping an admin.")
            return
        _af, _ = _gif_attach(app_gif(app))
        sent = await chan.send(embed=app_embed(app), view=ReviewView(),
                               file=_af if _af else discord.utils.MISSING)
        DBX.maxsec_set_msg(app_id, chan.id, sent.id)
        await dm.send("✅ **Application submitted!** MaxSec command will review it and you'll get a DM with the "
                      "decision. Good luck.")
    finally:
        _in_wizard.discard(user.id)


RANK_LABELS = {"cadet": "Cadet", "patrol": "Patrol Officer", "corp": "Corporal", "sgt": "Sergeant"}


async def finalize(interaction, app_id, decision, note, rank=None):
    # ack within 3s, then do the (slower) DB + message edits and report via followup.
    try:
        await interaction.response.defer(ephemeral=True)
    except Exception:
        pass
    # rank: only meaningful on accept; the reviewer picks it (capped at Sergeant in the select). Note stored on
    # the row = the granted rank (accept) or the reviewer's reason (deny), so the embed shows it.
    _rank = ((rank or ACCEPT_RANK).lower()) if decision == "accepted" else None
    _dbnote = (f"whitelisted as {RANK_LABELS.get(_rank, _rank)}") if decision == "accepted" else note
    row = DBX.maxsec_decide(app_id, decision, interaction.user.id, str(interaction.user), _dbnote)
    if row is None:
        await interaction.followup.send(
            "This application was already decided by someone else.", ephemeral=True)
        return

    granted_msg = ""
    if decision == "accepted":
        ok, msg = await _to_thread(DBX.set_whitelist, row["pid"], "cop", _rank)
        granted_msg = ("\n✅ Whitelisted: " + msg) if ok else ("\n⚠️ Whitelist FAILED: " + str(msg))

    # update the review embed in place + drop the buttons, then archive the private thread. We locate the
    # message via the STORED thread_id (a modal-submit -- the Deny path -- has no interaction.message).
    try:
        loc_id = int(row.get("thread_id") or CFG.get("review_channel_id") or 0)
        loc = client.get_channel(loc_id)
        if loc is None and loc_id:
            try:
                loc = await client.fetch_channel(loc_id)
            except Exception:
                loc = None
        if loc and row.get("review_msg_id"):
            rmsg = await loc.fetch_message(int(row["review_msg_id"]))
            await rmsg.edit(embed=app_embed(row), view=None)
        if isinstance(loc, discord.Thread):
            try:
                await loc.edit(archived=True)   # close the ticket thread (still readable)
            except Exception:
                pass
    except Exception:
        pass

    # confirm to the reviewer (ephemeral) and DM the applicant
    try:
        await interaction.followup.send(
            f"Application #{app_id} **{decision}**.{granted_msg}", ephemeral=True)
    except Exception:
        pass
    try:
        applicant = client.get_user(int(row["discord_id"])) or await client.fetch_user(int(row["discord_id"]))
        if decision == "accepted":
            await applicant.send(
                f"🎉 Your **MaxSec application** was **accepted**! You've been whitelisted as "
                f"**{RANK_LABELS.get(_rank, _rank)}** — it applies on your next connect. Welcome to the force.")
        else:
            reason = f"\nReason: _{note}_" if note else ""
            await applicant.send(f"Your **MaxSec application** was **denied**.{reason}\nYou're welcome to reapply "
                                 f"later.")
    except Exception:
        pass

    log_id = int(CFG.get("log_channel_id") or 0)
    if log_id:
        ch = client.get_channel(log_id)
        if ch:
            await ch.send(f"📋 Application #{app_id} (`{row['pid']}`) **{decision}** by "
                          f"{interaction.user.mention}.{granted_msg}")


async def _to_thread(fn, *args):
    import asyncio
    return await asyncio.to_thread(fn, *args)


# ================================================================== MaxSec rank voice-nick (owner 2026-06-23)
# When a whitelisted cop JOINS one of RANK_VC_IDS, prefix their Discord nickname with their in-game MaxSec rank
# (players_global.coplevel -> name), e.g. "Cadet Doomba". On LEAVE, restore the exact nick they had. Robust to:
#   - a name change WHILE in-channel (we only ever re-derive "<Rank> <bareName>"; our own edits match -> no loop),
#   - a bot restart (original nicks persisted to disk; on_ready reconciles current occupants + anyone who left),
#   - non-cops / unlinked Discord (coplevel 0 -> left untouched),
#   - the SERVER OWNER / higher-role members (Discord forbids the rename -> logged, state stays clean).
COPLEVEL_NAME = {1: "Cadet", 2: "Patrol Officer", 3: "Corporal", 4: "Sergeant",
                 5: "Lieutenant", 6: "Captain", 7: "Chief"}
# strips a leading rank prefix we applied -- BOTH the new "<order> <Rank> " form (e.g. "1 Chief ") and the
# legacy "<Rank> " form -- so we never double-prefix or eat the real name. (rank names sorted longest-first
# is unnecessary here: none is a prefix of another.)
_RANK_PREFIX_RE = re.compile(r"^\s*\d*\s*(?:" + "|".join(re.escape(n) for n in COPLEVEL_NAME.values()) + r")\s+")
NICKS_PATH = HERE / "officer_maggot.ranknicks.json"
_orig_nick = {}     # str(member_id) -> nick to restore on leave (their real name, no prefix; may be None). Persisted.
_rank_cache = {}    # int member_id -> coplevel, cached at join for the name-change handler

def _load_nicks():
    global _orig_nick
    try:
        _orig_nick = json.load(open(NICKS_PATH, encoding="utf-8"))
    except Exception:
        _orig_nick = {}

def _save_nicks():
    try:
        json.dump(_orig_nick, open(NICKS_PATH, "w", encoding="utf-8"))
    except Exception as e:
        print(f"[officer_maggot] ranknicks save failed: {e}")

def _coplevel_for_discord(discord_id):
    """in-game MaxSec coplevel (1-7) for a Discord user via discord_links, or 0 if unlinked / not a cop."""
    try:
        r = DBX.q("SELECT g.coplevel AS c FROM discord_links dl JOIN players_global g ON g.playerid=dl.playerid "
                  "WHERE dl.discord_id=%s LIMIT 1", (int(discord_id),), "one")
        return int((r or {}).get("c") or 0)
    except Exception as e:
        print(f"[officer_maggot] coplevel lookup failed for {discord_id}: {e}")
        return 0

def _strip_rank_prefix(name):
    """Strip a leading rank prefix we may have applied (new '1 Chief ' or legacy 'Chief ' form)."""
    s = name or ""
    m = _RANK_PREFIX_RE.match(s)
    return s[m.end():] if m else s

def _desired_nick(lvl, member):
    # owner 2026-06-25: lead with an ORDER NUMBER (Chief=1 .. Cadet=7, = 8-coplevel) so Discord's alphabetical
    # voice-channel member sort puts the highest rank at the TOP (Chief, then Captain, ...). The number is the
    # rank position the owner asked for; the full rank name follows for readability. e.g. "1 Chief Doomba".
    base = _strip_rank_prefix(member.display_name)
    order = 8 - lvl
    return f"{order} {COPLEVEL_NAME[lvl]} {base}".strip()[:32]   # Discord nickname hard limit = 32 chars

async def _set_nick(member, value):
    try:
        await member.edit(nick=value, reason="MaxSec rank voice-nick")
        return True
    except discord.Forbidden:
        # can't rename: bot lacks Manage Nicknames, the target outranks the bot, or it's the SERVER OWNER
        print(f"[officer_maggot] nick edit FORBIDDEN for {member} ({member.id}) -- hierarchy / server owner / perms")
    except Exception as e:
        print(f"[officer_maggot] nick edit error for {member.id}: {e}")
    return False

async def _apply_rank_nick(member):
    if member.bot:
        return
    lvl = await _to_thread(_coplevel_for_discord, member.id)
    if lvl not in COPLEVEL_NAME:        # 0 / unlinked / non-cop -> leave them alone
        return
    if str(member.id) not in _orig_nick:
        _orig_nick[str(member.id)] = member.nick   # exact restore target (may be None = no nick)
        _save_nicks()
    _rank_cache[member.id] = lvl
    desired = _desired_nick(lvl, member)
    if member.nick != desired:
        await _set_nick(member, desired)

async def _restore_nick(member):
    key = str(member.id)
    _rank_cache.pop(member.id, None)
    if key in _orig_nick:
        orig = _orig_nick.pop(key)
        _save_nicks()
        if member.nick != orig:
            await _set_nick(member, orig)          # None -> clears the nick back to their username
    else:
        bare = _strip_rank_prefix(member.display_name)   # untracked -> just strip any prefix we may have left
        if member.nick and member.nick != bare:
            await _set_nick(member, bare)

def _in_rank_vc(state):
    return bool(state and state.channel and state.channel.id in RANK_VC_IDS)

@client.event
async def on_voice_state_update(member, before, after):
    if member.bot or not RANK_VC_IDS:
        return
    was_in, now_in = _in_rank_vc(before), _in_rank_vc(after)
    if now_in and not was_in:
        await _apply_rank_nick(member)
    elif was_in and not now_in:
        await _restore_nick(member)
    # moving between two watched channels (was_in and now_in) -> keep the prefix, no-op

@client.event
async def on_member_update(before, after):
    # name change WHILE rank-prefixed in a cop channel -> re-derive cleanly (no double-prefix, no edit loop)
    if after.bot or before.nick == after.nick:
        return
    key = str(after.id)
    if key not in _orig_nick:                 # not currently managed by us -> ignore
        return
    lvl = _rank_cache.get(after.id)
    if lvl not in COPLEVEL_NAME:
        return
    desired = _desired_nick(lvl, after)
    if after.nick == desired:                 # already correct (incl. our own edit) -> stop, no loop
        return
    _orig_nick[key] = _strip_rank_prefix(after.nick) if after.nick else None   # restore to their NEW bare name
    _save_nicks()
    await _set_nick(after, desired)

# ------------------------------------------------------------------ events / owner command
@client.event
async def on_ready():
    try:
        DBX.maxsec_init()
    except Exception as e:
        print(f"[officer_maggot] maxsec_init failed: {e}")
    client.add_view(ApplyView())
    client.add_view(ReviewView())
    print(f"[officer_maggot] online as {client.user} | reviewers={REVIEWER_ROLE_IDS} owners={OWNER_IDS}")
    # MaxSec rank voice-nick reconcile after a (re)start: prefix anyone currently in a watched cop VC, and restore
    # anyone we had prefixed who has since left (their original nick was persisted across the restart).
    if RANK_VC_IDS:
        try:
            _load_nicks()
            in_vc = set()
            for guild in client.guilds:
                for ch in guild.voice_channels:
                    if ch.id in RANK_VC_IDS:
                        for m in ch.members:
                            in_vc.add(m.id)
                            await _apply_rank_nick(m)
            for key in list(_orig_nick.keys()):
                mid = int(key)
                if mid in in_vc:
                    continue
                m = next((g.get_member(mid) for g in client.guilds if g.get_member(mid)), None)
                if m:
                    await _restore_nick(m)
                else:
                    _orig_nick.pop(key, None); _save_nicks()   # member no longer visible -> drop stale entry
            print(f"[officer_maggot] rank-nick reconcile done | watching {len(RANK_VC_IDS)} VC(s), {len(in_vc)} cop(s) in")
        except Exception as e:
            print(f"[officer_maggot] rank-nick reconcile error: {e}")


COP_RANK_LIST = "cadet/patrol/corp/sgt/lt/captain/chief"
MAGGOT_HELP = (
    "**🚔 Officer Maggot — MaxSec Whitelist**\n"
    f"`!whitelist <playerID> <rank> [maxtac:on|off]` — whitelist a cop (optional 4th arg toggles MaxTac).  ranks: {COP_RANK_LIST}\n"
    "`!maxtac <playerID> <on|off>` — grant/remove MaxTac whitelist on its own (players.ismaxtac)\n"
    "`!undercover <playerID> <on|off>` — grant/remove undercover whitelist (gates the undercover cop slots)\n"
    "`!unwhitelist <playerID>` — remove cop: rank + retired + MaxTac + SCD all off (keeps their cop progress)\n"
    "`!pid <in-game name>` — find a player's PID by name\n"
    "`!dpid <@mention | discord-id | name>` — find a player's linked PID from their Discord\n"
    "`!help` — this screen\n"
    "Applications: members hit **Apply for MaxSec** / `!join`; MaxSec command Accept/Deny in the app thread.\n"
    "_Whitelist commands work in this channel only, for MaxSec command roles._"
)

async def handle_cop_whitelist(message, content):
    """`!whitelist <pid> <rank>` / `!unwhitelist <pid>` / `!help` — cop only (MaxSec bot). Gated to the 7 roles."""
    if not is_whitelister(message.author):
        await reply_gif(message.channel, f"{message.author.mention} ⛔ You're not authorized to whitelist cops.")
        return
    parts = content.split()
    cmd = parts[0].lower()

    if cmd == "!help":
        await reply_gif(message.channel, MAGGOT_HELP)
        return

    arg = content.split(maxsplit=1)[1].strip() if len(parts) > 1 else ""

    # !pid <name> -> PID(s) by in-game name (mirrors loonybot)
    if cmd == "!pid":
        if not arg:
            await reply_gif(message.channel, "Usage: `!pid <in-game name>`  (Discord lookup: `!dpid <@mention|id|name>`)")
            return
        if arg.isdigit() and len(arg) >= 17:
            await reply_gif(message.channel, "That's a PID already. For a Discord account use `!dpid <@mention|id|name>`.")
            return
        try:
            rows = await _to_thread(DBX.pid_by_name, arg)
        except Exception as e:
            await reply_gif(message.channel, f"⚠️ DB error: {e}"); return
        await reply_gif(message.channel, admin.fmt_pid(rows))
        return

    # !dpid <@mention | discord-id | name> -> linked PID (mirrors loonybot)
    if cmd == "!dpid":
        target_id = None
        if message.mentions:
            target_id = message.mentions[0].id
        elif arg and arg.lstrip("@").isdigit() and len(arg.lstrip("@")) >= 17:
            target_id = int(arg.lstrip("@"))
        elif arg and message.guild is not None:
            q = arg.lstrip("@")
            try:
                found = await message.guild.query_members(query=q, limit=5)
            except Exception:
                found = []
            if len(found) == 1:
                target_id = found[0].id
            elif len(found) > 1:
                await reply_gif(message.channel, "Multiple matches — narrow it or use the id/@mention:\n" +
                                "\n".join(f"• {m.display_name} (`{m.id}`)" for m in found))
                return
            else:
                await reply_gif(message.channel, f"No Discord member matching `{q}`."); return
        if target_id is None:
            await reply_gif(message.channel, "Usage: `!dpid <@mention | discord-id | name>`")
            return
        try:
            row = await _to_thread(DBX.link_by_discord, target_id)
        except Exception as e:
            await reply_gif(message.channel, f"⚠️ DB error: {e}"); return
        if row:
            await reply_gif(message.channel, f"<@{target_id}> → PID `{row['playerid']}`")
        else:
            await reply_gif(message.channel, f"<@{target_id}> isn't linked (no `!link` on record).")
        return

    if cmd in ("!unwhitelist", "!unwl"):
        if len(parts) < 2 or not admin.valid_pid(parts[1]):
            await reply_gif(message.channel, "Usage: `!unwhitelist <playerID>` — strips cop **rank + retired + MaxTac** (coplevel/copretired/ismaxtac → 0).")
            return
        pid = parts[1]
        try:
            ok, msg = await _to_thread(DBX.unwhitelist_cop, pid)
        except Exception as e:
            ok, msg = False, f"DB error: {e}"
        await reply_gif(message.channel, f"{'✅' if ok else '⚠️'} `{pid}` — {msg}")
        return

    # !maxtac <pid> <on|off> -> MaxTac whitelist (players.ismaxtac). Shares admin.DB.set_maxtac with loonybot.
    if cmd == "!maxtac":
        if len(parts) < 3 or not admin.valid_pid(parts[1]):
            await reply_gif(message.channel, "Usage: `!maxtac <playerID> <on|off>` — grant/remove MaxTac whitelist (players.ismaxtac; gates MaxTac Armory + MaxTac Garage).")
            return
        tok = parts[2].lower()
        if tok in ("on", "1", "true", "yes", "add", "grant", "maxtac"):
            on = True
        elif tok in ("off", "0", "false", "no", "remove", "rm"):
            on = False
        else:
            await reply_gif(message.channel, f"⚠️ `{tok}` — use `on` or `off`.")
            return
        try:
            ok, msg = await _to_thread(DBX.set_maxtac, parts[1], on)
        except Exception as e:
            ok, msg = False, f"DB error: {e}"
        await reply_gif(message.channel, f"{'✅' if ok else '⚠️'} `{parts[1]}` — {msg}")
        return

    # !undercover <pid> <on|off> -> undercover whitelist (players.isscd -- internal/code name is "scd").
    # Mirrors !maxtac. Gates the cop_scd_* slots (pure whitelist; fn_initCop). Shares admin.DB.set_scd.
    if cmd == "!undercover":
        if len(parts) < 3 or not admin.valid_pid(parts[1]):
            await reply_gif(message.channel, "Usage: `!undercover <playerID> <on|off>` — grant/remove undercover whitelist (gates the undercover cop slots).")
            return
        tok = parts[2].lower()
        if tok in ("on", "1", "true", "yes", "add", "grant", "undercover", "uc"):
            on = True
        elif tok in ("off", "0", "false", "no", "remove", "rm"):
            on = False
        else:
            await reply_gif(message.channel, f"⚠️ `{tok}` — use `on` or `off`.")
            return
        try:
            ok, msg = await _to_thread(DBX.set_scd, parts[1], on)
        except Exception as e:
            ok, msg = False, f"DB error: {e}"
        await reply_gif(message.channel, f"{'✅' if ok else '⚠️'} `{parts[1]}` — {msg}")
        return

    # !whitelist <pid> <rank> [maxtac:on|off]   (optional 4th arg toggles MaxTac, mirrors loonybot)
    if len(parts) < 3 or not admin.valid_pid(parts[1]):
        await reply_gif(message.channel, f"Usage: `!whitelist <playerID> <rank> [maxtac:on|off]`  ·  ranks: {COP_RANK_LIST}")
        return
    pid, rank = parts[1], parts[2].lower()
    if rank not in admin.COP_RANKS:
        await reply_gif(message.channel, f"⚠️ Unknown rank `{rank}`. ranks: {COP_RANK_LIST}")
        return
    try:
        ok, msg = await _to_thread(DBX.set_whitelist, pid, "cop", rank)
    except Exception as e:
        ok, msg = False, f"DB error: {e}"
    # optional 4th arg -> also set MaxTac whitelist in one shot
    if ok and len(parts) >= 4:
        stok = parts[3].lower()
        if stok in ("on", "1", "true", "yes", "maxtac", "add"):
            try:
                _, smsg = await _to_thread(DBX.set_maxtac, pid, True);  msg += "  ·  " + smsg
            except Exception as e:
                msg += f"  ·  ⚠️ maxtac: {e}"
        elif stok in ("off", "0", "false", "no", "remove"):
            try:
                _, smsg = await _to_thread(DBX.set_maxtac, pid, False); msg += "  ·  " + smsg
            except Exception as e:
                msg += f"  ·  ⚠️ maxtac: {e}"
        else:
            msg += f"  ·  ⚠️ ignored maxtac arg `{parts[3]}` (use on/off)"
    await reply_gif(message.channel, f"{'✅' if ok else '⚠️'} `{pid}` — {msg}")


@client.event
async def on_message(message):
    if message.author.bot:
        return
    _content = message.content.strip()
    _first = _content.split(" ", 1)[0].lower()
    _chan = getattr(message.channel, "id", 0)
    # ---- manual cop whitelist / unwhitelist: ONLY in the whitelist channel, gated to the 7 roles (owner 6/18) ----
    if _first in ("!whitelist", "!wl", "!unwhitelist", "!unwl", "!help", "!pid", "!dpid", "!maxtac", "!undercover"):
        if WHITELIST_CHANNEL_ID and _chan != WHITELIST_CHANNEL_ID:
            return   # silent outside the whitelist channel
        await handle_cop_whitelist(message, _content)
        return
    # only listen in the configured command channel (0 = any). DMs (wizard answers) handled via wait_for.
    _cmd_chan = int(CFG.get("command_channel_id") or 0)
    if _cmd_chan and _chan != _cmd_chan:
        return
    if _content.lower() == "!join":
        # anyone can apply: a public hype reply + a random maggot gif, then DM them the application wizard.
        _pf, _ = _gif_attach(random.choice(PUBLIC_GIFS))
        await message.channel.send(
            f"{message.author.mention} **Hell yeah boy check your DMs**",
            file=_pf if _pf else discord.utils.MISSING)
        try:
            await message.delete()
        except Exception:
            pass
        await run_wizard(message.author)


def main():
    token = CFG.get("token") or os.environ.get("OFFICER_MAGGOT_TOKEN", "")
    if not token:
        raise SystemExit("No token — set 'token' in officer_maggot.config.json or $OFFICER_MAGGOT_TOKEN")
    client.run(token)


if __name__ == "__main__":
    main()
