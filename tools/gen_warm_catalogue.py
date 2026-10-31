#!/usr/bin/env python3
"""Regenerate the curated classname list inside core/web/fn_warmCatalogue.sqf.

WHY THIS EXISTS.  The connect-time cache worker (ui/html/warm.html) has to warm the
weapon shop's thumbnails, and the only honest source for "which weapons does a shop
show" is fn_weaponShopCfg.sqf's own `_weaponList`.  That array cannot be read at
runtime: it is a `private` local, it is built AFTER the gating prologue, and calling
the function for every shop id to get at it pops "You don't have a Rebel Training!"
toasts at connect and returns only the shops this player currently qualifies for.

So the classname column is lifted out of that exact file here, and `--check` fails
tools/run_checks.sh the moment the two drift.  A stale list would warm the wrong
weapons and look exactly like the bug it was written to fix -- silently.

    python3 tools/gen_warm_catalogue.py            # rewrite the generated block
    python3 tools/gen_warm_catalogue.py --check    # exit 1 if it is stale

Only the CURATED half is generated.  The rebel/MaxSec shops merge a runtime
CfgWeapons sweep (AP_dynGuns) that no static list can contain; fn_warmCatalogue.sqf
covers that half with a config walk of its own.  See its header.
"""
import argparse
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
SRC = REPO / "mission/Armapunk2035.Malden/core/config/fn_weaponShopCfg.sqf"
DST = REPO / "mission/Armapunk2035.Malden/core/web/fn_warmCatalogue.sqf"
ANCHOR = "private _weaponList="
BEGIN = "// --- BEGIN GENERATED (tools/gen_warm_catalogue.py -- do not hand-edit) ---"
END = "// --- END GENERATED ---"


def _scan_array(text: str, start: int) -> str:
    """Return the bracketed array literal that starts at or after `start`.

    SQF escapes a quote by DOUBLING it, never with a backslash, so a naive
    string-skipper that honours \\" walks straight off the end of a path like
    "\\A3\\Weapons_F\\...".  This one uses the SQF rule.
    """
    i = text.index("[", start)
    depth = 0
    j = i
    in_str = False
    while j < len(text):
        c = text[j]
        if in_str:
            if c == '"':
                if j + 1 < len(text) and text[j + 1] == '"':
                    j += 2
                    continue
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
        j += 1
    raise SystemExit("gen_warm_catalogue: unbalanced _weaponList array in %s" % SRC)


def _rows(arr: str):
    """Yield each top-level row of an SQF array-of-arrays, as source text."""
    depth = 0
    in_str = False
    open_at = None
    for j, c in enumerate(arr):
        if in_str:
            if c == '"':
                if j + 1 < len(arr) and arr[j + 1] == '"':
                    continue
                in_str = False
            continue
        if c == '"':
            in_str = True
            continue
        if c == "[":
            depth += 1
            if depth == 2:
                open_at = j
        elif c == "]":
            if depth == 2 and open_at is not None:
                yield arr[open_at:j + 1]
            depth -= 1


def classnames():
    src = SRC.read_text()
    arr = _scan_array(src, src.index(ANCHOR) + len(ANCHOR))
    out, seen = [], set()
    rows = list(_rows(arr))
    if not rows:
        raise SystemExit("gen_warm_catalogue: no rows parsed out of _weaponList")
    for row in rows:
        m = re.match(r'\[\s*"([^"]+)"', row)
        if not m:
            raise SystemExit("gen_warm_catalogue: row without a leading classname: %s" % row[:70])
        cls = m.group(1)
        if cls.lower() in seen:
            continue
        seen.add(cls.lower())
        out.append(cls)
    return len(rows), out


def block(rows: int, names) -> str:
    body = []
    line = "   "
    for n in names:
        piece = ' "%s",' % n
        if len(line) + len(piece) > 106:
            body.append(line)
            line = "   "
        line += piece
    if line.strip():
        body.append(line)
    if body:
        body[-1] = body[-1].rstrip(",")
    return "\n".join([
        BEGIN,
        "// %d distinct classnames, lifted from the %d rows of fn_weaponShopCfg.sqf's _weaponList."
        % (len(names), rows),
        "private _curated = [",
        "\n".join(body),
        "];",
        END,
    ])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if the generated block is stale instead of rewriting it")
    args = ap.parse_args()

    rows, names = classnames()
    want = block(rows, names)
    cur = DST.read_text()
    if BEGIN not in cur or END not in cur:
        print("gen_warm_catalogue: markers missing from %s" % DST, file=sys.stderr)
        return 1
    head = cur[:cur.index(BEGIN)]
    tail = cur[cur.index(END) + len(END):]
    new = head + want + tail

    if args.check:
        if new != cur:
            print("gen_warm_catalogue: %s is STALE -- fn_weaponShopCfg.sqf's catalogue moved."
                  % DST.relative_to(REPO), file=sys.stderr)
            print("  regenerate with: python3 tools/gen_warm_catalogue.py", file=sys.stderr)
            return 1
        print("ok: %d classnames, in sync with fn_weaponShopCfg.sqf" % len(names))
        return 0

    DST.write_text(new)
    print("wrote %s: %d distinct classnames from %d rows"
          % (DST.relative_to(REPO), len(names), rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
