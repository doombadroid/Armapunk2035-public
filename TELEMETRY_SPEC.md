# Telemetry — server + client metrics into VictoriaMetrics / Grafana

Spec, owner-approved 2026-09-09 ("go with option A, don't stop until it's complete").
Companion plan: `telemetry_plan.md`. Lives at the repo root because `docs/` is git-ignored.

## Goal

Ship live game-state numbers (server FPS, player FPS, entity counts, script load, scheduler and
DB health) out of the Arma process into a time-series store, and put them on a Grafana side
monitor. The use-case is the one from the Arma Discord thread that prompted this: "why is the
server at 12 FPS", "why are there 1200 rockets", "what did that mission do to everyone's
client FPS" — answered from a graph, not from guesswork in the RPT.

## What already exists and is reused

- **`armapunk-pysqfd`** (PySQF daemon, Unix socket, 8-worker thread pool, modules loaded via
  `--modules`). This is the "job server" role from the thread. `tools/pysqf_modules` is already on
  its `PYTHONPATH`. A new module = one Python file + one flag edit.
- **`APS_fnc_pysqfCall`** — the only way mission code talks to the daemon. Scheduled-context only,
  returns `[true, value]` / `[false, "why"]`.
- **Server scheduler wheel** (`AP_fnc_schedule`, `core/system/fn_scheduler.sqf`) — jobs run in
  short transient spawns, jittered, error-isolated. Telemetry adds two jobs, no new loops.
- **CfgRE.hpp** whitelist, `allowedTargets = 2` for client → server requests; the server derives
  the caller from `remoteExecutedOwner`, never from the payload (`sec-log-attribution-rule`).
- **`AP_hcOwner`** — the server-authoritative headless-client owner id (server `init.sqf:10-13`).
- **.96 box**: docker + compose 5.1.4, 6 GB RAM free, ports 3000/8428 free, cloudflared tunnel
  `armapunk` (system unit, `~/.cloudflared/armapunk.yml`, origincert `cert-armapunk.pem`).

## Verified constraints (measured this session, not assumed)

- Arma **2.22.154045** on both live and dev has **no WebSocket script commands** (`strings` over the
  binaries: zero hits). The thread's transport is dev-branch only. PySQF is the transport here.
- `diag_activeScripts`, `diag_activeSQFScripts`, `diag_fpsMin`, `allSimpleObjects`,
  `allMissionObjects`, `remoteExecutedOwner`, `getUserInfo` all present in the 2.22 binary.
- VictoriaMetrics `v1.151.0` accepts Prometheus exposition lines with millisecond timestamps at
  `POST /api/v1/import/prometheus` (204). Its default `-search.latencyOffset=30s` hides the last 30 s
  from queries — **the live instance runs with `-search.latencyOffset=1s`** or a 5 s dashboard is
  always half a minute stale.
- **SQF numbers are 32-bit floats.** An epoch timestamp in ms (1.7e12) cannot cross the boundary
  intact, so **the Python module stamps every sample on receipt**; SQF never sends timestamps.
- `docs/` is git-ignored (`.gitignore:46`): spec and plan live at the repo root like every other
  `*_SPEC.md` / `*_plan.md` here.
- `AP_fnc_MP` audit watch-list contains no substring of `telemetrybeat`, so the client beat does
  not generate `-FNCALL-` log rows.

## Architecture

```
client / HC  --10 s--> APS_fnc_telemetryBeat (server, CfgRE allowedTargets=2)
                              |  writes AP_telemetry_clients[uid]
server 5 s job  ------------> telemetry.push([[name, labels, value], ...])   (one pysqf call)
server 60 s job (census) ---> telemetry.push(top-40 typeOf histogram)
                              |
                       pysqfd module telemetry.py: stamp ts, host label, bounded queue,
                       flusher thread -> POST /api/v1/import/prometheus (VictoriaMetrics :8428)
                              |
                       Grafana :3000 (provisioned datasource + 3 dashboards)
                              |
                       https://grafana.armapunk.com  (cloudflared armapunk tunnel, Grafana login)
```

Every stage is fire-and-forget toward the game: `telemetry.push` returns `True` immediately, the
HTTP POST happens on the module's own daemon thread, and a dead sink costs the game nothing but a
counter.

## Metrics (Prometheus names, prefix `ap_`; every sample gets `host="live"` from the daemon)

Server job `telemetryServer`, every 5 s, labels `machine="server"`:

