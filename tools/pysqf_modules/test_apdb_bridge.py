"""What SQF ACTUALLY RECEIVES, asserted against what extDB3 used to hand it.

    PYSQF_DB_DSN="host=... dbname=..._scratch user=... password=..." \\
    <venv>/bin/python -m unittest tools.pysqf_modules.test_apdb_bridge

Needs a real PostgreSQL and psycopg, so it does not run under the plain
interpreter the other suites use; skipped, loudly, when the DSN is absent.

WHY THIS SUITE EXISTS
    Everything else checks a layer that was never wrong. The SQL translator has
    a 400-statement corpus; the differential harness proves both engines hold the
    same rows. Both were green while four real bugs shipped, because all four
    lived in the seam between "the database holds the right value" and "the value
    SQF sees means the same thing".

    The contract being reproduced is extDB3's, and it is easy to state and easy
    to forget: **extDB3 returned SQF SOURCE, which the caller `call compile`d.**
    Every consequence below follows from that one sentence.

      - A text value arrived as `"..."` and the compile consumed those quotes as
        string delimiters. The caller got the CONTENT. The bridge builds an array
        instead of compiling, so it has to unwrap them itself -- and when it did
        not, `houses.pinv` (whose value is the game's own codec, itself wrapped
        in quotes) was read one layer too deep, decoded as empty, and then SAVED
        BACK as empty over the player's real storage.
      - A number arrived bare and compiled to a number. SQF numbers are 32-bit
        floats, so anything past 16,777,216 has to travel as a string instead --
        which is what `QUOTE()` was for, and why the translator tracks which
        output positions it wrapped.
      - NULL arrived as an empty string, and the callers were written against
        that rather than against nil.

    Each case below is one of those consequences, and the four that are marked
    were found by playing the game rather than by any check in this repository.
"""

from __future__ import annotations

import decimal
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

DSN = os.environ.get("PYSQF_DB_DSN", "")

if DSN:
    try:
        import apdb                                            # noqa: E402
        from pysqf import db                                   # noqa: E402
    except ImportError:
        # The DSN is set but this interpreter lacks psycopg/pysqf (the plain
        # python3 run_checks.sh uses). Same loud skip as no DSN: the suite's
        # real run is the venv entry run_checks registers separately.
        DSN = ""



@unittest.skipUnless(DSN, "PYSQF_DB_DSN is not set: this suite needs a real PostgreSQL")
class BridgeCase(unittest.TestCase):
    """One scratch table holding a column of every kind the game stores."""

    TABLE = "apdb_bridge_probe"

    @classmethod
    def setUpClass(cls) -> None:
        db.execute("DROP TABLE IF EXISTS %s" % cls.TABLE)
        db.execute("""
            CREATE TABLE %s (
                id            integer PRIMARY KEY,
                plain_text    text,
                codec_text    text,
                big_money     bigint,
                small_number  integer,
                exact_decimal decimal(20,4),
                flag          boolean,
                doc           jsonb,
                stamp         timestamp,
                nullable      text
            )""" % cls.TABLE)

    @classmethod
    def tearDownClass(cls) -> None:
        db.execute("DROP TABLE IF EXISTS %s" % cls.TABLE)

    def setUp(self) -> None:
        db.execute("DELETE FROM %s" % self.TABLE)

    def insert(self, **columns) -> None:
        columns.setdefault("id", 1)
        names, marks, values = [], [], []
        for name, value in columns.items():
            names.append(name)
            if name == "doc":
                # jsonb takes JSON TEXT with an explicit cast. Handed a Python
                # list, psycopg tries to adapt it as a PostgreSQL array and
                # refuses a mixed-type one.
                marks.append("%s::jsonb")
                values.append(json.dumps(value))
            else:
                marks.append("%s")
                values.append(value)
        db.execute("INSERT INTO %s (%s) VALUES (%s)"
                   % (self.TABLE, ", ".join(names), ", ".join(marks)), values)

    def read(self, select: str, multiarr: bool = False):
        """The single VALUE of a one-column select.

        A row is an array -- that is the contract, and `test_mode_2_*` below
        asserts it. This helper unwraps it so the value tests read as what SQF
        would index out, rather than repeating `select 0` in every assertion.
        """
        row = apdb.query("SELECT %s FROM %s WHERE id=1" % (select, self.TABLE), 2, multiarr)
        if multiarr or not isinstance(row, list) or len(row) != 1:
            return row
        return row[0]


