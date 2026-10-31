#!/usr/bin/env python3
"""Find AP_fnc_* names that are CALLED but defined nowhere.

Written after fn_p_updateMenu: commit ce1f5e23 retired the native phone shell and
deleted the function plus its Functions.h entry, but left three call sites behind.
Each threw "Undefined variable in expression: ap_fnc_p_updatemenu" at runtime and
nothing static noticed for ten days -- SQF resolves function names at CALL time, so
a deleted function is invisible until a player walks the path.

Report-only by design. Most of what it finds is dead code around removed items
rather than a live break, and the difference needs a human: an unregistered name
behind an item that no longer exists in fn_virtItemCfg is unreachable, while the
same name behind a dialog button is a hot path. Wiring this into run_checks.sh
means first deciding which of the current findings are bugs and which are litter.

Two extraction rules that cost a round each:
  - Functions.h packs several `class x {};` per line, so the class regex must NOT
    be anchored to line start -- anchoring under-reported definitions and produced
    ~50 false positives including registered functions like miningRig.
  - The convention allows inline helpers assigned anywhere (`AP_fnc_x = {...}` in
    configuration.sqf and elsewhere), so definitions are not only Functions.h.
"""
import os, re, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M = os.path.join(REPO, "mission", "Armapunk2035.Malden")
NAME = re.compile(r"\bAP_fnc_[A-Za-z0-9_]+")


def walk(exts):
    for root, _, files in os.walk(M):
        for fn in files:
            if fn.endswith(exts):
                yield os.path.join(root, fn)


def main():
    defined = set()
    fh = os.path.join(M, "Functions.h")
    if os.path.exists(fh):
        # unanchored on purpose -- several classes share one line in this file
        for m in re.finditer(r"class ([A-Za-z0-9_]+)", open(fh, encoding="utf-8", errors="replace").read()):
            defined.add("AP_fnc_" + m.group(1))
    for f in walk((".sqf",)):
        for m in re.finditer(r"(AP_fnc_[A-Za-z0-9_]+)\s*=[^=]", open(f, encoding="utf-8", errors="replace").read()):
            defined.add(m.group(1))

    used = {}
    for f in walk((".sqf", ".hpp")):
        rel = os.path.relpath(f, REPO)
        for ln, line in enumerate(open(f, encoding="utf-8", errors="replace").read().splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue          # a comment mentioning a dead function is not a call
            for m in NAME.finditer(line.split("//")[0]):
                used.setdefault(m.group(0), []).append((rel, ln))

    missing = {n: s for n, s in used.items() if n not in defined}
    if not missing:
        print("all AP_fnc_* references resolve")
        return 0
    print(f"{len(missing)} AP_fnc_* name(s) called but defined nowhere:\n")
    for n in sorted(missing):
        print(f"  {n}")
        for rel, ln in missing[n][:3]:
            print(f"      {rel}:{ln}")
    print("\nreport-only: check reachability before treating any of these as a live bug")
    return 0


if __name__ == "__main__":
    sys.exit(main())
