"""
LoonyBot admin layer -- direct MariaDB player management for LooneyBin.

ALL queries are parameterised (never interpolate user input). The only f-string
substitutions are column names drawn from the fixed FACTIONS/ACCOUNTS whitelists.

Rank maps below are the source of truth -- EDIT them to match the server's intended
levels. They drive both !whitelist (rank -> level) and !info (level -> rank name).
"""
import re
import json
import random
import pymysql
import pymysql.cursors

# ---------------------------------------------------------------- rank maps
COP_RANKS = {"cadet": 1, "patrol": 2, "corp": 3, "sgt": 4, "lt": 5, "captain": 6, "chief": 7,
             "const": 2, "constable": 2, "patrolofficer": 2}   # aliases after canonical for forgiving input
MED_RANKS = {"emr": 1, "emt": 2, "aemt": 3, "para": 4, "asstchief": 5, "chief": 6}
# in-game AP_adminLevel ladder, verified against the mission code + live DB:
#   fn_requestReceived: _isAdmin = adminLevel >= 3 ; fn_onPlayerKilled: 3 -> "admin", 4 -> "developer"
#   live players_global: staff (staffA/staffB/staffC) = 4, owner = 5.
#   => developer (4) is ABOVE admin (3). 2 = mod (admin-menu/ESP tier), 1 = trial, 0 = none.
# Canonical names first (reverse level->name lookup returns those); aliases after for forgiving input.
SRV_RANKS = {"none": 0, "trial": 1, "mod": 2, "admin": 3, "dev": 4, "owner": 5,
             "pleb": 0, "moderator": 2, "developer": 4}
OWNER_LEVEL = 5          # adminlevel of an owner -- bot refuses to set or overwrite this

FACTIONS = {"cop": ("coplevel", COP_RANKS),
            "med": ("mediclevel", MED_RANKS),
            "srv": ("adminlevel", SRV_RANKS)}
ACCOUNTS = {"bank": "bankacc", "cash": "cash"}

PID_RE = re.compile(r"^\d{17}$")     # Steam64


def valid_pid(s):
    return bool(PID_RE.match((s or "").strip()))


def _rank_name(ranks, level):
    try:
        level = int(level)
    except (TypeError, ValueError):
        return "?"
    for name, lvl in ranks.items():
        if lvl == level:
            return name
    return f"lvl{level}" if level else "none"


