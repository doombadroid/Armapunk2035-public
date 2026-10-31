"""Tests for `mres` — the source game's array codec.

WHY THIS EXISTS
    The columns this codec reads are player property, and the recorded production
    failures were all *silent*: a value that failed to decode came back as empty,
    the caller believed the container was empty, and the next write destroyed the
    contents. These tests pin the cases the original source comments say actually
    broke — empty strings inside arrays, arrays of empty strings, the backtick
    substitution — plus the ones that will break next: doubled quotes, the
    delimiter byte in source data, and integers past the source engine's
    float-exact range.

    They also assert `mres.decode` against a verbatim copy of the reference
    implementation (`loonybot/enrique.py:84-115`) over a corpus, so "matches the
    reference exactly" is a checked claim rather than a comment.

    What they cannot do is validate against production. No live dump exists in
    this repository. Every expected value here is hand-derived from the three
    source implementations; the first real dump is still the first real test.

Usage:
    python3 -m unittest discover -s tools/pgmigrate -p 'test_*.py' -v
    python3 tools/pgmigrate/test_mres.py
"""

from __future__ import annotations

import json
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mres  # noqa: E402
from model import TransformError  # noqa: E402


# --------------------------------------------------------------------------- #
# The reference implementation, copied verbatim from loonybot/enrique.py:84-115.
# Present so the tests can diff against it rather than paraphrase it. Do not
# "improve" it — its value is that it is unchanged.
# --------------------------------------------------------------------------- #


def ref_decode(s):
    if s is None:
        return None
    s = s.replace("`", '"')
    if s.startswith('"') and s.endswith('"'):
        s = s[1:-1]
    s = s.replace('""', '"')
    try:
        return json.loads(s)
    except Exception:  # noqa: BLE001 - verbatim copy of the reference
        return None


