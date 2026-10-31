#!/usr/bin/env python3
"""tools/aq_verbcheck.py -- the verb gate.

WHY THIS EXISTS
    ArmaQuest's `action` objective type (types/fn_typeAction.sqf) counts one
    host-named event: whatever config names in its `verb = "...";` field IS
    the event name the type subscribes to, verbatim -- there is no default,
    no filter, no fallback. A quest can name any string there and validate
    clean (`verb` is just a required, non-empty STRING as far as
    aq_fnc_validate is concerned), be offered, be accepted, and then never
    complete, because nothing in the mission or server trees ever calls
    `["<that verb>", [...]] call aq_fnc_event;`. That failure has no error,
    no log line, and no player able to describe it beyond "this quest is
    stuck" -- the exact shape of failure this project has been bitten by
    before with config that looks completely correct.

WHAT THIS SCRIPT DOES
    1. Parses every `verb = "<name>";` out of the mission's OWN quest
       content -- mission/Armapunk2035.Malden/aq_content.hpp. Never the
       vendored ArmaQuest/ tree: that tree is a byte-identical upstream copy
       (see aq_content.hpp's own header comment) replaced wholesale on the
       next re-vendor, so it holds no host content, only the library's own
       AQ_TypeProbe self-test fixture (`verb = "aq_probe_verb";`) -- a
       placeholder that is never meant to be instrumented and would be a
       pure false positive if scanned.
    2. For each verb, greps the mission/ and server/ trees (again excluding
       the vendored ArmaQuest/ subtree -- its own docstrings use the literal
       text "aq_fnc_event" in usage examples, which is noise, not a call
       site) for a line naming that verb AND calling aq_fnc_event -- or
       APS_fnc_aqFact, the server-side reporter for the verbs a client may not
       report (AQ_Settings >> serverFacts[], see aq_content.hpp). A verb in
       serverFacts[] needs an APS_fnc_aqFact site: aq_fnc_srvFact refuses it
       from a client, so an aq_fnc_event line for it counts for nothing. A
       verb used only by weight = 0 templates (never offered) is not required.

       COMMENTS DO NOT COUNT, and that is not pedantry. fn_handleQuest.sqf's
       header documents the rewiring with a worked example:

           ["action", "robstore", 1] call AP_fnc_handleQuest;
           ["action", "robstore", 1] call aq_fnc_event;      // what it becomes

       The second line is a picture of a call site, and this script reported
       "robstore OK" on the strength of it -- for a verb with no real
       instrumentation anywhere. A checker that accepts its own documentation
       as evidence is worse than no checker, because it is trusted. Line
       comments and block comments are stripped before matching.
    3. Exits non-zero and lists every verb with no call site found. Exits 0
       (printing PASS) when every authored verb has at least one.

WHAT THIS SCRIPT DELIBERATELY DOES NOT CHECK
    The other eight objective types (gather, sell, craft, deliver, zoneHold,
    visit, kill, talk) each key off their OWN config field -- `events[]` for
    most, no host verb at all for deliver/visit/zoneHold (self-contained
    watchers) -- never a field literally named `verb`. That is a different,
    unscoped concern; this gate is specifically the one `action` promises by
    its own contract (fn_typeAction.sqf's docstring: "verb ... IS the bus
    name"), and widening it to every event name in the catalogue would mean
    guessing at a grammar the config does not actually have.

Usage:
    python3 tools/aq_verbcheck.py
"""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTENT_FILE = REPO_ROOT / "mission" / "Armapunk2035.Malden" / "aq_content.hpp"
SEARCH_ROOTS = [
    REPO_ROOT / "mission",
    REPO_ROOT / "server",
]
# Byte-identical vendored copy (see aq_content.hpp's header comment) -- never
# host content. Excluded from BOTH the verb parse and the call-site search.
VENDORED_DIR = REPO_ROOT / "mission" / "Armapunk2035.Malden" / "ArmaQuest"

# Arma-aware enough for this purpose: "" is an escaped quote inside a string
# (never seen inside a verb name in practice), and only // and /* */ need
# stripping so a commented-out example doesn't parse as real content.
COMMENT_RE = re.compile(r"//[^\n]*|/\*.*?\*/", re.DOTALL)
VERB_RE = re.compile(r'\bverb\s*=\s*"([^"]*)"\s*;')
SERVER_FACTS_RE = re.compile(r'\bserverFacts\[\]\s*=\s*\{([^}]*)\}')
# class-open / brace / weight / verb, walked in order to tell which verbs sit
# under a weight = 0 template (bare braces are array literals; they balance).
WALK_RE = re.compile(r'\bclass\s+\w+\s*(?::\s*\w+\s*)?\{|\{|\}|\bweight\s*=\s*([-\d.]+)\s*;|\bverb\s*=\s*"([^"]*)"\s*;')
SOURCE_EXTS = {".sqf", ".hpp", ".ext", ".cpp"}
CALL_NEEDLES = ("aq_fnc_event", "APS_fnc_aqFact")


