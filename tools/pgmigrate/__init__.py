"""pgmigrate — one-time ETL: live MariaDB dump -> new PostgreSQL database.

Purpose:
    Carry player data from the live game's MariaDB database into the overhauled
    game's PostgreSQL database, once, at open beta. One direction, one event.
    There is no sync, no dual-write and no reverse path.

WHY THIS EXISTS:
    Three failures this package is built to prevent, in order of how much they
    would cost:

    1. Silent data loss. A migration that "succeeds" and quietly drops 4% of
       rows is discovered weeks later by players, not by us. Every stage counts
       what it moved and refuses to finish on a mismatch (see `etl.reconcile`).
    2. Currency corruption. The source has a bigint currency column and an
       exact-decimal one. A single implicit float conversion anywhere in the
       pipeline rounds balances above 2**53 (and, upstream in the game itself,
       above 2**24). Nothing in this package may pass a currency value through
       `float` — `model.Money` enforces that at the type level.
    3. Carrying dead data. The new game is on a different map, so every
       map-anchored value (worldspace, positions, turf, cartels, capture
       points) is meaningless in the target and must not be carried as if it
       were valid.

    A fourth, quieter one: the source stores arrays in a bespoke text codec
    that is implemented four times in three languages. The target uses JSONB.
    Transcoding happens exactly once, here, at the door. The old encoding is
    never written to the target.

Modules:
    model     — the shared data contract (Column/Table/Row/Issue,
                TransformError, Money). Imported by every other module.
    dump      — streaming reader for a `mysqldump` file (schema + rows as text).
    ddl       — MySQL DDL -> PostgreSQL DDL translation. Takes the carry-over
                policy as input, so the schema it emits is the schema the ETL
                loads into rather than a translation of the source alone.
    rules     — carry-over semantics: what carries, what cannot, what
                compensates. The file to read first.
    mres      — the source's array codec -> JSON.
    etl       — the orchestrator and CLI.
    reconcile — the independent auditor: its own dump parser, its own decoder,
                every total re-derived. A shared parser would cancel its own
                bugs out, so nothing here is shared with `dump` except a test
                fixture of hostile literals both must agree on.
    carryover_spec — the auditor's `--spec`, generated from `rules` so the
                policy is not written down twice.

Usage:
    python3 -m pgmigrate.etl --dump live.sql --out ./pgout --report report.json

STATUS — READ THIS BEFORE TRUSTING ANY OUTPUT:
    No live dump exists in this repository, so nothing here has been run
    against real data. Every claim about the source schema comes from the
    written plan (`postgres_plan.md`), not from measurement. Treat this package
    as unvalidated until it has processed a real dump and the reconciliation
    report has been read by a human.
"""

__all__ = ["model", "dump", "etl"]