class TestTheCallCompileContract(BridgeCase):
    """extDB3 returned SQF source. These are the consequences of that."""

    def test_a_codec_value_arrives_unwrapped(self) -> None:
        """FOUND IN GAME. House storage read as empty and then saved empty.

        `houses.pinv` holds the game's own codec, which is itself wrapped in
        quotes: `"[[`item`,1]],9]"`. extDB3 put that on the wire and the compile
        stripped the outer pair. Handed over with them intact, the decoder sees a
        string where it expects an array, reads nothing, and the client writes
        that nothing back over the contents.
        """
        stored = '"[[[`arifle_MX_F`,2],[`FirstAidKit`,6]],14]"'
        self.insert(codec_text=stored)
        self.assertEqual(self.read("codec_text"),
                         "[[[`arifle_MX_F`,2],[`FirstAidKit`,6]],14]")

    def test_an_interior_quote_is_unescaped_with_the_wrapper(self) -> None:
        """`""` is the escape for a quote inside the wrapper, and unwrapping
        without unescaping leaves a value that no longer parses."""
        self.insert(codec_text='"he said ""hello"" loudly"')
        self.assertEqual(self.read("codec_text"), 'he said "hello" loudly')

    def test_text_without_a_wrapper_is_left_exactly_alone(self) -> None:
        """Only a MATCHED outer pair is a wrapper. A value that merely contains
        a quote, or starts with one, is data."""
        for value in ('plain', '[[],0]', 'say "hi"', '"unbalanced', 'trailing"'):
            self.insert(codec_text=value)
            self.assertEqual(self.read("codec_text"), value, value)
            db.execute("DELETE FROM %s" % self.TABLE)

    def test_an_apostrophe_survives(self) -> None:
        self.insert(plain_text="O'Brien")
        self.assertEqual(self.read("plain_text"), "O'Brien")


class TestNumbersThatSQFCannotHold(BridgeCase):
    """SQF numbers are 32-bit floats. Money is not."""

    def test_money_past_the_float_exact_range_travels_as_a_string(self) -> None:
        """16,777,216 is where an SQF number stops being exact. A bank balance
        above it that arrives as a number arrives ROUNDED, and rounding money on
        read is how a dupe becomes possible."""
        self.insert(big_money=9007199254740993)
        got = self.read("big_money")
        self.assertIsInstance(got, str)
        self.assertEqual(got, "9007199254740993")

    def test_a_small_number_stays_a_number(self) -> None:
        """Everything the game does arithmetic on directly must not become text."""
        self.insert(small_number=42)
        got = self.read("small_number")
        self.assertIsInstance(got, int)
        self.assertEqual(got, 42)

    def test_an_exact_decimal_keeps_every_place(self) -> None:
        """`new_drachma` is decimal(20,4) and a float loses the fourth place."""
        self.insert(exact_decimal=decimal.Decimal("12345678901234.5678"))
        got = self.read("exact_decimal")
        self.assertIsInstance(got, str)
        self.assertEqual(got, "12345678901234.5678")

    def test_a_text_cast_arrives_as_a_string(self) -> None:
        """QUOTE() is banned at the source now (the harvest lint); the ported
        form for a number that must travel as text is an explicit ::text cast,
        and the transport must hand it over as the string it is."""
        self.insert(small_number=42, plain_text="x")
        row = apdb.query("SELECT (small_number)::text AS n, plain_text FROM %s WHERE id=1"
                         % self.TABLE, 2, False)
        self.assertIsInstance(row[0], str)
        self.assertEqual(row[0], "42")


class TestTheOtherColumnKinds(BridgeCase):

    def test_a_boolean_arrives_as_0_or_1(self) -> None:
        """The carry-over makes 14 tinyint(1) columns real booleans, and the SQF
        reading them compares with `isEqualTo 1`. `true` makes every one of those
        comparisons false, quietly."""
        self.insert(flag=True)
        self.assertEqual(self.read("flag"), 1)
        db.execute("UPDATE %s SET flag = false" % self.TABLE)
        self.assertEqual(self.read("flag"), 0)

    def test_jsonb_arrives_as_something_parseSimpleArray_can_read(self) -> None:
        """FOUND IN GAME. Every garage read logged a parse error.

        The game calls `parseSimpleArray` on these, and JSON is already valid
        input to it -- `["a",3]` is an SQF array literal. Re-encoding into the
        source's codec wrapped it in quotes and broke every read.
        """
        self.insert(doc=["a", 3])
        self.assertEqual(self.read("doc"), '["a",3]')
        db.execute("UPDATE %s SET doc = '[]'::jsonb" % self.TABLE)
        self.assertEqual(self.read("doc"), "[]")

    def test_null_arrives_as_an_empty_string(self) -> None:
        """extDB3 rendered NULL that way and every caller was written against it.
        `nil` inside an array is not something to hand SQF."""
        self.insert(nullable=None)
        self.assertEqual(self.read("nullable"), "")

    def test_a_timestamp_arrives_in_the_form_the_sqf_parses(self) -> None:
        self.insert(stamp="2026-09-11 14:00:00")
        self.assertEqual(self.read("stamp"), "2026-09-11 14:00:00")


