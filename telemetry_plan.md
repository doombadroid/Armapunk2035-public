# Telemetry Implementation Plan

**Status: EXECUTED 2026-09-09, live on .96 as b2022.** Every task below ran in one session; the two live findings (HC owner 0 / isRemoteExecuted false, pysqf stats nested under "store") are in `TELEMETRY_SPEC.md` § Live findings. Player-client beats still need a human join.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Server, HC and player metrics flow from the Arma process through pysqfd into VictoriaMetrics and show on Grafana at `https://grafana.armapunk.com`.

**Architecture:** A pysqfd module (`telemetry.py`) accepts `[name, labels, value]` samples, stamps them, queues them and POSTs Prometheus-format lines to VictoriaMetrics from its own thread. Two scheduler jobs on the server collect engine numbers every 5 s / 60 s; every client and the HC send a five-number beat every 10 s to a whitelisted server function that the 5 s job flushes. VictoriaMetrics + Grafana run as two loopback-bound containers on .96 behind the existing cloudflared tunnel.

**Tech Stack:** Python 3.14 stdlib (urllib, threading, unittest), SQF, docker compose 5.1.4, `victoriametrics/victoria-metrics:v1.151.0`, `grafana/grafana-oss:13.0.2`, cloudflared.

## Global Constraints

