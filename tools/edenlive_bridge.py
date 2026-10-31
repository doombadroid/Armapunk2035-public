#!/usr/bin/env python3
"""edenlive_bridge -- the Eden Live host's door into map_objects (design: EdenLive repo,
docs/armapunk/2026-09-08-eden-live-t3-design.md).

Runs on the game box next to Postgres, HTTP on 127.0.0.1 only, one shared token. The Eden Live
headless host (C#) is its only client: it POSTs the edits editors make in 3DEN and polls for rows
that changed under it (in-game F12 edits, pushes). It never does frame maths: editors send the
model-centre world position plus vectorDir/vectorUp, which is exactly what the table stores.

    GET  /rev                      {"world": ..., "rev": N}
    GET  /rows?since=N&limit=500   rows with rev > N, ordered by rev, deleted ones included
    POST /ops                      [{"op": "insert"|"update"|"delete", ...}] -> [{"tmp","id","rev"}]
    GET  /players                  live player positions (eden_live_players, rows < 10 s old)
    GET  /mission/manifest         the staged edit scenario: {rev, staged_at, files:[{path,size,sha1}]}
    GET  /mission/file?path=&offset=&len=   one slice of one of those files

Writes go through tools/map_push.sql_ops, the same statements the Eden push uses, with author
"eden-live:<editor>". `init` is written only when the host says so (op "init_ok", from the designer
key's init flag, see EdenLive/Tools/designer_keys.sh) or, for a host without keys, for editors
listed in ~/.config/armapunk/edenlive.editors (one name per line); everyone else's init is dropped
and logged. The map_objects_stamp trigger
assigns rev on every write, so this process never invents one.

    python3 tools/edenlive_bridge.py --world Malden --port 2331
    python3 tools/edenlive_bridge.py --world EdenLiveTest --port 2399   # tests use a scratch world

The mission endpoints exist so designers never have to be sent a zip again: the bridge stages the
edit scenario from the same table the host serves (tools/map_codegen.py, into a cache directory),
publishes a hash manifest, and hands out the pieces. The Eden Live host relays them over its own
authenticated connection, so nothing here is ever exposed to the network.
"""
import argparse
import hashlib
import json
import logging
import os
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apdb_dsn          # noqa: E402
import map_push          # noqa: E402

import psycopg           # noqa: E402

log = logging.getLogger("edenlive")

CONFIG_DIR = os.path.expanduser("~/.config/armapunk")
TOKEN_FILE = os.path.join(CONFIG_DIR, "edenlive.token")
EDITORS_FILE = os.path.join(CONFIG_DIR, "edenlive.editors")
PLAYER_STALE_S = 10

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MISSION_SRC = os.path.join(REPO, "mission", "Armapunk2035.Malden")
MISSION_CACHE = os.path.expanduser("~/.cache/armapunk/elive_mission")
MISSION_MAX_AGE_S = 600      # re-stage at most this often; the delta join covers the rest
MISSION_MAX_SLICE = 1 << 20  # 1 MiB per request

ROW_COLS = ("id", "classname", "model", "scale", "x", "y", "z", "vdir_x", "vdir_y", "vdir_z",
            "vup_x", "vup_y", "vup_z", "init", "lod", "stream_r", "deleted", "rev")

PLAYERS_DDL = """
CREATE TABLE IF NOT EXISTS eden_live_players (
    uid   text PRIMARY KEY,
    name  text NOT NULL DEFAULT '',
    x     double precision NOT NULL,
    y     double precision NOT NULL,
    z     double precision NOT NULL,
    dir   double precision NOT NULL DEFAULT 0,
    at    timestamptz NOT NULL DEFAULT now()
)"""


def read_token():
    try:
        return open(TOKEN_FILE).read().strip()
    except FileNotFoundError:
        return ""


def read_editors():
    try:
        return {l.strip() for l in open(EDITORS_FILE) if l.strip() and not l.startswith("#")}
    except FileNotFoundError:
        return set()


def row_to_json(r):
    d = dict(zip(ROW_COLS, r))
    return {
        "id": d["id"], "cls": d["classname"] or "", "model": d["model"] or "",
        "scale": float(d["scale"]) if d["scale"] is not None else 1.0,
        "world": [float(d["x"]), float(d["y"]), float(d["z"])],
        "dir": [float(d["vdir_x"]), float(d["vdir_y"]), float(d["vdir_z"])],
        "up": [float(d["vup_x"]), float(d["vup_y"]), float(d["vup_z"])],
        "init": d["init"] or "", "lod": d["lod"],
        "stream_r": float(d["stream_r"]) if d["stream_r"] is not None else None,
        "deleted": bool(d["deleted"]), "rev": int(d["rev"]),
    }