class TestTheResultShape(BridgeCase):
    """mode, multiarr, and the difference between empty and failed."""

    def test_mode_2_without_multiarr_returns_the_first_row(self) -> None:
        self.insert(id=1, plain_text="first")
        db.execute("INSERT INTO %s (id, plain_text) VALUES (2, 'second')" % self.TABLE)
        got = apdb.query("SELECT plain_text FROM %s ORDER BY id" % self.TABLE, 2, False)
        self.assertEqual(got, ["first"])

    def test_mode_2_with_multiarr_returns_every_row(self) -> None:
        self.insert(id=1, plain_text="first")
        db.execute("INSERT INTO %s (id, plain_text) VALUES (2, 'second')" % self.TABLE)
        got = apdb.query("SELECT plain_text FROM %s ORDER BY id" % self.TABLE, 2, True)
        self.assertEqual(got, [["first"], ["second"]])

    def test_no_rows_is_an_empty_array_and_not_an_error(self) -> None:
        """[] and a failure must stay different answers. The helper this replaced
        returned [] for both, and every caller downstream guessed the same wrong
        way -- "the database is down" and "that player has no vehicles" took the
        same code path."""
        self.assertEqual(apdb.query("SELECT plain_text FROM %s WHERE id=999" % self.TABLE,
                                    2, True), [])

    def test_a_write_at_mode_2_returns_no_rows_rather_than_raising(self) -> None:
        """FOUND IN GAME. Callers run writes at mode 2 and extDB3 answered with
        no rows; `db.query` would raise "the last operation didn't produce a
        result" instead."""
        self.insert(plain_text="before")
        got = apdb.query("UPDATE %s SET plain_text='after' WHERE id=1" % self.TABLE, 2, False)
        self.assertEqual(got, [])
        self.assertEqual(self.read("plain_text"), "after")

    def test_mode_1_returns_true_and_actually_writes(self) -> None:
        self.insert(plain_text="before")
        self.assertIs(apdb.query("UPDATE %s SET plain_text='after' WHERE id=1" % self.TABLE, 1),
                      True)
        self.assertEqual(self.read("plain_text"), "after")

    def test_two_columns_of_the_same_name_refuse_loudly(self) -> None:
        """Rows come back keyed by column name, so two expressions PostgreSQL
        both calls `coalesce` cannot ride one row object. The translator used
        to alias these invisibly; it is retired, the port aliased every real
        statement, and the harvest lint keeps new ones honest -- so the
        transport's job here is to REFUSE loudly, never to collapse silently."""
        self.insert(plain_text=None, codec_text=None)
        from pysqf.db import DBUsageError
        with self.assertRaises(DBUsageError):
            apdb.query("SELECT COALESCE(plain_text,'a'), COALESCE(codec_text,'b') "
                       "FROM %s WHERE id=1" % self.TABLE, 2, False)


class TestMresFixturesThroughPostgres(BridgeCase):
    """H4: real payload shapes, encode -> PostgreSQL -> wire -> DECODED, both
    storage generations. Values are compared PARSED, never as bytes -- jsonb
    round-trips legally change whitespace and quoting.

    The two consumer chains being emulated, exactly:
      - game-generation text blob: SQF gets the wire value, mresToArray turns
        backticks to quotes, RE-WRAPS in quotes, compiles, parses. In Python
        that whole chain is `mres.decode('"%s"' % wire)` after the backtick
        conversion mres.decode itself performs -- i.e. decode of the re-wrapped
        wire text.
      - ETL-generation jsonb document: the wire value is compact JSON, and its
        consumers call parseSimpleArray on it. `json.loads` is that parse.
    """

    FIXTURES = [
        [],                                                     # the sentinel
        [[], 0],
        [[["marijuana", 40], ["smashpowder", 25]], 215],            # house inventory
        [[[], [], [], ["U_C_Poloshirt_blue", []], [], [], "", "", [],
          ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", ""]],
         [[["debitcard", 1]], 0], [-1, -1]],                    # starter gear, "" slots
        [["license_civ_boat", True], ["license_civ_bounty", False]],
        [["Gérard", 1], ["Кириллица", 2], ["日本語", 3]],          # unicode names
        [[["deep", [["deeper", [["deepest", 9]]]]]], 1],
    ]

    def _mres(self):
        import importlib
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        "..", "pgmigrate"))
        return importlib.import_module("mres")

    def test_game_generation_blobs_round_trip_parsed(self) -> None:
        mres = self._mres()
        for value in self.FIXTURES:
            stored = mres.encode(value)         # the blob the game writes, wrapper included
            self.insert(codec_text=stored)
            wire = self.read("codec_text")
            decoded = mres.decode('"%s"' % wire)   # the SQF chain: re-wrap, then decode
            self.assertEqual(decoded, self._normalise(value), stored[:80])
            db.execute("DELETE FROM %s" % self.TABLE)

    def test_etl_generation_documents_round_trip_parsed(self) -> None:
        for value in self.FIXTURES:
            self.insert(doc=value)
            wire = self.read("doc")
            self.assertEqual(json.loads(wire), self._normalise(value), str(value)[:80])
            db.execute("DELETE FROM %s" % self.TABLE)

    def test_a_near_upload_cap_payload_survives(self) -> None:
        """fn_pysqfRaw caps the args upload at 8000 chars; the biggest real
        writers (gear saves) must clear it with room. This fixture's ENCODED
        form sits just under the cap and must round-trip parsed-equal."""
        mres = self._mres()
        big = [[["item_%04d" % i, i] for i in range(280)], 12345]
        stored = mres.encode(big)
        self.assertLess(len(stored), 7900, "fixture must sit under the 8000-char args cap")
        self.assertGreater(len(stored), 4000, "fixture must be big enough to mean something")
        self.insert(codec_text=stored)
        wire = self.read("codec_text")
        self.assertEqual(mres.decode('"%s"' % wire), self._normalise(big))

    @staticmethod
    def _normalise(value):
        """The codec renders booleans as engine literals; parsed they come back
        as 1/0-ish or true/false depending on the chain. Normalise BOTH sides
        the same way so the comparison is about structure and data, not the
        boolean spelling each layer uses."""
        if isinstance(value, bool):
            return 1 if value else 0
        if isinstance(value, list):
            return [TestMresFixturesThroughPostgres._normalise(v) for v in value]
        return value


