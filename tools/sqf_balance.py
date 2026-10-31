#!/usr/bin/env python3
"""Arma-aware bracket balance check -- including INSIDE code-bearing string literals.

SQF escapes a quote by DOUBLING it ("" inside "..", '' inside '..') -- a backslash means nothing --
and comments only count outside strings. A per-line net delta would also be useless here: `} else {`
is net zero, and a mis-PAIRED bracket (a ] closing a { ) balances perfectly by count. So this walks
a stack and reports the first bracket that closes the wrong opener, with line and column.

WHY THE STRING LAYER EXISTS
---------------------------
A plain tokenizer treats a quoted literal as opaque, which is correct for SQF *syntax* -- but this
codebase stores real code inside quotes. Every scroll-menu entry in core/fn_setupActions.sqf carries
its show-condition as a quoted string, compiled by the engine at menu-build time:

    ...,'!isNull cursorObject && {(cursorObject getVariable ["AP_x", false])}',6]);

Delete one paren in there and the file still tokenizes perfectly -- the old checker said `ok`. Arma
then fails to compile the condition at menu-build time and raises NOTHING; the scroll menu is simply
gone. That is the exact silent fault this gate exists to prevent, and it was invisible to it.

HOW A "CODE" STRING IS TOLD FROM A "TEXT" STRING
------------------------------------------------
Balance-checking every string would cry wolf -- SQL fragments, format templates, structured-text
markup and single-character literals are legitimately unbalanced all over this tree. Two filters,
both required:

  1. CONCATENATION.  A literal glued to its neighbours with `+` is a FRAGMENT; its brackets close in
     a sibling fragment, so it can never be checked alone. Adjacent literals joined only by `+` are
     concatenated and checked as ONE unit (this is how the cartel condition in
     custom_p3ds/malden_cartel_actions.sqf is built, and joining it is what makes it checkable).
     If any operand in the chain is NOT a literal -- `"... IN (" + (_uids joinString ",") + ")"` --
     the content is unknowable and the whole chain is skipped.

  2. CODE SHAPE.  What is left is checked only if it contains SQF syntax that does not occur in
     prose: one HARD token (`&&`, `getVariable`, `isEqualTo`, `cursorObject`, `objNull`, ...), or two
     distinct SOFT ones (English-ambiguous words like `player`, `count`, `distance`). SQL keywords,
     `%1` format placeholders and `<t size=...>` markup carry neither.

Inside a code string, nested literals are themselves opaque (a classname is not code), and a nested
literal that is ITSELF code-shaped is recursed into. Positions are mapped back through the doubled
quotes, so a fault reported at line N really is at line N of the file.

Limits are documented at the bottom of this file.

Usage:  python3 tools/sqf_balance.py <file> [<file> ...]
        --no-strings   only the old outer-syntax check (escape hatch)
        --verbose      report every string the string layer actually parsed, and every one it
                       dropped because the content turned out not to lex as SQF
Prints `ok   <path>` per clean file, `FAIL <path>:<line>:<col>  <why>` otherwise; exit 1 if any bad.
"""
import bisect
import re
import sys

PAIRS = {")": "(", "]": "[", "}": "{"}
OPENS = "([{"
BRACKETS = set("([{)]}")
MAX_DEPTH = 3

# SQF syntax that effectively cannot appear in display text, SQL or markup. One is enough.
HARD = re.compile(
    r"&&|\|\||_fnc_|"
    r"(?<![A-Za-z0-9_])(?:"
    r"isEqualTo|isNotEqualTo|isEqualType|isNull|isNotNull|isNil|isKindOf|"
    r"getVariable|setVariable|missionNamespace|profileNamespace|uiNamespace|"
    r"cursorObject|playerSide|getPlayerUID|objNull|typeOf|nearestObjects|nearestObject|"
    r"exitWith|forEach|pushBack|addAction|remoteExec|configFile|getPos|getPosATL|"
    r"_this|_target|_caller|_x"
    r")(?![A-Za-z0-9_])|"
    # this repo's global prefixes -- prose does not contain AP_/APS_/APV_/SRV_ identifiers
    # (the alternation words are not followed by "_", so the token rename could not see them)
    r"(?<![A-Za-z0-9_])(?:AP|APS|APV|SRV|BIS)_[A-Za-z]"
)
# A private-variable sigil. Good evidence, but NOT on its own: `"Weird_)_Class"` would qualify,
# so it counts as one soft signal and needs a second.
PRIVATE = re.compile(r"(?<![A-Za-z0-9_])_[a-zA-Z][A-Za-z0-9_]*")
# Words that ARE SQF but also ordinary English. Two distinct ones are needed.
SOFT = re.compile(
    r"(?<![A-Za-z0-9_])("
    r"player|vehicle|alive|count|select|call|spawn|distance|distance2D|"
    r"param|params|format|str|hint"
    r")(?![A-Za-z0-9_])"
)
# Arma structured-text markup. Only display strings carry it.
MARKUP = re.compile(r"<\s*/?\s*(?:t|br|a|img|font)\b", re.I)


