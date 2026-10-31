"""Streaming reader for a `mysqldump` file: schema out, rows out, as text.

Purpose:
    Turn a `mysqldump` file into `Table` objects (from `CREATE TABLE`) and
    `Row` objects (from `INSERT INTO ... VALUES (...),(...)`), without holding
    the file in memory and without coercing a single value.

WHY THIS EXISTS:
    Three failures, all of which have bitten naive dump parsers.

    1. Memory. The live dump is ~65 MB gzipped, several hundred MB raw. Any
       approach that reads the file, or even one table, into a string works on
       a test fixture and dies on the real thing. This reader is line-driven
       and buffers at most one statement (mysqldump bounds those with
       --net-buffer-length, ~1 MB by default).

    2. Escaping. Splitting a dump on `;` or `),(` is the classic bug: both
       sequences appear *inside* string values, and so do `--`, `#`, `/*` and
       newlines. A player display name containing an apostrophe, or an
       inventory blob containing a backslash, silently shifts every subsequent
       value in the row by one column — which in this database means moving
       money. So the splitter is a real quote-aware state machine, and
       `test_dump.py` exists almost entirely for it.

    3. Premature coercion. Values are yielded as `str` (or `None` for NULL),
       exactly as the dump held them after unescaping. Never `int`, never
       `float`, never `Decimal`. The source has a bigint currency column whose
       values exceed float's exact range; parsing it here to "be helpful"
       would corrupt balances before any transform got a chance to object.

    Deliberately not handled, because this is an ETL for player data and not a
    general-purpose dump loader: triggers, stored routines, views and events.
    They live inside `/*! ... */` conditional comments; this reader skips them
    but *counts* them and reports them as `Statement(kind="routine")` so the
    orchestrator can say out loud that the dump contained things it did not
    migrate. (`deploy/run-boot2.sh` drops a trigger that exists in no `.sql`
    file in this repo, so silently discarding them would be a bad idea.)

Usage:
    from pgmigrate import dump

    tables = dump.read_schema("live.sql")            # pass 1: DDL only
    for row in dump.iter_rows("live.sql", tables):   # pass 2: rows, streamed
        print(row.table, row.values["uid"])

    # inspection:
    python3 -m pgmigrate.dump --dump live.sql --schema

STATUS:
    Written against the mysqldump format and the plan's description of the
    source schema. It has never seen the live dump — no live dump exists in
    this repository. Unvalidated until it meets one.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Iterable, Iterator

if __package__ in (None, ""):  # allow `python3 dump.py` from this directory
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from pgmigrate.model import Column, Row, Table, TransformError, error
else:
    from .model import Column, Row, Table, TransformError, error

__all__ = [
    "Statement",
    "iter_statements",
    "read_schema",
    "iter_rows",
    "open_dump",
    "dump_sha256",
    "parse_create_table",
    "unescape_mysql_string",
]

DUMP = "<dump>"  # table name used for file-level problems


# --------------------------------------------------------------------------
# File access
# --------------------------------------------------------------------------


def open_dump(path: str, *, encoding: str = "utf-8") -> io.TextIOBase:
    """Open a dump for streaming text reads; transparently handles gzip.

    Decoding is strict. A dump written by an old server may be latin1; when
    that happens this raises `UnicodeDecodeError` rather than substituting
    replacement characters into player names, and the caller passes a
    different `encoding`.
    """
    with open(path, "rb") as probe:
        magic = probe.read(2)
    if magic == b"\x1f\x8b":
        binary: io.BufferedIOBase = gzip.open(path, "rb")  # type: ignore[assignment]
    else:
        binary = open(path, "rb")
    return io.TextIOWrapper(binary, encoding=encoding, errors="strict", newline="")


def dump_sha256(path: str, *, chunk: int = 1 << 20) -> str:
    """Hash the dump file as it sits on disk. Identifies a run's input."""
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            block = fh.read(chunk)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest()


# --------------------------------------------------------------------------
# Statement splitting (the quote-aware state machine)
# --------------------------------------------------------------------------

_NORMAL = 0
_SQUOTE = 1
_DQUOTE = 2
_BTICK = 3
_BLOCK = 4

