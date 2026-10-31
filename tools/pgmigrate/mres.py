"""mres — the source game's bespoke array codec, decoded once so it never ships again.

PURPOSE
    Turn the source database's custom array-in-TEXT encoding into ordinary Python
    values, ready to be written as JSONB into the target PostgreSQL database.
    `to_json()` is the ETL's entry point. `decode()`/`encode()` exist to mirror
    and test the original implementations.

WHY THIS EXISTS
    This is the highest-risk module in the harness. The columns it reads —
    `houses.vinv`, `houses.pinv`, `houses.keyholders`, the suite equivalents and
    `storage_vault` — are player *property*, and a decode failure in this codec
    has already destroyed stored items in production at least once
    (postgres_plan.md §7.1). The failure is silent by construction: the original
    reader returns an empty array on a value it cannot parse, the caller reads
    "empty" as "this container has nothing in it", and the next write persists
    that emptiness over the real contents.

    The codec is implemented four times in three languages, and the plan's
    decision is to end that: transcode at the door, once, in this module, and
    write JSONB from here on (§7.1). Nothing downstream of the ETL ever sees the
    old encoding again — which is why `encode()` is a test and verification
    instrument, not part of the output path. **The ETL must never emit the old
    encoding.**

    Consequently this module refuses rather than guesses. `decode_strict()`
    separates "this value is empty" from "this value cannot be parsed" and raises
    on the latter, naming table, column and primary key. That distinction is the
    single control that prevents an unreadable inventory from being carried across
    as an empty one.

Usage:
    >>> import mres
    >>> mres.decode('"[``arifle_MX_F``,3]"')
    ['arifle_MX_F', 3]
    >>> mres.to_json('"[]"')
    []
    >>> mres.to_json(None) is None
    True
    >>> mres.encode(['arifle_MX_F', 3])
    '"[``arifle_MX_F``,3]"'

STATUS
    **Unvalidated against real data.** No live dump exists in this repository and
    this module has never met one. The tests below are hand-derived from the three
    source implementations, not from production values. Every claim here is a
    claim about the source code, not about the data.

================================================================================
THE ENCODING, PRECISELY
================================================================================

The encoder is `DB_fnc_mresArray`; the reader is `DB_fnc_mresToArray`. Encoding a
value `x` is four steps:

1.  ``str(str(x))`` — the double wrap.

    The engine's `str` renders a value as its source literal, and rendering a
    *string* wraps it in double quotes and doubles any double quote inside it. So
    the first `str` turns the array `["a","b"]` into the 9-character string
    ``["a","b"]``; the second `str` turns that string into the 13-character string
    ``"[""a"",""b""]"``.

    The outer wrap is deliberate: it is what makes the column read back as a
    string rather than as something the reader's `call compile` would evaluate.
    The inner doubling is the artifact of the second `str`, and undoing it is what
    the decoder's un-double step is for.

2.  **Delete every backtick (byte 96) — a security control, see below.**

3.  **Substitute interior double quotes for backticks.** Every ``"`` (byte 34)
    *except the first and last character* becomes a backtick (byte 96). The first
    and last characters are the outer wrap from step 1 and stay as ``"``.

4.  Store the result as TEXT.

So the delimiters, and the only characters with meaning to this codec, are:

    ``"``  (34)  the outer wrap — first and last byte only
    `` ` `` (96)  an interior double quote, doubled by step 1's second `str`
    ``[ ] ,``     structure, inherited from the engine's array literal syntax

Decoding reverses it: backtick → ``"``, strip the outer wrap if present,
un-double ``""`` → ``"``, then parse. The resulting text is a JSON document for
every value this codec is used on — arrays of numbers, of strings, and of nested
arrays of both — which is why all three reference decoders finish with a JSON
parse rather than an engine-syntax parser. That equivalence has one hole, and it
is documented under DIVERGENCES below.

WHY STEP 2 DELETES A BYTE FROM SOURCE DATA
    The backtick is this codec's delimiter, and the codec has no escape for it.
    A backtick present in *source* data — a gang name, a loadout label, any free
    text a player controls — survives the encode untouched and is then turned into
    a double quote by the decoder. That quote closes the string literal early, and
    the value is subsequently handed to a `call compile` on the consuming side:
    the remainder of the player's text is then executed as code on the server.

    The encoder therefore deletes the byte outright rather than escaping it. It is
    lossy on purpose. The load-bearing comment in the original states the
    justification plainly: legitimate data never contains a backtick, and the
    alternative is remote code execution on the server.

    This module reproduces the deletion in `encode()`. It matters for the ETL in
    one direction only: a backtick appearing in a *source* value is evidence that
    the row predates the control or bypassed it, and `decode()` will produce a
    stray quote from it. `decode_strict()` will then usually fail to parse, which
    is the correct outcome — that row wants a human.

================================================================================
THE THREE SOURCES, AND WHERE THEY DISAGREE
================================================================================

Reconciled from:

  A. ``server/life_server/core/DB/fn_mresArray.sqf`` (encoder) and
     ``fn_mresToArray.sqf`` (decoder) — the originals, carrying comments about
     bugs already hit in production.
  B. ``loonybot/enrique.py`` lines 84-115 — a Python port whose comment states it
     is **validated byte-identical** to A on real `houses.vinv` data. **This is
     the reference implementation and this module follows it**, except where noted.
  C. ``website/src/lib/arma.ts`` and ``website/src/lib/houseInv.ts`` — a
     TypeScript third implementation.

All three agree on the wire format. They agree on every well-formed value. They
disagree at the edges, as follows.

DIVERGENCE 1 — the SQF decoder reads a *different input* from the other two.
    A's decoder does not see the raw column. The query layer `call compile`s the
    whole result set first, which consumes the outer wrap. A therefore receives
    ``str(x)`` with its quotes still doubled, and re-wraps it in quotes before
    compiling, to un-double them. B and C read the raw column text and so must
    strip the outer wrap themselves.

    This is not a behavioural disagreement, it is a different starting point. This
    module reads the raw dump text, i.e. B and C's input.

DIVERGENCE 2 — backtick → which quote? (a fixed production bug, recorded here so
it is not reintroduced.)
    An earlier version of A mapped backtick to a *single* quote (39) instead of a
    double quote (34). Empty strings encode as ``""``, so they became ``''``, and
    the decode of any array containing an empty string returned nil — which the
    game read as "no gear", handing every player the default loadout on every
    spawn. Non-empty strings and numbers round-tripped either way, which is why
    only gear was affected and why it took so long to find.

    All three current sources map to the double quote. The tests below lock the
    empty-string cases specifically.

DIVERGENCE 3 — empty input.
    A returns `[]` for an empty string (an explicit early exit).
    B returns `None` (the JSON parse of an empty document fails).
    C's `decodeArma` returns `null`, but its `decodeArray` wrapper coerces to `[]`,
    and `decodeHouseInv` treats `""` and `"[]"` as an explicitly empty container.

    This module keeps B's behaviour in `decode()`, and follows A in `to_json()` /
    `decode_strict()`: an empty or whitespace-only column decodes to `[]`, because
    `[]` is what the game itself reads there. See EMPTY_VALUES.

DIVERGENCE 4 — single vs paired backtick replacement.
    B and C's `arma.ts` replace *each* backtick with a quote and then un-double.
    C's `houseInv.ts` replaces backtick *pairs* with a single quote and does not
    un-double. Identical on well-formed data (interior quotes are always doubled
    before substitution, so backticks always occur in pairs); they differ only on
    a value with an odd number of backticks, which means corruption either way.
    This module follows B.

DIVERGENCE 5 — strings containing a double quote. **The important one.**
    A's encoder doubles interior quotes (the engine's `str` does it), producing
    ``["a""b"]`` inside the wrap. B's `_sqf` does **not** — it emits ``["a"b"]``,
    which is not a valid literal in either syntax. So A and B produce different
    bytes for the same input, and *neither* result survives B's or C's decoder,
    because JSON has no doubled-quote escape: the parse fails and all three
    decoders report "unparseable".

    Consequences, both deliberate:
      * `encode()` **raises** on a string containing a double quote rather than
        reproducing B's provably-corrupt output. This is the one place this module
        knowingly departs from the reference, on the grounds that the reference
        emits a value nothing can read.
      * `decode()` returns None for such a value and `decode_strict()` raises. It
        does not attempt a repair. A source row like this needs a human decision,
        and quietly inventing one would be exactly the class of silent substitution
        this module exists to prevent.

    Apostrophes are *not* affected — the engine's `str` does not escape them — so
    `O'Brien` round-trips cleanly. (Names mangled by the historical input
    sanitizers arrive already mangled and are carried as stored; repairing them
    here would make reconciliation lie.)

DIVERGENCE 7 — backslashes. **The silent one, and it is not in any source comment.**
    Found by the randomised round-trip property test in `test_mres.py`, not by
    reading the three implementations, which is why it is spelled out here.

    The engine's string literals have **no** backslash escape: a backslash is an
    ordinary character, and `str` emits it unchanged. JSON's string literals do
    have one. So the final JSON parse in all three reference decoders
    *reinterprets* it, and does so without any error:

        source value   'a\\tb'          (4 characters: a, backslash, t, b)
        encoded        "[``a\\tb``]"
        decoded        'a\tb'           (3 characters: a, TAB, b)

    Four characters in, three out, no exception, no warning. That is the exact
    shape of the failure this module exists to prevent, and it survives in the
    reference implementation today.

    A raw control character (a literal tab or newline inside a source string) is
    the less dangerous half of the same mismatch: JSON forbids them unescaped, so
    the parse fails and the value is at least reported.

    Handling here:
      * `decode()` keeps the reference's behaviour, mutation included, because it
        is the reference mirror and must stay comparable.
      * `decode_strict()` / `to_json()` **raise** when the unwrapped text contains
        a backslash. This is not a guess about the data — the source syntax has no
        escapes, so the backslash is unambiguously literal — but repairing it
        silently would mean this module quietly disagreeing with every other
        decoder about what a row contains. A human decides.
      * `encode()` refuses backslashes and raw control characters, for the same
        reason it refuses double quotes: the reference emits a value that is
        either unreadable or read as something else.

DIVERGENCE 6 — backtick deletion on encode.
    A deletes byte 96 from the source (the security control above). B does not.
    This module follows **A**, because B's omission is not a validated behaviour —
    it is untested territory (legitimate data has no backticks, so the
    byte-identical validation never exercised it) and the consequence of getting
    it wrong is server-side code execution rather than a wrong value.

NUMBERS
    `decode()` parses numbers exactly as the reference does, via `json.loads`,
    which yields `float` for anything written with a decimal point or an exponent.
    `to_json()` does not: it parses the numeric literal exactly and returns an
    `int` whenever the literal denotes a whole number, including the
    scientific-notation forms the engine emits for large values (``1e+015``).

    This matters because the source engine's only numeric type is a 32-bit float,
    exact to 2**24 = 16,777,216, and `DB_fnc_numberSafe` exists solely to stop it
    writing scientific notation into an integer column (postgres_plan.md §7.3).
    Values above that range are already stored as whole numbers in text form; a
    float round-trip in *this* module would round them a second time. A
    non-integral literal is kept as `float` and is the only lossy numeric path
    here — currency never travels through this codec, and must not be made to.
"""

