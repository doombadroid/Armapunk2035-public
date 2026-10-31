"""Substitute format[] placeholders the way runtime would, or return None.

Extracted from the retired translator's test suite (test_apdb_sql.py) at
Phase T -- the PREPARE gate still needs it. A statement whose TABLE, whose
whole SET/WHERE clause, or whose identifiers are placeholder-built cannot be
realised without the call site; those return None and the gate reports them
as needing dbSoak coverage.
"""
import re


def realise(sql: str):
    if re.search(r"(?:FROM|INTO|UPDATE|JOIN)\s+`?%\d+`?", sql, re.I):
        return None
    if re.search(r"\b(SET|WHERE|ORDER BY|BY|FROM)\s+%\d+", sql, re.I):
        return None
    if re.search(r"`%\d+`", sql):
        return None
    if re.search(r"%\d+_", sql):
        return None
    return re.sub(r"%\d+", "1", re.sub(r"'%\d+'", "'x'", sql))
