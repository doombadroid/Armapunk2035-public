#!/usr/bin/env python3
"""tools/aq_check.py -- offline structural validator for ArmaQuest content.

WHY THIS EXISTS
    The game validates its own quest catalogue at boot (aq_fnc_validate, plus
    aq_fnc_reachability for the prerequisite/chain graph -- both vendored at
    mission/Armapunk2035.Malden/ArmaQuest/diagnostics/). That is the ground truth,
    but reaching it costs a full deploy-and-boot cycle (~2 minutes) to learn a
    quest has a typo. This script parses the SAME content file offline and checks
    the structural half of what the in-game validator checks, in well under a
    second, plus one check the in-game tools do not currently make (chain/giver
    agreement -- see CHAIN below).

WHAT IT READS
    mission/Armapunk2035.Malden/aq_content.hpp        -- Arma config syntax (NOT
                                                          C, NOT JSON): nested
                                                          `class NAME { key = v;
                                                          key[] = {a,b}; class
                                                          SUB {...}; };`. Parsed
                                                          with a small tolerant
                                                          parser below -- no
                                                          dependency pulled in.
    core/config/fn_factionCfg.sqf                     -- faction ids, for rep:
    core/quests/fn_aqWorld.sqf                        -- world: key registry
    mission.sqm                                       -- markers, via the
                                                          shared tools/sqm_read.py
                                                          reader every other map
                                                          tool in this repo uses.

CHECKS (each reported with its class path, never just a line number)
    1. giver references resolve       AQ_Quests>>id>>giver and
                                       AQ_Templates>>id>>givers[] name a real
                                       AQ_Givers class.
    2. requires[] tokens are well-formed
                                       kinds: quest: license: item: item:c:qty
                                       rep:faction:n world:key[:value]. rep: is
                                       always exactly three parts and its n may
                                       be NEGATIVE (FACTION_REP_SPEC.md 6.1) --
                                       this is checked with a character-walk
                                       numeric-literal test, not `float()`,
                                       because a threshold of "-500" is data,
                                       not a parse failure to reject.
    3. quest: prerequisites resolve, and the prerequisite graph has no cycle.
    4. every quest is reachable       offered by some giver, or chained to from
                                       a reachable quest (mirrors
                                       aq_fnc_reachability's own fixed point).
       CHAIN: `chain` hands off to the SAME giver only (fn_srvComplete.sqf
       stamps the personal offer's giver from the CHAIN TARGET's own `giver`
       field, and fn_srvBoard.sqf only ever shows a personal offer to a player
       standing at that exact giver) -- so a `chain` naming a quest whose
       `giver` differs is a quest nothing ever offers, and it validates clean
       today: aq_fnc_reachability's own graph does not compare givers across a
       chain edge. check_chain_same_giver below is the check that closes that
       gap; it is not a restatement of reachability.
    5. rep: factions exist            cross-checked against fn_factionCfg.sqf's
                                       `_factions` rows, [_id, _name, ...].
    6. world: keys are registered     cross-checked against fn_aqWorld.sqf's
                                       aq_fnc_registerWorld calls, including the
                                       one dynamic pattern the mission actually
                                       uses (a `format ["cartel_%1", _cartel]`
                                       key inside `{...} forEach [...]`) --
                                       resolved to concrete keys when the
                                       forEach source is a literal list, else
                                       reported as a note (unverifiable), never
                                       as a hard error.
    7. markers referenced by objectives exist in mission.sqm, as GENUINE
       Marker entities (dataType="Marker"), not merely something with a
       matching name="..." -- sqm_read.py's node shape keeps `name` scoped to
       the same entity as `dataType`, which is what makes this precise: an
       earlier bug matched any name= in the file and let an NPC's object name
       pass as a marker.
    8. objective `type` values are among the nine registered types.

Usage:
    python3 tools/aq_check.py

Exit code: 0 if no problems were found, 1 if any were, 2 if the content file
itself could not be parsed at all.
"""
from __future__ import annotations

import pathlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
import sqm_read  # noqa: E402  -- the shared mission.sqm reader (tools/sqm_read.py)

MISSION_DIR = REPO_ROOT / "mission" / "Armapunk2035.Malden"
CONTENT_FILE = MISSION_DIR / "aq_content.hpp"
FACTION_FILE = MISSION_DIR / "core" / "config" / "fn_factionCfg.sqf"
WORLD_FILE = MISSION_DIR / "core" / "quests" / "fn_aqWorld.sqf"
SQM_FILE = MISSION_DIR / "mission.sqm"

OBJECTIVE_TYPES = {"gather", "sell", "craft", "deliver", "zoneHold", "visit", "kill", "talk", "action"}
REQUIRES_KINDS_WITH_THIRD_PART = ("item", "rep", "world")


# =================================================================================================
# Tokenizer -- shared by the Arma-config parser (aq_content.hpp) and the light-touch SQF scans
# (fn_factionCfg.sqf, fn_aqWorld.sqf). Only what this grammar subset needs: strings (double-quote
# only -- Arma CONFIG syntax, unlike SQF, never uses '...' as a string; every apostrophe seen in
# this tree is dialogue text INSIDE a "..." string, e.g. "'Good. Now the part...'", so treating '
# as a delimiter would desynchronise the whole rest of the file on the first one), numbers (signed,
# one optional decimal point), identifiers, comments, and the punctuation this grammar uses.
# Anything else is skipped rather than raising -- tolerant by design; genuinely-unparseable value
# positions still raise ParseError with a line number, they just don't happen from stray characters.
# =================================================================================================

