"""Tests for the mysqldump reader — concentrated on escaping.

Purpose:
    Prove that the statement splitter and value parser survive the byte
    sequences that actually appear in a live player database, rather than the
    tidy ones in a hand-written fixture.

WHY THIS EXISTS:
    Dump parsers do not fail on the schema; they fail on one player whose name
    contains an apostrophe and one inventory blob containing a backslash. When
    that happens the parser mis-splits a row and every value after the bad one
    shifts by a column — in this database that means a currency column
    receiving a licence flag, silently, for one player in a hundred thousand.
    There is no reverse path after the migration runs, so the escaping cases
    below are the difference between a correct migration and an undiscoverable
    corruption.

    Each test name states the byte sequence it defends against. If one fails,
    the failure is in `dump.py`, not in the fixture.

Usage:
    python3 tools/pgmigrate/test_dump.py
    python3 -m unittest discover -s tools/pgmigrate -p 'test_*.py'
"""

from __future__ import annotations

import gzip
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pgmigrate import dump                      # noqa: E402
from pgmigrate.model import TransformError      # noqa: E402


def write_dump(text: str, *, gz: bool = False, encoding: str = "utf-8") -> str:
    suffix = ".sql.gz" if gz else ".sql"
    fd, path = tempfile.mkstemp(suffix=suffix)
    os.close(fd)
    if gz:
        with gzip.open(path, "wt", encoding=encoding, newline="") as fh:
            fh.write(text)
    else:
        with open(path, "w", encoding=encoding, newline="") as fh:
            fh.write(text)
    return path


class DumpTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._paths: list[str] = []

    def tearDown(self) -> None:
        for path in self._paths:
            try:
                os.unlink(path)
            except OSError:
                pass

    def dump_file(self, text: str, **kw) -> str:
        path = write_dump(text, **kw)
        self._paths.append(path)
        return path

    def rows(self, text: str, **kw) -> list:
        path = self.dump_file(text, **kw)
        return list(dump.iter_rows(path, dump.read_schema(path)))

    def one_value(self, literal: str) -> object:
        """Round-trip a single-column INSERT and return the parsed value."""
        text = (
            "CREATE TABLE `t` (`v` text);\n"
            f"INSERT INTO `t` VALUES ({literal});\n"
        )
        rows = self.rows(text)
        self.assertEqual(len(rows), 1)
        return rows[0].values["v"]


# --------------------------------------------------------------------------
# Escaping — the reason this file exists
# --------------------------------------------------------------------------


class TestStringEscaping(DumpTestCase):
    def test_escaped_single_quote_backslash(self):
        self.assertEqual(self.one_value(r"'O\'Brien'"), "O'Brien")

    def test_escaped_single_quote_doubled(self):
        """A dump taken with NO_BACKSLASH_ESCAPES doubles quotes instead."""
        self.assertEqual(self.one_value("'O''Brien'"), "O'Brien")

    def test_escaped_double_quote(self):
        self.assertEqual(self.one_value(r"'say \"hi\"'"), 'say "hi"')

    def test_escaped_backslash(self):
        self.assertEqual(self.one_value(r"'a\\b'"), "a\\b")

    def test_trailing_backslash_before_delimiter(self):
        """`'a\\\\',1` — the classic mis-split: the closing quote looks escaped."""
        text = (
            "CREATE TABLE `t` (`a` text, `b` int);\n"
            "INSERT INTO `t` VALUES ('a\\\\',1),('b',2);\n"
        )
        rows = self.rows(text)
        self.assertEqual([r.values["a"] for r in rows], ["a\\", "b"])
        self.assertEqual([r.values["b"] for r in rows], ["1", "2"])

    def test_escaped_newline_and_tab_and_return(self):
        self.assertEqual(self.one_value(r"'l1\nl2\tx\ry'"), "l1\nl2\tx\ry")

    def test_escaped_nul(self):
        self.assertEqual(self.one_value(r"'nul\0here'"), "nul\0here")

    def test_escaped_backspace_and_ctrl_z(self):
        self.assertEqual(self.one_value(r"'\b\Z'"), "\b\x1a")

    def test_like_wildcards_keep_their_backslash(self):
        """MySQL leaves `\\%` and `\\_` alone; stripping them changes stored text."""
        self.assertEqual(self.one_value(r"'50\% \_x'"), "50\\% \\_x")

    def test_unknown_escape_drops_the_backslash(self):
        self.assertEqual(self.one_value(r"'\q'"), "q")

    def test_literal_newline_inside_string(self):
        """Hand-edited dumps sometimes contain a real newline in a value."""
        text = "CREATE TABLE `t` (`v` text);\nINSERT INTO `t` VALUES ('a\nb');\n"
        rows = self.rows(text)
        self.assertEqual(rows[0].values["v"], "a\nb")