def _is_code(text):
    """True if `text` reads as SQF source rather than prose/SQL/markup."""
    if HARD.search(text):
        return True                      # unambiguous SQF wins even if it also builds markup
    if MARKUP.search(text):
        return False                     # Arma structured text -- a display string, not code
    soft = set(m.group(1) for m in SOFT.finditer(text))
    if PRIVATE.search(text):
        soft.add("_var")
    return len(soft) >= 2


class Str:
    """One string literal: decoded content plus a per-character map back to source indices."""
    __slots__ = ("q", "text", "map", "start", "closed")

    def __init__(self, q, start):
        self.q = q
        self.start = start
        self.text = []
        self.map = []
        self.closed = False


def lex(src, base=0):
    """Tokenize SQF. `base` offsets every recorded source index (for nested levels).

    Returns (err, toks) where err is (srcindex, msg, opener_index_or_None) for the first structural
    fault and toks is the ordered significant-token stream: ('s', Str) for literals, ('c', char) for
    everything else. Whitespace and comments produce no tokens.
    """
    toks = []
    stack = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c in " \t\r\n":
            i += 1
            continue
        if c == "/" and nxt == "/":
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == "/" and nxt == "*":
            j = src.find("*/", i + 2)
            if j < 0:
                return (base + i, "unterminated /* */", None), toks
            i = j + 2
            continue
        if c in "\"'":
            s = Str(c, base + i)
            i += 1
            while i < n:
                if src[i] == c:
                    if i + 1 < n and src[i + 1] == c:   # "" -> a literal quote, string continues
                        s.text.append(c)
                        s.map.append(base + i)
                        i += 2
                        continue
                    i += 1
                    s.closed = True
                    break
                s.text.append(src[i])
                s.map.append(base + i)
                i += 1
            s.text = "".join(s.text)
            if not s.closed:
                return (s.start, "unterminated string", None), toks
            toks.append(("s", s))
            continue
        if c in OPENS:
            stack.append((c, base + i))
            toks.append(("c", c))
        elif c in PAIRS:
            if not stack:
                return (base + i, "closing %r with nothing open" % c, None), toks
            o, oi = stack.pop()
            if o != PAIRS[c]:
                return (base + i, "%r closes %r opened at " % (c, o), oi), toks
            toks.append(("c", c))
        else:
            toks.append(("c", c))
        i += 1
    if stack:
        o, oi = stack[-1]
        return (oi, "%r never closed" % o, None), toks
    return None, toks


def chains(toks):
    """Group literals joined ONLY by `+` into concatenation chains.

    Yields (list_of_Str, pure) -- pure is False when any operand in the chain is not a literal, in
    which case the content is unknowable and the caller must skip it.
    """
    idx = [k for k, t in enumerate(toks) if t[0] == "s"]
    seen = set()
    for k in idx:
        if k in seen:
            continue
        group, pure = [toks[k][1]], True
        seen.add(k)
        # left edge: a `+` whose other operand is not a literal poisons the chain
        if k >= 2 and toks[k - 1] == ("c", "+") and toks[k - 2][0] != "s":
            pure = False
        elif k == 1 and toks[0] == ("c", "+"):
            pure = False
        # walk right
        j = k
        while j + 2 < len(toks) and toks[j + 1] == ("c", "+"):
            if toks[j + 2][0] != "s":
                pure = False
                break
            group.append(toks[j + 2][1])
            seen.add(j + 2)
            j += 2
        if j + 1 < len(toks) and toks[j + 1] == ("c", "+") and j + 2 >= len(toks):
            pure = False
        yield group, pure