PUNCT = set("{}[]();=,:")


class Tok:
    __slots__ = ("kind", "value", "line")

    def __init__(self, kind, value, line):
        self.kind = kind      # "string" | "number" | "ident" | "punct"
        self.value = value
        self.line = line

    def __repr__(self):
        return "Tok(%r, %r, line=%d)" % (self.kind, self.value, self.line)


class TokenizeError(Exception):
    def __init__(self, line, msg):
        self.line = line
        super().__init__("line %d: %s" % (line, msg))


def tokenize(text):
    """Arma-config-flavoured tokenizer. "" inside a "..." string is a literal quote (doubled-quote
    escaping, same convention as SQF and as sqm_read.py's own text-form reader), not a terminator.
    """
    toks = []
    i, n = 0, len(text)
    line = 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            if j < 0:
                raise TokenizeError(line, "unterminated /* */ comment")
            line += text.count("\n", i, j)
            i = j + 2
            continue
        if c == '"':
            start_line = line
            i += 1
            buf = []
            closed = False
            while i < n:
                ch = text[i]
                if ch == '"':
                    if i + 1 < n and text[i + 1] == '"':
                        buf.append('"')
                        i += 2
                        continue
                    i += 1
                    closed = True
                    break
                if ch == "\n":
                    line += 1
                buf.append(ch)
                i += 1
            if not closed:
                raise TokenizeError(start_line, "unterminated string")
            toks.append(Tok("string", "".join(buf), start_line))
            continue
        if c.isdigit() or (c in "+-" and i + 1 < n and text[i + 1].isdigit()):
            start = i
            start_line = line
            if c in "+-":
                i += 1
            while i < n and text[i].isdigit():
                i += 1
            is_float = False
            if i < n and text[i] == "." and i + 1 < n and text[i + 1].isdigit():
                is_float = True
                i += 1
                while i < n and text[i].isdigit():
                    i += 1
            raw = text[start:i]
            val = float(raw) if is_float else int(raw)
            toks.append(Tok("number", val, start_line))
            continue
        if c.isalpha() or c == "_":
            start = i
            start_line = line
            i += 1
            while i < n and (text[i].isalnum() or text[i] == "_"):
                i += 1
            toks.append(Tok("ident", text[start:i], start_line))
            continue
        if c in PUNCT:
            toks.append(Tok("punct", c, line))
            i += 1
            continue
        i += 1   # tolerant: skip an unrecognised character (e.g. a stray operator) rather than abort
    return toks


# =================================================================================================
# Config parser -- aq_content.hpp only. Produces a tree of CfgClass nodes; property order and
# class declaration order are preserved (plain dicts, Python 3.7+ insertion order) because
# objectives are evaluated in declaration order (server/fn_srvFact.sqf) and because deterministic
# iteration order keeps this tool's own output reproducible run to run.
# =================================================================================================

class ParseError(Exception):
    def __init__(self, line, msg):
        self.line = line
        super().__init__("line %d: %s" % (line, msg))


class CfgClass:
    __slots__ = ("name", "line", "props", "prop_lines", "children")

    def __init__(self, name, line):
        self.name = name
        self.line = line
        self.props = {}         # key -> parsed value (str | int | float | list)
        self.prop_lines = {}    # key -> line the assignment started on
        self.children = {}      # name -> CfgClass, in declaration order


class _Parser:
    def __init__(self, toks):
        self.toks = toks
        self.i = 0
        self.n = len(toks)

    def _peek(self):
        return self.toks[self.i] if self.i < self.n else None

    def _line_at_eof(self):
        return self.toks[-1].line if self.toks else 1

    def _at(self, kind, value=None):
        t = self._peek()
        return t is not None and t.kind == kind and (value is None or t.value == value)

    def _advance(self):
        t = self.toks[self.i]
        self.i += 1
        return t

    def _expect_punct(self, ch):
        t = self._peek()
        if not (t and t.kind == "punct" and t.value == ch):
            got = "end of file" if t is None else repr(t.value)
            raise ParseError(t.line if t else self._line_at_eof(), "expected '%s', got %s" % (ch, got))
        return self._advance()

    def parse_value(self):
        t = self._peek()
        if t is None:
            raise ParseError(self._line_at_eof(), "expected a value, got end of file")
        if t.kind == "string" or t.kind == "number":
            self._advance()
            return t.value
        if t.kind == "punct" and t.value == "{":
            return self.parse_array()
        raise ParseError(t.line, "expected a value (string, number or {{ array }}), got %r" % (t.value,))

    def parse_array(self):
        self._expect_punct("{")
        items = []
        if self._at("punct", "}"):
            self._advance()
            return items
        while True:
            items.append(self.parse_value())
            if self._at("punct", ","):
                self._advance()
                if self._at("punct", "}"):
                    self._advance()
                    break
                continue
            self._expect_punct("}")
            break
        return items

    def parse_body(self, name, line):
        node = CfgClass(name, line)
        while True:
            t = self._peek()
            if t is None or (t.kind == "punct" and t.value == "}"):
                break
            if t.kind == "ident" and t.value == "class":
                self._advance()
                name_tok = self._peek()
                if not (name_tok and name_tok.kind == "ident"):
                    raise ParseError(name_tok.line if name_tok else t.line, "expected a class name after 'class'")
                self._advance()
                cname = name_tok.value
                if self._at("punct", ":"):
                    self._advance()
                    if self._at("ident"):
                        self._advance()   # base class name -- inheritance not modelled, not needed here
                if self._at("punct", "{"):
                    self._advance()
                    child = self.parse_body(cname, name_tok.line)
                    self._expect_punct("}")
                else:
                    child = CfgClass(cname, name_tok.line)   # forward declaration, no body
                if self._at("punct", ";"):
                    self._advance()
                if cname not in node.children:   # first declaration wins (matches this engine's
                    node.children[cname] = child  # documented "member already defined" behaviour)
                continue
            if t.kind == "ident":
                key_tok = self._advance()
                key = key_tok.value
                if self._at("punct", "["):
                    self._advance()
                    self._expect_punct("]")
                self._expect_punct("=")
                val = self.parse_value()
                if self._at("punct", ";"):
                    self._advance()
                node.props[key] = val
                node.prop_lines[key] = key_tok.line
                continue
            self._advance()   # tolerant recovery: skip a token that starts neither a class nor a property
        return node