# In normal SQL text, the next thing that can change how we read is a string
# or identifier quote, a statement terminator, or a comment opener. `--` only
# opens a comment when followed by whitespace or end-of-line (MySQL rule);
# `4--5` is arithmetic.
_NORMAL_RE = re.compile(r"['\"`;#]|--(?=[ \t\r\n]|$)|/\*")
_SQ_RE = re.compile(r"\\.|'", re.S)
_DQ_RE = re.compile(r'\\.|"', re.S)
_BT_RE = re.compile(r"`")
_BLOCK_END_RE = re.compile(r"\*/")

_ROUTINE_RE = re.compile(
    r"\bCREATE\b[^;]{0,400}?\b(TRIGGER|PROCEDURE|FUNCTION|VIEW|EVENT)\b", re.I | re.S
)


@dataclass
class Statement:
    """One top-level SQL statement lifted out of the dump."""

    kind: str        # "create_table" | "insert" | "routine" | "other"
    line: int        # 1-based line the statement started on
    text: str        # statement text, comments stripped, no trailing ';'
    table: str | None = None


def _split_statements(fh: Iterable[str]) -> Iterator[tuple[int, str]]:
    """Yield (start_line, statement_text) pairs, comments removed.

    Quote-aware: `;`, `--`, `#` and `/*` inside a string are data, not syntax.
    Handles both MySQL escape styles inside strings — backslash escapes
    (`\\'`) and SQL doubling (`''`) — because a dump taken with
    NO_BACKSLASH_ESCAPES uses the latter.
    """
    state = _NORMAL
    buf: list[str] = []
    comment_buf: list[str] = []
    lineno = 0
    start_line = 1
    for line in fh:
        lineno += 1
        if state == _NORMAL and not buf:
            start_line = lineno
        i = 0
        n = len(line)
        while i < n:
            if state == _NORMAL:
                m = _NORMAL_RE.search(line, i)
                if m is None:
                    buf.append(line[i:])
                    break
                buf.append(line[i:m.start()])
                tok = m.group()
                i = m.end()
                if tok == ";":
                    stmt = "".join(buf).strip()
                    buf = []
                    if stmt:
                        yield start_line, stmt
                    start_line = lineno
                elif tok in ("--", "#"):
                    # Line comment: drop the rest of the line but keep a
                    # separator so `a --c\nb` does not become `ab`.
                    buf.append("\n")
                    break
                elif tok == "/*":
                    state = _BLOCK
                    comment_buf = []
                elif tok == "'":
                    state = _SQUOTE
                    buf.append(tok)
                elif tok == '"':
                    state = _DQUOTE
                    buf.append(tok)
                else:  # backtick
                    state = _BTICK
                    buf.append(tok)

            elif state in (_SQUOTE, _DQUOTE):
                quote = "'" if state == _SQUOTE else '"'
                pattern = _SQ_RE if state == _SQUOTE else _DQ_RE
                m = pattern.search(line, i)
                if m is None:
                    # Unterminated on this line: a literal newline inside the
                    # string. Legal, and mysqldump normally escapes it, but a
                    # hand-edited dump may not.
                    buf.append(line[i:])
                    break
                buf.append(line[i:m.start()])
                got = m.group()
                if got.startswith("\\"):
                    buf.append(got)          # keep escape intact for the value parser
                    i = m.end()
                    continue
                # got == quote
                if m.end() < n and line[m.end()] == quote:
                    buf.append(quote * 2)    # SQL-doubled quote, stays in the string
                    i = m.end() + 1
                    continue
                buf.append(quote)
                i = m.end()
                state = _NORMAL

            elif state == _BTICK:
                m = _BT_RE.search(line, i)
                if m is None:
                    buf.append(line[i:])
                    break
                buf.append(line[i:m.end()])
                i = m.end()
                if i < n and line[i] == "`":
                    buf.append("`")          # doubled backtick inside identifier
                    i += 1
                    continue
                state = _NORMAL

            else:  # _BLOCK
                m = _BLOCK_END_RE.search(line, i)
                if m is None:
                    comment_buf.append(line[i:])
                    break
                comment_buf.append(line[i:m.start()])
                i = m.end()
                state = _NORMAL
                body = "".join(comment_buf)
                comment_buf = []
                if _ROUTINE_RE.search(body):
                    # Not migrated, but never silently dropped.
                    yield start_line, "\x00ROUTINE\x00" + body.strip()

    tail = "".join(buf).strip()
    if state != _NORMAL:
        raise error(
            DUMP, None, None,
            f"dump ended inside a quoted string or comment (state {state}, "
            f"statement starting at line {start_line}); the file is truncated",
        )
    if tail:
        yield start_line, tail


