#!/usr/bin/env python3
"""
lagwatch.py  --  LooneyBin lag-switch DETECTOR (Layer 2).  stdlib only.

A lag switch = a player deliberately throttling/dropping their OWN packets so they freeze on the
server then teleport on resync (unhittable, warp kills). SQF has no per-player ping, so the only
script-visible signal is kinematic guessing. The ENGINE knows each player's real ping though, and
exposes it over BattlEye RCON (`players` command). This polls that, tracks per-player ping, and
flags the lag-switch SIGNATURE -- repeated ping spike->recover->spike OR timeout/lobby flaps -- to
the CLANKR Discord channel for HUMAN REVIEW.

  IT NEVER BANS OR KICKS. A lag switch and a bad ISP are byte-identical; intent is unprovable. The
  reliable AUTO action lives in the engine (server.cfg maxPacketLoss/maxDesync + kickClientsOnSlowNetwork,
  = Layer 1). This is detection/visibility only -- surfaces repeat offenders so a human can watch them.

Signal model (per player, rolling window):
  - SPIKE  : a ping sample >= spike_ms AND >= rel_mult x the player's own calm-baseline median
             (so a 40ms player jumping to 600 trips; a steady-300 overseas player does NOT).
  - FLAP   : present -> absent (dropped off the list) -> present, OR present -> (Lobby) -> present,
             inside the window (= a brief timeout, the hallmark of a switch).
  - FLAG   : (#spikes + #flaps) >= min_events in the window, with at least one RECOVERY present
             (oscillation). Steady-high ping with NO recovery is a bad connection, not a switch -> not flagged.

Runs standalone (mirrors deploy/ddos_watch.sh): writes the same outbox JSON LoonyBot posts.
  Launch:  cd loonybot && venv/bin/python lagwatch.py        (or plain python3 -- stdlib only)
  Auto-(re)launched by deploy/run-boot2.sh on boot IFF config.json lagwatch.enabled = true.

Config (config.json "lagwatch", all optional -- safe defaults; RCON creds AUTO-READ from the live
BE cfg so no second copy of the password is committed):
  enabled, rcon_host, rcon_port, rcon_password, be_cfg (path to beserver_x64.cfg to read creds from),
  poll_secs, window_secs, spike_ms, baseline_ms, rel_mult, min_events, cooldown_secs,
  channel_id (default clankr_channel_id), ping_ids (default clankr_ping_ids).
"""
import os, sys, json, time, socket, struct, zlib, re, glob
from collections import defaultdict, deque

HERE = os.path.dirname(os.path.abspath(__file__))
OUTBOX = os.path.join(HERE, "outbox")
CFG_PATH = os.path.join(HERE, "config.json")


def load_cfg():
    try:
        with open(CFG_PATH) as f:
            return json.load(f)
    except Exception as e:
        print(f"[lagwatch] FATAL: cannot read config.json: {e}", flush=True)
        sys.exit(1)


CFG = load_cfg()
_L = CFG.get("lagwatch", {}) or {}

ENABLED       = bool(_L.get("enabled", False))
RCON_HOST     = str(_L.get("rcon_host", "127.0.0.1"))
POLL_SECS     = float(_L.get("poll_secs", 5))
WINDOW_SECS   = float(_L.get("window_secs", 120))
SPIKE_MS      = int(_L.get("spike_ms", 700))        # absolute ping (ms) that counts as a spike
BASELINE_MS   = int(_L.get("baseline_ms", 200))     # samples below this = "calm" (used for the median baseline)
REL_MULT      = float(_L.get("rel_mult", 3.0))      # a spike must also be >= this x the player's calm median
MIN_EVENTS    = int(_L.get("min_events", 3))        # spikes+flaps in the window to flag
COOLDOWN_SECS = float(_L.get("cooldown_secs", 600)) # per-player alert dedupe
CHANNEL       = int(_L.get("channel_id", CFG.get("clankr_channel_id", 0)) or 0)
PING_IDS      = [int(x) for x in (_L.get("ping_ids") or CFG.get("clankr_ping_ids") or CFG.get("owner_ids") or [])]
PING = " ".join(f"<@{u}>" for u in PING_IDS)
HEARTBEAT_HRS = float(_L.get("heartbeat_hours", 12))


