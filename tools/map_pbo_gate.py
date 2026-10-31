#!/usr/bin/env python3
"""map_pbo_gate -- nothing that belongs to the table may be in the mission tree (mapdb.md D7).

Three checks, any failure exits 1:
  1. the files the table replaced do not exist under mission/Armapunk2035.Malden/. A resurrected
     fn_mapData.sqf would ship 1 MB of rows that nothing reads; a resurrected
     malden_buildings.sqf would spawn every custom building TWICE (once from the file, once from
     its row).
  2. every path in deploy/pbo_exclude.txt exists in the tree. The packer matches the list
     exactly, so a typo there does not fail the pack -- it silently ships the file.
  3. the dev reload script passes that list to the packer (--exclude-list=...pbo_exclude.txt).

    python3 tools/map_pbo_gate.py        # exit 0 = clean
"""
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MISSION = os.path.join(REPO, "mission", "Armapunk2035.Malden")
EXCLUDE_LIST = os.path.join(REPO, "deploy", "pbo_exclude.txt")
RELOAD = os.path.join(REPO, "deploy", "reload-armapunk2035.sh")

FORBIDDEN = (
    "core/config/fn_mapData.sqf",
    "core/config/fn_dynamicMapCfg.sqf",
    "core/functions/fn_dynamicMapSystem.sqf",
    "custom_p3ds/malden_buildings.sqf",
    "custom_p3ds/load.sqf",
    "compositions/zones.sqf",
    "custom_p3ds/Skyscraper20_r14.p3d",
)


def read_exclude_list(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if line:
                out.append(line.strip("/\\").replace("\\", "/"))
    return out


def check(mission=MISSION, exclude_list=EXCLUDE_LIST, reload_script=RELOAD):
    """Return the list of failures (empty = clean)."""
    fails = []
    for rel in FORBIDDEN:
        if os.path.lexists(os.path.join(mission, *rel.split("/"))):
            fails.append("forbidden file present in the mission tree: %s" % rel)
    try:
        listed = read_exclude_list(exclude_list)
    except OSError as e:
        return fails + ["cannot read %s: %s" % (exclude_list, e)]
    if not listed:
        fails.append("%s lists nothing" % os.path.relpath(exclude_list, REPO))
    for rel in listed:
        if not os.path.isfile(os.path.join(mission, *rel.split("/"))):
            fails.append("pbo_exclude.txt names a path that is not in the mission tree "
                         "(a typo here silently ships the file): %s" % rel)
    try:
        src = open(reload_script, encoding="utf-8").read()
    except OSError as e:
        return fails + ["cannot read %s: %s" % (reload_script, e)]
    if "--exclude-list=" not in src or "pbo_exclude.txt" not in src:
        fails.append("%s does not pass --exclude-list=.../pbo_exclude.txt to pack_pbo.py"
                     % os.path.relpath(reload_script, REPO))
    return fails


def main():
    fails = check()
    for f in fails:
        print("FAIL " + f)
    if fails:
        return 1
    print("map_pbo_gate: %d forbidden paths absent, %d excluded paths present, reload script passes the list"
          % (len(FORBIDDEN), len(read_exclude_list(EXCLUDE_LIST))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