from __future__ import annotations

import decimal
import json

try:  # package import (python3 -m pgmigrate ...)
    from .model import Issue, TransformError
except ImportError:  # direct import / running the tests in this directory
    from model import Issue, TransformError


__all__ = [
    "BACKTICK",
    "QUOTE",
    "BACKSLASH",
    "DELIMITER_BYTE",
    "EMPTY_VALUES",
    "decode",
    "decode_strict",
    "encode",
    "to_json",
    "is_empty",
    "diagnose",
]


QUOTE = '"'
BACKTICK = "`"
BACKSLASH = "\\"
#: The byte the encoder deletes from source data. See "WHY STEP 2 DELETES A BYTE".
DELIMITER_BYTE = 96

#: Column texts that mean "this container is empty", as opposed to "this value
#: could not be read". The distinction is the whole point of `decode_strict`.
#: An empty column is what a `DEFAULT ''` produces and what the game's own reader
#: turns into `[]` on its explicit early-exit path.
EMPTY_VALUES = ("", "[]", '"[]"')


# --------------------------------------------------------------------------- #
# decode
# --------------------------------------------------------------------------- #


def _unwrap(s: str) -> str:
    """Apply the textual half of the decode: backticks, outer wrap, un-double.

    Byte-for-byte the reference's sequence (`loonybot/enrique.py:84-94`), kept as
    one function so `decode`, `to_json` and `diagnose` cannot drift apart.
    """
    text = s.replace(BACKTICK, QUOTE)  # backtick -> quote (all of them)
    if len(text) >= 2 and text.startswith(QUOTE) and text.endswith(QUOTE):
        text = text[1:-1]  # strip the outer str() wrap
    return text.replace(QUOTE + QUOTE, QUOTE)  # un-double interior quotes