def _read_be_creds():
    """RCON password + port: config override wins, else parse the live BE cfg (no committed second copy)."""
    pw = _L.get("rcon_password")
    port = _L.get("rcon_port")
    if pw and port:
        return str(pw), int(port)
    candidates = []
    if _L.get("be_cfg"):
        candidates.append(_L["be_cfg"])
    candidates += [
        os.path.expanduser("~/.local/share/Steam/steamapps/common/Arma 3 Server/battleye/beserver_x64.cfg"),
        os.path.expanduser("~/.local/share/Steam/steamapps/common/Arma 3 Server/battleye/beserver.cfg"),
    ]
    candidates += glob.glob(os.path.expanduser(
        "~/.local/share/Steam/steamapps/common/Arma 3 Server/battleye/**/beserver_x64.cfg"), recursive=True)
    for path in candidates:
        try:
            txt = open(path, "r", errors="replace").read()
        except Exception:
            continue
        mpw = re.search(r"^\s*RConPassword\s+(\S+)", txt, re.M)
        mpt = re.search(r"^\s*RConPort\s+(\d+)", txt, re.M)
        if mpw and mpt:
            return (pw or mpw.group(1)), int(port or mpt.group(1))
    return (str(pw) if pw else None), (int(port) if port else 2310)


# ----------------------------------------------------------------- BattlEye RCON (BERcon) protocol
# Packet:  'B''E' + CRC32LE(payload) + payload     payload = 0xFF <subtype> <data...>
#   subtype 0x00 login   : send 0xFF 00 <pass>      ; recv 0xFF 00 (01=ok / 00=fail)
#   subtype 0x01 command : send 0xFF 01 <seq> <cmd> ; recv 0xFF 01 <seq> <data>  (multipart: <seq> 00 <total> <idx> <data>)
#   subtype 0x02 server  : recv 0xFF 02 <seq> <msg> ; MUST ack with 0xFF 02 <seq>
# Keepalive: an empty command (0xFF 01 <seq>) at least every ~45s or the server drops the session.
class BERconError(Exception):
    pass