_CREATE_RE = re.compile(
    r"^CREATE\s+(?:TEMPORARY\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"
    r"(`(?:[^`]|``)*`|[A-Za-z0-9_$]+)(?:\s*\.\s*(`(?:[^`]|``)*`|[A-Za-z0-9_$]+))?\s*\(",
    re.I | re.S,
)
_INSERT_RE = re.compile(
    r"^(?:INSERT|REPLACE)\s+"
    r"(?:LOW_PRIORITY\s+|DELAYED\s+|HIGH_PRIORITY\s+|IGNORE\s+)*"
    r"INTO\s+(`(?:[^`]|``)*`|[A-Za-z0-9_$]+)(?:\s*\.\s*(`(?:[^`]|``)*`|[A-Za-z0-9_$]+))?"
    r"\s*(\([^()]*\))?\s*VALUES\s*",
    re.I | re.S,
)


def _unquote_ident(text: str) -> str:
    text = text.strip()
    if text.startswith("`") and text.endswith("`") and len(text) >= 2:
        return text[1:-1].replace("``", "`")
    return text


def iter_statements(path: str, *, encoding: str = "utf-8") -> Iterator[Statement]:
    """Classify every top-level statement in the dump. Streams."""
    with open_dump(path, encoding=encoding) as fh:
        for line, text in _split_statements(fh):
            if text.startswith("\x00ROUTINE\x00"):
                yield Statement(kind="routine", line=line, text=text[len("\x00ROUTINE\x00"):])
                continue
            head = text.lstrip()
            m = _CREATE_RE.match(head)
            if m:
                name = _unquote_ident(m.group(2) or m.group(1))
                yield Statement(kind="create_table", line=line, text=head, table=name)
                continue
            m = _INSERT_RE.match(head)
            if m:
                name = _unquote_ident(m.group(2) or m.group(1))
                yield Statement(kind="insert", line=line, text=head, table=name)
                continue
            yield Statement(kind="other", line=line, text=head)


# --------------------------------------------------------------------------
# CREATE TABLE parsing
# --------------------------------------------------------------------------

_TOKEN_RE = re.compile(
    r"""
      (?P<ident>`(?:[^`]|``)*`)
    | (?P<sstr>'(?:\\.|''|[^'])*')
    | (?P<dstr>"(?:\\.|""|[^"])*")
    | (?P<word>[A-Za-z_$][A-Za-z0-9_$]*)
    | (?P<num>[0-9][0-9A-Za-z_.+\-]*)
    | (?P<punct>[(),=])
    | (?P<other>\S)
    """,
    re.X | re.S,
)

# Type names that are more than one bare word.
_MULTIWORD_TYPES = {
    ("double", "precision"),
    ("character", "varying"),
    ("national", "varchar"),
    ("national", "char"),
}
_TYPE_SUFFIX_WORDS = {"unsigned", "zerofill"}


def _tokenize(text: str) -> list[str]:
    """Token list where a parenthesised group is one token, quotes intact."""
    tokens: list[str] = []
    depth = 0
    group: list[str] = []
    for m in _TOKEN_RE.finditer(text):
        tok = m.group()
        if tok == "(":
            depth += 1
            group.append(tok)
            continue
        if depth:
            group.append(tok)
            if tok == ")":
                depth -= 1
                if depth == 0:
                    tokens.append("".join(group))
                    group = []
            continue
        tokens.append(tok)
    if depth:
        raise error(DUMP, None, None, "unbalanced parentheses in a CREATE TABLE body")
    return tokens


