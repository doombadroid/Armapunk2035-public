# pgmigrate — the one-time player carry-over

**pgmigrate is a one-time, one-direction ETL that carries player data from the live
MariaDB database into this project's PostgreSQL database, run once at open beta.**

There is no sync, no dual-write and no path back. It reads a `mysqldump` file, transforms
it (dialect, encoding, schema delta, carry-over semantics), writes PostgreSQL-ready output,
and refuses to complete unless what came out reconciles against what went in.

Contract: `postgres_plan.md` §7.1 (encoding), §9 (the carry-over), §11 (the three risks).
Where this README and the plan disagree, the plan wins and this file is the bug.

---

## ⚠ STATUS: NEVER RUN AGAINST REAL DATA

No live dump exists in this repo, and none has been obtained. **Nothing here has processed a
single row of real player data.** It has never parsed a real dump, never carried a real
balance, and nothing it produced has ever been read back by the game.

Precisely what *has* been exercised, so the gap is visible rather than assumed:

- the unit tests below — the codec, the DDL translation, the dump reader, the rules;
- one end-to-end run over a **synthetic** fixture dump (`testdata_fixture_dump.sql`) with the
  real modules wired together, audited afterwards by `reconcile.py`, and — with
  `PGMIGRATE_TEST_DSN_DISPOSABLE` set — loaded into a disposable PostgreSQL 18.4 and read
  back column by column;
- `run_rehearsal.sh`'s own mechanics — guards, drop protection, load and row-count verify —
  against a throwaway PostgreSQL cluster with **synthetic** output standing in for the ETL's.

That is plumbing, not evidence. Every claim about the source schema comes from
`postgres_plan.md`, which is a written plan, not a measurement. The first real dump will find
bugs — that is what the rehearsal loop is for, and the loop is the deliverable, not the script.

Do not schedule a beta date off the existence of this directory.

---

## The rehearsal loop (the primary workflow)

The whole thing is testable at zero risk, and the loop should be boring long before beta.
Run it end to end, repeatedly, from a fresh dump each time.

```
dump live  ──▶  transform  ──▶  load scratch PostgreSQL  ──▶  point dev server at it  ──▶  inspect
     ▲                                                                                        │
     └────────────────────────────────────── repeat ◀───────────────────────────────────────┘
```

### 1. Dump live (read-only, from the live box)

```bash
mkdir -p ~/pgmigrate-dumps
mysqldump --single-transaction --quick \
          --routines --triggers --events \
          --hex-blob --default-character-set=utf8mb4 \
          --databases <live_db_name> \
          > ~/pgmigrate-dumps/live-$(date +%Y%m%d-%H%M).sql
```

`--single-transaction` so the dump is consistent without locking players out.
`--routines --triggers --events` is **not optional**: the repo does not know the full schema
(`postgres_plan.md` §2, "the schema lives in four places"), and the dump is the only complete
description of what is actually there. A dump taken without them will parse, and will be wrong.

Do not dump straight into the repo. `~/pgmigrate-dumps/` is outside it on purpose — a dump is
real player data.

### 2–5. Transform, audit, load, verify

One command does all four, with a guard in front of every destructive step:

```bash
tools/pgmigrate/run_rehearsal.sh ~/pgmigrate-dumps/live-20260814-1100.sql pgm_scratch
```

It prints the full plan and stops for confirmation before it touches anything.
Useful flags:

| flag | effect |
|---|---|
| `--dry-run` | print the plan and exit; touches nothing |
| `--yes` | skip the confirmation prompt (for a loop you have already watched run) |
| `--transform-only` | stop after the transform; no database is created or dropped |
| `--keep` | do not drop/recreate the target database; load into it as-is (will fail on duplicate keys — see failure modes) |
| `--allow-decide` | run with tables whose carry-over rule is still `DECIDE`. They are listed loudly and their rows are **not** migrated. **Rehearsal only** |
| `--allow-undecided-policy` | run with the four decisions in `DECISIONS.md` unmade. Among other things, property destroyed by the map change is compensated at **nothing**. **Rehearsal only**; the report is stamped `rehearsal` |
| `--limit N` | sample run: N rows per table. Shakes out the pipeline, proves nothing about completeness |