def _exact_number(literal: str) -> object:
    """Parse a JSON numeric literal without inventing a float.

    Returns `int` when the literal denotes a whole number — including the
    ``1e+015`` forms the source engine emits — and `float` otherwise. See NUMBERS
    in the module docstring.
    """
    value = decimal.Decimal(literal)
    if value == value.to_integral_value():
        return int(value)
    return float(value)


def _parse(text: str, exact_numbers: bool) -> object:
    """JSON-parse the unwrapped text. Raises ValueError if it is not parseable."""
    if exact_numbers:
        return json.loads(text, parse_int=int, parse_float=_exact_number)
    return json.loads(text)


def decode(s: str | None) -> object:
    """Decode one column value, exactly as the reference implementation does.

    Returns the decoded value, or `None` if the value is `None` or does not parse.

    This function reproduces the reference's *silent* failure mode on purpose, so
    the two can be compared. **The ETL must not call it.** Use `to_json()`, which
    refuses instead of returning `None`, because "did not parse" reaching a caller
    as an empty-ish value is the exact mechanism that has destroyed player
    property before.
    """
    if s is None:
        return None
    if not isinstance(s, str):
        raise TypeError("mres.decode expects str or None, got %r" % (type(s),))
    try:
        return _parse(_unwrap(s), exact_numbers=False)
    except (ValueError, RecursionError):
        # The reference catches bare `Exception` here. Narrowed deliberately: any
        # other exception is a bug in this module and must not be swallowed into
        # a `None` that a caller will read as "empty".
        return None