def parse_config(text):
    toks = tokenize(text)
    p = _Parser(toks)
    root = p.parse_body("", 0)
    if p.i < p.n:
        t = p.toks[p.i]
        raise ParseError(t.line, "unexpected %r at top level (an unmatched '}'?)" % (t.value,))
    return root


def gtxt(node, key, default=""):
    v = node.props.get(key, default)
    return v if isinstance(v, str) else default


def garr(node, key):
    v = node.props.get(key, [])
    return v if isinstance(v, list) else []


def pjoin(*parts):
    return " >> ".join(parts)


# A signed-number-literal test, not float(): a threshold like "-500" is legitimate data
# (FACTION_REP_SPEC.md 6.1 -- standing may be gated NEGATIVE), and float() would also accept
# things this grammar never meant to ("1e10", "inf", "  12  ") that a content author fat-fingering
# a threshold should still get flagged for. Ported from the in-game validator's own
# _isNumberLiteral (diagnostics/fn_validate.sqf): walk the characters, allow one leading sign and
# one decimal point, require at least one digit.
def is_number_literal(s):
    if s == "":
        return False
    digits = 0
    dots = 0
    for idx, ch in enumerate(s):
        if ch.isdigit():
            digits += 1
            continue
        is_sign = idx == 0 and ch in "+-"
        is_dot = ch == "." and dots == 0
        if is_dot:
            dots += 1
        if not is_sign and not is_dot:
            return False
    return digits > 0


def parse_num_literal(s):
    return float(s)   # only ever called after is_number_literal() confirms the shape


# =================================================================================================
# Bracket-aware token-stream helpers, shared by the two SQF side-file scans below. Not a SQF
# parser -- these files are tokenized with the SAME tokenize() used for the config file (safe here
# because neither fn_factionCfg.sqf nor fn_aqWorld.sqf uses a '-delimited string), and then walked
# for a handful of specific, known shapes rather than a general grammar.
# =================================================================================================

def parse_bracket_array(toks, i, open_ch, close_ch):
    """toks[i] must be `open_ch`. Returns (list_of_values, index_after_close)."""
    i += 1
    items = []
    if i < len(toks) and toks[i].kind == "punct" and toks[i].value == close_ch:
        return items, i + 1
    while True:
        v, i = _parse_bracket_value(toks, i, open_ch, close_ch)
        items.append(v)
        if i < len(toks) and toks[i].kind == "punct" and toks[i].value == ",":
            i += 1
            if i < len(toks) and toks[i].kind == "punct" and toks[i].value == close_ch:
                return items, i + 1
            continue
        if i < len(toks) and toks[i].kind == "punct" and toks[i].value == close_ch:
            return items, i + 1
        return items, i   # tolerant: the shape stopped matching -- stop rather than loop forever


def _parse_bracket_value(toks, i, open_ch, close_ch):
    if i >= len(toks):
        return None, i
    t = toks[i]
    if t.kind == "string" or t.kind == "number":
        return t.value, i + 1
    if t.kind == "punct" and t.value == open_ch:
        return parse_bracket_array(toks, i, open_ch, close_ch)
    return None, i + 1   # an expression, not a literal -- opaque to this scan


def find_foreach_blocks(toks):
    """Yields (body_tokens, iterable_or_None) for every `{ ... } forEach <expr>` in the stream."""
    n = len(toks)
    i = 0
    out = []
    while i < n:
        t = toks[i]
        if t.kind == "punct" and t.value == "{":
            depth = 1
            j = i + 1
            while j < n and depth > 0:
                if toks[j].kind == "punct" and toks[j].value == "{":
                    depth += 1
                elif toks[j].kind == "punct" and toks[j].value == "}":
                    depth -= 1
                j += 1
            close_idx = j - 1
            if 0 <= close_idx < n and close_idx + 1 < n and toks[close_idx + 1].kind == "ident" \
                    and toks[close_idx + 1].value == "forEach":
                body = toks[i + 1:close_idx]
                k = close_idx + 2
                iterable = None
                if k < n and toks[k].kind == "punct" and toks[k].value == "[":
                    iterable, k = parse_bracket_array(toks, k, "[", "]")
                out.append((body, iterable))
                i = k
                continue
        i += 1
    return out