class BERcon:
    def __init__(self, host, port, password):
        self.addr = (host, port)
        self.password = password.encode("ascii", "ignore")
        self.sock = None
        self.seq = 0
        self.last_tx = 0.0
        self._frag = {}  # seq -> {"total": n, "parts": {idx: bytes}}

    @staticmethod
    def _wrap(payload):
        crc = zlib.crc32(payload) & 0xFFFFFFFF
        return b"BE" + struct.pack("<I", crc) + payload

    def _raw_send(self, payload):
        self.sock.sendto(self._wrap(payload), self.addr)
        self.last_tx = time.time()

    @staticmethod
    def _payload(pkt):
        # strip 'BE' + crc(4); return the 0xFF... payload (trust the CRC; BE on loopback is reliable)
        if len(pkt) < 8 or pkt[0:2] != b"BE" or pkt[6] != 0xFF:
            return None
        return pkt[6:]

    def connect(self, timeout=8):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(timeout)
        self._raw_send(b"\xff\x00" + self.password)
        try:
            pkt, _ = self.sock.recvfrom(4096)
        except socket.timeout:
            raise BERconError("login timeout (RCON not bound / wrong port?)")
        pl = self._payload(pkt)
        if not pl or pl[1] != 0x00:
            raise BERconError("malformed login reply")
        if len(pl) < 3 or pl[2] != 0x01:
            raise BERconError("login REJECTED (wrong RConPassword?)")
        self.sock.setblocking(False)

    # NOTE (verified live 2026-06-25): this BE server tracks an EXPECTED command-sequence counter that starts at
    # 0 on login and only answers the IN-ORDER seq (0,1,2,...). So the FIRST command after connect MUST be seq 0,
    # then advance. Sending seq 1 first (pre-increment) left the counter stuck at 0 and EVERY reply was silently
    # dropped (login OK, but `players` never came back). Hence: emit the CURRENT seq, THEN advance.
    def keepalive(self):
        if time.time() - self.last_tx >= 30:
            self._raw_send(b"\xff\x01" + bytes([self.seq]))   # empty cmd (keepalive) at the current seq
            self.seq = (self.seq + 1) & 0xFF

    def send_command(self, cmd):
        s = self.seq
        self._frag.pop(s, None)
        self._raw_send(b"\xff\x01" + bytes([s]) + cmd.encode("ascii", "ignore"))
        self.seq = (self.seq + 1) & 0xFF
        return s

    def pump(self):
        """Drain all pending datagrams. ACK server msgs, reassemble command replies.
        Returns list of (seq, full_text) for any command responses completed this call."""
        done = []
        while True:
            try:
                pkt, _ = self.sock.recvfrom(8192)
            except (BlockingIOError, socket.error):
                break
            pl = self._payload(pkt)
            if not pl or len(pl) < 2:
                continue
            sub = pl[1]
            if sub == 0x02:                                   # server message -> must ack
                if len(pl) >= 3:
                    self._raw_send(b"\xff\x02" + bytes([pl[2]]))
                continue
            if sub == 0x01:                                   # command response
                if len(pl) < 3:
                    continue
                seq = pl[2]
                rest = pl[3:]
                # multipart header: 0x00 <total> <index> <data...>
                if len(rest) >= 3 and rest[0] == 0x00:
                    total, idx, data = rest[1], rest[2], rest[3:]
                    f = self._frag.setdefault(seq, {"total": total, "parts": {}})
                    f["total"] = total
                    f["parts"][idx] = data
                    if len(f["parts"]) >= total:
                        buf = b"".join(f["parts"][i] for i in sorted(f["parts"]))
                        del self._frag[seq]
                        done.append((seq, buf.decode("utf-8", "replace")))
                else:
                    done.append((seq, rest.decode("utf-8", "replace")))
        return done

    def close(self):
        try:
            if self.sock:
                self.sock.close()
        except Exception:
            pass


# ----------------------------------------------------------------- players-table parsing
# "0   1.2.3.4:2304   50   <32hexGUID>(?)   Name (Lobby)"
PLAYER_RE = re.compile(
    r"^\s*(\d+)\s+([0-9.]+):\d+\s+(-?\d+)\s+([0-9a-fA-F]{32})(?:\([^)]*\))?\s+(.*?)\s*$")


def parse_players(text):
    """-> list of dicts {id, ip, ping, guid, name, lobby}."""
    out = []
    for line in text.splitlines():
        m = PLAYER_RE.match(line)
        if not m:
            continue
        name = m.group(5)
        lobby = name.endswith("(Lobby)")
        if lobby:
            name = name[:-len("(Lobby)")].strip()
        out.append({
            "id": int(m.group(1)), "ip": m.group(2), "ping": int(m.group(3)),
            "guid": m.group(4).lower(), "name": name, "lobby": lobby,
        })
    return out


# ----------------------------------------------------------------- detection state
# IMPORTANT (learned from live data): BE marks loading/JIP players "(Lobby)", and on a busy server many
# players sit in Lobby briefly as they join -- so a Lobby state is NORMAL, not a lag switch. We therefore:
#   - record a ping sample ONLY while a player is IN-WORLD (not lobby) -- lobby pings are loading noise;
#   - count a FLAP only as a SHORT vanish->return while in-world (a lag timeout blip), NEVER a lobby pass
#     (that's a relog/JIP) and never a long absence (that's a relog);
#   - require an established in-world baseline before we trust spikes (don't flag someone still loading in).
FLAP_MAX_GAP = float(_L.get("flap_max_gap", 15))   # vanish<=this then return in-world = a lag blip flap
MIN_BASELINE = int(_L.get("min_baseline", 5))      # in-world calm samples needed before we trust spike flags