def is_empty(s: str | None) -> bool:
    """True when the column text means "empty container", not "unreadable".

    `None` is *not* empty — a SQL NULL is carried across as NULL, and conflating
    the two would invent a container the source never had.
    """
    if s is None:
        return False
    if not isinstance(s, str):
        raise TypeError("mres.is_empty expects str or None, got %r" % (type(s),))
    return s.strip() in EMPTY_VALUES


def decode_strict(
    s: str | None,
    *,
    table: str = "<unknown table>",
    column: str | None = None,
    pk: object | None = None,
) -> object:
    """Decode, distinguishing "empty" from "unparseable" and raising on the latter.

    Returns:
        `None`  for a SQL NULL (carried across as NULL).
        `[]`    for an empty column — matching the game's own reader, which has an
                explicit early exit for it.
        the decoded value otherwise.

    Raises:
        TransformError: the value is non-empty and cannot be parsed. The
            `Issue` names the table, column and primary key.

    The TypeScript carries the rule this enforces: a non-empty value that fails to
    parse must **never** be treated as empty, because a writer that reads it as
    empty overwrites — and wipes — storage it could not read. Refusing the whole
    run is cheaper than discovering that afterwards.
    """
    if s is None:
        return None
    if not isinstance(s, str):
        raise TransformError(
            Issue(
                "error",
                table,
                column,
                pk,
                "expected TEXT for an mres column, got %s" % (type(s).__name__,),
            )
        )
    if is_empty(s):
        return []

    text = _unwrap(s)

    # DIVERGENCE 7. Must be checked BEFORE the parse: with a backslash present the
    # parse usually succeeds and returns a value that differs from the source, so
    # there is no exception to catch and nothing downstream would ever notice.
    if BACKSLASH in text:
        raise TransformError(
            Issue(
                "error",
                table,
                column,
                pk,
                "mres value contains a backslash. The source engine's string "
                "literals have no backslash escape, but JSON's do, so decoding "
                "this would silently REWRITE the value (e.g. 'a\\\\tb', 4 "
                "characters, becomes 'a<TAB>b', 3) with no error. Refusing to "
                "transcode a value this module would change. Raw value: %r" % (s,),
            )
        )

    try:
        return _parse(text, exact_numbers=True)
    except (ValueError, RecursionError) as exc:
        raise TransformError(
            Issue(
                "error",
                table,
                column,
                pk,
                "mres value is non-empty but does not decode (%s); %s. "
                "Refusing to carry it as empty — that would overwrite the "
                "player's stored contents. Raw value: %r"
                % (exc.__class__.__name__, diagnose(s), s),
            )
        ) from exc


def to_json(
    s: str | None,
    *,
    table: str = "<unknown table>",
    column: str | None = None,
    pk: object | None = None,
) -> object:
    """The ETL entry point: source column text in, JSONB-ready value out.

    Thin alias for `decode_strict` — named for the job it does in the pipeline, so
    that a call site reads as "transcode this column" rather than "parse this
    string". Numbers come back exact (see NUMBERS); the result contains only
    `None`, `bool`, `int`, `float`, `str` and `list`, all of which `json.dumps`
    handles natively.

    Never returns the old encoding, and there is no option to.
    """
    return decode_strict(s, table=table, column=column, pk=pk)