def op_to_entity(op, allow_init):
    """A bridge op -> the entity dict map_push.sql_ops expects (world/dir/up already model-centre)."""
    e = {"world": tuple(float(v) for v in op["world"]),
         "dir": tuple(float(v) for v in op["dir"]),
         "up": tuple(float(v) for v in op["up"])}
    if op.get("model"):
        e["model"] = op["model"]
        e["scale"] = float(op.get("scale", 1.0))
    else:
        e["cls"] = op.get("cls", "")
    # init travels for BOTH kinds of row. It used to be carried only for class rows, which silently
    # stripped the shop init off every vending-machine anchor placed through Eden Live (a model row
    # with `[_this,'<slug>'] call NPC_fnc_vendShop`, measured 2026-09-10 on row 14482).
    if allow_init and "init" in op:
        e["init"] = op["init"] or ""
    if op.get("lod") is not None:
        e["lod"] = int(op["lod"])
    if op.get("stream_r") is not None:
        e["stream_r"] = float(op["stream_r"])
    return e


class Bridge:
    def __init__(self, world, dsn):
        self.world = world
        self.dsn = dsn
        self.lock = threading.Lock()
        self.mission_lock = threading.Lock()

    def connect(self):
        return psycopg.connect(self.dsn)

    def ensure_players_table(self):
        with self.connect() as c:
            c.execute(PLAYERS_DDL)
            c.commit()

    def rev(self):
        with self.connect() as c:
            row = c.execute("SELECT rev FROM map_meta WHERE world=%s", (self.world,)).fetchone()
            return int(row[0]) if row else 0

    def rows_since(self, since, limit):
        with self.connect() as c:
            cur = c.execute(
                "SELECT %s FROM map_objects WHERE world=%%s AND rev > %%s ORDER BY rev LIMIT %%s"
                % ", ".join(ROW_COLS), (self.world, since, limit))
            return [row_to_json(r) for r in cur.fetchall()]

    def apply(self, ops, editors):
        """Apply a list of ops in one transaction; returns one result per op."""
        results = []
        with self.lock, self.connect() as c:
            for op in ops:
                editor = str(op.get("editor", ""))
                # Designer keys on the host decide init when they are on (init_ok present);
                # otherwise the editors file here does.
                allow_init = op["init_ok"] if isinstance(op.get("init_ok"), bool) else editor in editors
                author = "eden-live:%s" % (editor or "?")
                kind = op.get("op")
                if kind == "delete":
                    rid = int(op["id"])
                    stmts = map_push.sql_ops(self.world, {"update": [], "insert": [], "delete": [rid]}, author)
                    for sql, params in stmts:
                        c.execute(sql, params)
                    rev = c.execute("SELECT rev FROM map_objects WHERE id=%s AND world=%s", (rid, self.world)).fetchone()
                    results.append({"tmp": op.get("tmp"), "id": rid, "rev": int(rev[0]) if rev else None})
                    continue
                if "init" in op and not allow_init:
                    log.warning("init from non-allowlisted editor %r dropped (op %s id %s)", editor, kind, op.get("id"))
                e = op_to_entity(op, allow_init)
                if kind == "update":
                    rid = int(op["id"])
                    if "init" not in e and not e.get("model"):
                        # sql_ops always writes init for class rows; keep the stored value
                        cur = c.execute("SELECT init FROM map_objects WHERE id=%s AND world=%s", (rid, self.world)).fetchone()
                        e["init"] = cur[0] if cur else ""
                    stmts = map_push.sql_ops(self.world, {"update": [(rid, e)], "insert": [], "delete": []}, author)
                    for sql, params in stmts:
                        c.execute(sql, params)
                    rev = c.execute("SELECT rev FROM map_objects WHERE id=%s AND world=%s", (rid, self.world)).fetchone()
                    results.append({"tmp": op.get("tmp"), "id": rid, "rev": int(rev[0]) if rev else None})
                elif kind == "insert":
                    stmts = map_push.sql_ops(self.world, {"update": [], "insert": [e], "delete": []}, author)
                    assert len(stmts) == 1
                    sql, params = stmts[0]
                    row = c.execute(sql + " RETURNING id, rev", params).fetchone()
                    results.append({"tmp": op.get("tmp"), "id": int(row[0]), "rev": int(row[1])})
                else:
                    results.append({"tmp": op.get("tmp"), "error": "unknown op %r" % kind})
            c.commit()
        return results

    # ---------------------------------------------------------------- the edit scenario

    def _stage_dir(self):
        """The current staging: a symlink the stager repoints, so a designer mid-download keeps
        reading the tree they started on while a fresh one is built beside it."""
        return os.path.join(MISSION_CACHE, self.world)

    def stage_mission(self, force=False):
        """Stage MaldenEdit from the table into a NEW directory and repoint the current-staging
        symlink to it, at most every MISSION_MAX_AGE_S. map_codegen symlinks everything except
        mission.sqm, so a staging is cheap; reads go through the links and the manifest hashes
        what they point at. Older stagings are kept for an hour for downloads still in flight."""
        cur = self._stage_dir()
        stamp = os.path.join(cur, "AP_stage.txt")
        with self.mission_lock:
            age = time.time() - os.path.getmtime(stamp) if os.path.exists(stamp) else None
            if not force and age is not None and age < MISSION_MAX_AGE_S:
                return cur
            os.makedirs(MISSION_CACHE, exist_ok=True)
            fresh = os.path.join(MISSION_CACHE, "%s-%d" % (self.world, int(time.time())))
            env = dict(os.environ, AP_EDIT_MISSION=fresh, AP_FORCE_STAGE="1", PYSQF_DB_DSN=self.dsn)
            log.info("staging the edit scenario into %s (current age %s)", fresh, "none" if age is None else round(age))
            r = subprocess.run([sys.executable, os.path.join(REPO, "tools", "map_codegen.py"), "stage"],
                               env=env, cwd=REPO, capture_output=True, text=True, timeout=600)
            if r.returncode != 0 or not os.path.exists(os.path.join(fresh, "AP_stage.txt")):
                log.error("staging failed: %s", (r.stderr or r.stdout)[-500:])
                if not os.path.exists(stamp):
                    raise RuntimeError("staging failed and there is no earlier staging to serve")
                return cur
            # A real directory at the current path is the layout the first version of this
            # endpoint used (it staged in place). A symlink cannot be renamed over a directory,
            # so move it aside once; it is pruned with the other old stagings below.
            if os.path.isdir(cur) and not os.path.islink(cur):
                os.rename(cur, "%s-%d-legacy" % (cur, int(time.time())))
            tmp_link = cur + ".new"
            if os.path.lexists(tmp_link):
                os.unlink(tmp_link)
            os.symlink(fresh, tmp_link)
            os.replace(tmp_link, cur)            # atomic: readers see the old tree or the new one
            # prune stagings older than an hour (none of them is the current one)
            keep_after = time.time() - 3600
            for name in os.listdir(MISSION_CACHE):
                d = os.path.join(MISSION_CACHE, name)
                if d == fresh or os.path.islink(d) or not os.path.isdir(d) or not name.startswith(self.world + "-"):
                    continue
                try:
                    if os.path.getmtime(d) < keep_after:
                        import shutil
                        shutil.rmtree(d)
                except OSError:
                    pass
            return cur

    def _servable(self, full):
        """True if a staged path resolves inside the staging or the mission it was spliced from."""
        real = os.path.realpath(full)
        allowed = (os.path.realpath(self._stage_dir()), os.path.realpath(MISSION_SRC))
        return any(real == a or real.startswith(a + os.sep) for a in allowed)

    def mission_manifest(self):
        d = self.stage_mission()
        files = []
        for root, _, names in os.walk(d, followlinks=True):
            for n in names:
                full = os.path.join(root, n)
                rel = os.path.relpath(full, d).replace(os.sep, "/")
                if not self._servable(full):
                    log.warning("manifest: skipping %s (resolves outside the staging)", rel)
                    continue
                try:
                    with open(full, "rb") as fh:
                        h = hashlib.sha1()
                        size = 0
                        while True:
                            b = fh.read(1 << 20)
                            if not b:
                                break
                            h.update(b); size += len(b)
                except OSError:
                    continue
                files.append({"path": rel, "size": size, "sha1": h.hexdigest()})
        files.sort(key=lambda f: f["path"])
        rev = 0
        try:
            txt = open(os.path.join(d, "AP_stage.txt")).read()
            for line in txt.splitlines():
                if line.startswith("staged_from_rev="):
                    rev = int(line.split("=", 1)[1].strip())
        except OSError:
            pass
        return {"world": self.world, "rev": rev, "staged_at": os.path.getmtime(os.path.join(d, "AP_stage.txt")),
                "files": files}

    def mission_file(self, rel, offset, length):
        """One slice of one staged file. The path is checked twice: as text, and again after
        resolving it, because the staging is a tree of symlinks into the repo."""
        if not rel or rel.startswith("/") or ".." in rel.split("/") or ":" in rel:
            raise ValueError("bad path")
        full = os.path.join(self._stage_dir(), rel)
        if not self._servable(full):
            raise ValueError("path outside the staged scenario")
        full = os.path.realpath(full)
        length = max(0, min(int(length), MISSION_MAX_SLICE))
        with open(full, "rb") as fh:
            fh.seek(int(offset))
            return fh.read(length)

    def players(self):
        with self.connect() as c:
            cur = c.execute(
                "SELECT uid, name, x, y, z, dir, extract(epoch from now() - at) FROM eden_live_players "
                "WHERE at > now() - interval '%s seconds' ORDER BY name" % PLAYER_STALE_S)
            return [{"uid": r[0], "name": r[1], "world": [float(r[2]), float(r[3]), float(r[4])],
                     "dir": float(r[5]), "age": round(float(r[6]), 1)} for r in cur.fetchall()]


