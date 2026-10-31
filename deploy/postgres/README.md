# Dev PostgreSQL — handover

> **The dev database is `pgm_full_scratch`, not `armapunk`.** 66 tables and the real player rows
> live there; `armapunk` is an empty shell the container auto-created and nothing uses. The name is
> a fossil of how it was made (the ETL full-run scratch target). `rename-dev-db.sh` in this
> directory fixes it properly — dump, stop, rename, repoint `/etc/conf.d/pysqfd`, restart — and
> needs root for that conf file alone.

The database PySQF talks to. Stood up 2026-08-14 so smoke-test stage 5 has a
target. See `postgres_plan.md` for why any of this exists.

**Dev only.** Loopback-bound, no backups, no tuning, statement logging on. When
there is a real deployment target this file is the starting point, not the
answer.

---

## Connection

| | |
|---|---|
| host | `127.0.0.1` |
| port | `5432` |
| database | `armapunk` |
| user | `armapunk` |
| password | **`deploy/postgres/.env`** — gitignored, never committed |
| server | PostgreSQL 18.6 (container `armapunk-pg`) |

```
PYSQF_DB_DSN='host=127.0.0.1 port=5432 user=armapunk password=<from .env> dbname=pgm_full_scratch'
```

It is bound to loopback deliberately. If the daemon ever runs somewhere other
than this box, change the DSN — do not change the binding.

---

## Start the daemon against it

```sh
cd ~/PySQF/python
PYSQF_SOCKET=/run/user/$(id -u)/pysqf.sock \
PYSQF_DB_DSN="$(grep -h . /path/to/deploy/postgres/.env | sed -n 's/^PGPASSWORD=/password=/p' | \
                 xargs -I{} echo "host=127.0.0.1 port=5432 user=armapunk dbname=pgm_full_scratch {}")" \
~/pysqf-venv/bin/python pysqfd.py
```

Or more simply, read the three values out of `.env` and paste them. Then in the
server console:

```sqf
[] spawn APS_fnc_pysqfSmoke;
```

Stage 5 should go green. Stages 1–4 already passed on 2026-08-14.

**`PYSQF_SOCKET` must be identical for the daemon and the server process.** A
mismatch is the most likely failure and it presents as "Python is down" rather
than "you typed two different paths".

---

## Managing it

```sh
cd deploy/postgres
docker compose up -d          # start
docker compose ps             # health
docker compose logs -f        # statement log — every query, on purpose
docker compose down           # stop, KEEP data
docker compose down -v        # stop, DESTROY data (this is fine and expected)
```

Destroying and recreating is the normal move while the ETL is being rehearsed.
Nothing in here is precious.

### Reload the schema

```sh
cd tools
python3 -m pgmigrate.etl --dump ../sql/looneybin_dev_schema.sql \
  --out /tmp/pgout --report /tmp/pg.json --allow-decide --allow-undecided-policy
PGPASSWORD=<from .env> psql -h 127.0.0.1 -U armapunk -d armapunk -v ON_ERROR_STOP=1 \
  -f /tmp/pgout/schema.sql -f /tmp/pgout/schema_post_load.sql
```

The two `--allow-*` flags are **rehearsal only**. They waive the four product
decisions in `tools/pgmigrate/DECISIONS.md`; a real run must not use them.

---

## Verified 2026-08-14

- container healthy, PostgreSQL 18.6, reachable on loopback
- schema loaded under `ON_ERROR_STOP=1` — **12 tables**
- PySQF's own `db.query` reached it through the dispatch path:
  `select 1` → `[{"ok": 1}]`, and a parameterised catalogue query → `[{"t": 12}]`

Not verified: anything through Arma. That is the other instance's job, and it
is what stage 5 exists to report.

---

## One gotcha worth knowing

The `postgres:18+` images **changed the volume layout**. The mount must be
`/var/lib/postgresql`, *not* `/var/lib/postgresql/data`. Data now lives in a
major-version subdirectory so `pg_upgrade --link` does not cross a mount
boundary.

Get it wrong and the container crash-loops with a long message that reads like a
corruption warning. Every pre-18 compose file you will find online has the old
path, so this will bite anyone copying one. It bit this file first.

## PostGIS (2026-09-04)

The image is `postgis/postgis:18-3.6` (PostGIS 3.6.4 on the same PG 18 layout). `deploy/postgis.sql`
adds the geometry column, the cell-key function and the `faction_territory` table; run it after any
recreate. `docker compose` needs `PGPASSWORD` in the environment on a box without `.env`. Full
notes and the verify steps: `postgis.md`.