_hist = defaultdict(lambda: deque())     # guid -> deque[(ts, ping)]  (in-world samples only)
_spikes = defaultdict(lambda: deque())   # guid -> deque[ts]
_flaps = defaultdict(lambda: deque())    # guid -> deque[ts]
_calm_seen = defaultdict(int)            # guid -> count of calm in-world samples ever (baseline established?)
_last_state = {}                         # guid -> 'inworld' | 'lobby' | 'absent' (from last poll)
_inworld_ts = {}                         # guid -> last ts seen in-world
_name = {}                               # guid -> last name
_ip = {}                                 # guid -> last ip
_cooldown = {}                           # guid -> last alert ts


def _roll(dq, now):
    while dq and now - (dq[0][0] if isinstance(dq[0], tuple) else dq[0]) > WINDOW_SECS:
        dq.popleft()


def _median(vals):
    if not vals:
        return 0
    s = sorted(vals)
    n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2.0


def emit(name, guid, ip, detail, snippet):
    """drop a CLANKR-channel review alert (no auto-action). Matches clankr.emit's outbox JSON."""
    if CHANNEL == 0:
        print(f"[lagwatch] no channel -- would alert: {name} {guid} :: {detail}", flush=True)
        return
    os.makedirs(OUTBOX, exist_ok=True)
    head = "🟡 **CLANKR MOD-ALERT** — LAG-SWITCH (review)"
    body = (f"{head}\n**Player:** {name} `({guid})`  `{ip}`\n{detail}\n"
            f"```\n{snippet[:900]}\n```"
            f"_RCON-measured ping pattern. NOT auto-actioned (a lag switch and a bad ISP look identical). "
            f"Spectate them / check if it lines up with fights before acting._")
    if PING:
        body += f"\n{PING}"
    job = {"channel_id": CHANNEL, "content": body}
    fn = os.path.join(OUTBOX, f"clankr_{int(time.time()*1000)}_{abs(hash(guid)) % 100000}.json")
    tmp = fn + ".tmp"
    json.dump(job, open(tmp, "w"))
    os.replace(tmp, fn)
    print(f"[lagwatch] ALERT lag-switch | {name} ({guid}) :: {detail}", flush=True)


