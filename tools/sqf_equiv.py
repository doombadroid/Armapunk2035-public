#!/usr/bin/env python3
r"""
sqf_equiv.py  --  Prove that a reformat of an .sqf / .hpp / .ext file changed
NOTHING the engine can observe.

WHY THIS EXISTS: the obvious gate -- "strip comments and all whitespace, compare
the rest" -- is unsound, and unsound in the direction that hurts. Under it,
    "Mixing Cement"   ==   "MixingCement"
so a reflow that eats a space or a newline INSIDE a string literal passes with a
green tick while silently corrupting a diary page, a scroll-menu caption or a
hint. The same gate cannot see newlines at all, which is exactly what the config
preprocessor is sensitive to: join a `#define` onto the following line and the
macro body swallows a whole control class, and the gate still says OK.

So this gate checks THREE things, and a reformat must survive all three:

  1. TOKEN STREAM  -- identical sequence of tokens (identifiers, numbers,
     operators, punctuation). Whitespace between tokens is free; whitespace that
     merges or splits a token is not.
  2. STRING LITERALS -- every literal byte-identical, in the same order,
     including its delimiters. This is the check the naive gate lacks.
  3. PREPROCESSOR LINES -- every `#` directive still starts its own logical
     line, in the same order, with the same body, and with its `\` continuations
     intact. Directives are newline-significant; nothing may be joined onto one.

Comments are the only thing allowed to disappear (or appear).

USAGE
    python3 tools/sqf_equiv.py OLD NEW              # one pair
    python3 tools/sqf_equiv.py --git REV -- PATH..  # compare working tree vs a git rev
    python3 tools/sqf_equiv.py --selftest           # prove the gate catches the known breaks

Exit status: 0 = equivalent, 1 = difference found, 2 = usage/lex error.
"""

import sys
import os
import re
import subprocess

IDENT = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*")
NUMBER = re.compile(r"0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?")
# longest-first so '==' never lexes as '=' '='
OPS = ["...", "<<=", ">>=", "==", "!=", ">=", "<=", "&&", "||", ">>", "->", "+=",
       "-=", "*=", "/=", "%=", "^=", "++", "--"]


class LexError(Exception):
    pass


def _is_pp_start(text, i):
    """True if a '#' at index i begins a preprocessor directive: it is the first
    non-whitespace character on its physical line. Note the directive may be
    INDENTED -- ui.hpp, vehicleShop.hpp and govLaw.hpp all indent theirs, and a
    lexer that only accepts column 0 is how a real corruption got shipped."""
    j = i - 1
    while j >= 0 and text[j] in " \t":
        j -= 1
    return j < 0 or text[j] == "\n"


def lex(text, path="<buf>"):
    """Return (tokens, strings, directives).

    tokens     -- list of (kind, value); kind in {id, num, op, str, pp}
                  string tokens carry a placeholder value so that a changed
                  literal shows up in `strings`, not as a token-shape change.
    strings    -- list of raw literals INCLUDING delimiters, in source order.
    directives -- list of normalised '#...' directive bodies, in source order.
    """
    toks, strings, directives = [], [], []
    i, n = 0, len(text)
    while i < n:
        c = text[i]

        # --- whitespace -------------------------------------------------
        if c in " \t\r\n":
            i += 1
            continue

        # --- comments (never inside a string: strings are consumed below) --
        if c == "/" and i + 1 < n:
            if text[i + 1] == "/":
                j = text.find("\n", i)
                i = n if j < 0 else j
                continue
            if text[i + 1] == "*":
                j = text.find("*/", i + 2)
                if j < 0:
                    raise LexError(f"{path}: unterminated /* comment at offset {i}")
                i = j + 2
                continue

        # --- preprocessor directive -------------------------------------
        if c == "#" and _is_pp_start(text, i):
            j = i
            body = []
            while j < n:
                k = text.find("\n", j)
                if k < 0:
                    body.append(text[j:])
                    j = n
                    break
                line = text[j:k]
                body.append(line)
                j = k + 1
                if not line.rstrip().endswith("\\"):
                    break
            raw = "\n".join(body)
            # normalise: collapse intra-line whitespace, keep continuation shape
            norm = "\n".join(re.sub(r"[ \t]+", " ", ln.strip()) for ln in raw.split("\n"))
            directives.append(norm)
            toks.append(("pp", f"<pp{len(directives) - 1}>"))
            i = j
            continue

        # --- string literals --------------------------------------------
        if c in "\"'":
            q = c
            j = i + 1
            while True:
                if j >= n:
                    raise LexError(f"{path}: unterminated {q} string at offset {i}")
                if text[j] == q:
                    if j + 1 < n and text[j + 1] == q:   # SQF escapes by doubling
                        j += 2
                        continue
                    j += 1
                    break
                j += 1
            strings.append(text[i:j])
            toks.append(("str", f"<s{len(strings) - 1}>"))
            i = j
            continue

        # --- number -------------------------------------------------------
        m = NUMBER.match(text, i)
        if m and (c.isdigit() or (c == "." and i + 1 < n and text[i + 1].isdigit())):
            toks.append(("num", m.group(0)))
            i = m.end()
            continue

        # --- identifier ---------------------------------------------------
        m = IDENT.match(text, i)
        if m:
            toks.append(("id", m.group(0)))
            i = m.end()
            continue

        # --- operators / punctuation ---------------------------------------
        for op in OPS:
            if text.startswith(op, i):
                toks.append(("op", op))
                i += len(op)
                break
        else:
            toks.append(("op", c))
            i += 1

    return toks, strings, directives