# =================================================================================================
# fn_factionCfg.sqf -- faction ids for rep:
# =================================================================================================

def parse_faction_ids(path):
    """Pull the ids (row[0] of every row) out of `private _factions = [ [...], [...] ];`."""
    toks = tokenize(path.read_text(encoding="utf-8"))
    for idx, t in enumerate(toks):
        if t.kind == "ident" and t.value == "_factions" and idx + 1 < len(toks) \
                and toks[idx + 1].kind == "punct" and toks[idx + 1].value == "=" \
                and idx + 2 < len(toks) and toks[idx + 2].kind == "punct" and toks[idx + 2].value == "[":
            rows, _ = parse_bracket_array(toks, idx + 2, "[", "]")
            return {row[0] for row in rows if isinstance(row, list) and row and isinstance(row[0], str)}
    return set()


# =================================================================================================
# fn_aqWorld.sqf -- world: key registry, including the one dynamic (forEach/format) pattern.
# =================================================================================================

def _format_arg_ident(toks, open_idx):
    """toks[open_idx] is the '[' of `format [ "fmt", IDENT ]`. Returns IDENT's name, or None."""
    if not (toks[open_idx].kind == "punct" and toks[open_idx].value == "["):
        return None
    j = open_idx + 1
    if j >= len(toks) or toks[j].kind != "string":
        return None
    j += 1
    if j >= len(toks) or not (toks[j].kind == "punct" and toks[j].value == ","):
        return None
    j += 1
    if j >= len(toks) or toks[j].kind != "ident":
        return None
    return toks[j].value


def _binds_to_loop_var(body, var_name):
    """True if `body` contains `private <var_name> = _x ;` -- i.e. var_name IS the forEach var."""
    if var_name == "_x":
        return True
    for idx, t in enumerate(body):
        if (t.kind == "ident" and t.value == "private"
                and idx + 3 < len(body)
                and body[idx + 1].kind == "ident" and body[idx + 1].value == var_name
                and body[idx + 2].kind == "punct" and body[idx + 2].value == "="
                and body[idx + 3].kind == "ident" and body[idx + 3].value == "_x"):
            return True
    return False


def _resolve_foreach_world_keys(body, iterable):
    """If `body` (a forEach block's contents) registers a world key via
    `[format ["<prefix>_%1", VAR], ...] call aq_fnc_registerWorld;`, returns (keys, prefix):

      keys    the concrete resolved key set, when `iterable` is a literal list of strings that
              VAR is bound to (directly, or via `private VAR = _x;`) -- else an empty set.
      prefix  the format string's static prefix (e.g. "cartel_"), whenever a format(...)-based
              registration was found at all, REGARDLESS of whether `keys` could be resolved. The
              caller needs this even on failure, to know which "unverifiable" fallback pattern
              this specific attempt corresponds to (see parse_world_registrations).

    Returns (set(), None) when `body` contains no such registration.
    """
    for idx, t in enumerate(body):
        if t.kind == "ident" and t.value == "format" and idx + 1 < len(body) \
                and body[idx + 1].kind == "punct" and body[idx + 1].value == "[":
            items, _ = parse_bracket_array(body, idx + 1, "[", "]")
            if len(items) >= 1 and isinstance(items[0], str) and "%1" in items[0]:
                fmt = items[0]
                prefix = fmt.split("%1")[0]
                if not (isinstance(iterable, list) and iterable and all(isinstance(v, str) for v in iterable)):
                    return set(), prefix
                var_name = _format_arg_ident(body, idx + 1)
                if var_name and _binds_to_loop_var(body, var_name):
                    return {fmt.replace("%1", v) for v in iterable}, prefix
                return set(), prefix
    return set(), None


def parse_world_registrations(path):
    """Returns (literal_keys, dynamically_resolved_keys, unverifiable_prefixes).

    unverifiable_prefixes holds a format-call's static prefix ONLY when that specific dynamic
    registration could NOT be fully resolved to concrete keys -- a prefix that WAS fully resolved
    must not also sit in the fallback set, or an out-of-range key (a real typo, e.g. "cartel_gold"
    when the registered list is wongs/arms/drug/oil) would be wrongly waved through as
    "unverifiable" instead of being reported as the unknown key it actually is.
    """
    toks = tokenize(path.read_text(encoding="utf-8"))
    literal_keys = set()
    candidate_prefixes = set()   # every format-based registration site's prefix, resolved or not
    n = len(toks)

    for idx, t in enumerate(toks):
        if not (t.kind == "ident" and t.value == "call" and idx + 1 < n
                and toks[idx + 1].kind == "ident" and toks[idx + 1].value == "aq_fnc_registerWorld"):
            continue
        close_idx = idx - 1
        if not (close_idx >= 0 and toks[close_idx].kind == "punct" and toks[close_idx].value == "]"):
            continue
        depth = 1
        j = close_idx - 1
        open_idx = None
        while j >= 0:
            if toks[j].kind == "punct" and toks[j].value == "]":
                depth += 1
            elif toks[j].kind == "punct" and toks[j].value == "[":
                depth -= 1
                if depth == 0:
                    open_idx = j
                    break
            j -= 1
        if open_idx is None:
            continue
        first = toks[open_idx + 1] if open_idx + 1 < n else None
        if first is None:
            continue
        if first.kind == "string":
            literal_keys.add(first.value)
        elif first.kind == "ident" and first.value == "format":
            fmt_open = open_idx + 2
            if fmt_open < n and toks[fmt_open].kind == "punct" and toks[fmt_open].value == "[":
                fmt_items, _ = parse_bracket_array(toks, fmt_open, "[", "]")
                if fmt_items and isinstance(fmt_items[0], str) and "%1" in fmt_items[0]:
                    candidate_prefixes.add(fmt_items[0].split("%1")[0])

    dyn_resolved = set()
    resolved_prefixes = set()
    for body, iterable in find_foreach_blocks(toks):
        keys, prefix = _resolve_foreach_world_keys(body, iterable)
        dyn_resolved |= keys
        if keys and prefix:
            resolved_prefixes.add(prefix)

    dyn_prefixes = candidate_prefixes - resolved_prefixes
    return literal_keys, dyn_resolved, dyn_prefixes