class TestSyntaxInsideStrings(DumpTestCase):
    def test_semicolon_inside_string_does_not_split(self):
        self.assertEqual(self.one_value("'end; not really'"), "end; not really")

    def test_tuple_delimiter_inside_string(self):
        text = (
            "CREATE TABLE `t` (`a` text, `b` text);\n"
            "INSERT INTO `t` VALUES ('x),(y','z');\n"
        )
        rows = self.rows(text)
        self.assertEqual(rows[0].values["a"], "x),(y")
        self.assertEqual(rows[0].values["b"], "z")

    def test_line_comment_markers_inside_string(self):
        self.assertEqual(self.one_value("'a -- b # c'"), "a -- b # c")

    def test_block_comment_marker_inside_string(self):
        self.assertEqual(self.one_value("'a /* b */ c'"), "a /* b */ c")

    def test_keyword_values_inside_string(self):
        self.assertEqual(self.one_value("'VALUES (1)'"), "VALUES (1)")

    def test_backtick_inside_string(self):
        self.assertEqual(self.one_value("'a `b` c'"), "a `b` c")

    def test_word_null_as_string_is_not_sql_null(self):
        self.assertEqual(self.one_value("'NULL'"), "NULL")

    def test_sql_null_is_none(self):
        self.assertIsNone(self.one_value("NULL"))

    def test_empty_string_is_not_null(self):
        self.assertEqual(self.one_value("''"), "")


class TestComments(DumpTestCase):
    def test_line_comment_is_dropped(self):
        text = (
            "-- MySQL dump 10.19\n"
            "CREATE TABLE `t` (`v` int); # trailing\n"
            "INSERT INTO `t` VALUES (1);\n"
        )
        rows = self.rows(text)
        self.assertEqual(rows[0].values["v"], "1")

    def test_double_dash_without_space_is_not_a_comment(self):
        """`4--5` is arithmetic in MySQL, not a comment."""
        text = "CREATE TABLE `t` (`v` int);\nINSERT INTO `t` VALUES (4--5);\n"
        rows = self.rows(text)
        self.assertEqual(rows[0].values["v"], "4--5")

    def test_conditional_comment_is_skipped(self):
        text = (
            "/*!40101 SET NAMES utf8mb4 */;\n"
            "CREATE TABLE `t` (`v` int);\n"
            "/*!40000 ALTER TABLE `t` DISABLE KEYS */;\n"
            "INSERT INTO `t` VALUES (1);\n"
        )
        rows = self.rows(text)
        self.assertEqual(len(rows), 1)

    def test_routines_are_skipped_but_counted(self):
        text = (
            "CREATE TABLE `t` (`v` int);\n"
            "/*!50003 CREATE TRIGGER `t_ins` BEFORE INSERT ON `t` "
            "FOR EACH ROW SET NEW.v = 1 */;;\n"
            "INSERT INTO `t` VALUES (1);\n"
        )
        path = self.dump_file(text)
        scan = dump.scan_schema(path)
        self.assertEqual(len(scan.routines), 1)
        self.assertIn("trigger", scan.routines[0])


# --------------------------------------------------------------------------
# Values are text, and stay text
# --------------------------------------------------------------------------