def strip_comments(text: str) -> str:
    return COMMENT_RE.sub(" ", text)


def under(path: Path, ancestor: Path) -> bool:
    try:
        path.relative_to(ancestor)
        return True
    except ValueError:
        return False


def parse_verbs():
    """-> (verbs in order, server-only verbs, verbs used by an offered quest)."""
    if not CONTENT_FILE.is_file():
        print(f"[aq-verbcheck] ERROR: {CONTENT_FILE} does not exist.", file=sys.stderr)
        sys.exit(2)
    text = strip_comments(CONTENT_FILE.read_text(encoding="utf-8"))
    verbs = []
    for m in VERB_RE.finditer(text):
        v = m.group(1)
        if v and v not in verbs:
            verbs.append(v)
    sf = SERVER_FACTS_RE.search(text)
    server_facts = set(re.findall(r'"([^"]*)"', sf.group(1))) if sf else set()
    live, stack = set(), []   # stack: one "weight is 0" flag per open brace
    for m in WALK_RE.finditer(text):
        tok = m.group(0)
        if tok == "}":
            if stack:
                stack.pop()
        elif tok.endswith("{"):
            stack.append(False)
        elif m.group(1) is not None:
            if stack:
                stack[-1] = float(m.group(1)) == 0
        elif m.group(2) and not any(stack):
            live.add(m.group(2))
    return verbs, server_facts, live


def iter_source_files():
    for root in SEARCH_ROOTS:
        if not root.is_dir():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() not in SOURCE_EXTS:
                continue
            if under(path, VENDORED_DIR):
                continue
            yield path


def strip_comment_lines(lines: list) -> list:
    """Blank out SQF comments, preserving line numbering.

    Named apart from strip_comments() above on purpose: that one collapses a whole
    file to a string for parsing, this one must keep one output line per input line
    or every reported call site would cite the wrong number. Defining a second
    strip_comments() here shadowed the first and broke parse_verbs immediately,
    which is the good version of that mistake.

    Deliberately simple: // to end of line, and /* */ across lines. It does not
    track string literals, so a `//` inside a quoted string would be treated as a
    comment -- which for THIS script's purpose only ever loses a match, never
    invents one, and a lost match is a loud MISSING rather than a silent OK.
    """
    out, in_block = [], False
    for line in lines:
        buf, i, n = [], 0, len(line)
        while i < n:
            if in_block:
                j = line.find("*/", i)
                if j == -1:
                    i = n
                else:
                    in_block = False
                    i = j + 2
                continue
            if line.startswith("//", i):
                break
            if line.startswith("/*", i):
                in_block = True
                i += 2
                continue
            buf.append(line[i])
            i += 1
        out.append("".join(buf))
    return out


def find_call_sites(verbs: list, server_facts: set) -> dict:
    hits = {v: [] for v in verbs}
    for path in iter_source_files():
        try:
            lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        except OSError:
            continue
        rel = path.relative_to(REPO_ROOT)
        for lineno, line in enumerate(strip_comment_lines(lines), start=1):
            if not any(n in line for n in CALL_NEEDLES):
                continue
            for v in verbs:
                # a server-only verb counts only at a server reporter
                if f'"{v}"' in line and (v not in server_facts or "APS_fnc_aqFact" in line):
                    hits[v].append(f"{rel}:{lineno}")
    return hits


def main() -> int:
    verbs, server_facts, live = parse_verbs()
    if not verbs:
        print(f"[aq-verbcheck] no `verb = \"...\";` entries found in {CONTENT_FILE.relative_to(REPO_ROOT)} -- nothing to check.")
        return 0

    hits = find_call_sites(verbs, server_facts)
    missing = [v for v in verbs if not hits[v] and v in live]

    print(f"[aq-verbcheck] {len(verbs)} authored verb(s): {', '.join(verbs)}")
    for v in verbs:
        sites = hits[v]
        if sites:
            print(f"[aq-verbcheck]   OK       {v:<15} {', '.join(sites)}")
        elif v not in live:
            print(f"[aq-verbcheck]   OFFBOARD {v:<15} only weight = 0 templates use it; needs a call site before it goes back on a board")
        else:
            want = "APS_fnc_aqFact (it is in serverFacts[])" if v in server_facts else "aq_fnc_event / APS_fnc_aqFact"
            print(f"[aq-verbcheck]   MISSING  {v:<15} no {want} call site found in mission/ or server/")

    if missing:
        print(f"[aq-verbcheck] FAIL: {len(missing)} verb(s) with no call site: {', '.join(missing)}")
        return 1

    print(f"[aq-verbcheck] PASS: all {len(live)} offered verb(s) instrumented.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
