#!/usr/bin/env python3
"""
gen_face_shop.py -- regenerate core/config/fn_clothing_faces.sqf from the FSOF pack's own CfgFaces.

The face shop lists Zeealex's Fifty Shades of Female faces, which ship in the @Armapunk2035 client mod
(radio/addon/zee_fsof). Rather than hand-maintaining 166 rows, read them out of her config so the shop
and the pack can never disagree: classnames come from the class headers and display names verbatim from
her own displayName fields, so re-running this after a pack update is the whole maintenance story.

Only scope=2 faces are listed -- scope=1 entries exist in the pack but are not player-selectable.

Reads  : radio/addon/zee_fsof/config.cpp   (CfgFaces section only -- CfgHeads below it defines
                                            fsof_head_* classes which are NOT faces and must not leak in)
Writes : mission/Armapunk2035.Malden/core/config/fn_clothing_faces.sqf
"""
import os
import re
import sys

SC = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(SC, '..', 'radio', 'addon', 'zee_fsof', 'config.cpp')
OUT = os.path.join(SC, '..', 'mission', 'Armapunk2035.Malden', 'core', 'config', 'fn_clothing_faces.sqf')
PRICE = 0   # owner 2026-08-03: free

HEADER = '''/*
    AP_fnc_clothing_faces  (BUGS.md #65 -- built 2026-08-03, owner: free)
    Shop type "faces": rows of [CfgFaces classname, displayName, price].
    fn_changeClothes applies the pick with `player setFace`, fn_clothingMenu reverts it on cancel.

    Faces are Zeealex's Fifty Shades of Female pack, shipped in the @Armapunk2035 client mod
    (radio/addon/zee_fsof -- see radio/addon/PROVENANCE.md for attribution and permission).

    GENERATED, do not hand-edit: regenerate with scratchpad/gen_face_shop.py after changing the pack.
    Display names are the author's own, taken verbatim from her CfgFaces displayName fields.

    NB these classes only exist when the client mod is LOADED. fn_clothingFilter validates each row
    against CfgFaces >> Man_A3 and silently drops any it cannot resolve, so a player without the mod
    sees an empty Faces list rather than a broken one or an error.

    Price is 0 (owner 2026-08-03) -- cosmetic, and the pack is the whole point of shipping the mod.
*/
params [["_selection", 0, [0]]];
_selection;   // one category only; accepted for signature parity with the other clothing_* configs
[
'''


def extract(text):
    """Pull [(classname, displayName)] for every scope=2 face in the CfgFaces section."""
    start = text.find('class CfgFaces')
    if start < 0:
        sys.exit('no CfgFaces section found -- has the pack config changed shape?')
    # stop at CfgHeads: it declares fsof_head_* classes that are head MODELS, not selectable faces
    end = text.find('class CfgHeads')
    section = text[start:end if end > start else len(text)]

    parts = re.split(r'\n\s*class\s+(fsof_\w+)\s*:', section)
    seen, rows = set(), []
    for i in range(1, len(parts), 2):
        cls, body = parts[i], parts[i + 1]
        # a face's own body ends where the next nested class begins
        nested = body.find('\n\t\tclass ')
        if nested >= 0:
            body = body[:nested]
        if not re.search(r'scope\s*=\s*2', body):
            continue
        if cls in seen:
            continue
        seen.add(cls)
        m = re.search(r'displayname\s*=\s*"([^"]*)"', body, re.I)
        rows.append((cls, m.group(1) if m else cls))
    return rows


def main():
    rows = extract(open(SRC, encoding='utf-8', errors='replace').read())
    if not rows:
        sys.exit('extracted 0 faces -- refusing to write an empty shop')
    if any('"' in d for _, d in rows):
        sys.exit('a displayName contains a double quote -- would break the SQF literal')
    body = ',\n'.join(f'    ["{c}", "{d}", {PRICE}]' for c, d in rows)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(HEADER + body + '\n]\n')
    print(f'wrote {len(rows)} faces -> {os.path.relpath(OUT, os.path.join(SC, ".."))}')


if __name__ == '__main__':
    main()