The target database name is checked twice before anything happens: it must look like scratch
(`scratch`, `rehearsal`, `sandbox`, `dev`, `test`, `tmp`, `staging`) and must not look like
production. It also refuses to drop a database it did not create, refuses a non-local host
unless `PGMIGRATE_ALLOW_REMOTE=1`, and refuses a dump stored inside the repo — a live dump is
real player data and must not be able to reach git.

The steps it runs, if you would rather drive them by hand:

```bash
export PYTHONPATH=tools                     # so `-m pgmigrate.etl` resolves

# transform: stdlib only, no database involved, no network.
# It reconciles source-vs-output itself and refuses to emit anything on a mismatch.
python3 -m pgmigrate.etl \
        --dump   ~/pgmigrate-dumps/live-20260814-1100.sql \
        --out    ~/pgmigrate-work/pgm_scratch/out \
        --report ~/pgmigrate-work/pgm_scratch/report.json

# load: psql, from inside the output directory (load.sql's \copy paths are relative).
# schema_post_load.sql seeds the identity sequences and MUST run last: the rows
# carry their original ids, so a sequence seeded earlier hands the first new
# player an id that already exists.
cd ~/pgmigrate-work/pgm_scratch/out
psql -v ON_ERROR_STOP=1 -d pgm_scratch \
     -f schema.sql -f load.sql -f schema_post_load.sql

# ...or, if psycopg is installed, the ETL can load it directly:
python3 -m pgmigrate.etl --dump … --out … --report … --load "postgresql:///pgm_scratch"
```

The transform writes `schema.sql`, `schema_post_load.sql`, `ddl_report.txt`, `load.sql`,
`data/*.copy`, `jsonl/*.jsonl`, `MANIFEST.json` and `SHA256SUMS` into the output directory,
and the report to `--report`. `data/` is what the database loads; `jsonl/` is the same rows
in the shape `reconcile.py` audits, named by *source* table (pass `--no-jsonl` to skip it,
at the cost of having nothing independent to check the result against). The runner checksums
the output before loading it and, after loading, compares every table's row count in the
database against `MANIFEST.json` — the one boundary the transform's own reconciliation cannot
see, and exactly where a half-applied `\copy` would otherwise look like success.

### 5. Point the dev server at it and look

The dev instance is the inspection tool — a reconciliation report proves the rows arrived,
only a login proves they are *usable*.

```bash
# edit the dev server's database extension config to point at the scratch database,
# then rebuild + restart:
bash /home/timb/arma3server_dev/reload-armapunk2035.sh

# success marker (40-90s):
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
```

Then connect and check, in this order, because this is the order in which the damage is
severe: **money → owned items → licences → gang → vehicles in garage → gear**. Money and
container contents are the two that have historically been destroyed silently
(`postgres_plan.md` §7.1).

### 6. Repeat

Delete the scratch database, take a newer dump, run it again. Two properties are being
rehearsed as much as the data: it must be **idempotent** (re-runnable from a fresh dump with
no hand-cleaning) and **reconciling** (it counts, asserts, and refuses to finish on a
mismatch). If a run ever needs a manual fix-up to succeed, that fix-up is a missing feature.

---

## Decisions a human must make before this can run for real

These are product decisions with a technical floor. The transform holds an `UNDECIDED`
sentinel for each and **refuses to run** until it is replaced — deliberately, so that nobody
discovers the policy by reading what the ETL happened to do. Record the answer in
`DECISIONS.md`, then encode it in `rules.py`.

Rehearsals can proceed without them, because the loop has to exist long before the answers
do — but through **two separate waivers**, because they are two separate refusals:
`--allow-decide` skips tables nobody has ruled on, and `--allow-undecided-policy` proceeds
with the four decisions below unmade. One flag used to do both, which meant a switch named
for the first silently granted the second and turned off every gate this table exists to
enforce. The real run must use neither, and the runner says so on every plan that carries
one.

