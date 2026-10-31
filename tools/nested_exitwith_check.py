#!/usr/bin/env python3
"""Flag gates whose refusal is an exitWith nested inside an if-then block.

THE BUG CLASS. SQF's exitWith leaves only the innermost scope. So in

    if (_src isNotEqualTo 0) then {
        ...
        if (_lvl < 3) exitWith { ["-SEC-", _caller, "BLOCKED ..."] call APS_fnc_logIt; };
    };
    <the privileged work>

the refusal leaves the then-block and nothing else: the -SEC- row is written, the message is sent,
and the privileged work below runs anyway. Two such gates shipped (fabDebugSRV let any client flip
FREE BUILD; evidenceTruck handed out the seized-evidence truck to any caller). The fix is flat: set
a flag in the block and `if (_blocked) exitWith {};` right after it.

WHAT IS FLAGGED. An `if ... exitWith {...}` inside a then/else block, when the if-statement owning
that block is followed by more code in its own scope (the code the exit was meant to stop), and:
  * the exit logs a refusal (-SEC- / BLOCKED / not authorised) -- anywhere in the block; or
  * the exit is the LAST statement of the block (where it can skip nothing, so exitWith was written
    believing it leaves the function) and the file is server-side code, or the exit or the owning
    if's condition names a caller-identity primitive (remoteExecutedOwner, isRemoteExecuted,
    adminlevel). Client code without a marker is skipped: a client gate is not a trust boundary.
Not flagged: an exit body that assigns a plain local (the `_blocked = true` flag idiom), and a
block followed directly by an `if ... exitWith` (the refusal re-raised flat).

ponytail: token heuristic, not a parser. It misses an owning if that is the last statement of a
case block when code follows the switch; grow a real scope walk if that shape ever ships.

Usage:  python3 tools/nested_exitwith_check.py [path ...]      (default: mission/ server/)
Exit 1 on any hit outside KNOWN_PENDING.
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Real hits whose files another fix owns. Reported as PEND on every run, never failing it; remove
# an entry once its fix lands (the run then fails if the hit is still there).
KNOWN_PENDING = set()

TOKEN = re.compile(r"""
    (?P<ws>\s+)
  | (?P<lc>//[^\n]*)
  | (?P<bc>/\*.*?\*/)
  | (?P<pp>^[ \t]*\#[^\n]*(?:\\\n[^\n]*)*)
  | (?P<str>"(?:[^"]|"")*"|'(?:[^']|'')*')
  | (?P<id>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<num>\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+)
  | (?P<op>==|!=|>=|<=|&&|\|\||>>|.)
""", re.S | re.M | re.X)

SEC_STR = re.compile(r"-SEC-|\bBLOCKED\b|(?i:not authori[sz]ed|unauthori[sz]ed)")
SEC_ID = {"remoteexecutedowner", "isremoteexecuted", "adminlevel"}
PAIR = {"{": "}", "(": ")", "[": "]"}


def lex(src):
    toks, line = [], 1
    for m in TOKEN.finditer(src):
        kind, text = m.lastgroup, m.group()
        if kind in ("id", "str", "num", "op"):
            toks.append((kind, text, line))
        line += text.count("\n")
    return toks


def match_brackets(toks):
    """Map every opener index to its closer index. Unbalanced input -> partial map (sqf_balance's job)."""
    close, stack = {}, []
    for i, (k, t, _) in enumerate(toks):
        if k == "op" and t in PAIR:
            stack.append(i)
        elif k == "op" and t in ")]}" and stack:
            close[stack.pop()] = i
    return close


def statements(toks, lo, hi, close):
    """Split toks[lo:hi] on top-level `;` -> list of (start, end) index ranges, empties dropped."""
    out, start, i = [], lo, lo
    while i < hi:
        t = toks[i][1]
        if t in PAIR and i in close:
            i = close[i] + 1
            continue
        if t == ";":
            if i > start:
                out.append((start, i))
            start = i + 1
        i += 1
    if hi > start:
        out.append((start, hi))
    return out


def is_sec(toks, lo, hi):
    return any((k == "str" and SEC_STR.search(t)) or (k == "id" and t.lower() in SEC_ID)
               for k, t, _ in toks[lo:hi])


def assigns_local(toks, lo, hi):
    """True if toks[lo:hi] holds `_x = ...` that is not a `private` declaration (the flag idiom)."""
    return any(toks[i][1] == "=" and toks[i - 1][0] == "id" and toks[i - 1][1].startswith("_")
               and not (i >= 2 and toks[i - 2][1].lower() == "private")
               for i in range(lo + 1, hi))


def if_exit(toks, lo, hi, close):
    """If toks[lo:hi] is `if ... exitWith {...}`, return the exitWith index, else None."""
    if toks[lo][1].lower() != "if":
        return None
    ex = next((x for x in range(lo, hi) if toks[x][1].lower() == "exitwith"), None)
    if ex is None or ex + 1 >= hi or toks[ex + 1][1] != "{" or close.get(ex + 1) != hi - 1:
        return None
    return ex


def after_stmt(toks, j, close):
    """Index of the first token after the if-then(-else) statement whose block opens at j."""
    a = close[j] + 1
    if a + 1 < len(toks) and toks[a][1].lower() == "else" and toks[a + 1][1] == "{" and (a + 1) in close:
        a = close[a + 1] + 1
    if a < len(toks) and toks[a][1] == ";":
        a += 1
    return a


def is_flat_exit(toks, a, close):
    """True if the statement starting at `a` is `if ... exitWith` (the refusal re-raised flat)."""
    if a >= len(toks) or toks[a][1].lower() != "if":
        return False
    while a < len(toks) and toks[a][1] not in (";", "}", "]", ")"):
        if toks[a][1].lower() == "exitwith":
            return True
        a = close[a] + 1 if (toks[a][1] in PAIR and a in close) else a + 1
    return False


def cond_start(toks, i):
    """Index of the `if` that owns the `then` at i (same bracket level), else i."""
    d, c = 0, i - 1
    while c >= 0:
        t = toks[c][1]
        if t in ")]}":
            d += 1
        elif t in "([{":
            if d == 0:
                return i
            d -= 1
        elif d == 0 and t == ";":
            return i
        elif d == 0 and t.lower() == "if":
            return c
        c -= 1
    return i


def scan(src, strict=False):
    """Yield (line, message) for each nested-exitWith gate in `src`. strict = server-side code."""
    toks = lex(src)
    close = match_brackets(toks)
    for i, (k, t, _) in enumerate(toks):
        if k != "id" or t.lower() not in ("then", "else"):
            continue
        j = i + 1
        if j >= len(toks) or toks[j][1] != "{" or j not in close:
            continue
        a = after_stmt(toks, j, close)
        if a >= len(toks) or toks[a][1] in ("}", "]", ")", ",") or is_flat_exit(toks, a, close):
            continue   # nothing after the owning if in its scope, or the refusal is re-raised flat
        cond_lo = cond_start(toks, i) if t.lower() == "then" else i
        stmts = statements(toks, j + 1, close[j], close)
        for n, (s_lo, s_hi) in enumerate(stmts):
            ex = if_exit(toks, s_lo, s_hi, close)
            if ex is None or assigns_local(toks, ex + 1, s_hi):
                continue
            refusal = any(k2 == "str" and SEC_STR.search(t2) for k2, t2, _ in toks[ex + 1:s_hi])
            last = n == len(stmts) - 1
            if refusal or (last and (strict or is_sec(toks, s_lo, s_hi) or is_sec(toks, cond_lo, i))):
                yield toks[ex][2], "exitWith inside a %s-block (line %d) leaves only that block; the " \
                    "code after the block still runs" % (t.lower(), toks[i][2])


def files(args):
    roots = args or [os.path.join(REPO, "mission"), os.path.join(REPO, "server")]
    for r in roots:
        if os.path.isfile(r):
            yield r
            continue
        for d, subs, names in os.walk(r):
            subs[:] = sorted(s for s in subs if s != "ArmaQuest")   # vendored upstream tree
            for n in sorted(names):
                if n.endswith(".sqf"):
                    yield os.path.join(d, n)


def main(argv):
    bad = 0
    for path in files(argv[1:]):
        with open(path, encoding="utf-8", errors="replace") as f:
            src = f.read()
        rel = os.path.relpath(os.path.abspath(path), REPO)
        for line, msg in scan(src, strict=rel.startswith("server" + os.sep)):
            pending = rel in KNOWN_PENDING
            print("%s %s:%d  %s" % ("PEND" if pending else "FAIL", rel, line, msg))
            bad += not pending
    if bad:
        print("%d nested-exitWith gate(s). Fix: set a flag in the block, then a flat "
              "`if (_blocked) exitWith {};` right after it." % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
