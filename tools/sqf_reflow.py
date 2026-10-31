#!/usr/bin/env python3
r"""
sqf_reflow.py  --  Undo a naive beautifier's line explosion, safely.

Several files in this tree were minified at some point and then run back through
a formatter that put every '[', ']', '(', ')' and ';' on a line of its own --
including inside condition STRINGS, where the engine does not care. The result
is a file that is mostly punctuation: fn_setupActions.sqf measures 3,992
punctuation-only lines and 543 blank ones out of 7,318.

This joins those continuation lines back up. It is deliberately conservative and
it is string-aware, because the naive version of this transform is exactly how
you corrupt a diary page: a pass that squeezes blank lines without knowing it is
inside a multi-line string literal silently rewrites the text a player reads.

RULES -- a line is joined onto the previous one only when ALL hold:
  * the previous line does not end inside a string literal
  * the previous line does not end inside a '//' comment  (joining onto it would
    comment the joined code OUT -- silent, total, and the reason this check is
    not optional)
  * neither line is, or continues, a preprocessor directive (# lines are
    newline-significant; a '#define' that swallows the next line turns its body
    into whatever followed)
  * and either the line starts with a closing delimiter / ',' / ';', or the
    previous line ends with an opening delimiter or ',', or the line is nothing
    but punctuation

Blank-run squeezing likewise only counts a line as blank when it is blank in
CODE space -- a blank line inside a string literal is content, not layout.

Nothing here is trusted on its own: run tools/sqf_equiv.py over the result. That
gate compares the token stream, every string literal byte-for-byte, and every
preprocessor directive.

USAGE
    python3 tools/sqf_reflow.py FILE            # print reflowed text to stdout
    python3 tools/sqf_reflow.py FILE --write    # rewrite in place
    python3 tools/sqf_reflow.py FILE --stats    # just report what it would do
"""

import sys

OPEN_DELIMS = "([{"
CLOSE_DELIMS = ")]}"


def scan(text):
    """Per-line facts computed in code-space, honouring strings and comments.

    Returns a list of dicts, one per physical line:
      ends_in_string  -- the line ends while a string literal is still open
      ends_in_comment -- the line ends inside a '//' or unterminated '/*'
      is_pp           -- the line is, or continues, a preprocessor directive
      code            -- the line's characters with strings/comments blanked out,
                         so delimiter tests never see a '(' that lives in a string
    """
    lines = text.split("\n")
    out = []
    in_str = None          # quote char, or None
    in_block = False       # inside /* */
    pp_continues = False   # previous pp line ended with a backslash
    for ln in lines:
        i, n = 0, len(ln)
        code = []
        line_comment = False
        started_in_str = in_str is not None
        is_pp = pp_continues
        stripped = ln.strip()
        if not started_in_str and not in_block and stripped.startswith("#"):
            is_pp = True
        while i < n:
            c = ln[i]
            if in_block:
                if c == "*" and i + 1 < n and ln[i + 1] == "/":
                    in_block = False
                    code.append("  ")
                    i += 2
                    continue
                code.append(" ")
                i += 1
                continue
            if in_str is not None:
                if c == in_str:
                    if i + 1 < n and ln[i + 1] == in_str:   # SQF doubles to escape
                        code.append("  ")
                        i += 2
                        continue
                    in_str = None
                code.append(" ")
                i += 1
                continue
            if line_comment:
                code.append(" ")
                i += 1
                continue
            if c == "/" and i + 1 < n and ln[i + 1] == "/":
                line_comment = True
                code.append("  ")
                i += 2
                continue
            if c == "/" and i + 1 < n and ln[i + 1] == "*":
                in_block = True
                code.append("  ")
                i += 2
                continue
            if c in "\"'":
                in_str = c
                code.append(" ")
                i += 1
                continue
            code.append(c)
            i += 1
        pp_continues = is_pp and ln.rstrip().endswith("\\")
        out.append({
            "raw": ln,
            "code": "".join(code),
            "ends_in_string": in_str is not None,
            "ends_in_comment": line_comment or in_block,
            "is_pp": is_pp,
            "starts_in_string": started_in_str,
        })
    return out