def _split_top_level(body: str) -> list[str]:
    """Split a CREATE TABLE body on top-level commas, quote/paren aware."""
    parts: list[str] = []
    depth = 0
    buf: list[str] = []
    i = 0
    n = len(body)
    while i < n:
        ch = body[i]
        if ch in "'\"":
            quote = ch
            buf.append(ch)
            i += 1
            while i < n:
                c = body[i]
                if c == "\\" and i + 1 < n:
                    buf.append(body[i:i + 2])
                    i += 2
                    continue
                buf.append(c)
                i += 1
                if c == quote:
                    if i < n and body[i] == quote:
                        buf.append(quote)
                        i += 1
                        continue
                    break
            continue
        if ch == "`":
            buf.append(ch)
            i += 1
            while i < n:
                buf.append(body[i])
                i += 1
                if body[i - 1] == "`":
                    if i < n and body[i] == "`":
                        buf.append("`")
                        i += 1
                        continue
                    break
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append("".join(buf).strip())
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return parts


def _index_columns(group: str) -> list[str]:
    """Column list of a KEY definition; strips prefix lengths and ASC/DESC."""
    inner = group.strip()
    if inner.startswith("(") and inner.endswith(")"):
        inner = inner[1:-1]
    cols: list[str] = []
    for part in _split_top_level(inner):
        part = part.strip()
        if not part:
            continue
        m = re.match(r"^(`(?:[^`]|``)*`|[A-Za-z0-9_$]+)", part)
        if not m:
            # A functional index expression, e.g. KEY ((lower(name))). It has
            # no single source column; name it verbatim so the DDL translator
            # can decide, rather than dropping it.
            cols.append(part)
            continue
        cols.append(_unquote_ident(m.group(1)))
    return cols


def parse_create_table(text: str, *, line: int = 0) -> Table:
    """Parse one CREATE TABLE statement into a `Table`.

    Foreign keys and CHECK constraints are not represented — this ETL loads
    into a freshly built target whose constraints come from `ddl`, not from
    the source. They are skipped explicitly, not by accident.
    """
    text = text.lstrip()
    m = _CREATE_RE.match(text)
    if not m:
        raise error(DUMP, None, None, f"line {line}: not a CREATE TABLE statement")
    name = _unquote_ident(m.group(2) or m.group(1))
    open_paren = m.end() - 1                   # _CREATE_RE ends on the '('
    depth = 0
    close = -1
    i = open_paren
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in "'\"`":
            quote = ch
            i += 1
            while i < n:
                c = text[i]
                if c == "\\" and quote != "`" and i + 1 < n:
                    i += 2
                    continue
                i += 1
                if c == quote:
                    if i < n and text[i] == quote:
                        i += 1
                        continue
                    break
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                close = i
                break
        i += 1
    if close < 0:
        raise error(name, None, None, f"line {line}: unterminated CREATE TABLE body")

    body = text[open_paren + 1:close]
    columns: list[Column] = []
    primary_key: list[str] = []
    indexes: list[tuple[str, list[str], bool]] = []

    for item in _split_top_level(body):
        if not item:
            continue
        upper = item.upper()
        if upper.startswith("PRIMARY KEY"):
            group = item[item.index("("):]
            primary_key = _index_columns(group)
            continue
        if upper.startswith("CONSTRAINT") or upper.startswith("FOREIGN KEY") or upper.startswith("CHECK"):
            continue
        if re.match(r"^(UNIQUE|FULLTEXT|SPATIAL)?\s*(KEY|INDEX)\b", upper) or upper.startswith("UNIQUE"):
            unique = upper.startswith("UNIQUE")
            if "(" not in item:
                continue
            head = item[:item.index("(")]
            group = item[item.index("("):]
            idx_name_m = re.search(r"(`(?:[^`]|``)*`|[A-Za-z0-9_$]+)\s*$", head.strip())
            raw_name = idx_name_m.group(1) if idx_name_m else ""
            idx_name = _unquote_ident(raw_name)
            if idx_name.upper() in ("KEY", "INDEX", "UNIQUE", "FULLTEXT", "SPATIAL"):
                idx_name = ""
            cols = _index_columns(group)
            if not idx_name:
                idx_name = f"{name}_{'_'.join(cols)}_idx"
            indexes.append((idx_name, cols, unique))
            continue
        columns.append(_parse_column(item, table=name, line=line))

    if not columns:
        raise error(name, None, None, f"line {line}: CREATE TABLE has no columns")
    known = {c.name for c in columns}
    for pk_col in primary_key:
        if pk_col not in known:
            raise error(name, pk_col, None,
                        f"line {line}: PRIMARY KEY names a column that is not "
                        "in the table")
    return Table(name=name, columns=columns, primary_key=primary_key, indexes=indexes)