def inspect(players, now):
    """Update per-player history from one `players` snapshot and flag the lag-switch signature."""
    cur = {p["guid"]: p for p in players}
    for g, p in cur.items():
        _name[g] = p["name"]
        _ip[g] = p["ip"]
        prev_state = _last_state.get(g, "absent")

        if p["lobby"]:
            _last_state[g] = "lobby"          # loading/JIP -- not gameplay; record nothing
            continue

        # in-world this poll
        # FLAP: a SHORT vanish (truly absent, not lobby) then back in-world = a lag timeout blip.
        gap = now - _inworld_ts.get(g, now)
        if prev_state == "absent" and 0 < gap <= FLAP_MAX_GAP and _calm_seen[g] >= MIN_BASELINE:
            _flaps[g].append(now)
            _roll(_flaps[g], now)

        # ping sample (in-world only)
        h = _hist[g]
        h.append((now, p["ping"]))
        _roll(h, now)
        if 0 <= p["ping"] < BASELINE_MS:
            _calm_seen[g] += 1

        # SPIKE: high absolute AND high vs the player's own calm baseline, once a baseline exists
        calm = [pg for (_t, pg) in h if 0 <= pg < BASELINE_MS]
        base = _median(calm) if calm else BASELINE_MS
        if (_calm_seen[g] >= MIN_BASELINE and p["ping"] >= SPIKE_MS
                and p["ping"] >= REL_MULT * max(base, 1)):
            _spikes[g].append(now)
        _roll(_spikes[g], now)

        _last_state[g] = "inworld"
        _inworld_ts[g] = now

    # anyone known but NOT in the list this poll = absent (drives the next-poll flap test)
    for g in list(_last_state.keys()):
        if g not in cur:
            _last_state[g] = "absent"

    # FLAG: enough spikes+flaps in the window, with a recovery (oscillation, not a steady-bad line)
    for g, p in cur.items():
        if p["lobby"]:
            continue
        ns, nf = len(_spikes[g]), len(_flaps[g])
        if ns + nf < MIN_EVENTS:
            continue
        if now - _cooldown.get(g, 0) < COOLDOWN_SECS:
            continue
        pings = [pg for (_t, pg) in _hist[g]]
        calm = [pg for pg in pings if 0 <= pg < BASELINE_MS]
        if not calm:                          # no recovery sample -> just a bad connection, not a switch
            continue
        _cooldown[g] = now
        peak = max(pings) if pings else 0
        detail = (f"**Lag-switch pattern** in the last {int(WINDOW_SECS)}s: "
                  f"**{ns} ping-spike(s)** (>= {SPIKE_MS}ms) + **{nf} timeout flap(s)**, "
                  f"recovering to ~{int(_median(calm))}ms between. Peak {peak}ms.")
        recent = ", ".join(str(int(pg)) for (_t, pg) in list(_hist[g])[-16:])
        emit(_name[g], g, _ip.get(g, "?"), detail, f"recent in-world pings (ms): {recent}")

    # prune players gone > 2 windows so the dicts don't grow unbounded
    stale = [g for g, h in list(_hist.items()) if not h or now - h[-1][0] > 2 * WINDOW_SECS]
    for g in stale:
        for d in (_hist, _spikes, _flaps, _calm_seen, _last_state, _inworld_ts, _cooldown, _name, _ip):
            d.pop(g, None)


# ----------------------------------------------------------------- main loop
def run():
    if not ENABLED:
        print("[lagwatch] disabled (config.json lagwatch.enabled=false) -- exiting. "
              "Set it true + (re)launch to arm.", flush=True)
        return
    pw, port = _read_be_creds()
    if not pw:
        print("[lagwatch] FATAL: no RConPassword found (set lagwatch.rcon_password or be_cfg). exiting.", flush=True)
        return
    print(f"[lagwatch] starting -- RCON {RCON_HOST}:{port}, poll {POLL_SECS}s, window {int(WINDOW_SECS)}s, "
          f"spike>={SPIKE_MS}ms x{REL_MULT}, flag>={MIN_EVENTS} events. CHANNEL={CHANNEL}. REVIEW-ONLY (never bans).",
          flush=True)
    last_hb = time.time()
    backoff = 2
    while True:
        rc = BERcon(RCON_HOST, port, pw)
        try:
            rc.connect()
            print("[lagwatch] RCON login OK", flush=True)
            backoff = 2
            next_poll = 0.0
            while True:
                now = time.time()
                if now >= next_poll:
                    rc.send_command("players")
                    next_poll = now + POLL_SECS
                rc.keepalive()
                # drain replies for a slice of the poll interval
                deadline = min(next_poll, now + 1.0)
                while time.time() < deadline:
                    for _seq, text in rc.pump():
                        if "Players on server" in text or re.search(r"\d+\s+[0-9.]+:\d+\s+-?\d+\s+[0-9a-f]{32}", text):
                            inspect(parse_players(text), time.time())
                    time.sleep(0.05)
                if HEARTBEAT_HRS > 0 and time.time() - last_hb >= HEARTBEAT_HRS * 3600:
                    last_hb = time.time()
                    print(f"[lagwatch] heartbeat: tracking {len(_hist)} players", flush=True)
        except (BERconError, OSError) as e:
            print(f"[lagwatch] RCON error: {e} -- reconnecting in {backoff}s", flush=True)
        finally:
            rc.close()
        time.sleep(backoff)
        backoff = min(backoff * 2, 60)


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        pass