class TestNoCoercion(DumpTestCase):
    def test_bigint_beyond_float_exactness_survives(self):
        """9007199254740993 is 2**53+1 — the first integer a double loses."""
        value = self.one_value("9007199254740993")
        self.assertIsInstance(value, str)
        self.assertEqual(value, "9007199254740993")

    def test_exact_decimal_keeps_its_digits(self):
        value = self.one_value("1234567890.1234")
        self.assertIsInstance(value, str)
        self.assertEqual(value, "1234567890.1234")

    def test_negative_and_scientific_notation_are_untouched(self):
        self.assertEqual(self.one_value("-42"), "-42")
        self.assertEqual(self.one_value("1.5e3"), "1.5e3")

    def test_no_value_is_ever_a_float(self):
        text = (
            "CREATE TABLE `t` (`a` bigint, `b` decimal(14,4), `c` double);\n"
            "INSERT INTO `t` VALUES (9007199254740993,1234567890.1234,1.5);\n"
        )
        for row in self.rows(text):
            for value in row.values.values():
                self.assertNotIsInstance(value, float)

    def test_hex_literal_decodes_to_text(self):
        self.assertEqual(self.one_value("0x4142"), "AB")

    def test_x_prefixed_hex_literal(self):
        self.assertEqual(self.one_value("x'4142'"), "AB")

    def test_non_utf8_blob_is_a_loud_error(self):
        with self.assertRaises(TransformError) as ctx:
            self.one_value("0xFFFE")
        self.assertIn("not valid UTF-8", ctx.exception.issue.message)

    def test_bit_literal(self):
        self.assertEqual(self.one_value("b'101'"), "5")


# --------------------------------------------------------------------------
# Statement / row shape
# --------------------------------------------------------------------------


class TestRows(DumpTestCase):
    def test_extended_insert_yields_every_tuple(self):
        text = (
            "CREATE TABLE `t` (`a` int, `b` text);\n"
            "INSERT INTO `t` VALUES (1,'x'),(2,'y'),(3,'z');\n"
        )
        rows = self.rows(text)
        self.assertEqual([r.values["a"] for r in rows], ["1", "2", "3"])

    def test_multi_line_extended_insert(self):
        text = (
            "CREATE TABLE `t` (`a` int, `b` text);\n"
            "INSERT INTO `t` VALUES\n(1,'x'),\n(2,'y');\n"
        )
        self.assertEqual(len(self.rows(text)), 2)

    def test_explicit_column_list_is_honoured(self):
        text = (
            "CREATE TABLE `t` (`a` int, `b` int, `c` int);\n"
            "INSERT INTO `t` (`c`,`a`) VALUES (7,9);\n"
        )
        rows = self.rows(text)
        self.assertEqual(rows[0].values, {"c": "7", "a": "9"})

    def test_column_count_mismatch_is_an_error_not_an_alignment(self):
        text = (
            "CREATE TABLE `t` (`a` int, `b` int);\n"
            "INSERT INTO `t` VALUES (1);\n"
        )
        with self.assertRaises(TransformError) as ctx:
            self.rows(text)
        self.assertIn("refusing", ctx.exception.issue.message)

    def test_insert_without_ddl_or_column_list_is_an_error(self):
        text = "INSERT INTO `orphan` VALUES (1);\n"
        path = self.dump_file(text)
        with self.assertRaises(TransformError):
            list(dump.iter_rows(path, {}))

    def test_only_filter_skips_other_tables(self):
        text = (
            "CREATE TABLE `a` (`v` int);\n"
            "INSERT INTO `a` VALUES (1);\n"
            "CREATE TABLE `b` (`v` int);\n"
            "INSERT INTO `b` VALUES (2);\n"
        )
        path = self.dump_file(text)
        rows = list(dump.iter_rows(path, dump.read_schema(path), only=["b"]))
        self.assertEqual([r.table for r in rows], ["b"])

    def test_replace_into_is_read_like_insert(self):
        text = "CREATE TABLE `t` (`v` int);\nREPLACE INTO `t` VALUES (1);\n"
        self.assertEqual(len(self.rows(text)), 1)

    def test_qualified_table_name(self):
        text = (
            "CREATE TABLE `db`.`t` (`v` int);\n"
            "INSERT INTO `db`.`t` VALUES (1);\n"
        )
        rows = self.rows(text)
        self.assertEqual(rows[0].table, "t")

    def test_gzipped_dump(self):
        text = "CREATE TABLE `t` (`v` int);\nINSERT INTO `t` VALUES (1);\n"
        path = self.dump_file(text, gz=True)
        rows = list(dump.iter_rows(path, dump.read_schema(path)))
        self.assertEqual(rows[0].values["v"], "1")

    def test_truncated_dump_is_an_error(self):
        text = "CREATE TABLE `t` (`v` text);\nINSERT INTO `t` VALUES ('unterminated"
        path = self.dump_file(text)
        with self.assertRaises(TransformError) as ctx:
            list(dump.iter_rows(path, {}))
        self.assertIn("truncated", ctx.exception.issue.message)