def _parse_column(defn: str, *, table: str, line: int) -> Column:
    tokens = _tokenize(defn)
    if len(tokens) < 2:
        raise error(table, None, None, f"line {line}: cannot parse column definition {defn!r}")
    col_name = _unquote_ident(tokens[0])

    # --- type: base word(s), then an optional (…) spec attached with no
    #     space, then unsigned/zerofill. "bigint(20) unsigned", "enum('a','b')".
    i = 1
    base = [tokens[i].lower()]
    i += 1
    if i < len(tokens) and (base[0], tokens[i].lower()) in _MULTIWORD_TYPES:
        base.append(tokens[i].lower())
        i += 1
    mysql_type = " ".join(base)
    if i < len(tokens) and tokens[i].startswith("("):
        mysql_type += tokens[i]               # keep enum/set literals verbatim
        i += 1
    while i < len(tokens) and tokens[i].lower() in _TYPE_SUFFIX_WORDS:
        mysql_type += " " + tokens[i].lower()
        i += 1

    # --- attributes
    nullable = True
    default: str | None = None
    extra: list[str] = []
    while i < len(tokens):
        tok = tokens[i]
        up = tok.upper()
        if up == "NOT" and i + 1 < len(tokens) and tokens[i + 1].upper() == "NULL":
            nullable = False
            i += 2
            continue
        if up == "NULL":
            nullable = True
            i += 1
            continue
        if up == "DEFAULT":
            if i + 1 >= len(tokens):
                raise error(table, col_name, None, f"line {line}: DEFAULT with no value")
            default = tokens[i + 1]
            i += 2
            # A negative default tokenises as sign + number: `DEFAULT -1`.
            if default in ("-", "+") and i < len(tokens):
                default += tokens[i]
                i += 1
            # DEFAULT current_timestamp() arrives as word + "()" group
            elif i < len(tokens) and tokens[i].startswith("(") \
                    and re.match(r"^[A-Za-z_]", default):
                default += tokens[i]
                i += 1
            continue
        if up == "AUTO_INCREMENT":
            extra.append("auto_increment")
            i += 1
            continue
        if up == "ON" and i + 1 < len(tokens) and tokens[i + 1].upper() == "UPDATE":
            expr = tokens[i + 2] if i + 2 < len(tokens) else ""
            i += 3
            if i < len(tokens) and tokens[i].startswith("("):
                expr += tokens[i]
                i += 1
            extra.append(f"on update {expr.lower()}")
            continue
        if up in ("COMMENT", "COLLATE"):
            i += 2
            continue
        if up == "CHARACTER" and i + 1 < len(tokens) and tokens[i + 1].upper() == "SET":
            i += 3
            continue
        if up in ("GENERATED", "ALWAYS", "AS", "STORED", "VIRTUAL", "PERSISTENT"):
            if up in ("STORED", "VIRTUAL", "PERSISTENT"):
                extra.append(f"generated {up.lower()}")
                i += 1
                continue
            if up == "AS" and i + 1 < len(tokens) and tokens[i + 1].startswith("("):
                extra.append("generated as " + tokens[i + 1])
                i += 2
                continue
            i += 1
            continue
        if up in ("UNIQUE", "PRIMARY", "KEY", "INVISIBLE"):
            i += 1
            continue
        if tok.startswith("/*"):
            i += 1
            continue
        # Unknown attribute: do not guess. Naming it is cheap; ignoring it is
        # how a column arrives in the target with the wrong semantics.
        raise error(
            table, col_name, None,
            f"line {line}: unrecognised column attribute {tok!r} in {defn!r}",
        )

    return Column(
        name=col_name,
        mysql_type=mysql_type,
        nullable=nullable,
        default=default,
        extra=" ".join(extra),
    )


# --------------------------------------------------------------------------
# Value parsing
# --------------------------------------------------------------------------

_MYSQL_ESCAPES = {
    "0": "\0",
    "b": "\b",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "Z": "\x1a",
    "'": "'",
    '"': '"',
    "\\": "\\",
}