class TestTheStoreRoundTrip(BridgeCase):
    """The exact sequence that lost a house's contents, start to finish."""

    def test_a_codec_value_survives_write_read_write(self) -> None:
        """Write it, read it, write back what was read: the value must be the
        same at the end. The bug was that the read came back one layer deep, the
        client understood nothing, and the write-back was empty."""
        original = "[[[`marijuana`,40],[`cocaine`,25]],215]"
        wrapped = '"%s"' % original
        self.insert(codec_text=wrapped)

        first = self.read("codec_text")
        self.assertEqual(first, original, "the read must hand back what the game stored")

        # The game re-wraps before writing, which is what makes the round trip
        # stable rather than peeling a layer off on every save.
        db.execute("UPDATE %s SET codec_text = %%s WHERE id=1" % self.TABLE,
                   ['"%s"' % first])
        self.assertEqual(self.read("codec_text"), original,
                         "a save after a load must not change the value")


if __name__ == "__main__":
    unittest.main(verbosity=2)


class TestExecpAndParams(unittest.TestCase):
    """The [] write-ambiguity fix and the parameterised path (2026-08-27)."""

    def setUp(self):
        # These tests MOCK the db layer, so they need no DSN -- only an
        # importable apdb (which needs pysqf on the path; absent in the plain
        # interpreter run_checks uses -> same loud skip as the DSN suites).
        try:
            import apdb as _apdb
        except ImportError:
            self.skipTest("pysqf not importable in this interpreter")
        global apdb
        apdb = _apdb
        import decimal as _d
        class _FakeDB:
            def execute(self, sql, params=None):
                if "RETURNING" in sql:
                    return {"rowcount": 1, "rows": [{"id": 7, "bal": _d.Decimal("12.3400")}]}
                return {"rowcount": 0, "rows": None}
            def query(self, sql, params=None):
                return [{"a": 1, "b": None}] if "ONE" in sql else []
            def transaction(self, stmts):
                return [{"rowcount": i} for i, _ in enumerate(stmts, 1)]
        self._saved = apdb.db
        apdb.db = _FakeDB()

    def tearDown(self):
        apdb.db = self._saved

    def test_execp_guard_refused_is_visible(self):
        # rowcount 0 must be distinguishable from success-with-rows and failure
        self.assertEqual(apdb.execp("UPDATE t SET x=1 WHERE id = %s", ["nope"]), [1, 0, []])

    def test_execp_returning_rides_the_value_contract(self):
        # Decimal -> string, positionally shaped
        self.assertEqual(
            apdb.execp("UPDATE t SET x=1 WHERE id = %s RETURNING id, bal", ["y"]),
            [1, 1, [[7, "12.3400"]]])

    def test_queryp_null_contract(self):
        self.assertEqual(apdb.queryp("SELECT ONE %s", ["v"], 2, True), [[1, ""]])

    def test_txn_rowcounts_in_order(self):
        self.assertEqual(
            apdb.txn([["UPDATE a SET x=%s", [1]], ["UPDATE b SET y=%s", [2]]]),
            [1, [1, 2]])