# --------------------------------------------------------------------------
# CREATE TABLE parsing
# --------------------------------------------------------------------------


class TestSchema(DumpTestCase):
    DDL = (
        "CREATE TABLE `players` (\n"
        "  `id` int(11) NOT NULL AUTO_INCREMENT,\n"
        "  `uid` varchar(64) NOT NULL,\n"
        "  `name` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,\n"
        "  `cash` bigint(20) unsigned NOT NULL DEFAULT '0',\n"
        "  `bank` decimal(14,4) NOT NULL DEFAULT 0.0000,\n"
        "  `alive` tinyint(1) NOT NULL DEFAULT 0,\n"
        "  `side` enum('civ','cop','med') NOT NULL DEFAULT 'civ',\n"
        "  `note` text COMMENT 'free, text',\n"
        "  `lastupdated` datetime NOT NULL DEFAULT current_timestamp() "
        "ON UPDATE current_timestamp(),\n"
        "  PRIMARY KEY (`id`),\n"
        "  UNIQUE KEY `uid_uq` (`uid`),\n"
        "  KEY `name_idx` (`name`(10),`side`)\n"
        ") ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8mb4;\n"
    )

    def table(self):
        path = self.dump_file(self.DDL)
        return dump.read_schema(path)["players"]

    def test_columns_and_order(self):
        t = self.table()
        self.assertEqual(
            t.column_names(),
            ["id", "uid", "name", "cash", "bank", "alive", "side", "note", "lastupdated"],
        )

    def test_types_keep_unsigned_and_precision(self):
        t = self.table()
        self.assertEqual(t.column("cash").mysql_type, "bigint(20) unsigned")
        self.assertEqual(t.column("bank").mysql_type, "decimal(14,4)")
        self.assertEqual(t.column("alive").mysql_type, "tinyint(1)")

    def test_enum_literal_is_preserved_including_its_commas(self):
        self.assertEqual(self.table().column("side").mysql_type, "enum('civ','cop','med')")

    def test_nullability(self):
        t = self.table()
        self.assertFalse(t.column("uid").nullable)
        self.assertTrue(t.column("name").nullable)

    def test_defaults_are_kept_as_written(self):
        t = self.table()
        self.assertEqual(t.column("cash").default, "'0'")
        self.assertEqual(t.column("bank").default, "0.0000")
        self.assertEqual(t.column("name").default, "NULL")
        self.assertIsNone(t.column("note").default)

    def test_extra_carries_auto_increment_and_on_update(self):
        t = self.table()
        self.assertEqual(t.column("id").extra, "auto_increment")
        self.assertIn("on update", t.column("lastupdated").extra)

    def test_comment_containing_a_comma_does_not_split_the_body(self):
        self.assertEqual(self.table().column("note").mysql_type, "text")

    def test_primary_key_and_indexes(self):
        t = self.table()
        self.assertEqual(t.primary_key, ["id"])
        by_name = {n: (cols, uniq) for n, cols, uniq in t.indexes}
        self.assertEqual(by_name["uid_uq"], (["uid"], True))
        self.assertEqual(by_name["name_idx"], (["name", "side"], False))

    def test_composite_primary_key(self):
        text = (
            "CREATE TABLE `k` (`a` int NOT NULL, `b` int NOT NULL, "
            "PRIMARY KEY (`a`,`b`));\n"
        )
        path = self.dump_file(text)
        self.assertEqual(dump.read_schema(path)["k"].primary_key, ["a", "b"])

    def test_foreign_key_clause_is_skipped_not_read_as_a_column(self):
        text = (
            "CREATE TABLE `c` (\n"
            "  `id` int NOT NULL,\n"
            "  `p` int DEFAULT NULL,\n"
            "  PRIMARY KEY (`id`),\n"
            "  CONSTRAINT `fk` FOREIGN KEY (`p`) REFERENCES `players` (`id`)\n"
            ") ENGINE=InnoDB;\n"
        )
        path = self.dump_file(text)
        self.assertEqual(dump.read_schema(path)["c"].column_names(), ["id", "p"])

    def test_unrecognised_column_attribute_is_an_error(self):
        text = "CREATE TABLE `t` (`v` int WOMBAT);\n"
        path = self.dump_file(text)
        with self.assertRaises(TransformError) as ctx:
            dump.read_schema(path)
        self.assertIn("unrecognised", ctx.exception.issue.message)

    def test_duplicate_create_table_is_an_error(self):
        text = "CREATE TABLE `t` (`v` int);\nCREATE TABLE `t` (`v` int);\n"
        path = self.dump_file(text)
        with self.assertRaises(TransformError):
            dump.read_schema(path)

    def test_row_values_are_keyed_by_name_after_a_reorder(self):
        """The positional-read hazard: names must win over ordinals."""
        text = (
            "CREATE TABLE `t` (`cash` bigint, `licences` text);\n"
            "INSERT INTO `t` (`licences`,`cash`) VALUES ('[1,0]',500);\n"
        )
        rows = self.rows(text)
        self.assertEqual(rows[0].values["cash"], "500")
        self.assertEqual(rows[0].values["licences"], "[1,0]")