# NOTE: an earlier revision also flagged, in NEW alone, any `#define` line whose
# body contained a `class X:` -- on the theory that a joiner had swallowed a
# following class into the macro. That rule is wrong: `#define NC_MODLBL(...)
# class NAME: AP_RscText {...}` is a legitimate, widely used config idiom, and
# ui.hpp / vehicleShop.hpp use it today. The swallow case is caught properly and
# without false positives by the differential directive check below -- if a class
# gets folded into a macro, that macro's BODY changes, which check 3 reports.


def _code_string_equivalent(a, b):
    """True if two string literals differ only in whitespace BETWEEN SQF tokens.

    Only meaningful for literals the engine compiles as code -- an addAction
    condition, say -- where whitespace between tokens is insignificant. It is NOT
    valid for a literal that gets displayed, where a space is a space. The caller
    must have established which kind it is dealing with; this function only
    answers the narrow question.

    Nested literals inside the condition are still required to match byte for
    byte, so a display string wrapped inside a condition cannot be mangled.
    """
    if a[:1] != b[:1] or a[-1:] != b[-1:]:
        return False, "delimiter changed"
    try:
        ta, sa, da = lex(a[1:-1])
        tb, sb, db = lex(b[1:-1])
    except LexError as e:
        return False, f"nested lex failed: {e}"
    if ta != tb:
        return False, "nested token stream differs"
    if sa != sb:
        return False, "nested string literal differs"
    if da != db:
        return False, "nested preprocessor directive differs"
    return True, ""


def compare(old_text, new_text, old_name="OLD", new_name="NEW", code_strings=False):
    """Return list of human-readable differences. Empty list == equivalent.

    code_strings=True relaxes check 2 for literals that are themselves SQF: they
    may be reflowed, provided their token stream and any nested literals are
    unchanged. Everything else stays strict. Use it only on files where every
    changed literal has been shown to be compiled rather than displayed.
    """
    problems = []
    try:
        ot, os_, od = lex(old_text, old_name)
        nt, ns, nd = lex(new_text, new_name)
    except LexError as e:
        return [f"LEX ERROR: {e}"]

    # 1. token stream
    if len(ot) != len(nt):
        problems.append(f"token count {len(ot)} -> {len(nt)} (delta {len(nt) - len(ot):+d})")
    for idx, (a, b) in enumerate(zip(ot, nt)):
        if a != b:
            ctx_a = " ".join(t[1] for t in ot[max(0, idx - 4):idx + 5])
            ctx_b = " ".join(t[1] for t in nt[max(0, idx - 4):idx + 5])
            problems.append(
                f"token #{idx} differs: {a[0]}:{a[1]!r} -> {b[0]}:{b[1]!r}\n"
                f"      old ... {ctx_a}\n      new ... {ctx_b}")
            break

    # 2. string literals -- byte for byte
    if len(os_) != len(ns):
        problems.append(f"string-literal count {len(os_)} -> {len(ns)}")
    for idx, (a, b) in enumerate(zip(os_, ns)):
        if a == b:
            continue
        if code_strings:
            ok, why = _code_string_equivalent(a, b)
            if ok:
                continue
            problems.append(f"CODE STRING #{idx} NOT EQUIVALENT ({why}):\n"
                            f"      old {a!r}\n      new {b!r}")
            continue
        problems.append(f"STRING LITERAL #{idx} CHANGED:\n      old {a!r}\n      new {b!r}")

    # 3. preprocessor directives
    if len(od) != len(nd):
        problems.append(f"preprocessor directive count {len(od)} -> {len(nd)}")
    for idx, (a, b) in enumerate(zip(od, nd)):
        if a != b:
            problems.append(f"DIRECTIVE #{idx} CHANGED:\n      old {a!r}\n      new {b!r}")

    return problems


