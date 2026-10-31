#!/usr/bin/env bash
#
# run_rehearsal.sh -- the pgmigrate rehearsal loop, guarded end to end.
#
#   tools/pgmigrate/run_rehearsal.sh <dump.sql> <target-db> [flags]
#
# PURPOSE
#   Drive one full pass of the carry-over rehearsal: transform a mysqldump of the live
#   MariaDB database, load it into a *scratch* PostgreSQL database, and verify that every row
#   the transform says it wrote is actually in the database. Then you point the dev server at
#   that database and look at it.
#
# WHY THIS EXISTS
#   The carry-over is a one-time, one-direction, no-rollback event at open beta. The only
#   thing that makes that survivable is having run it, from a fresh dump, so many times that
#   it is boring. A loop nobody can run in one command is a loop nobody runs. Equally: the
#   loop lives one typo away from a production database name, so every destructive step here
#   is guarded by a check that fires *before* the damage, not by a habit of being careful.
#
# WHAT IT WILL NOT DO
#   - It never connects to the live database. Its input is a file. Taking the dump is a
#     separate, deliberate, human act (see README).
#   - It refuses any target that looks like production, by name, by host or by DSN.
#   - It refuses to drop a database it did not create.
#   - It never writes inside the repo, so a dump full of real player data cannot be committed.
#
# STATUS
#   NEVER RUN AGAINST REAL DATA. Nothing here has met a real dump. Assume the first real run
#   fails, and run it somewhere that does not matter.
#
# Usage:
#   tools/pgmigrate/run_rehearsal.sh ~/pgmigrate-dumps/live-20260814-1100.sql pgm_scratch
#   tools/pgmigrate/run_rehearsal.sh ~/pgmigrate-dumps/live.sql pgm_scratch --dry-run
#   tools/pgmigrate/run_rehearsal.sh ~/pgmigrate-dumps/live.sql pgm_scratch --allow-decide
#   tools/pgmigrate/run_rehearsal.sh ~/pgmigrate-dumps/live.sql pgm_scratch --limit 500
#   tools/pgmigrate/run_rehearsal.sh ~/pgmigrate-dumps/live.sql pgm_scratch --transform-only
#
# Idempotent: a second run with the same arguments reaches the same end state -- the work
# directory is rebuilt from scratch and the target database is dropped and recreated. Nothing
# accumulates, and no run depends on state left by the previous one.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG_DIR="$REPO/tools/pgmigrate"

# --------------------------------------------------------------------------- guards, as data
# A target is acceptable only if it matches ALLOW *and* misses DENY. Both, on purpose: a
# deny-list alone lets through a name nobody thought of, an allow-list alone lets through
# "live_scratch_prod_backup".
NAME_ALLOW='(scratch|rehearsal|sandbox|dev|test|tmp|staging)'
# "beta" is denied as well: the beta database is the one this ETL exists to create for real,
# and it is the one target a rehearsal must never be pointed at by accident.
NAME_DENY='(prod|production|live|master|primary|release|public|main|backup|real|beta)'

die()  { printf '\nrun_rehearsal: FATAL: %s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

# --------------------------------------------------------------------------- arguments
DUMP=""; TARGET_DB=""
DRY_RUN=0; ASSUME_YES=0; TRANSFORM_ONLY=0; KEEP_DB=0
ALLOW_DECIDE=0; ALLOW_UNDECIDED_POLICY=0; LIMIT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)        DRY_RUN=1 ;;
    --yes|-y)         ASSUME_YES=1 ;;
    --transform-only) TRANSFORM_ONLY=1 ;;
    --keep)           KEEP_DB=1 ;;
    --allow-decide)   ALLOW_DECIDE=1 ;;
    --allow-undecided-policy) ALLOW_UNDECIDED_POLICY=1 ;;
    --limit)          shift; [ $# -gt 0 ] || die "--limit needs a row count"; LIMIT="$1" ;;
    -h|--help)        sed -n '2,42p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)               die "unknown flag: $1" ;;
    *)
      if   [ -z "$DUMP" ];      then DUMP="$1"
      elif [ -z "$TARGET_DB" ]; then TARGET_DB="$1"
      else die "unexpected extra argument: $1"
      fi ;;
  esac
  shift
done