- Spec: `TELEMETRY_SPEC.md` (repo root; `docs/` is git-ignored).
- Arma 2.22 — no WebSocket commands; pysqf is the only out-of-process channel.
- SQF numbers are 32-bit floats: **never send epoch timestamps from SQF**; the daemon stamps.
- `APS_fnc_pysqfCall` only from a scheduled context (scheduler jobs run in `spawn` — fine).
- Client → server function needs `class APS_fnc_telemetryBeat {allowedTargets = 2;};` in `CfgRE.hpp`; identity from `remoteExecutedOwner`, never the payload.
- Client fn → `Functions.h`; server fn → `server/AP_server/config.cpp` (prefix `APS_`).
- Commit straight to `main` (marker `deploy/LIVE_IS_DEV` exists). Commit trailer: `Co-Authored-By: <funny defunct AI>`, name only, rotate.
- `deploy/push-96.sh` refuses a dirty tree; use `--no-notes` (telemetry is not player-facing).
- Restart order on .96: stop arma → daemon-reload → restart pysqfd → push (restarts arma).
- Tests run as `PYTHONPATH=/home/timb/PySQF/python /home/timb/pysqf-venv/bin/python -m unittest tools.pysqf_modules.test_telemetry -v` from the repo root (pysqf is not installed in the venv).
- Local smoke uses `VM_PORT=18428 GRAFANA_PORT=13000` (samurai's :3000 is taken).
- VictoriaMetrics runs with `-search.latencyOffset=1s` (default 30 s hides fresh data; measured).

---

### Task 1: pysqfd module `telemetry` (TDD)

**Files:**
- Create: `tools/pysqf_modules/telemetry.py`
- Test: `tools/pysqf_modules/test_telemetry.py`

**Interfaces:**
- Produces: `telemetry.push(samples: list) -> bool` where each sample is `[name: str, labels: dict | list[[k, v]], value: number | bool]`; `telemetry.stats() -> dict`; `telemetry.flush() -> dict` (synchronous drain + one POST). Test hooks: `telemetry._configure(url=, host=, enabled=, queue_max=)`, `telemetry._reset()`, `telemetry._now_ms` (patchable).
- Env: `AP_TELEMETRY_URL`, `AP_TELEMETRY_HOST`, `AP_TELEMETRY_ENABLED`, `AP_TELEMETRY_QUEUE`, `AP_TELEMETRY_FLUSH_S`, `AP_TELEMETRY_FLUSH_LINES`, `AP_TELEMETRY_TIMEOUT_S`.

- [x] **Step 1: Write the failing tests** — `tools/pysqf_modules/test_telemetry.py` with a local `ThreadingHTTPServer` sink recording POST bodies (204, or 503 when `sink.fail` is set). Cases: line format + stamping + host label, label escaping, bad samples counted, sink down never raises and retries once then drops, bounded queue drops oldest, batching (3 pushes → 1 POST), disabled flag, bool → 1/0, self-metrics appended, explicit host label kept.
- [x] **Step 2: Run, expect** `ModuleNotFoundError: No module named 'tools.pysqf_modules.telemetry'`.
- [x] **Step 3: Implement** `telemetry.py` (bounded deque, flusher thread started on first push, `urllib.request` POST, counters, rate-limited error log, `@pysqf.export` on `push`/`stats`/`flush`).
- [x] **Step 4: Run, expect** all tests `OK`.
- [x] **Step 5: Commit** `telemetry: pysqfd module that ships samples to VictoriaMetrics`.

### Task 2: Docker stack + Grafana provisioning + dashboards

**Files:**
- Create: `deploy/telemetry/docker-compose.live.yml`, `deploy/telemetry/up.sh`, `deploy/telemetry/README.md`, `deploy/telemetry/grafana/provisioning/datasources/vm.yaml`, `deploy/telemetry/grafana/provisioning/dashboards/armapunk.yaml`, `deploy/telemetry/gen_dashboards.py`, `deploy/telemetry/grafana/dashboards/{armapunk-server,armapunk-clients,armapunk-entities}.json` (generated)
- Modify: `.gitignore` (add `deploy/telemetry/.env`)

**Interfaces:**
- Consumes env `GRAFANA_ADMIN_PASSWORD` (required), `TELEMETRY_DATA` (default `/home/timb/telemetry`), `VM_PORT` (8428), `GRAFANA_PORT` (3000), `GRAFANA_ROOT_URL`, `PUID` (1000).
- Produces: VictoriaMetrics at `127.0.0.1:${VM_PORT}`, Grafana at `127.0.0.1:${GRAFANA_PORT}`, datasource uid `armapunk-vm`, dashboard uids `ap-server`, `ap-clients`, `ap-entities`.

- [x] **Step 1: Observe red state** — `docker compose -f deploy/telemetry/docker-compose.live.yml config` fails (file absent).
- [x] **Step 2: Write compose, provisioning, `up.sh`, `gen_dashboards.py`; run the generator.**
- [x] **Step 3: Local smoke** — `docker rm -f vmtest; GRAFANA_ADMIN_PASSWORD=smoke TELEMETRY_DATA=$SCRATCH/telemetry VM_PORT=18428 GRAFANA_PORT=13000 GRAFANA_ROOT_URL=http://127.0.0.1:13000 docker compose -p aptelemetry-smoke -f deploy/telemetry/docker-compose.live.yml up -d`; expect `curl 127.0.0.1:13000/api/health` → `"database": "ok"`, `curl -u admin:smoke 127.0.0.1:13000/api/search` lists 3 dashboards, `curl -u admin:smoke 127.0.0.1:13000/api/datasources` has `armapunk-vm`; push a sample to `127.0.0.1:18428/api/v1/import/prometheus`, query it through `127.0.0.1:13000/api/ds/query`.
- [x] **Step 4: Tear down** `docker compose -p aptelemetry-smoke ... down -v`.
- [x] **Step 5: Commit** `telemetry: VictoriaMetrics + Grafana compose stack and provisioned dashboards`.

### Task 3: Server-side SQF (collector jobs + beat receiver)

**Files:**
- Create: `server/AP_server/core/TON/fn_telemetry.sqf`, `server/AP_server/core/TON/fn_telemetryBeat.sqf`
- Modify: `server/AP_server/config.cpp` (after `class edenLiveBeat {};`), `server/AP_server/init.sqf` (after `[] call APS_fnc_edenLiveBeat;`)

**Interfaces:**
- Produces: `APS_fnc_telemetry` (registers jobs `telemetryServer` 5 s and `telemetryCensus` 60 s, defines `AP_fnc_telemetryPush`), `APS_fnc_telemetryBeat` (params `[fps, fpsMin, viewDistance, near, inVehicle]`, writes `AP_telemetry_clients[uid] = [name, machine, fps, fpsMin, vd, near, inVeh, tickTime]`).

- [x] **Step 1: Observe red state** — on .96 after deploy, `curl 'http://127.0.0.1:8428/api/v1/query?query=ap_server_fps&latency_offset=1s'` returns an empty result (nothing collects yet).
- [x] **Step 2: Write both functions, register, hook init.**
- [x] **Step 3: Syntax check** with `tools/fn_check.py` or `python3 tools/sqf_lint` equivalent if present; otherwise `deploy/cfgfn_audit.py` for registration.
- [x] **Step 4: Commit** `telemetry: server collector jobs and the client beat receiver`.

### Task 4: Client-side SQF (beat sender)

**Files:**
- Create: `mission/Armapunk2035.Malden/core/functions/fn_telemetryBeat.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h` (in `class Functions {file = "core\functions";` block), `mission/Armapunk2035.Malden/CfgRE.hpp`, `mission/Armapunk2035.Malden/init.sqf` (before the HC `exitWith`)

**Interfaces:**
- Consumes: `APS_fnc_telemetryBeat` via `[[fps, fpsMin, vd, near, inVeh], "APS_fnc_telemetryBeat", 2, false, true] spawn AP_fnc_MP`.

- [x] **Step 1: Write `fn_telemetryBeat.sqf`**, register in `Functions.h`, whitelist in `CfgRE.hpp`, spawn from `init.sqf` on every non-server machine.
- [x] **Step 2: Commit** `telemetry: client and HC beat every 10 s`.

### Task 5: Daemon config + deploy to .96 + tunnel

**Files:**
- Modify: `deploy/systemd/armapunk-pysqfd.service` (`--modules pysqf.db,apdb,webpages,telemetry`), `deploy/systemd/pysqfd.env.example` (+`AP_TELEMETRY_URL`, `AP_TELEMETRY_HOST`)
- On .96: `~/.config/armapunk/pysqfd.env`, `~/.config/systemd/user/armapunk-pysqfd.service`, `~/.config/armapunk/telemetry.env` (0600, generated password), `~/.cloudflared/armapunk.yml`

- [x] **Step 1: Commit config changes**, `git push`.
- [x] **Step 2: On .96**: write `telemetry.env`, `mkdir -p ~/telemetry/{vm,grafana}`, then `deploy/telemetry/up.sh` (from the deployed tree — but the tree is rsynced by push-96, so first run `deploy/push-96.sh --no-reload` to mirror).
- [x] **Step 3: On .96**: append env lines, copy unit, `systemctl --user stop armapunk-arma`, `daemon-reload`, `restart armapunk-pysqfd`, check `journalctl --user -u armapunk-pysqfd -n 20` shows `telemetry` in modules.
- [x] **Step 4: From samurai**: `deploy/push-96.sh --no-notes` (repack + restart arma; `systemctl --user start armapunk-hc` afterwards if not up).
- [x] **Step 5: Tunnel**: ingress line + `route dns` + `sudo systemctl restart armapunk-tunnel`; expect `curl -sI https://grafana.armapunk.com/login` → 200.

### Task 6: Verification + records

- [x] VM on .96: `ap_server_fps`, `ap_entities`, `ap_sched_last_ms`, `ap_client_fps{machine="hc"}` all answer with `latency_offset=1s`.
- [x] Grafana: `/api/health` ok, admin login works, three dashboards listed, server dashboard panel query returns points.
- [x] Arma journal: no `telemetry` script errors; `ap_census_ms` reported and sane (< 500 ms).
- [x] pysqfd journal: no telemetry errors after warm-up.
- [x] Memory file `armapunk-telemetry.md` + MEMORY.md index line; spec status line.
- [x] Final report names what was verified and what needs a real player (client beats).

## Self-review

- Spec coverage: metrics table → Task 3/4; module → Task 1; stack/dashboards → Task 2; deploy/tunnel → Task 5; testing → Tasks 1, 2, 6. Residual decisions recorded in the spec.
- Riskiest lines executed already: VM import format + latency offset (this session), diagnostic command names present in the 2.22 binary (`strings`), `remoteExecutedOwner`/`allowedTargets = 2` pattern (existing `APS_fnc_mapEditSRV`). Unverified until deploy: `allMissionObjects "All"` census cost on the live object count (reported via `ap_census_ms`), player-client beats (needs a human).
- Lifecycle owners: scheduler wheel owns job lifetime; pysqfd owns the flusher thread; compose owns containers; cloudflared system unit owns the ingress.
- Artefact paths: `docs/` ignored → root; `deploy/telemetry/.env` added to `.gitignore`; dashboards JSON committed (generated, generator committed too).

---

# Phase 2 plan (2026-09-09, "do them all") — spec § Phase 2

**Status: EXECUTED, live as b2024 (Tasks 7–11 done; findings in the spec § Phase 2 live findings).**

### Task 7: daemon collectors (TDD)
- Create `tools/pysqf_modules/telemetry_collectors.py`, `tools/pysqf_modules/test_telemetry_collectors.py`.
- [x] Failing tests for the pure parsers: `/proc/stat` → cpu pct between two samples, `/proc/meminfo`, `/proc/net/dev` (lo excluded), `/proc/<pid>/status|statm|stat` → rss/threads/uptime, cmdline matcher (arma vs hc by `-client`), collector error isolation (a raising collector counts and the others still push), sample → `[name, labels, value]` shape. DB collectors: gated on `PYSQF_DB_DSN` (skip loudly), asserted on .96 after deploy.
- [x] Run → `ModuleNotFoundError`. Implement. Green. `telemetry.py` starts the collector thread at import when enabled.
- [x] Commit.

### Task 8: server SQF (A, B, C) + receiver/profile (D server half)
- Modify `fn_telemetry.sqf` (tick + census + events + EHs), `fn_telemetryBeat.sqf` (19 params, hashMap entry), create `fn_telemetryProfile.sqf`, register in `config.cpp` + `CfgRE.hpp`; one-line hooks in `fn_wantedAdd`, `fn_setRestrained`, `fn_maldenBankSRV`, `fn_maldenFedSRV`, `fn_jewelryEmporiumSRV`.
- [x] `sqf_balance.py` on every touched file; `cfgfn_audit.py`. Commit.

### Task 9: client SQF (D client half)
- Modify `core/functions/fn_telemetryBeat.sqf` (19-number beat + one profile call). Commit.

### Task 10: dashboards + smoke
- Extend `gen_dashboards.py` (Server/Clients panels; new Host, Database, Economy, Events); extend `smoke.py` synthetic set to every new name; local compose smoke: every panel query answers. Commit.

### Task 11: deploy + verify on .96
- `push-96.sh --no-reload` → stop arma → restart pysqfd → `push-96.sh --no-notes` → HC up.
- [x] VM has `ap_player_ping_ms`, `ap_vehicles`, `ap_sqf_scripts`, `ap_events_total`, `ap_client_pos_x`, `ap_client_info`, `ap_host_cpu_pct`, `ap_proc_rss_bytes{proc="arma"}`, `ap_pg_backends`, `ap_econ_money_supply`; tick still < 100 ms; census logged its sample row; no script errors; DSN-gated tests green on the box; Grafana panels answer via the public host.
- [x] Spec/plan/memory updated, pushed.