def world_key_status(key, literal_keys, dyn_resolved, dyn_prefixes):
    if key in literal_keys or key in dyn_resolved:
        return "known"
    for p in dyn_prefixes:
        if p and key.startswith(p):
            return "unverifiable"
    return "unknown"


# =================================================================================================
# mission.sqm -- genuine markers only, via the shared reader.
# =================================================================================================

def parse_sqm_markers(path):
    """Every marker NAME, scoped correctly: sqm_read.py keeps `props` per-node, so `name` is only
    ever read from the SAME entity that carries dataType="Marker" -- never a sibling or child
    object's own `name=` (an object's variable name), which is exactly the bug this replaces.
    """
    root = sqm_read.parse(str(path))
    names = set()
    for node in sqm_read.walk(root):
        if node["props"].get("dataType") == "Marker":
            nm = node["props"].get("name")
            if isinstance(nm, str):
                names.add(nm)
    return names


# =================================================================================================
# Report
# =================================================================================================

class Report:
    def __init__(self):
        self.problems = []   # [(path, message)]
        self.notes = []       # [(path, message)] -- informational, does not fail the run

    def problem(self, path, msg):
        self.problems.append((path, msg))

    def note(self, path, msg):
        self.notes.append((path, msg))


# =================================================================================================
# Checks
# =================================================================================================

def check_giver_refs(quests_cfg, templates_cfg, givers_cfg, rpt):
    giver_ids = list(givers_cfg.children.keys()) if givers_cfg else []

    if quests_cfg:
        for qid, q in quests_cfg.children.items():
            giver = gtxt(q, "giver", "")
            if giver != "" and giver not in giver_ids:
                rpt.problem(pjoin("AQ_Quests", qid, "giver"), "'%s' is not a class in AQ_Givers" % giver)

    if templates_cfg:
        for tid, t in templates_cfg.children.items():
            for idx, gid in enumerate(garr(t, "givers")):
                if not isinstance(gid, str) or gid not in giver_ids:
                    rpt.problem(pjoin("AQ_Templates", tid, "givers[%d]" % idx),
                                "%r is not a class in AQ_Givers" % (gid,))

    return giver_ids


def check_requires(quests_cfg, quest_ids, faction_ids, world_info, rpt):
    """requires[] grammar + quest:/rep:/world: resolution. Returns (prereqs, dangling_quest,
    dangling_world) -- the graph check_prereq_cycles and check_reachability need, built here since
    this is already the one pass over every requires[] token.
    """
    literal_keys, dyn_resolved, dyn_prefixes = world_info
    prereqs = {qid: [] for qid in quest_ids}
    dangling_quest = {qid: [] for qid in quest_ids}
    dangling_world = {qid: [] for qid in quest_ids}

    if not quests_cfg:
        return prereqs, dangling_quest, dangling_world

    for qid in quest_ids:
        q = quests_cfg.children[qid]
        base = pjoin("AQ_Quests", qid)
        for idx, tok in enumerate(garr(q, "requires")):
            tp = "%s >> requires[%d]" % (base, idx)
            if not isinstance(tok, str):
                rpt.problem(tp, "is not a string")
                continue
            parts = tok.split(":")
            if len(parts) < 2 or len(parts) > 3:
                rpt.problem(tp, "'%s' is malformed; expected 'quest:<id>', 'license:<name>', "
                                 "'item:<class>[:<qty>]', 'rep:<factionId>:<n>', 'align:<factionId>' "
                                 "or 'world:<key>[:<value>]'"
                            % tok)
                continue
            kind, name = parts[0], parts[1]
            if len(parts) == 3 and kind not in REQUIRES_KINDS_WITH_THIRD_PART:
                rpt.problem(tp, "'%s' has a third part; only 'item:', 'rep:' and 'world:' take one" % tok)

            if kind == "quest":
                if name == qid:
                    rpt.problem(tp, "requires itself")
                elif name in quest_ids:
                    prereqs[qid].append(name)
                else:
                    dangling_quest[qid].append(name)
                    rpt.problem(tp, "requires quest '%s', which does not exist" % name)
            elif kind == "license":
                if name == "":
                    rpt.problem(tp, "names no license")
            elif kind == "item":
                if name == "":
                    rpt.problem(tp, "names no item class")
                if len(parts) == 3:
                    qty = parts[2]
                    if not is_number_literal(qty) or parse_num_literal(qty) <= 0:
                        rpt.problem(tp, "quantity '%s' is not a positive number" % qty)
            elif kind == "rep":
                if len(parts) != 3:
                    rpt.problem(tp, "'%s' is malformed; expected 'rep:<factionId>:<n>'" % tok)
                else:
                    if name == "":
                        rpt.problem(tp, "names no faction id")
                    elif name not in faction_ids:
                        rpt.problem(tp, "requires reputation with '%s', which is not a faction id in "
                                        "fn_factionCfg.sqf" % name)
                    n_s = parts[2]
                    if not is_number_literal(n_s):
                        rpt.problem(tp, "threshold '%s' is not a number" % n_s)
            elif kind == "align":
                # align:<factionId> -- the player's GANG is aligned with that
                # faction. Two parts always; there is no threshold to carry, so a
                # third part is a rep: token written from memory.
                #
                # "any" is reserved and means "aligned with somebody", so it is
                # accepted without being a faction id. Checked before the catalogue
                # lookup, or every align:any in the content would be reported as an
                # unknown faction.
                if len(parts) != 2:
                    rpt.problem(tp, "'%s' is malformed; expected 'align:<factionId>' or 'align:any'" % tok)
                elif name == "":
                    rpt.problem(tp, "names no faction id")
                elif name.lower() != "any" and name not in faction_ids:
                    rpt.problem(tp, "requires alignment with '%s', which is not a faction id in "
                                    "fn_factionCfg.sqf" % name)
            elif kind == "world":
                if name == "":
                    rpt.problem(tp, "names no key")
                else:
                    status = world_key_status(name, literal_keys, dyn_resolved, dyn_prefixes)
                    if status == "unknown":
                        dangling_world[qid].append(name)
                        rpt.problem(tp, "names world key '%s', which nothing has registered with "
                                        "aq_fnc_registerWorld" % name)
                    elif status == "unverifiable":
                        rpt.note(tp, "world key '%s' matches a dynamically-generated pattern "
                                     "(forEach/format); unverifiable offline, not checked" % name)
            else:
                rpt.problem(tp, "'%s' is not a known requirement kind" % kind)

    return prereqs, dangling_quest, dangling_world