class DB:
    def __init__(self, cfg):
        self.cfg = cfg

    def _conn(self):
        return pymysql.connect(
            host=self.cfg.get("host", "127.0.0.1"), port=int(self.cfg.get("port", 3306)),
            user=self.cfg["user"], password=self.cfg["password"], database=self.cfg["database"],
            autocommit=True, charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=8)

    def q(self, sql, params=(), fetch="all"):
        con = self._conn()
        try:
            with con.cursor() as cur:
                cur.execute(sql, params)
                if fetch == "all":
                    return cur.fetchall()
                if fetch == "one":
                    return cur.fetchone()
                if fetch == "lastrowid":
                    return cur.lastrowid
                return cur.rowcount
        finally:
            con.close()

    # ---------------------------------------------------------- operations
    def is_online(self, pid):
        return bool(self.q("SELECT 1 FROM online WHERE playerid=%s LIMIT 1", (pid,), "one"))

    def pid_by_name(self, name):
        rows = self.q("SELECT playerid, name FROM players WHERE name=%s "
                      "ORDER BY lastupdated DESC LIMIT 6", (name,))
        if not rows:
            rows = self.q("SELECT playerid, name FROM players WHERE name LIKE %s "
                          "ORDER BY lastupdated DESC LIMIT 6", (f"%{name}%",))
        return rows

    def info(self, pid):
        p = self.q("SELECT name, cash, bankacc, new_drachma, arrested, new_player, "
                   "lastupdated, gang0, gangrank0 FROM players WHERE playerid=%s", (pid,), "one")
        g = self.q("SELECT adminlevel, coplevel, copretired, mediclevel, "
                   "wealth, betatester FROM players_global WHERE playerid=%s", (pid,), "one")
        if not p and not g:
            return None
        return {"pid": pid, "p": p or {}, "g": g or {}, "online": self.is_online(pid),
                "names": self.last_names(pid), "ban": self.last_ban(pid),
                "gang": self.gang_of((p or {}).get("gang0"))}

    def gang_of(self, gid):
        """Gang name + bank + full member roster (name, rank, pid) for a gang id; None if gangless.
        gang model: players.gang0 = gang id, players.gangrank0 = member rank (1=leader .. 5=recruit)."""
        try:
            gid = int(gid)
        except (TypeError, ValueError):
            return None
        if gid <= 0:
            return None
        g = self.q("SELECT id, name, bank FROM gangs WHERE id=%s", (gid,), "one")
        if not g:
            return None
        g["members"] = self.q("SELECT name, gangrank0, playerid FROM players WHERE gang0=%s "
                              "ORDER BY gangrank0 ASC, name ASC", (gid,)) or []
        return g

    def last_names(self, pid, limit=5):
        # most-recently-seen distinct aliases (player_names is deduped on (pid,name))
        return self.q("SELECT name, seen FROM player_names WHERE playerid=%s "
                      "ORDER BY seen DESC LIMIT %s", (pid, int(limit)))

    def last_ban(self, pid):
        return self.q("SELECT reason, banned_by, until, created FROM bans "
                      "WHERE playerid=%s ORDER BY id DESC LIMIT 1", (pid,), "one")

    def set_whitelist(self, pid, faction, rank):
        col, ranks = FACTIONS[faction]
        level = ranks[rank]
        if col == "adminlevel":
            if rank == "owner":
                return False, "Refusing to grant **owner** via bot."
            cur = self.q("SELECT adminlevel FROM players_global WHERE playerid=%s", (pid,), "one")
            if int((cur or {}).get("adminlevel") or 0) >= OWNER_LEVEL:
                return False, "Target is an **owner** — bot won't change their rank."
        self.q("INSERT IGNORE INTO players_global (playerid) VALUES (%s)", (pid,), "rows")
        self.q(f"UPDATE players_global SET {col}=%s WHERE playerid=%s", (level, pid), "rows")
        return True, f"`{faction}` → **{rank}** ({col}={level})"

    def set_maxtac(self, pid, on):
        # MaxTac whitelist lives on players.ismaxtac (read by fn_queryRequest -> client AP_isMaxTac). Loaded on
        # next connect; gates the always-on MaxTac Armory + MaxTac Garage.
        # PRE-WHITELIST (owner 2026-06-13): upsert a stub players row so a never-joined PID can be set. The
        # stub uses column defaults + new_player=1, so first join still runs the new-player flow and the name
        # auto-corrects on the first periodic save (fn_updateRequest writes name=). insertRequest's later
        # INSERT IGNORE is a no-op once the row exists -> the ismaxtac=1 sticks.
        if on:
            self.q("INSERT INTO players (playerid, name, instance, new_player, ismaxtac) "
                   "VALUES (%s, 'Pre-Whitelisted', 1, 1, 1) ON DUPLICATE KEY UPDATE ismaxtac=1", (pid,), "rows")
            return True, "**granted** MaxTac whitelist (ismaxtac=1)"
        self.q("UPDATE players SET ismaxtac=0 WHERE playerid=%s", (pid,), "rows")
        return True, "**removed** MaxTac whitelist (ismaxtac=0)"

    def set_scd(self, pid, on):
        # Undercover/SCD whitelist on players.isscd (read by fn_queryRequest -> client AP_isSCD).
        # Loaded on next connect; gates the cop_scd_* slots as a PURE whitelist (owner 2026-06-19 -- replaced
        # the old Sgt+ rank gate in fn_initCop). Same pre-whitelist stub pattern as set_maxtac: upsert a stub players
        # row so a never-joined PID can be set; first join still runs the new-player flow, isscd=1 sticks.
        if on:
            self.q("INSERT INTO players (playerid, name, instance, new_player, isscd) "
                   "VALUES (%s, 'Pre-Whitelisted', 1, 1, 1) ON DUPLICATE KEY UPDATE isscd=1", (pid,), "rows")
            return True, "**granted** undercover/SCD whitelist (isscd=1)"
        self.q("UPDATE players SET isscd=0 WHERE playerid=%s", (pid,), "rows")
        return True, "**removed** undercover/SCD whitelist (isscd=0)"

    def set_casino_ban(self, pid, on):
        # Casino self-exclusion on players.casino_banned (read by fn_queryRequest -> client AP_casinoBanned +
        # server AP_bjBanned enforcement cache). Loaded on next connect: hides the Casino phone app AND the
        # server refuses blackjack deals. Players ban THEMSELVES in-game (phone Settings -> "Casino Ban"); this
        # is the ADMIN undo (on=False) -- and an optional manual ban (on=True). Same pre-whitelist stub pattern
        # as set_maxtac so a never-joined PID can still be set. Applies on the player's NEXT connect.
        if on:
            self.q("INSERT INTO players (playerid, name, instance, new_player, casino_banned) "
                   "VALUES (%s, 'Pre-Whitelisted', 1, 1, 1) ON DUPLICATE KEY UPDATE casino_banned=1", (pid,), "rows")
            return True, "**banned** from the casino (casino_banned=1) — applies on next connect"
        self.q("UPDATE players SET casino_banned=0 WHERE playerid=%s", (pid,), "rows")
        return True, "**lifted** casino ban (casino_banned=0) — applies on next connect"

    def unwhitelist_cop(self, pid):
        # owner 2026-06-18: full cop removal (Officer Maggot !unwhitelist). Rank + slot off = coplevel +
        # copretired (players_global) + ismaxtac (players) all -> 0. KEEPS cop progress (cop_exp/gear/licenses/
        # talents) so a re-whitelist restores their record. INSERT IGNORE so a never-joined PID still takes.
        self.q("INSERT IGNORE INTO players_global (playerid) VALUES (%s)", (pid,), "rows")
        self.q("UPDATE players_global SET coplevel=0, copretired=0 WHERE playerid=%s", (pid,), "rows")
        self.q("UPDATE players SET ismaxtac=0, isscd=0 WHERE playerid=%s", (pid,), "rows")
        return True, "cop whitelist **removed** — coplevel=0, copretired=0, ismaxtac=0, isscd=0"

    def player_logs(self, pid):
        # ENTIRE audit trail for a player from the `log` table (APS_fnc_logIt sink), oldest first.
        return self.q("SELECT id, ts, tag, name, message FROM log WHERE playerid=%s ORDER BY id ASC", (pid,))

    def comp(self, pid, amount, account="bank"):
        # owner 2026-06-21 (comp money LOST on logout -- player108): split by online status.
        #   OFFLINE -> credit the DB DIRECTLY (durable; applied on next login). The mailbox path credits the bank
        #     CLIENT-SIDE only on collect (APS_fnc_processMailbox -> AP_fnc_uC) and clears the mailbox first, so
        #     a player who collected then logged off before their next save LOST it = "keeps losing comp money".
        #   ONLINE -> still mailbox, because a direct DB write would be clobbered by the live session's next save.
        #     (The server fn_processMailbox now also persists collects directly as of b0085, so online is durable too.)
        # online table is maintained on connect/disconnect (fn_queryRequest / fn_playerDisconnected:105).
        amount = int(amount)
        col = "cash" if account == "cash" else "bankacc"
        label = "cash" if account == "cash" else "bank"
        on = self.q("SELECT COUNT(*) c FROM online WHERE playerid=%s", (pid,), "one")
        is_online = int((on or {}).get("c", 0)) > 0
        if not is_online:
            n = self.q(f"UPDATE players SET {col} = {col} + %s WHERE playerid=%s", (amount, pid), "rows")
            if not n:
                return False, f"no players row for {pid} (have they ever joined?) -- not comped."
            return True, f"credited ${amount:,} straight to their {label} (offline) -- durable, applied on next login."
        # ONLINE -> mailbox
        self.q("INSERT IGNORE INTO players_global (playerid) VALUES (%s)", (pid,), "rows")
        row = self.q("SELECT mailbox FROM players_global WHERE playerid=%s", (pid,), "one")
        raw = ((row or {}).get("mailbox") or "").strip()
        try:
            box = json.loads(raw) if raw not in ("", "[]") else []
            if not isinstance(box, list):
                box = []
        except Exception:
            box = []
        box.append([label, amount, random.randint(1, 99999)])
        self.q("UPDATE players_global SET mailbox=%s WHERE playerid=%s",
               (json.dumps(box, separators=(",", ":")), pid), "rows")
        return True, f"mailed ${amount:,} to their {label} mailbox (online -- Check Mailbox at the Altis Exchange NPC)."

    # ---- discord <-> playerID linking (!link) ----
    def player_exists(self, pid):
        return bool(self.q("SELECT 1 FROM players WHERE playerid=%s LIMIT 1", (pid,), "one"))

    def link_by_discord(self, discord_id):
        return self.q("SELECT discord_id, playerid, reward_pending FROM discord_links "
                      "WHERE discord_id=%s", (int(discord_id),), "one")

    def link_by_pid(self, pid):
        return self.q("SELECT discord_id, playerid FROM discord_links WHERE playerid=%s", (pid,), "one")

    def create_link(self, discord_id, pid, reward_pending):
        # PK on discord_id + UNIQUE on playerid -> a dup on either side raises; the caller checks first,
        # this is the final guard against a race. reward_pending=1 -> the server grants the bank incentive
        # on this PID's next connect (fn_queryRequest) then clears the flag.
        try:
            self.q("INSERT INTO discord_links (discord_id, playerid, reward_pending) VALUES (%s,%s,%s)",
                   (int(discord_id), pid, 1 if reward_pending else 0), "rows")
            return True, None
        except pymysql.err.IntegrityError as e:
            return False, str(e)

    # ---- support tickets (website web_tickets / web_ticket_messages bridge, 2026-07-05) ----
    def ticket_player_name(self, pid):
        r = self.q("SELECT name FROM players WHERE playerid=%s ORDER BY id DESC LIMIT 1", (pid,), "one")
        return (r or {}).get("name") or "Player"

    def ticket_open_for(self, pid):
        # open/answered tickets the player OWNS, most-recently-updated first
        return self.q("SELECT id, subject, status FROM web_tickets WHERE playerid=%s "
                      "AND status IN ('open','answered') ORDER BY updated_at DESC", (pid,), "all") or []

    def ticket_owned(self, pid, tid):
        return self.q("SELECT id, subject, status FROM web_tickets WHERE id=%s AND playerid=%s LIMIT 1",
                      (int(tid), pid), "one")

    def ticket_add_reply(self, tid, pid, name, body):
        # a linked owner replying from Discord: mirror the website's opener-reply (is_staff=0, status->open).
        # ownership enforced by ticket_owned. returns the ticket dict on success, "closed", or None.
        r = self.ticket_owned(pid, tid)
        if not r:
            return None
        if r.get("status") == "closed":
            return "closed"
        self.q("INSERT INTO web_ticket_messages (ticket_id, author_id, author_name, is_staff, body) "
               "VALUES (%s,%s,%s,0,%s)", (int(tid), pid, str(name)[:64], str(body)[:4000]), "rows")
        self.q("UPDATE web_tickets SET status='open', updated_at=NOW() WHERE id=%s", (int(tid),), "rows")
        return r

    def ticket_new_staff_replies(self, last_id):
        return self.q(
            "SELECT m.id, m.ticket_id, m.body, t.playerid, t.subject "
            "FROM web_ticket_messages m JOIN web_tickets t ON t.id=m.ticket_id "
            "WHERE m.is_staff=1 AND m.id > %s ORDER BY m.id ASC LIMIT 200", (int(last_id),), "all") or []

    def ticket_max_msg_id(self):
        r = self.q("SELECT COALESCE(MAX(id),0) AS m FROM web_ticket_messages", (), "one")
        return int((r or {}).get("m", 0))

    # ---- beta-tester whitelist + one-time $1M bonus (LooneyBin 2026-06-13) ----
    def is_betatester(self, pid):
        r = self.q("SELECT betatester FROM players_global WHERE playerid=%s", (pid,), "one")
        return bool(r and r.get("betatester"))

    def grant_betatester(self, pid):
        # whitelist flag (clothing-shop gate): upsert so a never-joined UID still sticks -- insertRequest's
        # later `INSERT IGNORE` won't clobber the 1 (BUGS: betatester would reset to default-0 otherwise).
        self.q("INSERT INTO players_global (playerid, betatester) VALUES (%s,1) "
               "ON DUPLICATE KEY UPDATE betatester=1", (pid,), "rows")
        # one-time $1M: server grants on next connect (fn_queryRequest beta block) then clears beta_pending
        self.q("UPDATE discord_links SET beta_pending=1 WHERE playerid=%s", (pid,), "rows")

    def all_links(self):
        return self.q("SELECT discord_id, playerid FROM discord_links", (), "all") or []

    # ---- server bridge: bot_commands queue + bans ----
    @staticmethod
    def _clean(s):
        # strip chars that would break the server-side QUOTE()->compile read of the text
        return re.sub(r"[\\'\"`\r\n]", "", s or "")[:240]

    def queue(self, command, target=None, arg1=None, arg2=None, issued_by=None):
        self.q("INSERT INTO bot_commands (command, target, arg1, arg2, issued_by) VALUES (%s,%s,%s,%s,%s)",
               (command, target,
                self._clean(arg1) if arg1 is not None else None,
                self._clean(arg2) if arg2 is not None else None, issued_by), "rows")

    def ban(self, pid, days, reason, by):
        days = int(days)
        reason = self._clean(reason) or "No reason"
        if days <= 0:
            self.q("INSERT INTO bans (playerid, reason, banned_by, until) VALUES (%s,%s,%s,NULL)",
                   (pid, reason, by), "rows")
        else:
            self.q("INSERT INTO bans (playerid, reason, banned_by, until) "
                   "VALUES (%s,%s,%s, DATE_ADD(NOW(), INTERVAL %s DAY))", (pid, reason, by, days), "rows")
        self.queue("kick", target=pid, arg2=f"Banned: {reason}", issued_by=by)

    # ---- MaxSec cop-whitelist applications (Officer Maggot bot, 2026-06-16) ----
    def maxsec_init(self):
        # one-time table create; safe to call on every bot boot.
        self.q(
            "CREATE TABLE IF NOT EXISTS maxsec_applications ("
            " id INT AUTO_INCREMENT PRIMARY KEY,"
            " discord_id BIGINT NOT NULL,"
            " discord_name VARCHAR(128),"
            " ig_name VARCHAR(128),"
            " pid VARCHAR(20),"
            " dob VARCHAR(64),"
            " time_on_server VARCHAR(255),"
            " cop_experience TEXT,"
            " why TEXT,"
            " disciplinary TEXT,"
            " status ENUM('pending','accepted','denied') NOT NULL DEFAULT 'pending',"
            " reviewer_id BIGINT,"
            " reviewer_name VARCHAR(128),"
            " decision_note VARCHAR(512),"
            " thread_id BIGINT,"
            " review_msg_id BIGINT,"
            " created_at DATETIME DEFAULT CURRENT_TIMESTAMP,"
            " decided_at DATETIME,"
            " KEY k_discord (discord_id), KEY k_status (status), KEY k_pid (pid)"
            ") CHARSET=utf8mb4", (), "rows")
        # idempotent migration for a table created before thread_id existed (MariaDB supports IF NOT EXISTS)
        try:
            self.q("ALTER TABLE maxsec_applications ADD COLUMN IF NOT EXISTS thread_id BIGINT", (), "rows")
        except Exception:
            pass

    def maxsec_pending_for(self, discord_id):
        return self.q("SELECT id FROM maxsec_applications WHERE discord_id=%s AND status='pending' "
                      "ORDER BY id DESC LIMIT 1", (int(discord_id),), "one")

    def maxsec_insert(self, discord_id, discord_name, ig_name, pid, dob, time_on_server,
                   cop_experience, why, disciplinary):
        return self.q(
            "INSERT INTO maxsec_applications (discord_id, discord_name, ig_name, pid, dob, "
            " time_on_server, cop_experience, why, disciplinary) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            (int(discord_id), discord_name, ig_name, pid, dob, time_on_server,
             cop_experience, why, disciplinary), "lastrowid")

    def maxsec_get(self, app_id):
        return self.q("SELECT * FROM maxsec_applications WHERE id=%s", (int(app_id),), "one")

    def maxsec_set_msg(self, app_id, thread_id, msg_id):
        self.q("UPDATE maxsec_applications SET thread_id=%s, review_msg_id=%s WHERE id=%s",
               (int(thread_id), int(msg_id), int(app_id)), "rows")

    def maxsec_decide(self, app_id, status, reviewer_id, reviewer_name, note=None):
        # atomically claim a still-pending application; returns the row if WE made the decision, else None
        # (someone else already accepted/denied it -> the button is a no-op for the loser of the race).
        rows = self.q(
            "UPDATE maxsec_applications SET status=%s, reviewer_id=%s, reviewer_name=%s, "
            " decision_note=%s, decided_at=NOW() WHERE id=%s AND status='pending'",
            (status, int(reviewer_id), reviewer_name, note, int(app_id)), "rows")
        if not rows:
            return None
        return self.maxsec_get(app_id)