# ----------------------------------------------------------------------------
SELFTESTS = [
    ("identical", 'private _a = "hi"; _a', 'private _a = "hi"; _a', True),
    ("free reflow: punctuation onto one line",
     'AP_actions pushBack(_o addAction\n[\n  "Go"\n  ,\n  {\n    [] spawn f\n  }\n]\n)\n;',
     'AP_actions pushBack(_o addAction [ "Go" , { [] spawn f } ]);', True),
    ("comment removal is allowed",
     '// header\nprivate _a = 1; /* mid */ _a',
     'private _a = 1; _a', True),
    ("BREAK: blank line eaten inside a multi-line string (briefing.sqf case)",
     'player createDiaryRecord ["Diary", ["Controls", "Line one\n\nLine two"]];',
     'player createDiaryRecord ["Diary", ["Controls", "Line one\nLine two"]];', False),
    ("BREAK: double space squeezed inside a string (IgiLoad caption case)",
     '_o addAction ["Load  Crate", f];',
     '_o addAction ["Load Crate", f];', False),
    ("BREAK: #define joined onto a class (govLaw.hpp case)",
     '#define padding 0.0050\nclass taxHeader: RscText { idc = 1001; };',
     '#define padding 0.0050    class taxHeader: RscText { idc = 1001; };', False),
    ("BREAK: indented #define swallowed (ui.hpp case)",
     '    #define AP_BAR(IDC) class AP_bv##IDC: RscText\n    class a { idc = 1; };',
     '    #define AP_BAR(IDC) class AP_bv##IDC: RscText class a { idc = 1; };', False),
    ("BREAK: token actually changed",
     'if (_x > 5) then { hint "a" };',
     'if (_x >= 5) then { hint "a" };', False),
    ("BREAK: tokens merged by losing whitespace",
     'private _a = 1;\ncall f',
     'private _a = 1;callf', False),
    ("string with an embedded // is not a comment",
     '_url = "http://x.y/z"; _a',
     '_url = "http://x.y/z";\n_a', True),
    ("doubled-quote escape survives",
     '_s = "he said ""hi"" ok";',
     '_s = "he said ""hi"" ok";', True),
    ("BREAK: escape content changed",
     '_s = "he said ""hi"" ok";',
     '_s = "he said ""hi""ok";', False),
]


def selftest():
    ok = True
    for name, a, b, expect_equal in SELFTESTS:
        probs = compare(a, b)
        got_equal = not probs
        status = "PASS" if got_equal == expect_equal else "FAIL"
        if status == "FAIL":
            ok = False
        print(f"  [{status}] {name}")
        if status == "FAIL":
            print(f"         expected {'equivalent' if expect_equal else 'DIFFERENT'}, "
                  f"got {'equivalent' if got_equal else 'DIFFERENT'}")
            for p in probs:
                print(f"         {p}")
    print(("\nself-test OK -- gate catches every known break"
           if ok else "\nSELF-TEST FAILED -- do not use this gate"))
    return 0 if ok else 1


def main(argv):
    if "--selftest" in argv:
        return selftest()

    cs = "--code-strings" in argv
    if "--git" in argv:
        k = argv.index("--git")
        rev = argv[k + 1]
        paths = argv[argv.index("--") + 1:] if "--" in argv else argv[k + 2:]
        if not paths:
            print("usage: sqf_equiv.py --git REV -- PATH [PATH...]", file=sys.stderr)
            return 2
        bad = 0
        for p in paths:
            try:
                old = subprocess.run(["git", "show", f"{rev}:{p}"], capture_output=True,
                                     check=True).stdout.decode("utf-8", "replace")
            except subprocess.CalledProcessError:
                print(f"?? {p}: not in {rev}")
                continue
            try:
                new = open(p, encoding="utf-8", errors="replace").read()
            except OSError as e:
                print(f"?? {p}: {e}")
                continue
            probs = compare(old, new, f"{rev}:{p}", p, code_strings=cs)
            if probs:
                bad += 1
                print(f"DIFFERENT  {p}")
                for x in probs:
                    print(f"    {x}")
            else:
                ol, nl = old.count("\n") + 1, new.count("\n") + 1
                print(f"equivalent {p}  ({ol} -> {nl} lines, {nl - ol:+d})")
        return 1 if bad else 0

    args = [a for a in argv if not a.startswith("-")]
    if len(args) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    a, b = args
    probs = compare(open(a, encoding="utf-8", errors="replace").read(),
                    open(b, encoding="utf-8", errors="replace").read(), a, b,
                    code_strings=cs)
    if probs:
        print(f"DIFFERENT  {a} vs {b}")
        for x in probs:
            print(f"    {x}")
        return 1
    print(f"equivalent {a} vs {b}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