| # | Decision | Lives in | Why it cannot be deferred |
|---|---|---|---|
| 1 | **What carries.** The map changes, so anything anchored to the old map cannot come. | `rules.CARRY_POLICY` | Every table needs an explicit disposition. An unlisted table is an error, not a skip; anything left on `DECIDE` blocks the run. |
| 2 | **Compensation.** Players who own property will lose it — refund at purchase price, at market value, or grant a credit. | `rules.set_compensation_policy()` + `rules.set_compensation_order()` | Deciding late means deciding under pressure with players watching. Before-scaling and after-scaling are different numbers, so the order is part of the answer. |
| 3 | **Balance scaling.** 1:1 carries the old economy's inflation into an overhauled one. | `rules.set_balance_scale(factor, rounding=…)` | A one-line change now; a live economy problem afterwards. Exact ratio, stated rounding, never a float (see Invariants). 1:1 still has to be confirmed — `BALANCE_SCALE_CONFIRMED` starts `UNDECIDED`. |
| 4 | **The freeze.** When the final dump is taken, whether there is a maintenance window, and whether a known delta is accepted and announced. | `rules.set_freeze(rules.Freeze(…))` | This is the only part of the plan players experience directly. |

`rules.validate()` is the gate that enforces all four; `rules.check()` reports what is open
without raising, and `rules.open_questions()` names every table still marked `DECIDE`.

What cannot carry, regardless of decision 1: `houses.worldspace` (×3 columns),
`storage.worldspace` / `houseworldspace`, `players.position`, `vehicle_mem.worldspace` / `dir`,
turf, cartels, capture points. Vehicles **do** carry — while garaged the rows are non-spatial —
but the transform forces `active = 0` so nothing is resurrected into a world position that no
longer exists.

---

## Invariants the code enforces (and why)

- **Money never becomes a float, anywhere.** The source has a bigint currency column and an
  exact-decimal column; both must round-trip exactly. Values are carried as `int` /
  `decimal.Decimal` from parse to emit, and scaling uses an exact ratio. A float anywhere in
  that path silently rounds every balance above 16,777,216 (`postgres_plan.md` §7.3, §7.4).
- **The old array encoding is transcoded here, once, and never emitted.** JSONB out, always.
  The custom codec is implemented four times in three languages; carrying it across would mean
  running two encodings in production and doing the dangerous conversion with real players
  attached. Transcode at the door (§7.1).
- **Columns are mapped by name, never by position.** The live login read is 30 positional
  columns; a one-column slip there moves every player's money. The same hazard applies to the
  ETL, so nothing in it is index-addressed.
- **`tinyint(1)` becomes `boolean` deliberately, per column — an ALLOWLIST, never a rule.**
  `1` vs `true` is the risk in §11.3 that produces a self-consistently wrong UI with no error
  and no log. The allowlist exists because `players.intake_path` is declared `tinyint(1)` and
  holds 0/1/2/3/9: a blanket rule collapses five states into two, silently for the values 0
  and 1, which are most of them. `rules.boolean_columns()` is handed to the DDL translator so
  the policy and the emitted schema cannot hold different opinions.
- **A dropped column drops the VALUE, not the column.** The target runs the same game code on
  a different map: it writes `players.position` on logout and reads `lastupdated` in its login
  query, and `players.id` is the identity key. So those columns are emitted, nothing populates
  them, the target's own default or identity fills them in, and the run lists them under
  `unpopulated_target_columns` in the report rather than leaving it to be discovered.
- **A value that cannot be transformed is an error naming the table, column and primary key.**
  Never a guess, never a default, never a skipped row.
- **Reconciliation is mandatory.** Players in vs out, total currency in vs out, per-table row
  deltas. Mismatch means non-zero exit and no "completed" claim. The failure mode of a silent
  ETL is discovering three weeks later that 4% of players lost their licences.

---

## What this deliberately does not do

- **No reverse transform.** There is no path back. After the first post-beta login, rollback
  would need a reverse ETL that nobody has written or tested — and this tool is not it.
- **No live sync.** It reads a dump file. A live-connection source mode is optional and, if
  it exists, is read-only; the tool never writes to the source.
- **No dual-write.** The two projects run different engines from a shared ancestry. Nothing
  here keeps them in step, and there is no replication path for the custom encoding.
- **No target schema management.** It emits DDL matching the engine port's schema; it does not
  own that schema and will not invent columns to make a row fit.
