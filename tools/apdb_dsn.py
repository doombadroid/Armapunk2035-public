#!/usr/bin/env python3
"""Where a box-side tool gets the database DSN. The only place.

Env first (a caller can always override), then ~/.pysqf_dsn, which the owner
writes once from the running daemon's environment and chmods 600. The real DSN
lives in root-only /etc/conf.d/pysqfd and is a secret; it never enters the repo.
"""
import os
import sys

DSN_FILE = os.path.expanduser("~/.pysqf_dsn")


def dsn():
    v = os.environ.get("PYSQF_DB_DSN", "").strip()
    if v:
        return v
    try:
        with open(DSN_FILE, encoding="utf-8") as fh:
            v = fh.read().strip()
    except OSError:
        v = ""
    if not v:
        sys.exit("no DSN: set PYSQF_DB_DSN or write ~/.pysqf_dsn (see tools/apdb_dsn.py)")
    return v


def connect():
    import psycopg
    return psycopg.connect(dsn(), autocommit=False)