# ---------------------------------------------------------------- formatters
def fmt_money(n):
    try:
        return f"${int(n):,}"
    except (TypeError, ValueError):
        return "$?"


def fmt_info(d):
    pid = d["pid"]; p = d["p"]; g = d["g"]
    cop = _rank_name(COP_RANKS, g.get("coplevel"))
    med = _rank_name(MED_RANKS, g.get("mediclevel"))
    adm = _rank_name(SRV_RANKS, g.get("adminlevel"))
    lines = [
        f"**Player** `{pid}`  ·  {'🟢 online' if d['online'] else '⚪ offline'}",
        f"Name: **{p.get('name','?')}**",
        f"Bank {fmt_money(p.get('bankacc'))} · Cash {fmt_money(p.get('cash'))} · "
        f"ND {p.get('new_drachma',0)} · Wealth {fmt_money(g.get('wealth'))}",
        f"Whitelist — cop **{cop}** · med **{med}** · srv **{adm}** · "
        f"beta {g.get('betatester',0)} · retired {g.get('copretired',0)}",
        f"Arrested {p.get('arrested',0)} · New {p.get('new_player','?')} · Updated {p.get('lastupdated','?')}",
        _fmt_gang(d.get("gang"), pid),
        f"Aliases (last 5): {_fmt_aliases(d.get('names'))}",
        f"Last ban: {_fmt_ban(d.get('ban'))}",
    ]
    return "\n".join(lines)