- **No product decisions.** See the table above. It refuses rather than defaults.
- **No data repair.** Names mangled by the historical input sanitizers (`O'Brien` stored as
  `OBrien`) and balances already rounded past float-exact range are carried **as stored**.
  Repairing them here would make reconciliation lie.

---

## Failure modes

| Symptom | Cause | What to do |
|---|---|---|
| Refuses to start: `UNDECIDED` in `rules.py` | One of the four decisions is unrecorded | Answer it in `DECISIONS.md`, encode it in `rules.py`. Not a bug. For a rehearsal, `--allow-undecided-policy`. |
| Exit 3, `UNRESOLVED TABLES` | Tables still marked `DECIDE` in `rules.CARRY_POLICY` | `rules.open_questions()` names them. Each needs a disposition, or `--allow-decide` for a rehearsal. |
| `TransformError: players.bankacc pk=… not an exact integer` | Currency reached a float path, or the dump holds a value the column cannot hold | Do not coerce. Find where the float entered; the invariant is the point. |
| Reconciliation fails on total currency | Scaling applied twice, or the rounding direction differs between transform and reconcile | Both must use the same exact ratio and the same stated rounding. |
| Reconciliation fails on row counts for one table | Rows dropped by a carry rule that is not recorded as a deliberate drop | An intentional drop must be declared in `rules.CARRY_POLICY` so reconcile expects it. |
| `TransformError: unknown table <name>` | The dump contains a table with no disposition | Add it to `rules.CARRY_POLICY`, explicitly carried or explicitly dropped. Silence is not an option here by design. Neither waiver excuses it. |
| Refuses: "the COPY header names this column but the translated schema has no such column" | The policy adds a target column (`add_columns`) that the DDL was not told about | Declare the column's type in `rules.CARRY[table].add_columns`. This is the check that stops the ETL reporting success on output `psql` refuses at its first line. |
| Refuses: "compensation: N player(s) are owed credit but have no row in players" | Property valued for an owner with no account row | Decide it explicitly — the credit must not evaporate. Under `--limit` it is a warning, because a sample carries only the first N players. |
| Parse error mid-dump; a table the repo has never heard of | Expected — this project's own additions exist in no `.sql` file. Or the dump was taken without `--routines --triggers --events` | Re-take the dump with the full flags; then teach the parser the table. |
| `ModuleNotFoundError: psycopg` | Only `--load` needs it; the transform is stdlib-only | Load with `psql -f schema.sql -f load.sql` instead — which is what the runner does — or install psycopg. |
| Load fails on duplicate key | Loading into a database that already has rows — i.e. `--keep` on a second run | Drop and recreate (the default), or load into a fresh scratch database. |
| `\copy: No such file or directory` on `data/...` | `load.sql` was run from somewhere other than the output directory; its paths are relative | `cd` into the output directory first. |
| Runner stops: "output checksums do not match SHA256SUMS" | A data file changed after the transform wrote it | Do not load it. Re-run the transform; if it happens again, something else is writing into the output directory. |
| Runner stops: row counts do not match `MANIFEST.json` | The load is incomplete — a `\copy` failed or was rolled back | The run did not succeed regardless of what earlier steps printed. Do not point the dev server at that database. |
| Everything passes, but the numbers look too small | `--limit` was left on: it is a sample, not a migration | Re-run without `--limit`. The plan prints a warning for exactly this. |
| Runner refuses: "target name looks like production" | The guard fired on the database name, host, or DSN | Correct — rename the scratch database. Do not edit the guard. |
| Players spawn at 0,0,0 or inside terrain | An old-map position carried instead of being reset to spawn | `players.position` must be dropped, not translated. Nothing maps between maps. |
| Owned vehicles missing from the garage | `active` not forced to `0` on load | Vehicles carry only because they are non-spatial while garaged. |
| Storage/house containers read as empty in game | Old encoding emitted instead of JSONB, or a decode returned null and something defaulted it | The historical property-destroying bug. `vinv`, `pinv`, `keyholders`, the suite equivalents and `storage_vault` get round-trip assertions first. |
| A free daily action charges the player | `tinyint(1)` → `boolean`: `true isEqualTo 1` is `false` in SQF | §11.3. Grep every `SELECT (<predicate>)` before cutover, not after. |
| Load "succeeded" but the game shows nothing | A fire-and-forget write path swallowing an error — 229 of them have no error channel | Check the server log, not the exit code. Phase 0 of the plan exists for this. |
| Timestamps shifted by hours | Session timezone assumed rather than stated | Timestamps are carried as UTC explicitly; never rely on either engine's session default. |