def ref_sqf(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else repr(v)
    if isinstance(v, list):
        return "[" + ",".join(ref_sqf(x) for x in v) + "]"
    raise TypeError(v)


def ref_encode(arr):
    s = '"' + ref_sqf(arr).replace('"', '""') + '"'
    ch = list(s)
    for i in range(1, len(ch) - 1):
        if ch[i] == '"':
            ch[i] = "`"
    return "".join(ch)


#: Values that contain no backtick and no double quote — the domain on which all
#: three source implementations agree, and on which the round trip must be exact.
SAFE_CORPUS = [
    [],
    [0],
    [1, 2, 3],
    ["arifle_MX_F"],
    ["a", "b"],
    [""],                                   # empty string inside an array
    ["", "", ""],                           # array of empty strings
    ["U_B_CombatUniform_mcam", "", "", ""],  # a loadout with empty slots
    [["arifle_MX_F", 3], ["30Rnd_65x39_caseless_mag", 12]],
    [[["cannas_0", 5], ["cannai_3", 2]], 7],  # house vinv shape: [[items], total]
    [[[]], []],                             # nested empties
    [True, False],
    ["O'Brien"],                            # apostrophe: unaffected by the codec
    ["it's a trap", "don't"],
    [1.5, -2.25],
    [16777217],                             # 2**24 + 1: past the engine's exact range
    [9007199254740993],                     # 2**53 + 1: past a float's exact range
    [-1, 0, 1],
    ["mixed", 1, True, ["nested", [2]]],
]


class TestWireFormat(unittest.TestCase):
    """Hand-derived expected bytes. These lock the encoding itself."""

    def test_empty_array(self):
        self.assertEqual(mres.encode([]), '"[]"')

    def test_numbers_have_no_interior_quotes(self):
        self.assertEqual(mres.encode([1, 2]), '"[1,2]"')

    def test_strings_become_double_backticks(self):
        # str(str(["a","b"])) is "[""a"",""b""]"; each interior quote -> backtick,
        # so each source quote (already doubled) shows up as two backticks.
        self.assertEqual(mres.encode(["a", "b"]), '"[``a``,``b``]"')

    def test_outer_wrap_is_a_real_quote_not_a_backtick(self):
        wire = mres.encode(["a"])
        self.assertEqual(wire[0], '"')
        self.assertEqual(wire[-1], '"')
        self.assertNotIn("`", wire[0] + wire[-1])

    def test_empty_string_is_four_backticks(self):
        # The DIVERGENCE 2 bug: "" -> """" -> ```` . Mapping to a single quote
        # instead produced '''' and killed the whole decode.
        self.assertEqual(mres.encode([""]), '"[````]"')
        self.assertEqual(mres.decode('"[````]"'), [""])

    def test_house_inventory_shape(self):
        self.assertEqual(
            mres.encode([[["cannas_0", 5]], 5]),
            '"[[[``cannas_0``,5]],5]"',
        )

    def test_booleans_render_as_engine_literals(self):
        # bool before int: True must not render as 1 (postgres_plan.md §11.3).
        self.assertEqual(mres.encode([True, False]), '"[true,false]"')
        self.assertEqual(mres.decode('"[true,false]"'), [True, False])


class TestRoundTrip(unittest.TestCase):
    """decode(encode(v)) == v across the corpus, per value and as a property."""

    def test_round_trip_safe_corpus(self):
        for value in SAFE_CORPUS:
            with self.subTest(value=value):
                wire = mres.encode(value)
                self.assertEqual(mres.decode(wire), value)
                self.assertEqual(mres.to_json(wire), value)

    def test_encode_is_stable(self):
        for value in SAFE_CORPUS:
            with self.subTest(value=value):
                self.assertEqual(mres.encode(value), mres.encode(value))

    def test_decode_encode_decode_is_stable(self):
        """Second round trip is a fixed point — no drift in the quote doubling."""
        for value in SAFE_CORPUS:
            with self.subTest(value=value):
                wire = mres.encode(value)
                self.assertEqual(mres.encode(mres.decode(wire)), wire)

    def test_bare_values_without_the_outer_wrap_also_decode(self):
        """Some columns are stored bare ([...]), some wrapped ("[...]")."""
        self.assertEqual(mres.decode("[1,2]"), [1, 2])
        self.assertEqual(mres.decode("[``a``]"), ["a"])
        self.assertEqual(mres.to_json("[``a``,``b``]"), ["a", "b"])


class TestRoundTripProperty(unittest.TestCase):
    """Randomised round trip over the safe domain. Seeded, so failures reproduce.

    Generates only values the codec can represent losslessly: no double quote
    (DIVERGENCE 5), no backtick (the encoder deletes it by design), no backslash
    and no control character (DIVERGENCE 7). Each of those is covered explicitly
    elsewhere; this exists to find the shapes a hand-written corpus does not think
    of — and it earned its place, because DIVERGENCE 7 was found here and appears
    in none of the three source implementations' comments.
    """

    ALPHABET = "abzAZ09_ '.-[],:{}/"

    def _value(self, rng, depth=0):
        kind = rng.randrange(0, 8 if depth < 3 else 5)
        if kind == 0:
            return ""
        if kind == 1:
            return "".join(rng.choice(self.ALPHABET) for _ in range(rng.randrange(0, 12)))
        if kind == 2:
            return rng.randrange(-(2 ** 40), 2 ** 40)
        if kind == 3:
            return rng.choice([True, False])
        if kind == 4:
            return rng.randrange(-(2 ** 62), 2 ** 62)  # past float-exact range
        return [self._value(rng, depth + 1) for _ in range(rng.randrange(0, 4))]

    def test_random_structures_round_trip(self):
        rng = random.Random(20260814)
        for i in range(2000):
            value = [self._value(rng) for _ in range(rng.randrange(0, 5))]
            with self.subTest(i=i, value=value):
                wire = mres.encode(value)
                self.assertEqual(mres.decode(wire), value)
                self.assertEqual(mres.to_json(wire), value)
                self.assertEqual(mres.encode(mres.to_json(wire)), wire)

    def test_random_structures_match_the_reference_encoder(self):
        rng = random.Random(1312)
        for i in range(2000):
            value = [self._value(rng) for _ in range(rng.randrange(0, 5))]
            with self.subTest(i=i, value=value):
                self.assertEqual(mres.encode(value), ref_encode(value))
                self.assertEqual(mres.decode(mres.encode(value)), ref_decode(ref_encode(value)))


class TestAgainstReference(unittest.TestCase):
    """`mres` must not have drifted from the validated Python port."""

    def test_decode_matches_reference_on_corpus(self):
        for value in SAFE_CORPUS:
            with self.subTest(value=value):
                wire = mres.encode(value)
                self.assertEqual(mres.decode(wire), ref_decode(wire))

    def test_encode_matches_reference_on_corpus(self):
        for value in SAFE_CORPUS:
            with self.subTest(value=value):
                self.assertEqual(mres.encode(value), ref_encode(value))

    def test_decode_matches_reference_on_malformed_input(self):
        for wire in ['"[a]"', '"["', "", '"', "not an array", '"[1,]"', "[[[["]:
            with self.subTest(wire=wire):
                self.assertEqual(mres.decode(wire), ref_decode(wire))

    def test_decode_returns_none_on_unparseable_like_the_reference(self):
        self.assertIsNone(mres.decode('"[``a``'))
        self.assertIsNone(ref_decode('"[``a``'))


class TestEmptyVersusUnparseable(unittest.TestCase):
    """The distinction the TypeScript insists on: never read unparseable as empty."""

    def test_null_stays_null(self):
        self.assertIsNone(mres.to_json(None))
        self.assertIsNone(mres.decode_strict(None))
        self.assertFalse(mres.is_empty(None))

    def test_empty_column_decodes_to_empty_array(self):
        # The game's own reader has an explicit early exit for this.
        for raw in ["", "   ", "[]", '"[]"']:
            with self.subTest(raw=raw):
                self.assertTrue(mres.is_empty(raw))
                self.assertEqual(mres.to_json(raw), [])

    def test_unparseable_raises_and_names_the_cell(self):
        with self.assertRaises(TransformError) as caught:
            mres.to_json(
                '"[``arifle_MX_F``',
                table="houses",
                column="vinv",
                pk=4711,
            )
        issue = caught.exception.issue
        self.assertEqual(issue.severity, "error")
        self.assertEqual(issue.table, "houses")
        self.assertEqual(issue.column, "vinv")
        self.assertEqual(issue.pk, 4711)
        self.assertIn("houses.vinv", str(caught.exception))
        self.assertIn("4711", str(caught.exception))

    def test_unparseable_is_never_silently_empty(self):
        """The exact failure that destroyed stored items: refuse, do not empty."""
        for raw in ['"[``a``', "garbage", '"[1,]"', "{}}"]:
            with self.subTest(raw=raw):
                self.assertFalse(mres.is_empty(raw))
                with self.assertRaises(TransformError):
                    mres.to_json(raw, table="storage", column="storage_vault", pk=1)

    def test_non_text_value_is_an_error_not_a_coercion(self):
        with self.assertRaises(TransformError):
            mres.decode_strict(12345, table="houses", column="vinv", pk=1)


class TestQuotesAndApostrophes(unittest.TestCase):
    """DIVERGENCE 5 — the one input the three implementations cannot agree on."""

    def test_apostrophes_round_trip(self):
        for value in [["O'Brien"], ["don't", "won't"], ["'"]]:
            with self.subTest(value=value):
                self.assertEqual(mres.decode(mres.encode(value)), value)

    def test_encode_refuses_a_string_containing_a_double_quote(self):
        with self.assertRaises(TransformError) as caught:
            mres.encode(['a"b'])
        self.assertIn("double quote", str(caught.exception))

    def test_the_reference_would_have_emitted_something_unreadable(self):
        """Documents why encode refuses instead of following the reference here."""
        wire = ref_encode(['a"b'])
        self.assertIsNone(ref_decode(wire))
        self.assertIsNone(mres.decode(wire))

    def test_engine_escaped_quote_is_unparseable_and_says_so(self):
        # What the SQF encoder actually produces for ['a"b']:
        #   str(['a"b'])      -> ["a""b"]
        #   str(that)         -> "[""a""""b""]"
        #   interior 34 -> 96 -> "[``a````b``]"
        wire = '"[``a````b``]"'
        self.assertEqual(mres._unwrap(wire), '["a""b"]')
        self.assertIsNone(mres.decode(wire))
        with self.assertRaises(TransformError) as caught:
            mres.to_json(wire, table="gangs", column="name", pk=9)
        self.assertIn("JSON cannot express", str(caught.exception))


class TestBackslashes(unittest.TestCase):
    """DIVERGENCE 7 — the silent one. Found by the property test above.

    The source engine's string literals have no backslash escape; JSON's do. The
    reference decoder therefore returns a value that differs from what was stored,
    and raises nothing while doing it.
    """

    BS = chr(92)

    def test_the_reference_silently_rewrites_the_value(self):
        """Pins the bug in the reference, so the guard below cannot be 'simplified'."""
        source = "a" + self.BS + "tb"          # 4 chars: a \ t b
        wire = ref_encode([source])
        decoded = ref_decode(wire)
        self.assertIsNotNone(decoded)          # no error is raised...
        self.assertEqual(decoded, ["a\tb"])    # ...and the value has changed
        self.assertEqual(len(source), 4)
        self.assertEqual(len(decoded[0]), 3)
        self.assertNotEqual(decoded, [source])

    def test_decode_mirrors_the_reference_including_the_bug(self):
        wire = ref_encode(["a" + self.BS + "tb"])
        self.assertEqual(mres.decode(wire), ref_decode(wire))

    def test_to_json_refuses_rather_than_rewriting(self):
        wire = ref_encode(["a" + self.BS + "tb"])
        with self.assertRaises(TransformError) as caught:
            mres.to_json(wire, table="houses", column="vinv", pk=88)
        self.assertIn("backslash", str(caught.exception))
        self.assertIn("houses.vinv", str(caught.exception))

    def test_encode_refuses_a_backslash(self):
        with self.assertRaises(TransformError) as caught:
            mres.encode(["C:" + self.BS + "path"])
        self.assertIn("backslash", str(caught.exception))

    def test_encode_refuses_raw_control_characters(self):
        for bad in ["a\tb", "a\nb", "a\rb", "a\x00b"]:
            with self.subTest(bad=bad):
                with self.assertRaises(TransformError) as caught:
                    mres.encode([bad])
                self.assertIn("control character", str(caught.exception))

    def test_raw_control_character_in_source_is_reported_not_guessed(self):
        wire = '"[``a\tb``]"'
        self.assertIsNone(mres.decode(wire))  # json rejects it outright
        with self.assertRaises(TransformError) as caught:
            mres.to_json(wire, table="houses", column="pinv", pk=5)
        self.assertIn("control character", str(caught.exception))

    def test_diagnose_names_the_backslash(self):
        wire = ref_encode(["a" + self.BS + "tb"])
        self.assertIn("backslash", mres.diagnose(wire))


class TestDelimiterByte(unittest.TestCase):
    """The security control: the encoder deletes byte 96 from source data."""

    def test_encode_deletes_a_source_backtick(self):
        self.assertEqual(mres.encode(["ba`d"]), '"[``bad``]"')
        self.assertEqual(mres.decode(mres.encode(["ba`d"])), ["bad"])

    def test_deletion_is_lossy_on_purpose(self):
        """Round trip is NOT identity for a value holding the delimiter byte."""
        value = ["ba`d"]
        self.assertNotEqual(mres.decode(mres.encode(value)), value)
        self.assertEqual(mres.decode(mres.encode(value)), ["bad"])

    def test_the_reference_does_not_delete_it(self):
        """DIVERGENCE 6 — recorded, because this module follows the SQF here."""
        self.assertEqual(ref_encode(["ba`d"]), '"[``ba`d``]"')
        # And that is the whole problem: the stray backtick decodes to a quote
        # that closes the string early.
        self.assertIsNone(ref_decode(ref_encode(["ba`d"])))

    def test_a_surviving_backtick_in_source_data_is_reported_not_guessed(self):
        wire = '"[``ba`d``]"'  # a row that predates or bypassed the control
        with self.assertRaises(TransformError) as caught:
            mres.to_json(wire, table="gangs", column="name", pk=3)
        self.assertIn("odd number of backticks", str(caught.exception))


class TestNumbers(unittest.TestCase):
    """Integers must not become floats. postgres_plan.md §7.3."""

    def test_scientific_notation_decodes_to_an_exact_int(self):
        # The source engine emits this form for large values; DB_fnc_numberSafe
        # exists to stop it reaching an integer column.
        self.assertEqual(mres.to_json('"[1e+015]"'), [1000000000000000])
        self.assertIsInstance(mres.to_json('"[1e+015]"')[0], int)

    def test_large_scientific_notation_is_exact_not_float_rounded(self):
        exact = 10 ** 25
        self.assertEqual(mres.to_json('"[1e+025]"'), [exact])
        # A float path would have produced 10000000000000000905969664 here.
        self.assertNotEqual(int(float("1e+025")), exact)

    def test_integers_past_the_float_exact_range_survive(self):
        for n in [16777217, 9007199254740993, 2 ** 63 - 1]:
            with self.subTest(n=n):
                wire = mres.encode([n])
                self.assertEqual(mres.to_json(wire), [n])
                self.assertIsInstance(mres.to_json(wire)[0], int)

    def test_whole_valued_decimals_become_ints(self):
        self.assertEqual(mres.to_json('"[4.0]"'), [4])
        self.assertIsInstance(mres.to_json('"[4.0]"')[0], int)

    def test_genuinely_fractional_values_stay_float(self):
        self.assertEqual(mres.to_json('"[1.5]"'), [1.5])
        self.assertIsInstance(mres.to_json('"[1.5]"')[0], float)

    def test_decode_keeps_reference_float_behaviour(self):
        """`decode` is the reference mirror; only `to_json` is exact."""
        self.assertIsInstance(mres.decode('"[1e+015]"')[0], float)

    def test_result_is_json_serialisable(self):
        for wire in ['"[1e+015]"', '"[1.5]"', '"[````]"', '"[[[``a``,1]],1]"']:
            with self.subTest(wire=wire):
                json.dumps(mres.to_json(wire))


class TestNestedArrays(unittest.TestCase):
    def test_deeply_nested_mixed(self):
        value = [[["a", ["b", 1]], []], 2, [""]]
        self.assertEqual(mres.decode(mres.encode(value)), value)
        self.assertEqual(mres.to_json(mres.encode(value)), value)

    def test_nested_empty_strings_at_depth(self):
        value = [[["", ""], [""]], [""]]
        self.assertEqual(mres.to_json(mres.encode(value)), value)


class TestEncodeRefusals(unittest.TestCase):
    def test_unrepresentable_type_is_an_error(self):
        for value in [{"a": 1}, None, object()]:
            with self.subTest(value=value):
                with self.assertRaises(TransformError):
                    mres.encode(value)

    def test_error_names_the_path_inside_the_value(self):
        with self.assertRaises(TransformError) as caught:
            mres.encode([["ok", {"bad": 1}]])
        self.assertIn("[0][1]", str(caught.exception))


class TestDiagnose(unittest.TestCase):
    def test_reports_null_and_empty_distinctly(self):
        self.assertEqual(mres.diagnose(None), "value is NULL")
        self.assertEqual(mres.diagnose(""), "value is empty")

    def test_reports_a_missing_wrap(self):
        self.assertIn("no outer str() wrap", mres.diagnose("[``a``"))

    def test_produces_no_value(self):
        """diagnose repairs nothing — it only explains."""
        self.assertIsInstance(mres.diagnose('"[``a``'), str)


if __name__ == "__main__":
    unittest.main(verbosity=2)
