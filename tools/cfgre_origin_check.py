#!/usr/bin/env python3
"""Server-origin guard lint for server -> client remoteExec receivers.

CfgRE.hpp's allowedTargets limits a call's TARGET, never its SENDER: any client may remoteExec an
allowedTargets = 1 function at any other client. A receiver that only the server should ever call
(money pushes, quickhack effects, login payloads, suite doors ...) must therefore refuse a call whose
remoteExecutedOwner is not the server, as a flat top-level statement before it does anything:

    if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};

Every name in tools/cfgre_server_only.txt must
  * still be whitelisted in CfgRE.hpp with allowedTargets = 1 (a stale list entry fails), and
  * resolve to exactly one mission fn_<name>.sqf, whose top-level statements reach such a guard
    with nothing before it but params / disableSerialization / other `if (..) exitWith` early-outs.
Accepted guard conditions: `remoteExecutedOwner != 2`, `remoteExecutedOwner isNotEqualTo 2`, or
`!(remoteExecutedOwner in [0, 2])`, optionally &&-combined with other terms.

Usage: python3 tools/cfgre_origin_check.py   (exit 1 on any failure)
"""
import pathlib
import re
import sys

from sqf_balance import lex

REPO = pathlib.Path(__file__).resolve().parent.parent
MISSION = REPO / "mission" / "Armapunk2035.Malden"
LIST = REPO / "tools" / "cfgre_server_only.txt"

GUARD_COND = re.compile(r"remoteExecutedOwner(!=|isNotEqualTo)2(?![0-9.])|!\(remoteExecutedOwnerin\[0,2\]\)")
PRE_OK = re.compile(r"^(params\[|disableSerialization$)")


def top_statements(src):
    """Top-level statements with comments, whitespace and preprocessor lines gone and every string
    literal collapsed to "" -- so `if (a != 2) exitWith {}` arrives as `if(a!=2)exitWith{}`."""
    src = "\n".join("" if l.lstrip().startswith("#") else l for l in src.split("\n"))
    err, toks = lex(src)
    if err:
        raise ValueError("does not tokenize: %s" % err[1])
    out, cur, depth = [], [], 0
    for kind, v in toks:
        c = '""' if kind == "s" else v
        if kind == "c" and c in "([{":
            depth += 1
        elif kind == "c" and c in ")]}":
            depth -= 1
        if depth == 0 and c == ";":
            out.append("".join(cur))
            cur = []
            continue
        cur.append(c)
    if cur:
        out.append("".join(cur))
    return [s for s in out if s]


def split_if_exitwith(st):
    """(condition, True) for a top-level `if <cond> exitWith {...}` statement, else (None, False)."""
    if not st.startswith("if"):
        return None, False
    depth = 0
    for i in range(2, len(st)):
        c = st[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0 and st.startswith("exitWith", i):
            return st[2:i], True
    return None, False


def has_guard(src):
    for st in top_statements(src):
        cond, is_exit = split_if_exitwith(st)
        if is_exit and "remoteExecutedOwner" in cond:
            return bool(GUARD_COND.search(cond))
        if not (is_exit or PRE_OK.match(st)):
            return False
    return False


def whitelisted_targets(cfgre_text):
    body = re.sub(r"//[^\n]*", "", cfgre_text)
    out = {}
    for m in re.finditer(r"class\s+(\w+)\s*\{([^{}]*)\}", body):
        t = re.search(r"allowedTargets\s*=\s*(\d)", m.group(2))
        if t:
            out[m.group(1)] = int(t.group(1))
    return out


def main():
    names = [l.split("#", 1)[0].strip() for l in LIST.read_text().splitlines()]
    names = [n for n in names if n]
    targets = whitelisted_targets((MISSION / "CfgRE.hpp").read_text())
    files = {}
    for p in MISSION.rglob("fn_*.sqf"):
        if "ArmaQuest" not in p.parts:
            files.setdefault(p.name[3:-4].lower(), []).append(p)
    bad = []
    for n in names:
        if targets.get(n) != 1:
            bad.append("%s: not an allowedTargets = 1 entry in CfgRE.hpp (stale list entry?)" % n)
            continue
        hits = files.get(n.split("_fnc_", 1)[-1].lower(), [])
        if len(hits) != 1:
            bad.append("%s: expected one mission fn file, found %d" % (n, len(hits)))
            continue
        try:
            ok = has_guard(hits[0].read_text(encoding="utf-8", errors="replace"))
        except ValueError as e:
            bad.append("%s: %s" % (hits[0].relative_to(REPO), e))
            continue
        if not ok:
            bad.append("%s: no top-level server-origin guard before the first statement that does "
                       "anything (want: if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};)"
                       % hits[0].relative_to(REPO))
    if len(set(names)) != len(names):
        bad.append("duplicate names in %s" % LIST.relative_to(REPO))
    for b in bad:
        print("FAIL " + b)
    print("%s %d server-only receivers checked" % ("FAIL" if bad else "ok  ", len(names)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
