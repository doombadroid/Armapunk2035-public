#!/usr/bin/env python3
"""Strip `disableSimulation` from the playable slots in a binarized mission.sqm.

WHY
    Eden's "Disable simulation" tickbox on the 201 player slots looks like the obvious way to stop
    them falling out of the sky at 50km. It is not, and it breaks the spawn:

    The attribute is applied on EVERY machine at mission load, and `enableSimulation` is
    eff=LOCAL -- so when the client un-freezes itself after a teleport, the SERVER never hears about
    it and its copy of that unit stays simulation-disabled for the whole session. Measured across
    b0106-b0109 on 2026-07-27: the server then re-asserts the unit's own slot position 0.08-0.59s
    after ANY client-side setPos, so the login/relog teleport is reverted and the player free-falls
    from 50km. It follows each move, so it cannot be outwaited or out-re-asserted.

    The design that worked (commit dc8f2f9, and still what fn_spawnMenu does) holds the player
    CLIENT-SIDE on a normally-simulated unit:
        player setPosASL [worldSize/2, worldSize/2, 50000];
        player enableSimulation false;
    Slot position is then irrelevant to the hold -- keep them at 50km if you like, the client freezes
    them there before they fall anywhere.

SAFETY
    Uses the sqm_add_roles serializer, which is only trusted if a parse->serialize round-trip
    reproduces the input byte-for-byte. That check runs FIRST and aborts on mismatch. A .bak is
    written before the file is replaced, and the result is re-parsed and verified afterwards.

    Deliberately does NOT touch anything else -- positions, markers, ids, the map layer. A
    `git checkout mission.sqm` would revert the slot change but take same-session marker work
    (e.g. lt_cspawn_1..5) with it; this only clears the one attribute.

USAGE
    python3 tools/sqm_slot_sim.py <mission.sqm> [--apply]
    (without --apply it only reports)
"""
import sys, os, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sqm_add_roles as R
import sqm_read

TARGET = b"disableSimulation"


def slot_attr_nodes(node, _in_playable=False):
    """Yield every Attributes node that belongs to a playable unit and carries disableSimulation."""
    ents = node["entries"]
    names = {e[1] for e in ents if e[0] in ("value", "array")}
    is_playable = b"isPlayable" in names
    if is_playable and TARGET in names:
        yield node
    for e in ents:
        if e[0] == "class":
            for n in slot_attr_nodes(e[2]):
                yield n


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    apply_it = "--apply" in sys.argv

    data = open(path, "rb").read()
    if data[:4] != b"\x00raP":
        sys.exit("%s is not a binarized (rapified) sqm" % path)

    root = R.Rap(data).build()

    # trust gate: the serializer must reproduce this exact file before it may write a modified one
    rt = R.serialize(root)
    if rt != data:
        sys.exit("ABORT: round-trip is not byte-for-byte (%d in, %d out) -- serializer not trustworthy here"
                 % (len(data), len(rt)))
    print("round-trip OK: serializer reproduces %s byte-for-byte (%d bytes)" % (os.path.basename(path), len(data)))

    targets = list(slot_attr_nodes(root))
    print("playable slots carrying disableSimulation: %d" % len(targets))
    if not targets:
        print("nothing to do.")
        return

    if not apply_it:
        print("\ndry run -- pass --apply to strip it.")
        return

    removed = 0
    for node in targets:
        before = len(node["entries"])
        node["entries"] = [e for e in node["entries"] if not (e[0] in ("value", "array") and e[1] == TARGET)]
        removed += before - len(node["entries"])

    out = R.serialize(root)
    bak = path + ".bak-slotsim"
    shutil.copy(path, bak)
    open(path, "wb").write(out)
    print("removed %d disableSimulation entries; backup at %s" % (removed, os.path.basename(bak)))

    # verify the written file: parses, and no playable slot still carries the attribute
    check = R.Rap(open(path, "rb").read()).build()
    left = len(list(slot_attr_nodes(check)))
    print("re-parsed result: %d slots still carrying it (want 0)" % left)
    if left:
        shutil.copy(bak, path)
        sys.exit("ABORT: attribute survived -- restored the backup")

    # and that nothing else moved: entity counts must be identical
    a = sqm_read.parse(bak)
    b = sqm_read.parse(path)
    def counts(r):
        import collections
        c = collections.Counter()
        for n in sqm_read.walk(r):
            dt = n["props"].get("dataType")
            if dt:
                c[dt] += 1
        return dict(c)
    ca, cb = counts(a), counts(b)
    print("entity counts before: %s" % ca)
    print("entity counts after : %s" % cb)
    if ca != cb:
        shutil.copy(bak, path)
        sys.exit("ABORT: entity counts changed -- restored the backup")
    print("OK -- only the attribute changed.")


if __name__ == "__main__":
    main()