def unescape_mysql_string(text: str) -> str:
    """Decode the body of a MySQL single-quoted literal (quotes already off).

    Handles backslash escapes and SQL-doubled quotes. `\\%` and `\\_` keep
    their backslash — MySQL leaves them alone so that LIKE patterns survive a
    dump/restore, and dropping the backslash here would change stored text.
    """
    if "\\" not in text and "''" not in text:
        return text
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "\\" and i + 1 < n:
            nxt = text[i + 1]
            if nxt in _MYSQL_ESCAPES:
                out.append(_MYSQL_ESCAPES[nxt])
            elif nxt in ("%", "_"):
                out.append("\\" + nxt)
            else:
                out.append(nxt)
            i += 2
            continue
        if ch == "'" and i + 1 < n and text[i + 1] == "'":
            out.append("'")
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _parse_value(text: str, pos: int, table: str) -> tuple[object, int]:
    """Parse one value literal starting at `pos`. Returns (value, next_pos)."""
    n = len(text)
    while pos < n and text[pos] in " \t\r\n":
        pos += 1
    if pos >= n:
        raise error(table, None, None, "unexpected end of INSERT while reading a value")

    ch = text[pos]

    if ch == "'":
        i = pos + 1
        buf: list[str] = []
        while i < n:
            c = text[i]
            if c == "\\" and i + 1 < n:
                buf.append(text[i:i + 2])
                i += 2
                continue
            if c == "'":
                if i + 1 < n and text[i + 1] == "'":
                    buf.append("''")
                    i += 2
                    continue
                return unescape_mysql_string("".join(buf)), i + 1
            buf.append(c)
            i += 1
        raise error(table, None, None, "unterminated string literal in INSERT")

    if ch in "xX" and text.startswith("'", pos + 1):
        value, nxt = _parse_value(text, pos + 1, table)
        return _from_hex(str(value), table), nxt

    if text.startswith("0x", pos) or text.startswith("0X", pos):
        i = pos + 2
        while i < n and text[i] in "0123456789abcdefABCDEF":
            i += 1
        return _from_hex(text[pos + 2:i], table), i

    if ch in "bB" and text.startswith("'", pos + 1):
        i = pos + 2
        j = text.index("'", i)
        bits = text[i:j]
        if bits and set(bits) <= {"0", "1"}:
            return str(int(bits, 2)), j + 1
        raise error(table, None, None, f"malformed bit literal b'{bits}'")

    if text.startswith("_binary", pos) or text.startswith("_utf8", pos) or text.startswith("_latin1", pos):
        i = pos
        while i < n and text[i] not in " '":
            i += 1
        while i < n and text[i] == " ":
            i += 1
        return _parse_value(text, i, table)

    # Bare token: number, NULL, or a keyword such as CURRENT_TIMESTAMP.
    i = pos
    depth = 0
    while i < n:
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            if depth == 0:
                break
            depth -= 1
        elif c == "," and depth == 0:
            break
        i += 1
    token = text[pos:i].strip()
    if token == "":
        raise error(table, None, None, "empty value in INSERT tuple")
    if token.upper() == "NULL":
        return None, i
    return token, i


def _from_hex(hexdigits: str, table: str) -> str:
    """Decode a hex literal (--hex-blob output) to text.

    Kept as text, like everything else. A blob that is not valid UTF-8 is an
    error naming the table rather than a mojibake string quietly written to
    the target.
    """
    if len(hexdigits) % 2:
        hexdigits = "0" + hexdigits
    try:
        raw = bytes.fromhex(hexdigits)
    except ValueError as exc:
        raise error(table, None, None, f"malformed hex literal: {exc}")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise error(
            table, None, None,
            f"hex/blob value is not valid UTF-8 ({exc}); this column needs an "
            "explicit bytea decision before it can be carried",
        )


def _iter_tuples(text: str, start: int, table: str) -> Iterator[list[object]]:
    """Yield each `(...)` tuple of an INSERT's VALUES list, one at a time."""
    i = start
    n = len(text)
    while True:
        while i < n and text[i] in " \t\r\n,":
            i += 1
        if i >= n:
            return
        if text[i] == ";":
            return
        if text[i] != "(":
            trailing = text[i:i + 40].strip()
            if trailing.upper().startswith("ON DUPLICATE"):
                return
            raise error(table, None, None,
                        f"expected '(' in VALUES list, found {trailing!r}")
        i += 1
        values: list[object] = []
        while True:
            value, i = _parse_value(text, i, table)
            values.append(value)
            while i < n and text[i] in " \t\r\n":
                i += 1
            if i >= n:
                raise error(table, None, None, "unterminated VALUES tuple")
            if text[i] == ",":
                i += 1
                continue
            if text[i] == ")":
                i += 1
                break
            raise error(table, None, None,
                        f"expected ',' or ')' in VALUES tuple, found {text[i]!r}")
        yield values