def check_strings(toks, depth, report, note=None):
    """Recurse into every code-bearing literal (or pure concatenation of them)."""
    if depth > MAX_DEPTH:
        return
    for group, pure in chains(toks):
        if not pure:
            continue
        text = "".join(s.text for s in group)
        if not BRACKETS.intersection(text):
            continue        # nothing a balance checker could possibly say about it
        if not _is_code(text):
            continue
        cmap = []
        for s in group:
            cmap.extend(s.map)

        def to_src(off, _m=cmap, _g=group):
            return _m[off] if off < len(_m) else _g[0].start

        err, inner = lex(text)
        if err is not None:
            off, msg, opener = err
            if msg.startswith("unterminated"):
                # The content does not lex as SQF at all -- an English apostrophe in prose
                # ("You didn't select a vehicle") opens a string that never closes. That is
                # evidence we MIS-classified text as code, not evidence of a fault. Drop it.
                if note:
                    note(to_src(off), "skipped: %s (reads as text, not code)" % msg, text, off)
                continue
            report(to_src(off), msg, to_src(opener) if opener is not None else None, text, off)
            continue
        if note:
            note(group[0].start, "scanned (%d chars%s)"
                 % (len(text), ", %d-part concat" % len(group) if len(group) > 1 else ""), text, 0)
        # remap nested literals' indices from content-space to source-space before recursing
        for kind, tok in inner:
            if kind == "s":
                tok.start = cmap[tok.start] if tok.start < len(cmap) else group[0].start
                tok.map = [cmap[m] if m < len(cmap) else group[0].start for m in tok.map]
        check_strings(inner, depth + 1, report, note)


def linecol(starts, idx):
    ln = bisect.bisect_right(starts, idx)
    return ln, idx - starts[ln - 1] + 1


def excerpt(text, off, width=70):
    lo = max(0, off - width // 2)
    frag = text[lo:off + width // 2].replace("\n", " ").strip()
    return ("..." if lo else "") + frag + ("..." if off + width // 2 < len(text) else "")


def main(argv):
    do_strings = "--no-strings" not in argv
    verbose = "--verbose" in argv
    paths = [a for a in argv if not a.startswith("--")]
    bad = 0
    for path in paths:
        try:
            src = open(path, errors="replace").read()
        except OSError as e:
            bad += 1
            print("FAIL %s:1:1  %s" % (path, str(e)))
            continue
        starts = [0] + [m.end() for m in re.finditer("\n", src)]
        errs = []

        def fmt(msg, opener_idx, _s=starts):
            if opener_idx is None:
                return msg
            return msg + "%d:%d" % linecol(_s, opener_idx)

        err, toks = lex(src)
        if err is not None:
            i, msg, opener = err
            ln, co = linecol(starts, i)
            errs.append((ln, co, fmt(msg, opener)))
        elif do_strings:
            def report(srcidx, msg, opener_idx, text, off, _e=errs, _s=starts):
                ln, co = linecol(_s, srcidx)
                _e.append((ln, co, "%s inside a code-bearing string  |  %s"
                           % (fmt(msg, opener_idx), excerpt(text, off))))

            def note(srcidx, msg, text, off, _s=starts, _p=path):
                ln, co = linecol(_s, srcidx)
                print("     note %s:%d:%d  %s  |  %s" % (_p, ln, co, msg, excerpt(text, off)))

            check_strings(toks, 1, report, note if verbose else None)
        if errs:
            bad += 1
            for ln, co, msg in errs:
                print("FAIL %s:%d:%d  %s" % (path, ln, co, msg))
        else:
            print("ok   %s" % path)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

# ---------------------------------------------------------------------------------------------
# WHAT THIS STILL CANNOT SEE  (measured, not guessed -- see .superpowers/sdd/balance-checker-report.md)
#   * A condition assembled with a non-literal operand ("..." + _var + "...") -- the content is not
#     knowable statically, so the whole chain is skipped by design. 328 literals tree-wide.
#   * A bracket fault in a code string carrying no SQF tell at all, e.g. '!(someGlobalFlag' with no
#     AP_/AP_ prefix and no keyword. One such string exists in the tree today (a `#(argb,...)`
#     procedural texture, which is data anyway).
#   * A bracket inside a NESTED display literal -- '... hint "Oil Processing ($1,000)"'. Deleting
#     that paren changes what a player reads, not whether the code compiles, so it is deliberately
#     out of scope. A tree-wide mutation test found exactly 10 such cases and no others.
#   * Anything that is not a bracket: a missing `&&`, a stray `;`, an undefined variable, a
#     mis-ordered addAction slot. This is a balance checker, not a compiler.
#   * .hpp / description.ext / config.cpp -- only .sqf is passed to it by the deploy workflow.
#
# KNOWN FALSE-POSITIVE VECTOR (zero instances in the tree today, so left unguarded)
#   Display prose that carries two distinct SOFT words, no markup, no apostrophe, and an unbalanced
#   bracket -- e.g. "Select a player (see the list". If one ever appears, either reword it or add a
#   token to MARKUP. Do not widen SOFT without re-running the tree scan.
# ---------------------------------------------------------------------------------------------