---

## Files

| File | Role |
|---|---|
| `model.py` | The shared data contract: `Column`, `Table`, `Row`, `Issue`, `TransformError`, and `Money` — the type that makes "currency never becomes a float" a compile-time-ish fact rather than a discipline. Everything imports it. |
| `dump.py` | Streaming reader for a `mysqldump` file: schema and rows, as text. |
| `ddl.py` | MySQL DDL → PostgreSQL DDL translation (the §6 dialect table). |
| `rules.py` | **The four human decisions**, plus the per-table carry dispositions. The file to read first when asking "what will this actually do to my data". |
| `mres.py` | The source's bespoke array codec → JSON. The transcode-at-the-door step. |
| `etl.py` | Orchestrator and CLI. |
| `reconcile.py` | The independent auditor: its own dump parser, per-player id sets, exact currency totals, property round-trips. Wired into `run_rehearsal.sh` as step 2, and it gates the run. |
| `carryover_spec.py` | The auditor's `--spec`, generated from `rules.py` so the two cannot drift. |
| `testdata_fixture_dump.sql` | A small synthetic dump, shaped like the live schema, for the end-to-end test. Not real data. |
| `test_integration.py` | Runs the real `ddl` + `rules` + `mres` together over that fixture and checks the seams between them. |
| `test_mres.py` | Round-trip tests for the codec — the one part that can be tested without a dump. |
| `README.md` | This file. |
| `DECISIONS.md` | Where the four answers are recorded, with who decided and when. |
| `run_rehearsal.sh` | The rehearsal loop, guarded and idempotent. |

### The auditor, and what it is for

`reconcile.py` is the strongest check in the package. It re-reads the SOURCE DUMP with its
own parser and its own decoder and re-derives every total independently, because a transform
bug and the transform's own idea of what it produced share a cause. It compares player ids
one at a time rather than as counts — "541 in, 541 out" hides one lost plus one duplicated
perfectly — sums currency as exact integers, and round-trips every transcoded property column
back to the structure the source held.

It runs as **step 2** of `run_rehearsal.sh`, before any database is touched, and a non-zero
exit fails the rehearsal. Its `--spec` is `carryover_spec.py`, which is generated from
`rules.py` rather than written by hand: a hand-written spec is a second copy of the policy,
and when the two drift the failure is a table that quietly stopped carrying and reconciled
clean because the spec still expected zero rows. The independence that matters is the parser
and the decoder, not retyping the rules.

Two honest limits. The auditor has never met a real dump either, so the first real run should
be assumed to find bugs in **it** before it finds bugs in the carry-over. And a check it did
not run is reported as a warning naming the table, rather than being absent from the report —
"nothing was checked here" and "everything checked out" must not look the same.

Run what tests exist:

```bash
cd tools && python3 -m unittest discover -s pgmigrate -v
```

386 of them, two skipped by default. They cover the codec, the DDL translation, the dump readers, the
policy, the orchestrator's refusals, and — in `test_integration.py` — the seams between those
modules against a synthetic fixture. The two skipped ones load into a real PostgreSQL and run
only when `PGMIGRATE_TEST_DSN_DISPOSABLE` names a database they may DESTROY:
`test_ddl` loads the translated dev schema, and `test_integration` loads the ETL's own
output and reads the values back. Without that variable nothing in a run has met a server.

None of that is evidence the migration works. Passing tests here mean the encoding
round-trips on the cases someone thought of, and that the modules agree with each other about
a fixture someone wrote. Only a real dump shows the rest.

Core transform: Python 3, **stdlib only**. `psycopg` is imported lazily and only in the load
step, so the transform runs anywhere — including on a box that has no database client at all.