class Handler(BaseHTTPRequestHandler):
    bridge: Bridge = None   # set by main
    token: str = ""

    def log_message(self, fmt, *args):  # quiet; errors go through logging
        pass

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self):
        if not self.token:
            return True
        return self.headers.get("X-Eden-Token", "") == self.token

    def do_GET(self):
        if not self._authorized():
            return self._send(403, {"error": "bad token"})
        u = urlparse(self.path)
        q = parse_qs(u.query)
        try:
            if u.path == "/rev":
                return self._send(200, {"world": self.bridge.world, "rev": self.bridge.rev()})
            if u.path == "/rows":
                since = int(q.get("since", ["0"])[0])
                limit = min(int(q.get("limit", ["500"])[0]), 2000)
                return self._send(200, self.bridge.rows_since(since, limit))
            if u.path == "/players":
                return self._send(200, self.bridge.players())
            if u.path == "/mission/manifest":
                return self._send(200, self.bridge.mission_manifest())
            if u.path == "/mission/file":
                data = self.bridge.mission_file(q.get("path", [""])[0],
                                                int(q.get("offset", ["0"])[0]),
                                                int(q.get("len", [str(MISSION_MAX_SLICE)])[0]))
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            return self._send(404, {"error": "not found"})
        except ValueError as ex:
            return self._send(400, {"error": str(ex)})
        except Exception as ex:  # noqa: BLE001
            log.exception("GET %s failed", u.path)
            return self._send(500, {"error": str(ex)})

    def do_POST(self):
        if not self._authorized():
            return self._send(403, {"error": "bad token"})
        u = urlparse(self.path)
        try:
            n = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(n) or b"[]"
            log.debug("POST %s %d bytes: %s", u.path, len(raw), raw[:400])
            body = json.loads(raw)
            if u.path == "/ops":
                if not isinstance(body, list):
                    return self._send(400, {"error": "expected a list of ops"})
                return self._send(200, self.bridge.apply(body, read_editors()))
            return self._send(404, {"error": "not found"})
        except Exception as ex:  # noqa: BLE001
            log.exception("POST %s failed", u.path)
            return self._send(500, {"error": str(ex)})


def serve(world, port, dsn=None, token=None):
    bridge = Bridge(world, dsn or apdb_dsn.dsn())
    bridge.ensure_players_table()
    Handler.bridge = bridge
    Handler.token = read_token() if token is None else token
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    log.info("edenlive bridge: world %s, rev %s, http://127.0.0.1:%d, token %s, editors %s",
             world, bridge.rev(), port, "set" if Handler.token else "NONE", sorted(read_editors()) or "none")
    return srv


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--world", default="Malden")
    ap.add_argument("--port", type=int, default=2331)
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    srv = serve(args.world, args.port)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
