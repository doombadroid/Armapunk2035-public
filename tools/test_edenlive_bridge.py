#!/usr/bin/env python3
"""Exercise tools/edenlive_bridge.py against the dev database in a scratch world.

    ~/pysqf-venv/bin/python tools/test_edenlive_bridge.py

Uses world "EdenLiveTest" so Malden is never touched; the map_objects_stamp trigger gives that
world its own map_meta row. Rows the test creates are hard-deleted at the end.
"""
import json
import os
import socket
import sys
import threading
import unittest
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apdb_dsn            # noqa: E402
import edenlive_bridge     # noqa: E402
import psycopg             # noqa: E402

WORLD = "EdenLiveTest"
TOKEN = "test-token"


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


class BridgeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.port = free_port()
        cls.srv = edenlive_bridge.serve(WORLD, cls.port, token=TOKEN)
        cls.thread = threading.Thread(target=cls.srv.serve_forever, daemon=True)
        cls.thread.start()
        cls.editors_backup = edenlive_bridge.read_editors
        edenlive_bridge.read_editors = lambda: {"Doomba"}

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        edenlive_bridge.read_editors = cls.editors_backup
        with psycopg.connect(apdb_dsn.dsn()) as c:
            c.execute("DELETE FROM map_objects WHERE world=%s", (WORLD,))
            c.execute("DELETE FROM map_meta WHERE world=%s", (WORLD,))
            c.execute("DELETE FROM eden_live_players WHERE uid LIKE 'test-%'")
            c.commit()

    def call(self, method, path, body=None, token=TOKEN):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request("http://127.0.0.1:%d%s" % (self.port, path), data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if token is not None:
            req.add_header("X-Eden-Token", token)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def test_flow(self):
        code, _ = self.call("GET", "/rev", token="wrong")
        self.assertEqual(code, 403)

        code, rev0 = self.call("GET", "/rev")
        self.assertEqual(code, 200)
        self.assertEqual(rev0["world"], WORLD)

        # insert a class row (init from an allowlisted editor) and an anchor row
        ops = [
            {"op": "insert", "tmp": "T1", "cls": "Land_Cargo20_blue_F", "world": [100, 200, 30.5],
             "dir": [0, 1, 0], "up": [0, 0, 1], "init": 'this setVariable ["k", 1];', "editor": "Doomba"},
            {"op": "insert", "tmp": "T2", "model": "custom_p3ds\\Bank.p3d", "scale": 0.7,
             "world": [110, 210, 31], "dir": [1, 0, 0], "up": [0, 0, 1], "editor": "Designer"},
        ]
        code, res = self.call("POST", "/ops", ops)
        self.assertEqual(code, 200, res)
        self.assertEqual([r["tmp"] for r in res], ["T1", "T2"])
        id1, id2 = res[0]["id"], res[1]["id"]
        self.assertGreater(res[1]["rev"], res[0]["rev"])

        code, rows = self.call("GET", "/rows?since=%d" % rev0["rev"])
        self.assertEqual(code, 200)
        self.assertEqual([r["id"] for r in rows], [id1, id2])
        self.assertEqual(rows[0]["cls"], "Land_Cargo20_blue_F")
        self.assertEqual(rows[0]["init"], 'this setVariable ["k", 1];')
        self.assertEqual(rows[0]["world"], [100, 200, 30.5])
        self.assertEqual(rows[1]["model"], "custom_p3ds\\Bank.p3d")
        self.assertAlmostEqual(rows[1]["scale"], 0.7)
        self.assertEqual(rows[1]["stream_r"], 0.0)   # p3d default: always loaded

        # update from a NON-allowlisted editor: transform lands, init is dropped (kept as stored)
        code, res = self.call("POST", "/ops", [
            {"op": "update", "id": id1, "cls": "Land_Cargo20_blue_F", "world": [105, 200, 30.5],
             "dir": [0, 1, 0], "up": [0, 0, 1], "init": "hint 'evil';", "editor": "Rando"}])
        self.assertEqual(code, 200, res)
        code, rows = self.call("GET", "/rows?since=%d" % rows[1]["rev"])
        self.assertEqual([r["id"] for r in rows], [id1])
        self.assertEqual(rows[0]["world"][0], 105)
        self.assertEqual(rows[0]["init"], 'this setVariable ["k", 1];')

        # update WITH allowlisted editor changes init
        code, res = self.call("POST", "/ops", [
            {"op": "update", "id": id1, "cls": "Land_Cargo20_blue_F", "world": [105, 200, 30.5],
             "dir": [0, 1, 0], "up": [0, 0, 1], "init": "hint 'ok';", "editor": "Doomba"}])
        code, rows = self.call("GET", "/rows?since=%d" % rows[0]["rev"])
        self.assertEqual(rows[0]["init"], "hint 'ok';")

        # delete is soft
        code, res = self.call("POST", "/ops", [{"op": "delete", "id": id2, "editor": "Doomba"}])
        self.assertEqual(code, 200, res)
        code, rows = self.call("GET", "/rows?since=%d" % rows[0]["rev"])
        self.assertEqual([(r["id"], r["deleted"]) for r in rows], [(id2, True)])

        code, rev1 = self.call("GET", "/rev")
        self.assertEqual(rev1["rev"], rows[0]["rev"])

    def test_players(self):
        with psycopg.connect(apdb_dsn.dsn()) as c:
            c.execute("INSERT INTO eden_live_players (uid, name, x, y, z, dir) VALUES (%s,%s,%s,%s,%s,%s) "
                      "ON CONFLICT (uid) DO UPDATE SET x=EXCLUDED.x, at=now()", ("test-1", "Tester", 1, 2, 3, 90))
            c.execute("INSERT INTO eden_live_players (uid, name, x, y, z, dir, at) VALUES (%s,%s,%s,%s,%s,%s, now() - interval '60 seconds') "
                      "ON CONFLICT (uid) DO UPDATE SET at=now() - interval '60 seconds'", ("test-old", "Gone", 1, 2, 3, 0))
            c.commit()
        code, players = self.call("GET", "/players")
        self.assertEqual(code, 200)
        names = [p["name"] for p in players if p["uid"].startswith("test-")]
        self.assertEqual(names, ["Tester"])        # the stale one is dead


if __name__ == "__main__":
    unittest.main(verbosity=2)