class TestCounting(DumpTestCase):
    """Counting the tables that do NOT carry is half of "count in, count out"."""

    DUMP = (
        "CREATE TABLE `players` (`id` int, `name` text);\n"
        "INSERT INTO `players` VALUES (1,'a'),(2,'b');\n"
        "CREATE TABLE `log` (`id` int, `msg` text);\n"
        "INSERT INTO `log` VALUES (1,'x'),(2,'y'),(3,'z');\n"
    )

    def test_counts_every_table(self):
        path = self.dump_file(self.DUMP)
        self.assertEqual(dump.count_rows(path, dump.read_schema(path)),
                         {"players": 2, "log": 3})

    def test_counts_only_the_named_tables(self):
        path = self.dump_file(self.DUMP)
        self.assertEqual(dump.count_rows(path, dump.read_schema(path), only=["log"]),
                         {"log": 3})

    def test_a_short_row_is_still_a_parse_failure_while_counting(self):
        # The arity check is not a luxury of the value path: a row that does not
        # line up is a dump this tool must not quietly count as fine.
        path = self.dump_file(self.DUMP + "INSERT INTO `log` VALUES (4);\n")
        with self.assertRaises(TransformError):
            dump.count_rows(path, dump.read_schema(path))

    def test_counting_retains_no_values(self):
        path = self.dump_file(self.DUMP)
        rows = list(dump.iter_rows(path, dump.read_schema(path), values=False))
        self.assertEqual(len(rows), 5)
        self.assertEqual(rows[0].values, {})


class TestStreaming(DumpTestCase):
    def test_reader_does_not_buffer_the_whole_file(self):
        """Row count is right for a dump far larger than any single statement."""
        parts = ["CREATE TABLE `t` (`a` int, `b` text);\n"]
        for batch in range(50):
            tuples = ",".join(f"({i},'p{i}')" for i in range(batch * 100, batch * 100 + 100))
            parts.append(f"INSERT INTO `t` VALUES {tuples};\n")
        path = self.dump_file("".join(parts))
        count = 0
        for _ in dump.iter_rows(path, dump.read_schema(path)):
            count += 1
        self.assertEqual(count, 5000)


if __name__ == "__main__":
    unittest.main(verbosity=2)
