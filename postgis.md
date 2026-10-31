# postgis.md — PostGIS on the dev database (2026-09-04)

**Why:** the owner asked for it the day mapdb landed. Three uses, all built the same day:
a spatial index on `map_objects`, the fixer territories as real polygons, and a query tool.

## Install (done on dev; repeat for any stand-up)

- `deploy/postgres/compose.yml` image is `postgis/postgis:18-3.6` (the `18-3.5` tag does not exist).
  Same PG 18 major, same `armapunk_pg_data` volume, same env; `docker compose up -d` recreates the
  container in place. `PGPASSWORD` must be in the environment (the gitignored `.env` is absent on
  this box: `export PGPASSWORD="$(sed -n 's/.*password=\([^ ]*\).*/\1/p' ~/.pysqf_dsn)"`).
- Dump first: `docker exec armapunk-pg pg_dump -U armapunk -d pgm_full_scratch | gzip > ~/db_backups/...`
  (2026-09-04: `pgm_full_scratch_pre_postgis_20260904_221322.sql.gz`, 70 tables).
- `docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -v ON_ERROR_STOP=1 < deploy/postgis.sql`
- Bounce the daemon so its pool reconnects: `kill $(pgrep -f 'pysqf-venv/bin/python pysqfd.py')`
  (supervise-daemon respawns it; the game reconnects). One in-flight query sees `AdminShutdown`.
- Verify: `SELECT postgis_full_version()` → 3.6.4 / GEOS 3.14.1; `map_cell_key(7500,10500,NULL)` = `7_10`.

## What `deploy/postgis.sql` adds

| object | purpose |
|---|---|
| `map_objects.geom` | generated `Point(x,y)` SRID 0 (planar metres), GiST index on live rows |
| `map_cell_key(x, y, stream_r)` | the streamer's cell rule in SQL; `tools/test_map_cell_key.py` keeps its constants equal to `fn_mapCfg.sqf` |
| `faction_territory` | `faction_id`, `points` (the SQF literal the game parses), `geom` (closed ring, `ST_IsValid` CHECK), `rev` |

## Territories

- `tools/bake_territory.py <MaldenEdit sqm>` reads the `aq_terr_<id>_pN` markers and UPSERTs the
  table (`--check` dry-run, `--sqf` also refreshes the fallback literal in `fn_factionCfg.sqf`,
  `--seed-from-cfg` was the one-off copy of the literal into the table).
- Server boot (`APS_fnc_territoryLoad`, after `mapLoad`) publishes `AP_factionPolys`;
  `fn_factionCfg` overlays the polygons by id over its literals; clients flush
  `AP_fnc_factionTerritory`'s cache on the publicVariable. Bot verb `territoryreload` re-publishes
  after a bake — no repack, no restart.
- The HC self-test phase `territory` is the regression check (centroids resolve through both lookups).

## Tools

`~/pysqf-venv/bin/python tools/map_query.py near X Y R | bbox X1 Y1 X2 Y2 | cell KEY | cells |
territories | nearest X Y [N]` — ST_DWithin / envelope / KNN (`<->`) / ST_Contains. First answers:
f_dock 0.82 km² 724 rows, f_neon 0.49 km² 40 rows, f_pharma 0.56 km² 647 rows.

## Not done

Pavement-tile overlap detection (ST_Intersects) needs per-class footprints; the old `dezfight`
pass in `map_codegen.py` is unwired since `apply` retired. Follow-up.
