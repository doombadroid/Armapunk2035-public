#!/usr/bin/env python3
"""sql_global_check.py -- no missionNamespace global may be spliced into server SQL.

A client's publicVariable overwrites a missionNamespace global on the server too (verifySignatures=0, no
BattlEye filter), so every global formatted into a statement is a client-controlled string in the SQL:
`srv_table_wanted = "players WHERE true --"` turned the next wanted DELETE into a wipe of the players table
(audit 2026-09-26). Values belong in `%s` parameters; tunables the server needs belong in localNamespace
(`(localNamespace getVariable "APS_x")`), which the network cannot write, or in a server-local literal.

Flags, in every .sqf under server/: a `format [...]` whose template holds SELECT/INSERT/UPDATE/DELETE and
whose USED %N argument names a bare global, and `"SELECT " + GLOBAL` concatenation. Function calls
(`*_fnc_*`) and the file's own #define macros are not globals. Heuristic by design, known blind spots:
a global laundered through a local first; a global with no underscore in its name (GLOBAL needs one);
concatenation other than the `"SELECT ..." + X` form (e.g. `X + " WHERE ..."` or joinString).

    python3 tools/sql_global_check.py      # exit 1 on any hit
"""
import os
import re
import sys

SQL = re.compile(r'\b(SELECT|INSERT|UPDATE|DELETE)\b')
GLOBAL = re.compile(r'(?<![\w"])([A-Za-z]\w*_\w*)\b')
CONCAT = re.compile(r'"[^"]*\b(?:SELECT|INSERT|UPDATE|DELETE)\b[^"]*"\s*\+\s*([A-Za-z]\w*_\w*)\b')


def strip_comments(s):
    out, i, n = [], 0, len(s)
    while i < n:
        if s[i] == '"':
            j = i + 1
            while j < n and not (s[j] == '"' and s[j + 1:j + 2] != '"'):
                j += 2 if s[j] == '"' else 1
            out.append(s[i:j + 1]); i = j + 1
        elif s.startswith('//', i):
            j = s.find('\n', i); j = n if j < 0 else j
            i = j
        elif s.startswith('/*', i):
            j = s.find('*/', i); j = n if j < 0 else j + 2
            out.append('\n' * s.count('\n', i, j)); i = j
        else:
            out.append(s[i]); i += 1
    return ''.join(out)


def format_args(s, i):
    """s[i] == '[' of `format [`; the top-level comma-split arguments."""
    depth, args, cur, j = 0, [], [], i
    while j < len(s):
        c = s[j]
        if c == '"':
            k = j + 1
            while k < len(s) and not (s[k] == '"' and s[k + 1:k + 2] != '"'):
                k += 2 if s[k] == '"' else 1
            cur.append(s[j:k + 1]); j = k + 1; continue
        if c in '[({':
            depth += 1
            if depth == 1:
                j += 1; continue
        elif c in '])}':
            depth -= 1
            if depth == 0:
                return args + [''.join(cur)]
        elif c == ',' and depth == 1:
            args.append(''.join(cur)); cur = []; j += 1; continue
        cur.append(c); j += 1
    return args + [''.join(cur)]


def hits(src):
    s = strip_comments(src)
    macros = set(re.findall(r'#define\s+(\w+)', s))
    ok = lambda g: '_fnc_' in g or g in macros
    for m in re.finditer(r'\bformat\s*\[', s):
        args = format_args(s, m.end() - 1)
        if not SQL.search(args[0]):
            continue
        used = {int(x) for x in re.findall(r'%(\d+)', args[0])}
        for n, a in enumerate(args[1:], 1):
            bare = re.sub(r'"(?:[^"]|"")*"', '', a)
            for g in GLOBAL.findall(bare):
                if n in used and not ok(g):
                    yield s.count('\n', 0, m.start()) + 1, g
    for m in CONCAT.finditer(s):
        if not ok(m.group(1)):
            yield s.count('\n', 0, m.start()) + 1, m.group(1)


def _selftest():
    bad = 'x = format ["DELETE FROM %1 WHERE playerid=\'%2\'", srv_table_wanted, _uid];\n' \
          'y = ["SELECT " + APS_cols + " FROM t", 2] call DB_fnc_asyncQuery;'
    good = '#define GOV_GANG "5"\nx = format ["UPDATE g SET b=%1 WHERE id=\'%2\'", [_a] call DB_fnc_mresArray, GOV_GANG];\n' \
           'y = format ["DELETE FROM t WHERE p=\'%1\'", _uid, AP_unused_arg];\n' \
           'z = ["SELECT " + (localNamespace getVariable "APS_cols") + " FROM t", 2] call DB_fnc_asyncQuery;'
    assert [g for _, g in hits(bad)] == ['srv_table_wanted', 'APS_cols'], list(hits(bad))
    assert list(hits(good)) == [], list(hits(good))


def main():
    _selftest()
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'server')
    found = 0
    for dp, _, fn in os.walk(root):
        for f in sorted(fn):
            if f.endswith('.sqf'):
                p = os.path.join(dp, f)
                for line, g in hits(open(p, encoding='utf-8', errors='replace').read()):
                    print(f"{os.path.relpath(p, os.path.join(root, '..'))}:{line}: global {g} spliced into SQL")
                    found += 1
    print(f"{found} global(s) in server SQL" if found else "server SQL: no globals spliced in")
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