| name | labels | source |
|---|---|---|
| `ap_server_fps`, `ap_server_fps_min` | | `diag_fps`, `diag_fpsMin` |
| `ap_players` | `side=west\|civ\|guer` | `allPlayers - entities "HeadlessClient_F"`, by `side` |
| `ap_players_total` | | same, count |
| `ap_hc_online` | | `AP_hcOwner > 0` → 1/0 |
| `ap_entities` | `kind=units\|vehicles\|dead\|groups\|simple\|mission_objects\|weapon_holders\|mines` | `allUnits`, `vehicles`, `allDead`, `allGroups`, `allSimpleObjects []`, `allMissionObjects "All"`, `allMissionObjects "WeaponHolder"`, `allMines` |
| `ap_scripts` | `kind=spawn\|execvm\|exec\|fsm` | `diag_activeScripts` |
| `ap_sqf_scripts_active` | | `count diag_activeSQFScripts` |
| `ap_sched_last_ms`, `ap_sched_errors` | `job=<id>` | `AP_scheduler_jobs` tuple slots 6 and 5 |
| `ap_sched_jobs_enabled` | | count of tuples with slot 4 true |
| `ap_pysqf` | `stat=issued\|completed_ok\|completed_err\|pending\|refused\|dropped_late\|evicted_pending\|evicted_complete` | `["stats"] call APS_fnc_pysqfRaw` → `fromJSON` |
| `ap_db_rtt_ms` | | wall time of a mode-2 `SELECT 1` through `DB_fnc_asyncQuery` |
| `ap_mission_time_s`, `ap_server_time_s`, `ap_process_uptime_s` | | `time`, `serverTime`, `diag_tickTime` |
| `ap_telemetry_tick_ms` | | wall time of the job itself |

Server job `telemetryCensus`, every 60 s:

| name | labels | source |
|---|---|---|
| `ap_objects` | `class=<typeOf>` | histogram over `allMissionObjects "All"`, **top 40 classes**; the rest folded into `class="_other"` |
| `ap_objects_total` | | count |
| `ap_census_ms` | | wall time of the census |

Client beat, every 10 s from every player and the HC (`AP_fnc_telemetryBeat` → `APS_fnc_telemetryBeat`),
flushed by the 5 s server job for every entry younger than 30 s, labels `machine="client"|"hc"`,
`uid`, `name`:

| name | source |
|---|---|
| `ap_client_fps`, `ap_client_fps_min` | `diag_fps`, `diag_fpsMin` on the client |
| `ap_client_view_distance` | `viewDistance` |
| `ap_client_near_objects` | `count (player nearObjects 300)` (HC: `count vehicles` it owns) |
| `ap_client_in_vehicle` | 1 if `vehicle player != player` |

Payload from the client is `[fps, fpsMin, viewDistance, near, inVehicle]` — five numbers, every one
clamped server-side (`fps 0..1000`, `viewDistance 0..40000`, `near 0..100000`, `inVehicle 0/1`).
Identity (`uid`, `name`, `machine`) comes from the server's own player object found by
`owner _x == remoteExecutedOwner`, or `machine="hc"` when `remoteExecutedOwner == AP_hcOwner`.
An owner that matches nothing is dropped. Entries older than 60 s are deleted from the map.

Module self-metrics, appended to every flush: `ap_telemetry_sent_lines_total`,
`ap_telemetry_dropped_lines_total`, `ap_telemetry_failed_posts_total`, `ap_telemetry_queue_lines`.

Cardinality: ≤ 60 players × 5 series + 40 census classes + ~30 scheduler jobs ≈ 500 series. Trivial.

## pysqfd module `tools/pysqf_modules/telemetry.py`

```
["telemetry.push", [[name, labels, value], ...]] call APS_fnc_pysqfCall   -> true
["telemetry.stats", []]                          call APS_fnc_pysqfCall   -> {counters}
```

