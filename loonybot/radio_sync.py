#!/usr/bin/env python3
"""Build A: sync the website radio.json -> DB radio_schedule (read by APS_fnc_radioSRV). Owner edits radio.json;
this propagates it live every ~60s. song id must be a PACKED CfgSounds class."""
import json, subprocess, time, os, sys
RADIO_JSON = os.path.expanduser("~/loonybin-website/public/radio.json")
STATIONS = ["origin", "khr", "pulse", "classico", "anarchy"]   # index = station number in-game
def db(sql):
    subprocess.run(["docker","exec","-i","looneybin-db","mariadb","-ulooneybin","-plooneybin","looneybin","-e",sql],
                   stdin=subprocess.DEVNULL, check=False)
def sync():
    try:
        with open(RADIO_JSON) as f: data = json.load(f)
    except Exception as e:
        print("[radio_sync] read/parse fail:", e, flush=True); return
    rows = []
    stns = data.get("stations", {})
    for si, key in enumerate(STATIONS):
        pl = (stns.get(key) or {}).get("playlist", []) or []
        for idx, song in enumerate(pl):
            sid = "".join(c for c in str(song.get("id","")) if c.isalnum() or c=="_")[:64]
            ln = int(song.get("len",0) or 0)
            if sid and ln > 0: rows.append((si, idx, sid, ln))
    vals = ",".join("(%d,%d,'%s',%d)" % r for r in rows)
    sql = "START TRANSACTION; DELETE FROM radio_schedule;"
    if vals: sql += " INSERT INTO radio_schedule (station,idx,song_id,song_len) VALUES " + vals + ";"
    sql += " COMMIT;"
    db(sql)
    print("[radio_sync] synced %d rows" % len(rows), flush=True)
if __name__ == "__main__":
    once = "--once" in sys.argv
    while True:
        sync()
        if once: break
        time.sleep(60)