# gang ranks are INVERTED: 1 = leader (top) .. 5 = recruit (lowest). No in-game name labels exist (the
# mission gates purely on the numbers: R1 = destroy/set-house, R1-R3 = invite/pull/garage, R4-R5 restricted),
# so these labels are descriptive only.
GANG_RANKS = {1: "Leader", 2: "Co-Leader", 3: "Officer", 4: "Member", 5: "Recruit"}


def _fmt_gang(gang, pid, cap=25):
    if not gang:
        return "Gang: —"
    members = gang.get("members") or []
    head = (f"Gang: **{gang.get('name','?')}** (#{gang.get('id')}) · {len(members)} member(s)"
            f" · bank {fmt_money(gang.get('bank'))}")
    rows = []
    for m in members[:cap]:
        rv = m.get("gangrank0")
        try:
            rn = GANG_RANKS.get(int(rv), f"R{rv}")
        except (TypeError, ValueError):
            rn = "R?"
        mark = " ⬅ (this player)" if str(m.get("playerid")) == str(pid) else ""
        rows.append(f"  • {m.get('name','?')} — {rn}{mark}")
    if len(members) > cap:
        rows.append(f"  …and {len(members) - cap} more")
    return head + ("\n" + "\n".join(rows) if rows else "")


def _fmt_aliases(names):
    if not names:
        return "—"
    return ", ".join(f"**{n['name']}**" for n in names)


def _fmt_ban(ban):
    if not ban:
        return "none"
    until = ban.get("until")
    when = "permanent" if until is None else f"until {until}"
    return (f"⛔ {when} — _{ban.get('reason') or 'No reason'}_ "
            f"by {ban.get('banned_by') or '?'} (issued {ban.get('created','?')})")


def fmt_pid(rows):
    if not rows:
        return "No player found by that name."
    return "**Matches:**\n" + "\n".join(f"`{r['playerid']}` — {r['name']}" for r in rows)
