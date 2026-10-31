#!/usr/bin/env python3
"""
sqm_compare.py -- diff two rapified mission.sqm files.

Built for one job: telling a DELIBERATE editing session apart from the Eden re-bake.

THE RE-BAKE. This mission's map layer was moved out of mission.sqm into allLocalMapEntities and is
spawned at init. Eden does not know that -- it loads whatever it finds and on save writes every
object back into the .sqm as a real entity. One autosave on 2026-07-26 took the file from 1,705,895
to 5,357,304 bytes and objects from 4,260 to 19,902. Everything then exists twice at runtime.

So a diff here answers the question that matters: did the object count explode (re-bake, roll back),
or did a handful of markers change (real work, keep)? Rolling back blind destroys the session's
deliberate edits, which is why this prints markers separately and by name.

Usage:
    python3 tools/sqm_compare.py <old.sqm> <new.sqm>
    python3 tools/sqm_compare.py <old.sqm> <new.sqm> --markers    # marker detail only
"""
import ast
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_read

REBAKE_RATIO = 1.5   # objects growing by more than this is not hand-editing


def _pos(node):
    # Objects/Logics carry position under a PositionInfo child; MARKERS carry it on the node itself.
    # Reading only the child made every marker parse as None, so this tool -- which exists to protect
    # marker edits -- reported a moved marker as unchanged (found during the 2026-08-20 sqm salvage).
    pi = node.get("subs", {}).get("PositionInfo", {}).get("props", {})
    raw = pi.get("position")
    if raw is None:
        raw = node.get("props", {}).get("position")
    if raw is None:
        return None
    try:
        v = ast.literal_eval(str(raw))
    except (ValueError, SyntaxError):
        return None
    if len(v) < 3:
        return None
    # sqm position[] is [x, height, y]
    return (round(float(v[0]), 2), round(float(v[2]), 2), round(float(v[1]), 2))


def read(path):
    root = sqm_read.parse(path)
    types = collections.Counter()
    objects = collections.Counter()
    markers = {}
    for node in sqm_read.walk(root):
        p = node.get("props", {})
        dt = p.get("dataType")
        if dt is None:
            continue
        dt = str(dt)
        types[dt] += 1
        if dt == "Object" and p.get("type"):
            objects[str(p["type"])] += 1
        elif dt == "Marker":
            name = str(p.get("name", p.get("id", "?")))
            markers[name] = {
                "pos": _pos(node),
                "type": str(p.get("markerType", "")),
                "text": str(p.get("text", "")),
                "color": str(p.get("colorName", "")),
            }
    return {"types": types, "objects": objects, "markers": markers,
            "bytes": os.path.getsize(path)}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only_markers = "--markers" in sys.argv
    if len(args) != 2:
        print(__doc__)
        return 2
    old, new = read(args[0]), read(args[1])

    if not only_markers:
        print(f"bytes   {old['bytes']:>10,} -> {new['bytes']:>10,}   "
              f"({new['bytes'] - old['bytes']:+,})")
        print("\nentities by dataType:")
        for k in sorted(set(old["types"]) | set(new["types"])):
            a, b = old["types"][k], new["types"][k]
            print(f"   {k:10s} {a:6d} -> {b:6d}   {b - a:+d}" if a != b
                  else f"   {k:10s} {a:6d}      (unchanged)")

        ao, bo = sum(old["objects"].values()), sum(new["objects"].values())
        print(f"\nobjects with a type: {ao} -> {bo}  ({bo - ao:+d})")
        if ao and bo > ao * REBAKE_RATIO:
            print("\n  *** EDEN RE-BAKE. The map layer has been written back into the .sqm. ***")
            print("  Everything below will now exist TWICE at runtime -- script-spawned and")
            print("  sqm-placed. Do not deploy this. Recover with:")
            print("      git checkout -- mission/Armapunk2035.Malden/mission.sqm")
            print("  BUT FIRST: keep the baked file and read the marker section below --")
            print("  this session's deliberate edits are in there too and a rollback destroys them.")
            top = [(c, n) for c, n in (new["objects"] - old["objects"]).most_common(8)]
            print("\n  biggest additions (the map layer):")
            for c, n in top:
                print(f"      +{n:6d}  {c}")
        elif bo != ao:
            print("  (a hand-editing sized change, not a re-bake)")
            for c, n in (new["objects"] - old["objects"]).most_common(10):
                print(f"      +{n:5d}  {c}")
            for c, n in (old["objects"] - new["objects"]).most_common(10):
                print(f"      -{n:5d}  {c}")

    om, nm = old["markers"], new["markers"]
    added = sorted(set(nm) - set(om))
    removed = sorted(set(om) - set(nm))
    changed = sorted(k for k in set(om) & set(nm) if om[k] != nm[k])
    print(f"\nMARKERS  {len(om)} -> {len(nm)}   "
          f"+{len(added)} added, -{len(removed)} removed, ~{len(changed)} changed")
    for k in added:
        m = nm[k]
        print(f"   + {k:28s} {m['pos']}  type={m['type']}  text={m['text']!r}")
    for k in removed:
        m = om[k]
        print(f"   - {k:28s} {m['pos']}  type={m['type']}  text={m['text']!r}")
    for k in changed:
        for f in ("pos", "type", "text", "color"):
            if om[k][f] != nm[k][f]:
                print(f"   ~ {k:28s} {f}: {om[k][f]!r} -> {nm[k][f]!r}")
    if not (added or removed or changed):
        print("   (no marker changes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