def diagnose(s: str | None) -> str:
    """One-line human explanation of why a value did not decode. Diagnostic only.

    Produces no value and repairs nothing — it exists so the operator reading a
    failed run's output can tell a corrupted row from a known-hard one without
    hand-decoding the text.
    """
    if s is None:
        return "value is NULL"
    if not isinstance(s, str):
        return "value is %s, not text" % (type(s).__name__,)
    if is_empty(s):
        return "value is empty"

    notes: list[str] = []
    if not (s.startswith(QUOTE) and s.endswith(QUOTE)):
        notes.append("no outer str() wrap")
    if s.count(BACKTICK) % 2:
        notes.append(
            "odd number of backticks (%d) — a source backtick survived the "
            "encoder's deletion, or the text is truncated" % (s.count(BACKTICK),)
        )
    text = _unwrap(s)
    if BACKSLASH in text:
        notes.append(
            "contains a backslash — the source engine has no backslash escape "
            "but JSON does, so decoding would silently change the value "
            "(see DIVERGENCE 7)"
        )
    control = next((c for c in text if ord(c) < 0x20), None)
    if control is not None:
        notes.append(
            "contains the raw control character %r, which JSON forbids inside a "
            "string" % (control,)
        )
    if QUOTE + QUOTE in text:
        notes.append(
            "contains a doubled double-quote after un-doubling — this is an "
            "engine-escaped quote inside a string, which JSON cannot express "
            "(see DIVERGENCE 5); the source value contains a literal '\"'"
        )
    if not notes:
        notes.append("unwrapped text is not a valid array literal")
    return "; ".join(notes)


# --------------------------------------------------------------------------- #
# encode  —  test and verification instrument ONLY
# --------------------------------------------------------------------------- #


def _refuse(value: str, path: str, what: str, why: str) -> None:
    """Raise for a string `encode` cannot represent losslessly. Never returns."""
    raise TransformError(
        Issue(
            "error",
            "<mres.encode>",
            path or None,
            None,
            "cannot encode a string containing %s (%r): %s. Encoding is a test "
            "and verification instrument here; the ETL never emits this encoding."
            % (what, value, why),
        )
    )


def _sqf(v: object, *, path: str = "") -> str:
    """Render a value as the engine's array literal, as the reference's `_sqf` does.

    `bool` is checked before `int` deliberately: `bool` is a subclass of `int` in
    Python, and the engine's literals are `true`/`false`, not `1`/`0`. Getting
    that order wrong is postgres_plan.md §11.3 in miniature.
    """
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        # Three characters this codec cannot represent losslessly. In each case the
        # reference emits a value that is either unreadable or read back as
        # something else, so this module refuses rather than reproducing it.
        if QUOTE in v:
            _refuse(v, path, "a double quote", "no decoder can read the result "
                    "(JSON has no doubled-quote escape) — see DIVERGENCE 5")
        if BACKSLASH in v:
            _refuse(v, path, "a backslash", "the result decodes to a DIFFERENT "
                    "string with no error, because JSON has a backslash escape "
                    "and the source engine does not — see DIVERGENCE 7")
        control = next((c for c in v if ord(c) < 0x20), None)
        if control is not None:
            _refuse(v, path, "the raw control character %r" % (control,),
                    "JSON forbids unescaped control characters, so the result "
                    "does not parse — see DIVERGENCE 7")
        return QUOTE + v + QUOTE
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else repr(v)
    if isinstance(v, list):
        return "[" + ",".join(
            _sqf(x, path="%s[%d]" % (path, i)) for i, x in enumerate(v)
        ) + "]"
    raise TransformError(
        Issue(
            "error",
            "<mres.encode>",
            path or None,
            None,
            "no mres representation for %s" % (type(v).__name__,),
        )
    )


def encode(v: object) -> str:
    """Encode a value into the source game's codec.

    **Not part of the ETL's output path.** The migration transcodes to JSONB and
    never writes this encoding again (postgres_plan.md §7.1). `encode` exists so
    the round-trip property tests below can assert against the wire format, and so
    a suspicious source value can be reproduced and compared byte for byte.

    Reproduces the encoder's backtick deletion (DIVERGENCE 6): any backtick in the
    input is dropped, because it is this codec's delimiter and there is no escape
    for it. That is lossy, and it is the security control described in the module
    docstring, not an oversight.
    """
    body = _sqf(v)
    # The security control: delete byte 96 from the source before it can become a
    # delimiter. Applied to the rendered body, which is where every source string
    # now lives; the engine's own `str` never emits a backtick, so this is exactly
    # the original's `_array - [96]`.
    body = body.replace(BACKTICK, "")
    wrapped = QUOTE + body.replace(QUOTE, QUOTE + QUOTE) + QUOTE
    # Interior quotes (indices 1 .. len-2) become backticks; the outer wrap stays.
    return wrapped[0] + wrapped[1:-1].replace(QUOTE, BACKTICK) + wrapped[-1]