def _insert_columns(stmt_text: str) -> list[str] | None:
    m = _INSERT_RE.match(stmt_text.lstrip())
    if not m or not m.group(3):
        return None
    inner = m.group(3).strip()[1:-1]
    return [_unquote_ident(p) for p in _split_top_level(inner) if p.strip()]


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------


@dataclass
class SchemaScan:
    """Result of the DDL pass."""

    tables: dict[str, Table] = field(default_factory=dict)
    routines: list[str] = field(default_factory=list)   # skipped, but counted
    insert_tables: list[str] = field(default_factory=list)
    #: The verbatim `CREATE TABLE` text per table. Kept because the DDL
    #: translator parses MySQL DDL source, not `Table` objects — handing it
    #: the original text means the translation sees exactly what the live
    #: server declared, not this module's reading of it.
    ddl_text: dict[str, str] = field(default_factory=dict)


def scan_schema(path: str, *, encoding: str = "utf-8") -> SchemaScan:
    """Pass 1: every CREATE TABLE, plus a note of what was skipped.

    Also records which tables have INSERT statements, so a table that is
    dumped with data but no DDL (or vice versa) is visible in the report.
    """
    scan = SchemaScan()
    seen_inserts: set[str] = set()
    for stmt in iter_statements(path, encoding=encoding):
        if stmt.kind == "create_table":
            table = parse_create_table(stmt.text, line=stmt.line)
            if table.name in scan.tables:
                raise error(table.name, None, None,
                            f"line {stmt.line}: table defined twice in the dump")
            scan.tables[table.name] = table
            scan.ddl_text[table.name] = stmt.text.rstrip().rstrip(";") + ";"
        elif stmt.kind == "routine":
            m = _ROUTINE_RE.search(stmt.text)
            kind = m.group(1).lower() if m else "routine"
            scan.routines.append(f"line {stmt.line}: {kind}")
        elif stmt.kind == "insert":
            if stmt.table and stmt.table not in seen_inserts:
                seen_inserts.add(stmt.table)
                scan.insert_tables.append(stmt.table)
    return scan


def read_schema(path: str, *, encoding: str = "utf-8") -> dict[str, Table]:
    """Pass 1, convenience form: `{table_name: Table}` in dump order."""
    return scan_schema(path, encoding=encoding).tables


def count_rows(
    path: str,
    tables: dict[str, Table] | None = None,
    *,
    only: Iterable[str] | None = None,
    encoding: str = "utf-8",
) -> dict[str, int]:
    """Count the rows a dump holds per table, without building a `Row` for each.

    WHY THIS EXISTS
        "Count in, count out" has to include the tables that do NOT carry, or a
        dropped table's report line reads `rows_in: 0, rows_dropped: 0` and three
        very different situations become indistinguishable: the policy dropped
        12,431 houses, the table was empty, or the parser never saw the table at
        all. The last one reconciles clean, which is exactly the failure this
        tool exists to refuse.

        Every tuple is still parsed (the value parser is what knows where a tuple
        ends when a player's name contains a `)`), and the value count is still
        checked against the column count — a short row is a parse failure whether
        or not the rows are being kept. What is skipped is building the dict, so
        the cost is one extra pass over the dump's data, not one extra copy of it
        in memory.

    Usage:
        counts = dump.count_rows("live.sql", scan.tables, only=["houses", "log"])
    """
    counts: dict[str, int] = {}
    for row in iter_rows(path, tables, only=only, encoding=encoding, values=False):
        counts[row.table] = counts.get(row.table, 0) + 1
    return counts