def _closure(start, prereqs):
    """Every quest transitively required by `start` (BFS over prereqs)."""
    seen, seen_set = [], set()
    stack = list(prereqs.get(start, []))
    while stack:
        node = stack.pop(0)
        if node not in seen_set:
            seen_set.add(node)
            seen.append(node)
            stack.extend(prereqs.get(node, []))
    return seen


def _cycle_path(start, prereqs):
    """One concrete cycle path back to `start`, or [] if start is not in its own closure."""
    parent = {}
    queue = list(prereqs.get(start, []))
    for x in queue:
        parent.setdefault(x, start)
    hit = None
    qi = 0
    while qi < len(queue) and hit is None:
        node = queue[qi]
        qi += 1
        for x in prereqs.get(node, []):
            if x == start:
                hit = node
                break
            if x not in parent:
                parent[x] = node
                queue.append(x)
    if hit is None:
        return []
    path = []
    cur = hit
    steps = 0
    while steps < 64:
        path.append(cur)
        if cur == start:
            break
        cur = parent.get(cur, start)
        steps += 1
    path.reverse()
    path.append(start)
    return path


def check_prereq_cycles(quest_ids, prereqs, rpt):
    """A quest that requires itself (A -> A) is reported separately, at the token, by
    check_requires ("requires itself") -- self-loops are therefore excluded from `prereqs` itself
    (see check_requires) and this check is left to find real, multi-quest cycles.
    """
    cyclic = {qid for qid in quest_ids if qid in _closure(qid, prereqs)}
    for qid in quest_ids:
        if qid not in cyclic:
            continue
        path = _cycle_path(qid, prereqs)
        msg = "sits in a prerequisite cycle"
        if path:
            msg += ": " + " -> ".join(path)
        rpt.problem(pjoin("AQ_Quests", qid, "requires"), msg)
    return cyclic


def check_chain_targets(quests_cfg, quest_ids, rpt):
    if not quests_cfg:
        return
    for qid in quest_ids:
        chain = gtxt(quests_cfg.children[qid], "chain", "")
        if chain != "" and chain not in quest_ids:
            rpt.problem(pjoin("AQ_Quests", qid, "chain"), "chains to '%s', which is not a quest" % chain)


def check_chain_same_giver(quests_cfg, quest_ids, rpt):
    """chain hands off to the SAME giver only -- see the module docstring's CHAIN note. Not a
    restatement of reachability: aq_fnc_reachability's own graph does not compare givers across a
    chain edge, so this is the one check that actually catches a cross-giver chain.
    """
    if not quests_cfg:
        return
    for qid in quest_ids:
        q = quests_cfg.children[qid]
        chain = gtxt(q, "chain", "")
        if chain == "" or chain not in quests_cfg.children:
            continue   # empty, or nonexistent -- the latter is check_chain_targets's problem to report
        target = quests_cfg.children[chain]
        this_giver = gtxt(q, "giver", "")
        target_giver = gtxt(target, "giver", "")
        if this_giver != "" and target_giver != "" and this_giver != target_giver:
            rpt.problem(pjoin("AQ_Quests", qid, "chain"),
                        "chains to '%s', whose giver is '%s', but this quest's own giver is '%s'; "
                        "chain only ever hands off to the SAME giver, so '%s' is never actually offered "
                        "by this handoff" % (chain, target_giver, this_giver, chain))