- `labels` is a JSON object or a list of `[key, value]` pairs (SQF sends arrays of pairs).
- Name and label keys must match `^[a-zA-Z_:][a-zA-Z0-9_:]*$`; label values are escaped
  (`\`, `"`, newline). A bad sample is counted (`bad_samples`) and skipped, never raised.
- Values: numbers, or bools (→ 1/0). Anything else is a bad sample.
- Timestamp = daemon wall clock in ms at receipt. `host` label from `AP_TELEMETRY_HOST`
  (default: hostname) is added unless the sample carries its own.
- Bounded queue (20 000 lines, oldest dropped). A daemon flusher thread posts every 1 s or at
  500 lines, `urllib.request`, 2 s timeout, to `AP_TELEMETRY_URL`
  (default `http://127.0.0.1:8428/api/v1/import/prometheus`). A failed batch is retried once on
  the next tick, then dropped; failures are logged at most once per 60 s.
- `AP_TELEMETRY_ENABLED=0` → `push` still returns `True` and counts `disabled_lines`.
- Thread starts lazily on the first `push` so `pysqfd --check` imports cleanly.
- `telemetry.flush()` drains synchronously (tests and shutdown).

## Docker stack `deploy/telemetry/`

- `docker-compose.live.yml`: `victoriametrics/victoria-metrics:v1.151.0` as `armapunk-vm`
  (`127.0.0.1:8428`, `-retentionPeriod=90d -search.latencyOffset=1s`, data at
  `${TELEMETRY_DATA}/vm`) and `grafana/grafana-oss:13.0.2` as `armapunk-grafana` (`127.0.0.1:3000`,
  runs as uid 1000 so the bind mount at `${TELEMETRY_DATA}/grafana` is writable, sign-up and
  anonymous access off, `GF_SERVER_ROOT_URL=https://grafana.armapunk.com`, provisioning dirs
  mounted read-only from the repo).
- `up.sh`: sources `~/.config/armapunk/telemetry.env` (`GRAFANA_ADMIN_PASSWORD`, `TELEMETRY_DATA`,
  default `/home/timb/telemetry`), runs `docker compose -p armapunk-telemetry ... up -d`.
- `grafana/provisioning/datasources/vm.yaml`: Prometheus-type datasource `armapunk-vm` →
  `http://vm:8428`, default.
- `grafana/provisioning/dashboards/armapunk.yaml` + `grafana/dashboards/*.json`: three
  dashboards, **generated** by `deploy/telemetry/gen_dashboards.py` (committed alongside the JSON):
  - *Armapunk Server* — server FPS/min, players by side, entities by kind, scripts, scheduler
    last-ms and errors, pysqf counters, DB RTT, uptime.
  - *Armapunk Clients* — per-player FPS lines, a current-FPS table (name, fps, fps_min, view
    distance, near objects), HC row.
  - *Armapunk Entities* — top classes stacked, total objects, census cost.
- Backups: VictoriaMetrics data is 90-day operational telemetry, not player state; it is
  deliberately **not** in the NAS backup set. Grafana state is provisioned from git.

## Deploy / lifecycle

- `deploy/systemd/armapunk-pysqfd.service`: `--modules pysqf.db,apdb,webpages,telemetry`. The live
  unit file at `~/.config/systemd/user/` is a copy (identical today) — updated with it.
- `deploy/systemd/pysqfd.env.example` and the box's `~/.config/armapunk/pysqfd.env` gain
  `AP_TELEMETRY_URL` and `AP_TELEMETRY_HOST=live`.
- Restart order on the box: stop `armapunk-arma` → `daemon-reload` → restart `armapunk-pysqfd`
  → `deploy/push-96.sh --no-notes` (repacks, restarts arma, HC follows). Restarting the daemon
  under a running server would fail every DB call in the gap.
- Tunnel: ingress `grafana.armapunk.com → http://127.0.0.1:3000` added before the 404 catch-all in
  `~/.cloudflared/armapunk.yml`; DNS via `cloudflared tunnel --origincert cert-armapunk.pem route dns
  armapunk grafana.armapunk.com`; `sudo systemctl restart armapunk-tunnel` (system unit).
- Registration: `class telemetry {}; class telemetryBeat {};` in `server/AP_server/config.cpp`
  (TON block), `class telemetryBeat {};` in `mission/.../Functions.h` (`core\functions` block),
  `class APS_fnc_telemetryBeat {allowedTargets = 2;};` in `CfgRE.hpp`. Server: `[] call
  APS_fnc_telemetry;` next to `APS_fnc_edenLiveBeat` in server `init.sqf`. Client + HC: `[] spawn
  AP_fnc_telemetryBeat;` at the top of mission `init.sqf` before the HC `exitWith`.

## Residual decisions (taken under the "complete it" order; owner can reverse each in one line)

- Grafana is reachable on the public hostname behind its own login (admin + generated password
  written to `~/.config/armapunk/telemetry.env`, 0600). Remove the ingress line to make it
  ssh-tunnel only.
- Retention 90 days. Per-player series carry `uid` and `name`.
- No alerting in v1 (dashboards only). Grafana's built-in alerting can post to the Discord webhook
  later without touching the game side.

## Testing

- `tools/pysqf_modules/test_telemetry.py` (stdlib `unittest`, a local `http.server` sink): line
  format and stamping, label escaping, bad-sample refusal, sink-down never raises and counts,
  bounded queue, batching, disabled flag, pairs-list labels, bool values.
- Local compose smoke on samurai: `up`, Grafana `/api/health` 200, datasource present, three
  dashboards in `/api/search`, a pushed sample visible through Grafana's datasource proxy.
- On .96 after deploy: `ap_server_fps` and `ap_client_fps{machine="hc"}` answer a VM query with
  `latency_offset=1s`; `https://grafana.armapunk.com/login` is 200; admin login works; no
  `telemetry` script errors in the arma journal; daemon journal shows the module loaded and posting.
  Player-client beats are only verifiable with a real player and are reported as such.

## Live findings (2026-09-09, deployed b2020 → b2022 on .96)

- **Deployed and verified**: server tick, census, DB round trip, pysqf counters, HC beat
  (`ap_client_fps{machine="hc"}`), public Grafana with login (anonymous → 401), all 43 panel queries
  answering. Measured: server fps ~50, tick 40 ms, census 47–134 ms (95–279 objects at boot),
  DB rtt 19 ms, `telemetry.push` 0.4 ms in the daemon, zero dropped lines.
- **Player-client beat verified 19:08 CDT** — owner joined: `first beat from steamuser (client,
  owner 5, isRemoteExecuted true)`, `ap_client_fps` 40, 2,493 objects within 300 m. Every path in
  the architecture diagram has now been observed carrying real data.
- **Two engine facts that cost a deploy cycle each**, now encoded in the code and in
  `fn_telemetryBeat.sqf`'s header:
  1. `remoteExecutedOwner` is **0 by design** for a call from the headless client, and
     `isRemoteExecuted` is **false** for it too (first-beat log: `owner 0, isRemoteExecuted
     false`). Owner 0 while `AP_hcOwner > 0` is the HC; a player's call always carries its id.
  2. The pysqf `stats` verb nests the ticket counters under `"store"`.
- `tools/sqf_cmd_check.py` reports every `diag_*` command as unknown (the BIKI mirror has no
  `diag_` pages; `fn_apStress.sqf` trips it the same way). Pre-existing, not fixed here.

## Phase 2 — "everything possible and useful" (owner 2026-09-09: "do them all")

Additions only; nothing above changes. Same transport, same sink, same rules (daemon stamps,
identity from the engine, strings from clients sanitised to `[A-Za-z0-9_.-]` ≤ 32 chars).

### A. Server tick (5 s) additions
| name | labels | source |
|---|---|---|
| `ap_frame_ms`, `ap_frame_no`, `ap_mission_fsms` | | `diag_deltaTime`, `diag_frameNo`, `diag_activeMissionFSMs` |
| `ap_units{kind=player\|ai}`, `ap_units_ai{side=west\|east\|guer\|civ}` | | `allUnits` split on `isPlayer` |
| `ap_dead{kind=men\|vehicles}` | | `allDeadMen`, `allDead` |
| `ap_vehicles{family=tank\|car\|air\|ship\|other}`, `ap_vehicles_owner{owner=server\|hc\|player}`, `ap_vehicles_state{state=empty\|damaged\|destroyed}` | | one pass over `vehicles` |
| `ap_groups_empty`, `ap_markers`, `ap_effects{kind=particle\|light\|sound}`, `ap_weapon_holders{kind=ground\|simulated}` | | leak detectors: `allGroups`, `allMapMarkers`, `allMissionObjects "#particlesource"/"#lightpoint"/"#soundonvehicle"`, `GroundWeaponHolder`/`WeaponHolderSimulated` |
| `ap_env_daytime`, `ap_env_overcast`, `ap_env_rain`, `ap_env_fog`, `ap_env_wind`, `ap_env_sun`, `ap_env_time_multiplier` | | weather/time (correlate client fps with rain and night) |
| `ap_player_ping_ms`, `ap_player_bandwidth`, `ap_player_desync`, `ap_player_client_state`, `ap_player_admin`, `ap_player_session_s` | `machine`, `uid`, `name` | `allUsers` → `getUserInfo` (networkInfo = [ping, bandwidth, desync]); session from the connect handler |
| `ap_players_state{state=downed\|restrained\|in_vehicle\|dead}` | | `AP_downed` var, `AP_restrained_players`, `vehicle`, `alive` |
| `ap_duty{faction=maxsec\|trauma}`, `ap_wanted`, `ap_wanted_bounty_total`, `ap_bank_funds`, `ap_event_queue` | | `AP_dutyRoster`, `AP_wanted_list`, `AP_bank_funds`, `AP_event_queue` |
| `ap_events_total{type=…}` | | counters since boot, see C |

### B. Census (60 s) additions
| `ap_sqf_scripts{name=<basename>}` | top 20 of `diag_activeSQFScripts` by name, rest `_other` — the "which script has 1,000 copies" panel |

### C. Event counters (`AP_fnc_telemetryEvent`, rates in Grafana)
Mission EHs added by the collector: `PlayerConnected` → `connect` (+ session clock), `PlayerDisconnected`
→ `disconnect`, `EntityKilled` → `death_player` / `death_ai` / `vehicle_destroyed`, plus `pvp_kill`
when a player killed a player. One-line hooks in existing server code: `fn_wantedAdd` → `wanted`,
`fn_setRestrained` (true) → `restrain`, `fn_maldenBankSRV` open → `robbery_bank`, `fn_maldenFedSRV`
safe → `robbery_fed`, `fn_jewelryEmporiumSRV` robberyStarted → `robbery_jewelry`. Every hook is
`if (!isNil "AP_fnc_telemetryEvent") then { ["x"] call AP_fnc_telemetryEvent; }` — inert if the
collector is absent. **Not hooked:** jail (no single entry point; the self-jail path is the only
`fn_jailSys` caller), respawn (client-side only).

### D. Client beat (10 s) — 5 → 19 numbers, plus a once-per-session profile
Beat: `fps, fpsMin, frameMs, viewDistance, objectViewDistance, terrainGrid, shadowDistance,
nearObjects, nearPlayers, nearVehicles, inVehicle, speed, posX, posY, displays, scriptsSpawn,
scriptsExecVM, inMenu, alive` → `ap_client_*` (HC: nearObjects = local units, nearPlayers = local
groups, nearVehicles = owned vehicles). Profile once (`APS_fnc_telemetryProfile`, CfgRE 2):
`resW, resH, fov, buildNumber, branch, language` → `ap_client_res_w/h`, `ap_client_fov`,
`ap_client_build`, `ap_client_info{branch,lang} 1`. Server clamps every number; strings sanitised.
Positions are 2-D numbers, not labels — an FPS heatmap, no series churn.

### E. Daemon-side collectors (`tools/pysqf_modules/telemetry_collectors.py`, threads in pysqfd)
| every | what | names |
|---|---|---|
| 10 s | host: CPU %, load, memory, swap, disk, net (from `/proc`, stdlib only) | `ap_host_cpu_pct`, `ap_host_load{period}`, `ap_host_mem_bytes{kind}`, `ap_host_swap_bytes{kind}`, `ap_host_disk_bytes{path,kind}`, `ap_host_net_bytes_total{dir}`, `ap_host_uptime_s` |
| 10 s | processes matched by cmdline regex (`AP_TELEMETRY_PROCS`, default arma / hc / pysqfd / postgres): RSS, CPU %, threads, fds, uptime, running | `ap_proc_*{proc}` |
| 30 s | PostgreSQL via `pysqf.db`: `pg_stat_database`, activity by state, DB size, live/dead rows for `AP_TELEMETRY_TABLES` | `ap_pg_*`, `ap_pg_table_rows{table}`, `ap_pg_table_dead_rows{table}` |
| 60 s | economy, read-only SQL: players total / active 24 h, cash, bank, gang bank, money supply, gangs, vehicles alive/total, houses, exchange listings | `ap_econ_*` |
Each collector's failures count in `ap_telemetry_collector_errors_total{collector}`; a broken
collector never stops the others or the flusher. Off with `AP_TELEMETRY_COLLECTORS=0`.

### F. Dashboards
Server: frame time, vehicles by family/owner/state, leak panel, weather overlay, scripts by name.
Clients: ping / desync / bandwidth graphs, richer table (ping, near players/vehicles, speed, build).
New: **Host** (cpu/load/mem/net/processes), **Database** (pg + table rows), **Economy** (money
supply, players, vehicles, houses, listings), **Events** (rates per type, connects).

### Verified before design
`getUserInfo` networkInfo = `[ping, bandwidth, desync]` (BIKI); `allUsers`, `diag_deltaTime`,
`diag_frameNo`, `allDeadMen`, `allMapMarkers`, `moonPhase`, `sunOrMoon`, `getObjectViewDistance`,
`getTerrainGrid`, `getShadowDistance`, `productVersion` all present in the 2.22 binary (`strings`).
`productVersion` = `[name, nameShort, version, build, buildType, isModded, platform, arch, branch]`;
`getResolution` = `[w, h, vpW, vpH, aspect, uiScale, fovTop, fovLeft, tripleHead, texQ]`.
`diag_activeSQFScripts` element layout has no wiki page in the mirror: the census reads element 0
defensively and logs one sample row on its first run.

### Phase 2 live findings (b2023 → b2024, 2026-09-09 19:50 CDT)
- Everything in A–F is live: 122 metric names, 376 series with one HC and no players; collectors
  `host, proc, pg, econ` at 0 errors; DB collector tests green on the box against live PostgreSQL;
  public Grafana answers host / economy / events queries. Money supply read 5,410,837,971
  (bankacc + cash + gang banks), matching the migration ledger.
- Server tick cost 40 → 141–162 ms (getUserInfo per user, one vehicles pass, five
  `allMissionObjects` calls). Scheduled time, spread over frames; watch `ap_telemetry_tick_ms`.
- `diag_activeSQFScripts` names an anonymous `spawn` by its **whole code** (newlines included).
  The census keeps the first line, 48 chars. Bounded by top-20 either way.
- 15 of 17 vehicles at boot were neither Tank/Car/Air/Ship: `static`, `motorcycle`, `land_other`
  and `thing` buckets added so "other" means unknown.
- Reading `PYSQF_DB_DSN` for a shell test: the DSN is a space-separated libpq string;
  `set -a; . pysqfd.env` splits it into five variables (systemd's `EnvironmentFile` does not).
  Read the line whole (`deploy/telemetry/README.md`).

## Alerts (owner 2026-09-09: "set up the discord alerts for low fps and entity spikes")

Grafana unified alerting, file-provisioned from `deploy/telemetry/grafana/provisioning/alerting/`
(`contactpoints.yaml`, `policies.yaml`, `rules.yaml`), evaluated every 30 s against VictoriaMetrics.
Contact point = Discord webhook **"Armapunk Alerts" in #loonybot** (Staff Zone; created with the
LoonyBot token, id 100000000000000976); URL in `~/.config/armapunk/telemetry.env`
(`DISCORD_ALERT_WEBHOOK`), passed to Grafana by compose. Policy: one message per alert name,
30 s group wait, 5 min group interval, repeat every 4 h, resolved messages on.

| rule | fires when | for | severity |
|---|---|---|---|
| Server FPS low | 2-min average `ap_server_fps` < 20 | 2 m | warning |
| Server FPS critical | 1-min average < 12 | 1 m | critical |
| Telemetry silent | no `ap_server_fps` samples at all | 3 m | critical |
| Entity spike | `delta(mission_objects[10m])` > 500 | 1 m | warning |
| Object class spike | any class `delta(ap_objects[10m])` > 300 (per class) | 1 m | warning |
| Vehicle spike | `delta(vehicles[10m])` > 50 | 1 m | warning |
| Mission objects high | `mission_objects` > 3000 | 5 m | warning |
| Empty groups leaking | `delta(ap_groups_empty[30m])` > 50 | 5 m | warning |
| Client FPS low fleet-wide | ≥ 3 players under 20 FPS | 5 m | warning |

Thresholds are first guesses from one evening of data (server ~50 FPS, 279 objects at boot);
edit `rules.yaml`, `push-96.sh --no-reload`, then `deploy/telemetry/up.sh restart grafana` —
**alerting provisioning is read only at Grafana start** (dashboards are the ones re-read every
30 s; measured: an edited template stayed in memory until the restart). Move the channel by
creating another webhook and changing the env line, then the same restart; nothing in the game
side is involved. Verified 2026-09-09 20:35 CDT: a synthetic 9-FPS feed on the local stack
delivered `🔴 FIRING: Server FPS critical` into #loonybot through the live webhook.