def reflow(text, max_width=140):
    """Join continuation lines, but never past max_width.

    The cap is not cosmetic. Without it a 7,000-line data table collapses to 69
    lines of ~10,000 characters each -- fewer lines, unreadable file, strictly
    worse for anyone reading the source. 140 matches this tree's own shape
    (p90 = 114, p95 = 133), so reflowed code looks like the code around it.
    """
    info = scan(text)
    out = []          # list of [raw_text, info_of_last_line_merged]
    for rec in info:
        raw, code = rec["raw"], rec["code"]
        cs = code.strip()

        if not out:
            out.append([raw, rec])
            continue

        prev_raw, prev_rec = out[-1]
        prev_code = prev_rec["code"].rstrip()

        joinable = (
            not prev_rec["ends_in_string"]
            and not prev_rec["ends_in_comment"]
            and not prev_rec["is_pp"]
            and not rec["is_pp"]
            and not rec["starts_in_string"]
            and cs != ""
        )
        starts_closing = prev_opens = punct_only = False
        if joinable:
            starts_closing = cs[0] in CLOSE_DELIMS or cs[0] in ",;"
            prev_opens = prev_code != "" and prev_code[-1] in OPEN_DELIMS + ","
            punct_only = all(ch in "()[]{},; \t" for ch in cs)
            would_be = len(prev_raw.rstrip()) + 1 + len(raw.strip())
            if would_be > max_width:
                joinable = False
        if joinable:
            if starts_closing or prev_opens or punct_only:
                sep = "" if (starts_closing and cs[0] in CLOSE_DELIMS + ",;") else " "
                if prev_code.endswith(tuple(OPEN_DELIMS)):
                    sep = ""
                out[-1] = [prev_raw.rstrip() + sep + raw.strip(), rec]
                continue

        out.append([raw, rec])

    # squeeze blank runs -- blank in CODE space, and never inside a string
    result, blanks = [], 0
    for raw, rec in out:
        is_blank = raw.strip() == "" and not rec["starts_in_string"] and not rec["ends_in_string"]
        if is_blank:
            blanks += 1
            if blanks > 1:
                continue
        else:
            blanks = 0
        result.append(raw)
    return "\n".join(result)


def collapse_code_string(lit):
    """Collapse whitespace runs inside ONE string literal that is itself SQF.

    Whitespace between tokens is insignificant to the compiler, so an addAction
    condition spread over ten lines can become one. Nested literals inside it are
    copied byte for byte -- a display string wrapped in a condition must not be
    touched. Runs collapse to a single space, never to nothing, so two adjacent
    tokens can never be fused into one.

    `lit` includes its delimiters and is returned the same way.
    """
    q = lit[0]
    inner = lit[1:-1]
    out, i, n, in_str = [], 0, len(inner), None
    while i < n:
        c = inner[i]
        if in_str is not None:
            out.append(c)
            if c == in_str:
                if i + 1 < n and inner[i + 1] == in_str:   # doubled = escaped
                    out.append(inner[i + 1])
                    i += 2
                    continue
                in_str = None
            i += 1
            continue
        if c in "\"'":
            in_str = c
            out.append(c)
            i += 1
            continue
        if c in " \t\r\n":
            while i < n and inner[i] in " \t\r\n":
                i += 1
            out.append(" ")
            continue
        out.append(c)
        i += 1
    return q + "".join(out).strip() + q


def reflow_code_strings(text, only_multiline=True):
    """Rewrite the file, collapsing string literals that are themselves SQF.

    Walks the source in the same string/comment-aware way as scan(), so a literal
    that only appears inside a comment is never rewritten. Returns (new_text,
    count_rewritten).
    """
    out, i, n, changed = [], 0, len(text), 0
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(text[i:j])
            i = j
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(text[i:j])
            i = j
            continue
        if c in "\"'":
            q, j = c, i + 1
            while j < n:
                if text[j] == q:
                    if j + 1 < n and text[j + 1] == q:
                        j += 2
                        continue
                    j += 1
                    break
                j += 1
            lit = text[i:j]
            if (not only_multiline) or "\n" in lit:
                new = collapse_code_string(lit)
                if new != lit:
                    changed += 1
                lit = new
            out.append(lit)
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out), changed


def stats(text):
    info = scan(text)
    punct = sum(1 for r in info
                if r["code"].strip() and all(c in "()[]{},; \t" for c in r["code"].strip()))
    blank = sum(1 for r in info if r["raw"].strip() == "")
    comment = sum(1 for r in info if r["raw"].strip().startswith(("//", "/*", "*")))
    pp = sum(1 for r in info if r["is_pp"])
    multi = sum(1 for r in info if r["ends_in_string"])
    return {"lines": len(info), "punctuation_only": punct, "blank": blank,
            "comment": comment, "preprocessor": pp, "lines_ending_mid_string": multi}


def main(argv):
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    path = argv[0]
    text = open(path, encoding="utf-8").read()
    if "--stats" in argv:
        s = stats(text)
        for k, v in s.items():
            print(f"  {k:24} {v}")
        new = reflow(text)
        print(f"  {'would become':24} {new.count(chr(10)) + 1} lines "
              f"({new.count(chr(10)) + 1 - s['lines']:+d})")
        return 0
    mw = 140
    for a in argv:
        if a.startswith("--max-width="): mw = int(a.split("=")[1])
    new = reflow(text, mw)
    if "--write" in argv:
        open(path, "w", encoding="utf-8").write(new)
        print(f"{path}: {text.count(chr(10)) + 1} -> {new.count(chr(10)) + 1} lines")
    else:
        sys.stdout.write(new)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