def check_reachability(quests_cfg, quest_ids, giver_ids, prereqs, dangling_quest, dangling_world, cyclic, rpt):
    """Ports aq_fnc_reachability's own fixed-point algorithm: a quest is reachable when something
    can offer it (its own valid `giver`, or a chain from an already-reachable quest) and every
    quest: prerequisite it carries is itself reachable. Iterated to a fixed point, same as the
    in-game diagnostic, so declaration order cannot change the answer.
    """
    if not quests_cfg:
        return

    giver_of = {qid: gtxt(quests_cfg.children[qid], "giver", "") for qid in quest_ids}
    chain_of = {qid: gtxt(quests_cfg.children[qid], "chain", "") for qid in quest_ids}
    chained_by = {}
    for qid in quest_ids:
        target = chain_of[qid]
        if target:
            chained_by.setdefault(target, []).append(qid)

    def has_giver(qid):
        g = giver_of.get(qid, "")
        return g != "" and g in giver_ids

    reachable = {qid: False for qid in quest_ids}
    guard = len(quest_ids) + 1
    changed, passes = True, 0
    while changed and passes < guard:
        changed = False
        passes += 1
        for qid in quest_ids:
            if reachable[qid]:
                continue
            offerable = has_giver(qid) or any(reachable.get(src, False) for src in chained_by.get(qid, []))
            if not offerable:
                continue
            blocked = bool(dangling_quest.get(qid)) or bool(dangling_world.get(qid))
            if not blocked:
                blocked = any(not reachable.get(req, False) for req in prereqs.get(qid, []))
            if not blocked:
                reachable[qid] = True
                changed = True

    for qid in quest_ids:
        if reachable[qid]:
            continue
        path = pjoin("AQ_Quests", qid)
        dang = dangling_quest.get(qid) or []
        dangw = dangling_world.get(qid) or []
        g = giver_of.get(qid, "")
        inbound = chained_by.get(qid, [])

        # Each branch below states the SAME conclusion (this quest is unreachable) for a different
        # underlying cause; several of those causes are ALSO reported, worded differently, by an
        # earlier check (check_requires' dangling quest:/world:, check_prereq_cycles). That overlap
        # is deliberate, not a bug -- it mirrors this repo's real two-diagnostic split
        # (aq_fnc_validate vs aq_fnc_reachability), where the same root cause is legitimately named
        # by both tools. The "unreachable:" prefix makes the relationship obvious rather than
        # reading as an accidental duplicate.
        if dang:
            rpt.problem(path, "unreachable: requires quest(s) %s, which do not exist" % dang)
        elif dangw:
            rpt.problem(path, "unreachable: requires world key(s) %s, which nothing has registered "
                              "with aq_fnc_registerWorld" % dangw)
        elif qid in cyclic:
            rpt.problem(path, "unreachable: sits in a prerequisite cycle (see the requires[] problem above)")
        elif g == "" and not inbound:
            rpt.problem(path, "unreachable: has no giver and no quest chains into it, so nothing can offer it")
        elif g != "" and g not in giver_ids:
            rpt.problem(path, "unreachable: names giver '%s', which is not in AQ_Givers" % g)
        else:
            blockers = [r for r in prereqs.get(qid, []) if not reachable.get(r, False)]
            live = [c for c in inbound if reachable.get(c, False)]
            if blockers:
                rpt.problem(path, "unreachable: is blocked behind unreachable quest(s) %s" % blockers)
            elif inbound and not live:
                rpt.problem(path, "unreachable: is only chained into by unreachable quest(s) %s" % inbound)
            else:
                rpt.problem(path, "unreachable for a reason this check could not name (please report this)")


def check_objectives(quests_cfg, templates_cfg, markers, rpt):
    def group(container_path, container_node):
        objs = container_node.children.get("objectives")
        if objs is None:
            return
        for oid, o in objs.children.items():
            op = pjoin(container_path, "objectives", oid)

            otype = gtxt(o, "type", "")
            if otype == "":
                rpt.problem(pjoin(op, "type"), "objective declares no type")
            elif otype not in OBJECTIVE_TYPES:
                rpt.problem(pjoin(op, "type"), "'%s' is not a registered objective type (expected one "
                                                "of: %s)" % (otype, ", ".join(sorted(OBJECTIVE_TYPES))))

            marker = gtxt(o, "marker", "")
            if marker != "":
                if "%" in marker:
                    # A %SLOT% substitution marker (radiant templates with a `slots` class) is only
                    # a real marker name after generation. No content in this file uses slots today
                    # (AQ_Pools is deliberately empty -- see aq_content.hpp's own header), so this
                    # is a defensive no-op rather than a case being exercised; kept because a marker
                    # value containing '%' is definitionally not checkable against a literal name.
                    rpt.note(pjoin(op, "marker"), "'%s' looks like a template %%SLOT%% substitution; "
                                                   "not checked offline" % marker)
                elif marker not in markers:
                    rpt.problem(pjoin(op, "marker"), "marker '%s' does not exist as a Marker entity in "
                                                       "mission.sqm" % marker)

    if quests_cfg:
        for qid, q in quests_cfg.children.items():
            group(pjoin("AQ_Quests", qid), q)
    if templates_cfg:
        for tid, t in templates_cfg.children.items():
            group(pjoin("AQ_Templates", tid), t)


# =================================================================================================
# main
# =================================================================================================