def iter_rows(
    path: str,
    tables: dict[str, Table] | None = None,
    *,
    only: Iterable[str] | None = None,
    encoding: str = "utf-8",
    values: bool = True,
) -> Iterator[Row]:
    """Pass 2: stream every INSERTed row as a `Row` with text values.

    `tables` supplies column names for INSERTs written without an explicit
    column list (mysqldump's default). If omitted, CREATE TABLEs seen earlier
    in the same pass are used — which works because mysqldump emits a table's
    DDL immediately before its data.

    `only` restricts the stream to named tables; skipped tables are not parsed
    at all, which is the cheap way to avoid touching hundreds of MB of rows
    that the rules say cannot carry.

    `values=False` yields a `Row` with an EMPTY values dict — the tuple is still
    parsed and its width still checked, but nothing is retained. It exists for
    `count_rows`; nothing else should use it, because a Row with no values is a
    row nothing can be decided from.
    """
    known: dict[str, Table] = dict(tables) if tables else {}
    wanted = set(only) if only is not None else None
    values_wanted = values          # the loop below rebinds `values` per tuple
    for stmt in iter_statements(path, encoding=encoding):
        if stmt.kind == "create_table" and not tables:
            table = parse_create_table(stmt.text, line=stmt.line)
            known[table.name] = table
            continue
        if stmt.kind != "insert":
            continue
        name = stmt.table or ""
        if wanted is not None and name not in wanted:
            continue
        columns = _insert_columns(stmt.text)
        if columns is None:
            table_def = known.get(name)
            if table_def is None:
                raise error(
                    name, None, None,
                    f"line {stmt.line}: INSERT for a table with no CREATE TABLE "
                    "in the dump and no explicit column list; column names are "
                    "unknowable, so the rows cannot be read by name",
                )
            columns = table_def.column_names()
        m = _INSERT_RE.match(stmt.text.lstrip())
        assert m is not None  # guaranteed by kind == "insert"
        for values in _iter_tuples(stmt.text.lstrip(), m.end(), name):
            if len(values) != len(columns):
                raise error(
                    name, None, None,
                    f"line {stmt.line}: row has {len(values)} values but "
                    f"{len(columns)} columns ({', '.join(columns)}); refusing "
                    "to align them positionally",
                )
            yield Row(table=name,
                      values=dict(zip(columns, values)) if values_wanted else {})


# --------------------------------------------------------------------------
# CLI (inspection only — the migration itself lives in etl.py)
# --------------------------------------------------------------------------


def _main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python3 -m pgmigrate.dump",
        description="Inspect a mysqldump file (schema, row counts). Read-only.",
    )
    ap.add_argument("--dump", required=True, help="path to the mysqldump file (.sql or .sql.gz)")
    ap.add_argument("--encoding", default="utf-8")
    ap.add_argument("--schema", action="store_true", help="print the parsed schema")
    ap.add_argument("--counts", action="store_true", help="count rows per table (full pass)")
    args = ap.parse_args(argv)

    try:
        scan = scan_schema(args.dump, encoding=args.encoding)
    except TransformError as exc:
        print(exc.issue.format(), file=sys.stderr)
        return 2

    print(f"tables: {len(scan.tables)}")
    if scan.routines:
        print(f"skipped routines/triggers/views/events: {len(scan.routines)}")
        for note in scan.routines:
            print(f"  - {note}")
    missing_ddl = [t for t in scan.insert_tables if t not in scan.tables]
    if missing_ddl:
        print("tables with data but no CREATE TABLE: " + ", ".join(missing_ddl))

    if args.schema:
        for table in scan.tables.values():
            print(f"\n{table.name}  (pk: {', '.join(table.primary_key) or 'none'})")
            for col in table.columns:
                bits = [col.mysql_type, "NULL" if col.nullable else "NOT NULL"]
                if col.default is not None:
                    bits.append(f"default {col.default}")
                if col.extra:
                    bits.append(col.extra)
                print(f"    {col.name:<28} {'  '.join(bits)}")
            for idx_name, cols, unique in table.indexes:
                print(f"    {'UNIQUE ' if unique else ''}KEY {idx_name} ({', '.join(cols)})")

    if args.counts:
        try:
            counts = count_rows(args.dump, scan.tables, encoding=args.encoding)
        except TransformError as exc:
            print(exc.issue.format(), file=sys.stderr)
            return 2
        print()
        for name in sorted(counts):
            print(f"{counts[name]:>12}  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
