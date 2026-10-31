#!/usr/bin/env python3
"""Validate SQF command tokens against the local BIKI mirror (~/biki/wiki).

Born 2026-08-04: an invented command name (setObjectTextureLocal) compiled
nowhere and silently killed a whole client file ('Missing ;' at the unknown
token). Prose rules didn't prevent it; this check does.

Usage: python3 tools/sqf_cmd_check.py file.sqf [...]
Flags identifier tokens that are not: local vars, known project prefixes,
SQF keywords/literals, or a page in the BIKI mirror. Exit 1 on findings.
"""
import os
import re
import sys

BIKI = os.path.expanduser('~/biki/wiki')
KEYWORDS = {
    'if', 'then', 'else', 'exitwith', 'while', 'do', 'for', 'foreach', 'from', 'to', 'step',
    'switch', 'case', 'default', 'true', 'false', 'nil', 'private', 'params', 'param',
    'and', 'or', 'not', 'mod', 'min', 'max', 'atan2', 'in', 'select', 'count', 'call',
    'spawn', 'with', 'try', 'catch', 'throw', 'scopename', 'breakto', 'breakout', 'objnull',
    'displaynull', 'controlnull', 'grpnull', 'locationnull', 'tasknull', 'confignull',
    'scriptnull', 'teammembernull', 'netobjnull', 'apply', 'findif', 'pushback', 'set',
    'resize', 'deleteat', 'sleep', 'uisleep', 'waituntil', 'missionnamespace', 'uinamespace',
    'profilenamespace', 'parsingnamespace', 'east', 'west', 'independent', 'civilian',
    'sideunknown', 'blufor', 'opfor', 'resistance', 'floor', 'ceil', 'round', 'abs', 'sqrt',
    'ln', 'log', 'exp', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'random', 'str',
    'format', 'tolower', 'toupper', 'tostring', 'toarray', 'tofixed', 'parsenumber',
    'parsetext', 'isnil', 'isnull', 'time', 'diag_ticktime', 'diag_log', 'player',
    'keys', 'values', 'getordefault', 'get', 'merge', 'insert',
}
PROJECT_PREFIX = re.compile(r'^(_|AP_|AP_|APS_|db_|srv_|bis_|cba_|ap35_|mad_)', re.I)

pages = {p[:-5].lower() for p in os.listdir(BIKI) if p.endswith('.wiki')}
STRIP = [
    re.compile(r'//[^\n]*'),
    re.compile(r'/\*.*?\*/', re.S),
    re.compile(r'"(?:[^"]|"")*"'),
    re.compile(r"'[^']*'"),
]


def blank(m):
    """Erase a comment or string but keep its newlines.

    Collapsing a multi-line string to one space shifts the reported line of
    every token after it, so the tool names a line that has nothing to do with
    the finding. A checker that points at the wrong line costs more than the
    typo it caught.
    """
    return ' ' + '\n' * m.group(0).count('\n')


TOKEN = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
# `1e-6` is a number, but the token regex sees the `e` as an identifier: a
# letter can only follow a digit or a decimal point inside a numeric literal.
EXPONENT = re.compile(r'[0-9.]')

bad_total = 0
for path in sys.argv[1:]:
    src = open(path, encoding='utf-8', errors='replace').read()
    for rx in STRIP:
        src = rx.sub(blank, src)
    unknown = {}
    for m in TOKEN.finditer(src):
        t = m.group(0)
        tl = t.lower()
        if tl in KEYWORDS or PROJECT_PREFIX.match(t):
            continue
        if m.start() and EXPONENT.match(src[m.start() - 1]):
            continue
        if tl in pages or ('bis fnc ' + tl.removeprefix('bis_fnc_')) in pages:
            continue
        line = src[:m.start()].count('\n') + 1
        unknown.setdefault(t, line)
    for t, line in sorted(unknown.items(), key=lambda kv: kv[1]):
        print(f'{path}:{line}: unknown command token: {t}')
    bad_total += len(unknown)
sys.exit(1 if bad_total else 0)