def run(content_file=CONTENT_FILE, faction_file=FACTION_FILE, world_file=WORLD_FILE, sqm_file=SQM_FILE,
        out=sys.stdout):
    """Runs every check and returns (exit_code, report). Parameterised on the four input paths so
    tests can point it at small fixture files instead of the real, large content tree.
    """
    if not content_file.is_file():
        print("[aq-check] FATAL: %s does not exist" % content_file, file=out)
        return 2, None

    text = content_file.read_text(encoding="utf-8")
    try:
        root = parse_config(text)
    except (TokenizeError, ParseError) as e:
        print("[aq-check] FATAL: could not parse %s: %s" % (content_file, e), file=out)
        return 2, None

    rpt = Report()

    faction_ids = set()
    if faction_file.is_file():
        faction_ids = parse_faction_ids(faction_file)
    else:
        rpt.note(str(faction_file), "file not found; rep: faction membership not checked")

    world_info = (set(), set(), set())
    if world_file.is_file():
        world_info = parse_world_registrations(world_file)
    else:
        rpt.note(str(world_file), "file not found; world: key registration not checked")

    markers = set()
    if sqm_file.is_file():
        markers = parse_sqm_markers(sqm_file)
    else:
        rpt.note(str(sqm_file), "file not found; objective markers not checked")

    givers_cfg = root.children.get("AQ_Givers")
    quests_cfg = root.children.get("AQ_Quests")
    templates_cfg = root.children.get("AQ_Templates")
    quest_ids = list(quests_cfg.children.keys()) if quests_cfg else []

    giver_ids = check_giver_refs(quests_cfg, templates_cfg, givers_cfg, rpt)
    prereqs, dangling_quest, dangling_world = check_requires(quests_cfg, quest_ids, faction_ids, world_info, rpt)
    cyclic = check_prereq_cycles(quest_ids, prereqs, rpt)
    check_chain_targets(quests_cfg, quest_ids, rpt)
    check_chain_same_giver(quests_cfg, quest_ids, rpt)
    check_reachability(quests_cfg, quest_ids, giver_ids, prereqs, dangling_quest, dangling_world, cyclic, rpt)
    check_objectives(quests_cfg, templates_cfg, markers, rpt)

    n_templates = len(templates_cfg.children) if templates_cfg else 0
    print("[aq-check] %d quest(s), %d template(s), %d giver(s)"
          % (len(quest_ids), n_templates, len(giver_ids)), file=out)

    for i, (path, msg) in enumerate(rpt.problems, 1):
        print("[aq-check] %d. PROBLEM  %s  --  %s" % (i, path, msg), file=out)
    for i, (path, msg) in enumerate(rpt.notes, 1):
        print("[aq-check] %d. note  %s  --  %s" % (i, path, msg), file=out)

    if rpt.problems:
        print("[aq-check] FAIL: %d problem(s), %d note(s)" % (len(rpt.problems), len(rpt.notes)), file=out)
        return 1, rpt
    print("[aq-check] PASS: 0 problems, %d note(s)" % len(rpt.notes), file=out)
    return 0, rpt


def check_settings_drift(repo):
    """Every AQ_Settings key ArmaQuest ships must be one we carry, or be a known
    code-default fall-through.

    description.ext defines AQ_HOST_CONTENT, so the library's sample AQ_Settings is
    NOT declared and cannot supply defaults. Anything aq_content.hpp omits falls
    through to a default hardcoded in ArmaQuest's own SQF instead. That is fine and
    deliberate -- but it means a setting added upstream lands here silently, on
    whatever the code says, with nothing to notice it. This is that notice.
    """
    import re
    mission = repo / "mission" / "Armapunk2035.Malden"
    lib = mission / "ArmaQuest" / "config" / "CfgArmaQuest.hpp"
    ours = mission / "aq_content.hpp"
    if not lib.exists() or not ours.exists():
        return []

    def members(path, cls):
        m = re.search(rf"^class {cls} \{{(.*?)^\}};", path.read_text(), re.S | re.M)
        if not m:
            return set()
        body = "\n".join(l for l in m.group(1).split("\n") if not l.strip().startswith("//"))
        return set(re.findall(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:\[\])?\s*=", body, re.M))

    missing = sorted(members(lib, "AQ_Settings") - members(ours, "AQ_Settings"))
    # Known and accepted: these have never been set here and run on ArmaQuest's
    # code defaults, which the boot log reports. Listed explicitly so a NEW one
    # stands out instead of joining a silent crowd.
    accepted = {
        "boardMode", "boardSize", "debug", "factGeoSlack", "factMaxCount",
        "factRateLimit", "flushInterval", "maxActive", "offerLifetime",
        "sideMap", "sweepInterval",
    }
    unexpected = [k for k in missing if k not in accepted]
    if unexpected:
        return [
            "AQ_Settings drift: ArmaQuest now ships setting(s) aq_content.hpp does not "
            "carry, and AQ_HOST_CONTENT means its config cannot supply them -- they will "
            "run on whatever ArmaQuest's SQF hardcodes: " + ", ".join(unexpected)
        ]
    return []


def main(argv=None):
    code, _ = run()
    # Runs alongside the content checks rather than inside run(): it inspects two
    # config FILES rather than the parsed catalogue, so it has nothing to say about
    # a quest and does not belong in that report. Its failure still fails the run.
    drift = check_settings_drift(pathlib.Path(__file__).resolve().parents[1])
    for msg in drift:
        print("FAIL  " + msg)
    return code or (1 if drift else 0)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