[ -n "$DUMP" ]      || die "no dump file given. Usage: run_rehearsal.sh <dump.sql> <target-db> [flags]"
[ -n "$TARGET_DB" ] || die "no target database given. Usage: run_rehearsal.sh <dump.sql> <target-db> [flags]"
if [ -n "$LIMIT" ]; then
  printf '%s' "$LIMIT" | grep -Eq '^[1-9][0-9]*$' || die "--limit must be a positive integer, got '$LIMIT'"
fi

# --------------------------------------------------------------------------- guard: the dump
[ -e "$DUMP" ] || die "dump not found: $DUMP"
[ -f "$DUMP" ] || die "not a regular file: $DUMP"
[ -r "$DUMP" ] || die "dump is not readable: $DUMP"
[ -s "$DUMP" ] || die "dump is empty: $DUMP -- a zero-byte dump means the dump command failed"
DUMP="$(cd "$(dirname "$DUMP")" && pwd)/$(basename "$DUMP")"

case "$DUMP" in
  "$REPO"/*)
    die "the dump is inside the repo ($DUMP).
       A live dump is real player data and must never be able to reach git.
       Move it somewhere outside $REPO -- ~/pgmigrate-dumps/ is the documented home." ;;
esac

# --------------------------------------------------------------------------- guard: the target
printf '%s' "$TARGET_DB" | grep -Eq '^[a-z][a-z0-9_]*$' \
  || die "target database name must be lowercase [a-z][a-z0-9_]*: '$TARGET_DB'
       (quoting-sensitive names are refused so no step here has to quote an identifier)"

printf '%s' "$TARGET_DB" | grep -Eqi "$NAME_ALLOW" \
  || die "target '$TARGET_DB' does not look like a scratch database.
       It must contain one of: scratch, rehearsal, sandbox, dev, test, tmp, staging.
       This is a rehearsal runner; it has no legitimate non-scratch target."

if printf '%s' "$TARGET_DB" | grep -Eqi "$NAME_DENY"; then
  die "target '$TARGET_DB' looks like production. Refusing.
       Rename the scratch database. Do not relax this check -- it is the only thing
       standing between a typo and a database with players in it."
fi

PGHOST_EFF="${PGHOST:-local-socket}"
if printf '%s' "$PGHOST_EFF" | grep -Eqi "$NAME_DENY"; then
  die "PGHOST='$PGHOST_EFF' looks like production. Refusing."
fi
case "$PGHOST_EFF" in
  local-socket|localhost|127.0.0.1|::1|/*) : ;;
  *)
    [ "${PGMIGRATE_ALLOW_REMOTE:-0}" = "1" ] \
      || die "PGHOST='$PGHOST_EFF' is not local. Rehearsals belong on a throwaway local
       instance. If you genuinely mean a remote scratch host, set PGMIGRATE_ALLOW_REMOTE=1
       -- the production name check above still applies." ;;
esac

# --------------------------------------------------------------------------- work directory
# Outside the repo, deterministic per target, and stamped so this script can tell its own
# scratch space from a directory someone else cares about.
WORK="${PGMIGRATE_WORK:-$HOME/pgmigrate-work}/$TARGET_DB"
WORK_MARKER="$WORK/.pgmigrate-work"
case "$WORK" in "$REPO"/*) die "work directory would be inside the repo: $WORK" ;; esac
if [ -e "$WORK" ] && [ ! -e "$WORK_MARKER" ] && [ -n "$(ls -A "$WORK" 2>/dev/null || true)" ]; then
  die "work directory $WORK exists, is not empty, and was not created by this script
       (no .pgmigrate-work marker). Refusing to delete it. Move it aside, or set
       PGMIGRATE_WORK to a different root."
fi

# --------------------------------------------------------------------------- entry point
# Resolve the ETL rather than assume it, and fail naming every path tried -- a silent
# fallback here would run some *other* script over real player data.
command -v python3 >/dev/null 2>&1 || die "python3 not found"
export PYTHONPATH="$REPO/tools${PYTHONPATH:+:$PYTHONPATH}"
if   [ -f "$PKG_DIR/etl.py" ];      then CLI=(python3 -m pgmigrate.etl)
elif [ -f "$PKG_DIR/__main__.py" ]; then CLI=(python3 -m pgmigrate)
else
  die "no pgmigrate entry point. Tried:
         $PKG_DIR/etl.py        (python3 -m pgmigrate.etl)
         $PKG_DIR/__main__.py   (python3 -m pgmigrate)"
fi

if [ "$TRANSFORM_ONLY" -eq 0 ]; then
  for tool in psql createdb dropdb; do
    command -v "$tool" >/dev/null 2>&1 \
      || die "$tool not found -- needed for the load step. Use --transform-only to stop
       before any database work (the transform itself is stdlib-only and needs no client)."
  done
  # Checked here, before the transform spends minutes on a dump, rather than at createdb.
  # --dry-run still reports it rather than dying: a plan you cannot print is not a dry run.
  if ! psql -tAc 'SELECT 1' postgres >/dev/null 2>&1; then
    [ "$DRY_RUN" -eq 1 ] \
      || die "cannot reach a PostgreSQL server (host: $PGHOST_EFF).
       Start one, or use --transform-only."
    PG_UNREACHABLE=1
  fi
fi

# --------------------------------------------------------------------------- the plan, first
DB_EXISTS=n/a
if [ "$TRANSFORM_ONLY" -eq 0 ] && [ "${PG_UNREACHABLE:-0}" -eq 0 ]; then
  DB_EXISTS=no
  if psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB'" postgres 2>/dev/null \
       | grep -q 1; then DB_EXISTS=yes; fi
elif [ "${PG_UNREACHABLE:-0}" -eq 1 ]; then
  DB_EXISTS="unknown -- NO SERVER REACHABLE, this plan cannot run as-is"
fi

XFORM_ARGS=(--dump "$DUMP" --out "$WORK/out" --report "$WORK/report.json")
[ "$ALLOW_DECIDE" -eq 1 ] && XFORM_ARGS+=(--allow-decide)
[ "$ALLOW_UNDECIDED_POLICY" -eq 1 ] && XFORM_ARGS+=(--allow-undecided-policy)
[ -n "$LIMIT" ] && XFORM_ARGS+=(--limit "$LIMIT")

cat <<PLAN

pgmigrate rehearsal -- PLAN (nothing has happened yet)

  source dump      $DUMP
                   $(wc -c < "$DUMP" | tr -d ' ') bytes, read-only, never modified
  target database  $TARGET_DB   (host: $PGHOST_EFF, exists already: $DB_EXISTS)
  work directory   $WORK
  entry point      ${CLI[*]}

  Steps:
    1. transform   dump -> $WORK/out      (stdlib only, no database, no network)
                   report -> $WORK/report.json
                   the transform reconciles internally and refuses to emit on a mismatch
    2. audit       reconcile.py re-reads the DUMP with its OWN parser and re-derives every
                   total: player ids one at a time, currency exactly, property round-trips.
                   No database needed, and it gates the run.
PLAN
if [ "$TRANSFORM_ONLY" -eq 1 ]; then
  cat <<'PLAN'
    (--transform-only: stopping there. No database is created, dropped or written.)
PLAN
elif [ "$KEEP_DB" -eq 1 ]; then
  cat <<PLAN
    3. KEEP        $TARGET_DB left as-is (--keep). Loading a second time into a populated
                   database will fail on duplicate keys -- that is the intended, loud result.
    4. load        schema.sql + load.sql via psql into $TARGET_DB
    5. verify      MANIFEST.json row counts vs SELECT count(*) in the database
PLAN
else
  cat <<PLAN
    3. DESTRUCTIVE drop database $TARGET_DB (only if this script created it) and recreate it
    4. load        schema.sql + load.sql via psql into $TARGET_DB
    5. verify      MANIFEST.json row counts vs SELECT count(*) in the database
PLAN
fi
if [ "$ALLOW_DECIDE" -eq 1 ]; then
  cat <<'PLAN'

  --allow-decide: proceeding with tables whose carry-over rule is still UNDECIDED. Their rows
  are NOT migrated. REHEARSAL ONLY.
PLAN
fi
if [ "$ALLOW_UNDECIDED_POLICY" -eq 1 ]; then
  cat <<'PLAN'

  --allow-undecided-policy: proceeding with whichever decisions in DECISIONS.md are still
  unmade. It WAIVES THE GATE, it does not erase an answer -- a decision that has been made is
  still applied, and compensation that has a policy is still paid. The transform prints which
  ones were actually unanswered. REHEARSAL ONLY, and the report is stamped 'rehearsal'.
PLAN
fi
if [ -n "$LIMIT" ]; then
  cat <<PLAN

  --limit $LIMIT: SAMPLE RUN. Row counts will not match the source and this proves nothing
  about completeness. Useful for shaking out the pipeline, useless as a rehearsal result.
PLAN
fi
cat <<PLAN

  Also destructive: $WORK is emptied and rebuilt.
  Not touched: the live database, the repo, and anything not named above.

PLAN

[ "$DRY_RUN" -eq 1 ] && { echo "--dry-run: stopping here."; exit 0; }

if [ "$ASSUME_YES" -ne 1 ]; then
  [ -t 0 ] || die "not a terminal and --yes not given. Refusing to run destructive steps
       unattended without an explicit --yes."
  printf 'Proceed? [y/N] '
  read -r reply </dev/tty
  case "$reply" in y|Y|yes|YES) : ;; *) echo "aborted."; exit 1 ;; esac
fi

# --------------------------------------------------------------------------- 1. transform
step "1/5 transform"
rm -rf "$WORK"
mkdir -p "$WORK"
: > "$WORK_MARKER"
note "work directory rebuilt: $WORK"
"${CLI[@]}" "${XFORM_ARGS[@]}"
note "transform complete -> $WORK/out (report: $WORK/report.json)"

# The output must be complete before anything loads it. A missing artefact here means the
# transform exited zero without promoting, which is a bug worth stopping on.
for f in schema.sql load.sql MANIFEST.json SHA256SUMS; do
  [ -f "$WORK/out/$f" ] || die "transform produced no $f in $WORK/out"
done
if command -v sha256sum >/dev/null 2>&1; then
  ( cd "$WORK/out" && sha256sum -c SHA256SUMS --quiet ) \
    || die "output checksums do not match SHA256SUMS in $WORK/out -- the data files changed
       after the transform wrote them. Do not load this."
  note "checksums verified against SHA256SUMS"
fi

# --------------------------------------------------------------------------- 2. audit
# The independent auditor. Row counts alone would not catch one player lost plus one
# duplicated -- they cancel perfectly -- so this re-reads the SOURCE DUMP with its own parser
# and its own decoder and re-derives every total: per-player ids one at a time, currency as
# exact integers, every transcoded property column round-tripped back to the structure the
# source held. A gate, not a report: a non-zero exit fails the rehearsal.
step "2/5 audit (independent reconciliation, no database needed)"
if [ ! -f "$PKG_DIR/reconcile.py" ] || [ ! -f "$PKG_DIR/carryover_spec.py" ]; then
  die "reconcile.py or carryover_spec.py is missing -- this loop will not report success on
       row counts alone. Restore them, or say out loud what is not being checked."
fi
if [ ! -d "$WORK/out/jsonl" ]; then
  die "the transform wrote no jsonl/ tree, so the auditor has nothing to read (was
       --no-jsonl passed?). Row counts alone are not a rehearsal result."
fi
# ALLOW_UNRESOLVED mirrors the transform's own waiver: with tables still undecided there is no
# auditor rule for them, and the spec says so rather than inventing one.
if [ "$ALLOW_DECIDE" -eq 1 ]; then export PGMIGRATE_ALLOW_UNRESOLVED=1
else export PGMIGRATE_ALLOW_UNRESOLVED=0; fi
AUDIT_STATUS=0
python3 "$PKG_DIR/reconcile.py" \
  --dump "$DUMP" \
  --output "$WORK/out/jsonl" \
  --spec "$PKG_DIR/carryover_spec.py" \
  --report "$WORK/reconcile.json" \
  --omit-run-meta || AUDIT_STATUS=$?
if [ "$AUDIT_STATUS" -ne 0 ]; then
  die "the independent audit FAILED (exit $AUDIT_STATUS). Report: $WORK/reconcile.json
       This run did NOT succeed. The transform reconciled against its own idea of the data;
       the auditor re-derived it from the dump and disagreed. Read the findings before
       changing anything -- the first suspect is the auditor itself, which has never met a
       real dump either."
fi
note "independent audit passed: $WORK/reconcile.json"

if [ "$TRANSFORM_ONLY" -eq 1 ]; then
  cat <<DONE

--transform-only: done. The transform reconciled and the independent audit passed.
No database was touched.
Read $WORK/report.json, then re-run without the flag to load it.
DONE
  exit 0
fi

# --------------------------------------------------------------------------- 2. scratch db
# The marker table is how the drop guard knows this database is ours. A database without it
# is one this script did not create, and it is not this script's business to delete it.
MARKER_TABLE="pgmigrate_scratch_marker"

step "3/5 scratch database"
if [ "$KEEP_DB" -eq 1 ]; then
  note "--keep: leaving $TARGET_DB exactly as it is"
  [ "$DB_EXISTS" = yes ] || die "--keep given but database $TARGET_DB does not exist"
else
  if [ "$DB_EXISTS" = yes ]; then
    has_marker="$(psql -tAc "SELECT to_regclass('public.$MARKER_TABLE') IS NOT NULL" \
                    "$TARGET_DB" 2>/dev/null || echo f)"
    if [ "$has_marker" != "t" ]; then
      die "database '$TARGET_DB' exists but has no $MARKER_TABLE table, so this script did
       not create it. Refusing to drop a database that belongs to someone else.
       Drop it by hand if you are certain, or pick another name."
    fi
    note "dropping $TARGET_DB (marker present -- this script created it)"
    dropdb "$TARGET_DB"
  fi
  note "creating $TARGET_DB"
  createdb "$TARGET_DB"
  psql -q -v ON_ERROR_STOP=1 -d "$TARGET_DB" -c \
    "CREATE TABLE $MARKER_TABLE (
       created_at timestamptz NOT NULL DEFAULT now(),
       dump_path  text        NOT NULL,
       note       text        NOT NULL
     );
     INSERT INTO $MARKER_TABLE (dump_path, note)
     VALUES ('$(printf '%s' "$DUMP" | sed "s/'/''/g")',
             'pgmigrate rehearsal scratch database -- safe to drop');"
  note "marker table $MARKER_TABLE written"
fi

# --------------------------------------------------------------------------- 3. load
# psql, not psycopg: load.sql uses \copy with paths relative to the output directory, and the
# transform is deliberately importable without any third-party package. Run from $WORK/out so
# those relative paths resolve.
step "4/5 load"
( cd "$WORK/out" && psql -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f schema.sql -f load.sql >/dev/null )
note "schema.sql + load.sql applied to $TARGET_DB"

# --------------------------------------------------------------------------- 4. verify
# The transform reconciles source-vs-output on its own and refuses to emit on a mismatch.
# This step covers the boundary it cannot see: output files vs what is actually in the
# database. A half-applied \copy is exactly the failure that would otherwise look like success.
step "5/5 verify rows in the database"
python3 - "$WORK/out/MANIFEST.json" > "$WORK/verify.sql" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as fh:
    manifest = json.load(fh)
tables = manifest.get("tables") or {}
if not tables:
    sys.exit("MANIFEST.json lists no tables -- nothing was carried, which is not a "
             "successful rehearsal")
parts = []
for name, spec in sorted(tables.items()):
    target = str(spec["target"])
    if '"' in target:
        sys.exit("refusing to build SQL for a target name containing a quote: %r" % target)
    label = name.replace("'", "''")
    parts.append("SELECT '%s' AS tbl, %d::bigint AS expected, "
                 '(SELECT count(*) FROM "%s") AS actual' % (label, int(spec["rows"]), target))
print("SELECT tbl, expected, actual FROM (\n  "
      + "\n  UNION ALL ".join(parts)
      + "\n) s WHERE expected <> actual ORDER BY tbl;")
PY

MISMATCH="$(psql -tA -F' ' -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$WORK/verify.sql")"
if [ -n "$MISMATCH" ]; then
  printf '%s\n' "$MISMATCH" >&2
  die "row counts in $TARGET_DB do not match MANIFEST.json (table expected actual, above).
       The load is incomplete. This run did NOT succeed -- do not point anything at it."
fi
note "every table's row count matches MANIFEST.json"


cat <<DONE

== rehearsal complete: $TARGET_DB

The transform reconciled, the independent auditor re-derived the same answer from the dump,
and every row is in the database. That proves the rows arrived intact; it does not prove they
are usable. Only a login does. Next:

  1. Point the dev server's database extension config at '$TARGET_DB'.
  2. bash /home/timb/arma3server_dev/reload-armapunk2035.sh
  3. grep "read from bank" /home/timb/arma3server_dev/loonydev.log     # 40-90s
  4. Connect and check, in this order of severity:
       money -> owned items -> licences -> gang -> vehicles in garage -> gear
  5. Take a newer dump and run this again. Repeat until boring.

Artefacts: $WORK/out    transform report: $WORK/report.json    audit: $WORK/reconcile.json
DONE
