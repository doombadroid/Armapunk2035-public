# singleevh.md — Single-EVH Scheduler + Two-Hashmap Stat Buffer

**Status:** architecture plan. Implementation by Opus. Do the work on `doomba`, test on the isolated test-server BEFORE any live deploy (this is a broad refactor, not a hotfix). `git blame` before touching any loop — several are Infamous's (`Infamous-arma`); flag + get owner OK per the standing rule.

**Author's note on framing:** the research (3 codebase passes, all file:line-verified) changed the shape of this task. Two things the naive brief assumed are already partly true:

1. **A single-EVH cooperative scheduler already exists — client-side.** `mission/LooneyBin.Altis/core/fn_setupEVH.sqf:37` registers exactly one `addMissionEventHandler ["EachFrame", {call AP_fnc_onEachFrame}]`; `evh/eachFrame/fn_onEachFrame.sqf` is the dispatcher; `fn_addPerFrameHandler`/`fn_removePerFrameHandler` are the register/remove APIs. 10 callbacks already use it. This is not a greenfield build — it's **finish migrating onto it + build the server twin.**
2. **The 148-slot lifetime stat array is already an in-memory delta accumulator with a batched, dirty-checked flush** (`APV_tempStats` → `APS_fnc_statTableUpdate`). It is NOT per-change DB writes. The real wins are a durability timer, a double-buffer (swap-on-flush), unifying it with the 17-slot `A_stats` system, and killing the flat-index fragility — not "add batching that doesn't exist."

So this plan delivers the two requested subsystems **plus** the cheap high-value wins the research exposed (the `-FNCALL-` audit doubling every DB save; several no-sleep loop bugs).

---

## 0. Goals / non-goals

**Goals**
- Collapse the ~24 standalone server `spawn { while{true} … sleep }` loops and the ~7 easy client `spawn`-loops into **one scheduler per side** (extend the existing client one; build a server one).
- Replace the flat stat arrays + hard-named `A_stats_*` globals with a **two-hashmap buffer** (live map + dirty/in-flight map), batched flush driven by the scheduler, with crash durability and no lost deltas.
- Reduce DB write amplification and per-frame waste surfaced by the audit.

**Non-goals (explicitly out of scope)**
- The 92 `for "_i" from 0 to 1 step 0` progress-bar coroutines. These are per-action UI, not background tasks; they *must* keep suspending (`uiSleep`) mid-body. Leave them as `spawn`.
- The ~130 feature-session loops (sirens, event watchdogs, drug-lab timers) that spawn on a feature firing and self-exit. Optional later; not required for the win.
- Any DB **schema** change. The hashmaps serialize to the *existing* `lifetime_stats` / `stats` column formats on write and deserialize on read. Zero data migration.
- extDB3 protocol changes.

**Success metric:** fewer permanent scheduled scripts (measure with the scheduler introspection dump), lower steady-state DB query rate (count `SQL Query:` RPT lines/min), no gameplay regressions on the test server.

---

## 1. Current state (grounded — so the implementer doesn't re-discover)

### 1.1 The existing client scheduler (the template to extend)
- Driver: one `EachFrame` EH → `AP_fnc_onEachFrame` (`mission/.../evh/eachFrame/fn_onEachFrame.sqf`). Walks 4 arrays every frame:
  - `AP_eachFrameHandlerArray` — the PFH list. Entry = `[fn, args, delay, nextRunTime, startTime, handle]`; runs `[_args,_handle] call fn` when `diag_tickTime > nextRunTime`, then reschedules `nextRunTime = diag_tickTime + delay`.
  - `AP_waitAndExecArray` — delayed one-shots.
  - `AP_nextFrameBufferA/B` — next-frame double-buffer.
  - `AP_waitUntilAndExecArray` — condition-gated one-shots.
- Register: `[fn, args, interval] call AP_fnc_addPerFrameHandler` → handle. Remove: `handle call AP_fnc_removePerFrameHandler` (deferred via `AP_fnc_directCall` so it's mid-tick-safe). Arrays init at `core/init.sqf:40–51`.
- **Callbacks run via `call` → they cannot suspend.** This is the load-bearing constraint.
- 10 current users: `fn_setupEVH.sqf:104` (0.5s), `core/init.sqf:159` (1.3s), `initPlayerLocal.sqf:328` (10s), `fn_initCiv.sqf:111/141/158` (240/300/10s), `fn_initStats.sqf:22/63` (300/60s), `fn_jewelryEmporium.sqf:288/295` (~1.1s).

### 1.2 Server has NO scheduler
- `grep addPerFrameHandler|EachFrame server/AP_server` = 0 hits. Every server periodic task is a standalone `spawn { while{true} do { … uiSleep N } }`, and **every one suspends** (uiSleep and/or DB).
- ~24 live persistent server loops, mostly in `server/AP_server/init.sqf` (spawned from the server-only `initServer.sqf:174`). Full list in §A.5.

### 1.3 DB write path
- All reads/writes funnel through `server/.../core/DB/fn_asyncQuery.sqf`. **Global mutex** `waitUntil {!DB_Async_Active}` (:15) → one query at a time, server-wide, no parallelism. Writes = mode 1 (`"extDB3" callExtension "1:…"`, fire-and-forget, returns immediately). Reads = mode 2 (suspends: mutex + 5ms result-spin at :37).
- `DB_fnc_updatePartial` (server handler `core/DB/fn_updatePartial.sqf`): 24-mode `switch`, **1 extDB3 UPDATE per call**, no batching. No single mode writes both `players` and `players_global`.
- `AP_fnc_MP` (`core/functions/network/fn_MP.sqf`): the client→server chokepoint. `_target=false` → server (2).
- **`-FNCALL-` audit (`fn_MP.sqf:15–31`) doubles every matched save**: any MP call whose lowercased fn-name matches `AP_logCallList` (`init.sqf:38`, contains `"update"`, `"query"`, …) *spawns a second MP call* → `APS_fnc_logIt` → `INSERT INTO log`. So a routine stat/cash/gear save currently costs **~2 remoteExecs + 2 DB writes**. This is the single biggest cheap win.
- DEAD infra (registered, never called): `fn_addQueue`/`fn_processQueue`/`fn_queueManagement` (a DB pump), and the legacy `AP_update_buffer` + `fn_flushAllPlayers` (420s) path — the live save path bypasses both. Do not build on them; consider deleting in a cleanup pass.

### 1.4 Stat system (two subsystems)
| | **A — lifetime** | **B — A_stats** |
|---|---|---|
| Live var | `APV_tempStats` (148 ints, delta accumulator, reset-on-flush) | 17 named globals `A_stats_warKills…medRevives` (absolute) |
| Mutate API | `["name",delta] call AP_fnc_statArrUpdate` (name→index switch = source of truth) | `[case,amt] call AP_fnc_updateRemoteStat` |
| Mutation sites | 96 (all pure in-memory `set`, no DB) | ~7 + a 60s time tick |
| DB column | `players_global.lifetime_stats` (plain `str` array) | `players_global.stats` (mres/backtick array) |
| Flush | event-driven delta RMW (2 queries) via `fn_ClupdateRequest.sqf:51–66` → `APS_fnc_statTableUpdate` | **300s PFH** (`fn_initStats.sqf:4`) → `[9] ClupdatePartial` → 1 UPDATE (whole array) |
| Loaded at login? | **NO** (on-demand read only, `APS_fnc_getStatsArr` → `APV_statTotals` for display) | **YES** (`fn_requestReceived.sqf:92`) |
| Durability | crash between events loses ALL un-flushed deltas | loses ≤5 min |

Flush triggers for A (all event-driven, no periodic timer): respawn (`fn_respawned.sqf:43/45`), manual Sync button (5-min cooldown), T-55 restart (`fn_notifyServerRestart.sqf:12`), quit (`fn_onGameInterrupt.sqf:92`, gated), server force-flush at restart (`init.sqf:342/1366`). `APV_savedStats` is vestigial (assigned then reset; can be deleted). Index map = the `switch` in `fn_statArrUpdate.sqf` — **the single source of truth**; the label list in `fn_statsFilter.sqf` and thresholds in `fn_titleCfg.sqf` have known positional drift, so preserve exact index numbers on serialize.

---

## 2. Workstream A — unified single-EVH scheduler

### A.1 Design principle: the suspend rule
The one rule that decides every migration:

- **Trailing-sleep loop** (body does self-contained work, then a single `uiSleep N` sets cadence) → **EASY**. The body becomes a non-suspending scheduler callback with interval `N`.
- **Internally-suspending loop** (`uiSleep`/`waitUntil` mid-body, a `waitUntil` state machine, a blocking `DB_fnc_asyncQuery` mode-2 read, a nested progress loop) → **HARD**. It either (a) stays a `spawn`ed coroutine, or (b) is registered on the *server* wheel in **spawn mode** (see A.3) so its suspension happens in its own transient thread, not the wheel.

Corollary: `DB_fnc_asyncQuery` mode 2 (reads) suspends. **Any loop that reads the DB is HARD.** DB *writes* (mode 1) are fire-and-forget and do not suspend, so a write-only loop can be EASY.

### A.2 Client — extend the existing scheduler (do not rebuild)
1. Migrate the EASY standalone client loops onto `AP_fnc_addPerFrameHandler` (§A.5 client-EASY table). Each is a trailing-sleep loop → lift the body into a callback, interval = the old sleep.
2. Keep HARD client loops as `spawn` coroutines (survival tick, dynamicMap streamer, prison-break bar, hudSetup/sidechat state machines, the 92 progress bars).
3. Fix the HOT/buggy per-frame offenders regardless of the refactor (§A.6 / §4.2).
4. Add per-job **error isolation** to `fn_onEachFrame` (today a single erroring PFH aborts the whole `forEach` for that frame → all PFHs skip until next frame). Wrap each job dispatch so one bad job can't starve the others, and auto-disable a job after N consecutive throws (log the disable).

### A.3 Server — build a single master wheel (new)
No per-frame mechanism exists and every server loop suspends, so the server scheduler is **not** a per-frame `call`-dispatcher. It is one master coroutine driving a job wheel:

```
AP_scheduler_jobs = createHashMap;   // id -> [fn, args, intervalS, nextRunTt, mode, inFlight, enabled, errCount, lastMs]
AP_fnc_schedule   = { params [id, fn, intervalS, opts]; ... register/replace ... };
AP_fnc_unschedule = { params [id]; AP_scheduler_jobs deleteAt id };

// single spawned wheel (replaces ~24 permanent spawns with ONE)
[] spawn {
  private _base = 1;                              // base granularity, seconds
  while {true} do {
    private _now = diag_tickTime;
    {
      _y params ["fn","argsGetter","intervalS","nextRunTt","mode","inFlight","enabled","errCount"];
      if (_enabled && {_now > _nextRunTt} && {!_inFlight}) then {
        _y set [nextRunTt, _now + _intervalS];
        switch (_mode) do {
          case "call":  { /* light, non-DB: run inline, guarded */ [args] call _fn; };
          case "spawn": { /* heavy / DB: own thread + in-flight guard so a slow DB job can't stall the wheel */
                          _y set [inFlight, true];
                          [_y] spawn { params ["_j"]; [ (_j#1) ] call (_j#0); _j set [inFlight,false]; }; };
        };
      };
    } forEach (values AP_scheduler_jobs);
    uiSleep _base;
  };
};
```

- **`call` mode** for light non-DB jobs (publicVariable, setVariable, a small forEach) → runs inline in the wheel, cheap.
- **`spawn` mode** for DB-bearing / heavy jobs → transient thread, `inFlight` flag prevents overlap (a 480s vehicle-save that takes 8s under DB-mutex contention won't be re-entered or block the wheel). This is the key: consolidation buys **fewer permanent scheduled scripts + central cadence/ordering + jitter**, not non-suspension for DB jobs (they still serialize on `DB_Async_Active`, §1.3 — call this out, don't pretend otherwise).
- **Jitter / phase-offset (real win):** stagger same-interval jobs. Today many 300s loops can align and hit the DB mutex simultaneously → a periodic lag spike ("thundering herd"). `AP_fnc_schedule` should accept an initial phase offset (or auto-assign one per interval bucket) so 300s jobs fire spread across the window, smoothing DB load.
- **Ordering / warm-up:** one place to sequence boot-time job registration (some loops depend on others having run once). Register with an optional `runAtStart` flag.

Because the base tick is 1s, sub-second server loops (none of the EASY ones are) aren't targets. The 5s/60s/300s loops all quantize fine to a 1s wheel.

### A.4 Job API (both sides)
- **Client:** reuse `AP_fnc_addPerFrameHandler` as-is; optionally extend the tuple with a `name` (for introspection) and an initial-delay/jitter field. Callback contract: **must not suspend**.
- **Server:** `[id, fn, intervalS, opts] call AP_fnc_schedule`, `opts = [["mode","spawn"|"call"], ["jitter",N], ["enabled",true], ["runAtStart",false]]`. `argsGetter` should be a code snippet evaluated at fire-time (not a captured value) so jobs see fresh state. Return an id/handle; `AP_fnc_unschedule id` to remove.
- **Introspection (both):** `AP_fnc_schedulerDump` (admin/debug console) prints every job: id, interval, next-run, last-run-ms, error count, enabled. This is how you *prove* the consolidation and spot a runaway job — a first-class deliverable, not an afterthought.

### A.5 Migration disposition tables

**Server — EASY (register on the wheel; `call` mode unless it writes DB):**
| file:line | interval | job | mode |
|---|---|---|---|
| `initServer.sqf:50` | 600s | re-assert permanent noon | call |
| `server_init.sqf:58` | 200s | day/night `setTimeMultiplier` | call |
| `init.sqf:265` | 5s | fed-event → MaxSec alert edge-detector | call |
| `init.sqf:397` | 2–4h | ambient earthquake | call |
| `init.sqf:703` | 4s | fed-override cooldown clear | call |
| `init.sqf:735` | 20s | cop duty-tenure tracker | call |
| `init.sqf:924` | 3s | fed gate re-lock enforcer | call |
| `init.sqf:1071` | 60s | oil-cartel rubber generation | call |
| `init.sqf:1153` | 300s | bank-vault funds accrual (publicVariable) | call |
| `core/system/fn_spawnGoldBars.sqf:12` | 2–5min | fed gold-bar spawner | call |
| `core/system/fn_laserTag.sqf:9` | 120s | laser-tag arena tick | call |

**Server — HARD (register in `spawn` mode; each keeps its own DB-await):**
| file:line | interval | why |
|---|---|---|
| `init.sqf:123` | 60s | DB query/tick (gangfort auto-start) |
| `init.sqf:291` | 15s | `waitUntil{scriptDone}` + blocking saveVehicles (auto-restart) |
| `init.sqf:372` | 480s | blocking `DB_fnc_saveVehicles` + `updateCaptures` |
| `init.sqf:454/563` | 300s | UPDATE + `_tagHouses` (SELECT + nearestObjects/row) |
| `init.sqf:640` | ~960s var | forEach wanted+allPlayers + nested spawn (APB) |
| `init.sqf:793` | var + 900s window | turf rotation state machine + DB |
| `init.sqf:1034` | 60s | conditional DB REPLACE (cartel-ownership save) |
| `init.sqf:1096` | 300s + inner sleep 2 | storage save (per-item DB) |
| `init.sqf:1184` | 300s | `APS_fnc_cleanup` sweep + cartel auto-deposit DB |
| `init.sqf:1218` | 420s | blocking `DB_fnc_flushAllPlayers` (legacy; candidate to retire) |
| `init.sqf:1289` | 3600s | UPDATE (exchange listing timer) |
| `init.sqf:1312` | 5s | DB SELECT/tick (loonybot command bridge) |
| `core/system/fn_marketTick.sqf:66` | 90s | market recompute + DB |
| `core/system/fn_monitorCaptures.sqf:11` | 60s | cartel capture-progress scan |
| `core/TON/fn_houseFurnitureSRV.sqf:130` | 30s | furniture presence manager |

**Client — EASY (onto `addPerFrameHandler`):**
| file:line | interval | job |
|---|---|---|
| `initPlayerLocal.sqf:254` | 3s | Purge event watcher |
| `initPlayerLocal.sqf:296` | 6s | global cook-smoke attach |
| `initPlayerLocal.sqf:397` | 2s | #41 debug-island rescue |
| `initPlayerLocal.sqf:490` | 2s | cyber-skin mesh attach |
| `core/functions/fn_applyRandomBillboardTexture.sqf:19` | 300s | re-roll billboards |
| `npcs/fn_civConvoy.sqf:19` | 5s | convoy fence markers |
| `core/functions/fn_dynamicMapVehicleFix.sqf:6` | 5s | keep decor loaded near vehicle |

**Client — HARD (stay coroutines):** `initPlayerLocal.sqf:211` (suitcase-collision, inner waitUntil), `:337` (AC scan, inner uiSleep 0.075), `:452` (prison-break bar), `fn_hudSetup.sqf:4` (waitUntil state machine), `fn_dynamicMapSystem.sqf:76` (per-object stream sub-loops), `fn_survival.sqf:195/100`, `fn_trackMarkers.sqf`, `fn_sidechatMonitor.sqf`, and all 92 `step 0` progress loops.

### A.6 Robustness checklist (build into the scheduler)
- **Per-job error isolation** (both sides) + auto-disable after N throws + log.
- **JIP / re-init safety:** don't double-register on respawn/JIP. Mirror the existing `if (isNil "AP_civSavePFH")` guard pattern (`fn_initCiv.sqf:99`, reset per session at `init.sqf:49`) — the scheduler `schedule` call should be idempotent by `id` (replace, not duplicate).
- **Teardown:** jobs tied to a feature/side must `unschedule` on feature end (several current loops leak — see §4.2).
- **Introspection dump** (§A.4).

---

## 3. Workstream B — two-hashmap stat buffer + batched flush

### B.1 Reality check
The 148-array is already a coalescing delta buffer with a dirty-checked delta flush; `A_stats` already flushes on one 300s timer. So "batched" largely exists. What's actually missing/weak: **(1)** no periodic flush for the lifetime deltas → a hard crash loses the whole session's un-flushed deltas; **(2)** the flush resets `APV_tempStats` to zero *immediately after spawning* the MP call — if that call is dropped (net blip), those deltas are lost with no retry; **(3)** flat-index fragility (drift vs `fn_statsFilter`/`fn_titleCfg`); **(4)** two parallel systems + 17 hard-named globals; **(5)** lifetime stats aren't live-readable (every read is a DB round-trip via `APS_fnc_getStatsArr`).

### B.2 Target model — the two hashmaps
Unify both subsystems into one keyed model. **Two hashmaps** (keys = stat *names*, not indices):

- **`AP_stats_live`** — the authoritative in-memory **absolute** values for this session (loaded from DB at login; read directly for titles/thresholds/UI — kills the on-demand DB reads). Mutations update it.
- **`AP_stats_dirty`** — the **pending-delta buffer**: name → accumulated delta since last successful flush. This is the batch that gets sent. (Deltas, because the server does read-modify-write to combine with other sessions — never send absolutes or you clobber concurrent updates.)

Flush uses **swap-on-flush double-buffering:** atomically move `AP_stats_dirty` into a local `AP_stats_inflight`, install a fresh empty `AP_stats_dirty`, send `inflight`. New mutations during the async flush accumulate in the fresh dirty map (nothing lost, no mutation blocking). On server **ack**, drop `inflight`; on failure/timeout, **merge `inflight` back** into `AP_stats_dirty` (add deltas) so the next flush retries. This closes the drop-on-reset gap in today's code.

> "Two hashmaps" = `AP_stats_live` + `AP_stats_dirty` (with `inflight` as the transient third during a flush). If the owner prefers the literal minimal reading, it collapses to live + dirty and the swap uses a local var — same design.

### B.3 Write API (keep the call sites unchanged)
Do **not** touch the 96 `statArrUpdate` call sites or the 7 `updateRemoteStat` sites. Reimplement the two functions as thin shims over the maps:
- `["name", delta] call AP_fnc_statArrUpdate` → `AP_stats_live` add delta; `AP_stats_dirty` add delta. (Same name→index switch stays, but now only used at serialize time, §B.6.)
- `updateRemoteStat` cases → map keys for the 17 `A_stats_*`. Provide compat accessors (or `#define`/getter) anywhere code reads a raw `A_stats_*` global, so `A_stats_warRating` etc. resolve from `AP_stats_live`. (Grep the read sites — `fn_statsFilter`, `fn_titleCfg`, HUD, bounty — and route them through a `["name"] call AP_fnc_getStat` getter reading `AP_stats_live`.)

Net: call sites unchanged, storage becomes maps, reads become live.

### B.4 Flush — cadence + mechanism
- **Register a periodic flush job on the scheduler** (client PFH, e.g. 120s) that flushes `AP_stats_dirty` if non-empty. This is the durability fix.
- **Keep every existing event trigger** as an immediate flush (respawn, manual Sync, T-55 restart, quit, server force-flush) — they call the same flush fn.
- **Flush fn:** dirty-check → swap → serialize → send → ack/merge-back (§B.2).
- **Server side — batched RMW:** keep `APS_fnc_statTableUpdate`'s delta RMW for the lifetime column. For unification, the flush sends **both** the lifetime deltas and the `A_stats` deltas in one MP call; the server applies both and writes with as few queries as the columns require (lifetime_stats = SELECT+UPDATE; stats = 1 UPDATE). Add an **ack** back to the client (netSetVar or a tiny MP callback) so the double-buffer can confirm/merge-back.
- **Optional (cross-cutting, §4.1):** a multi-field UPDATE builder so a flush touching several `players_global` fields is one UPDATE, not N.

### B.5 Unify A_stats into the same buffer
`A_stats` is *absolute + loaded-at-login + read-live*, which the `AP_stats_live` map already provides. Fold the 17 counters in as named keys; the 60s time-tick (`fn_initStats.sqf`) becomes `["civTime",1] call statArrUpdate` on the scheduler; the 300s `[9] ClupdatePartial` flush is replaced by the unified periodic flush. Preserve the 17-slot pack order (`fn_ClupdatePartial.sqf:155` / `fn_requestReceived.sqf:119`) at the serialize boundary so the DB format is unchanged.

### B.6 Login load + serialization — NO schema/data migration
- **Serialize on write:** map → array via the `fn_statArrUpdate` name→index switch (lifetime, plain `str` array) and the fixed 17-order (A_stats, mres array). Byte-identical to today's DB format. This is the invariant that makes the refactor safe: **the DB never knows the client switched to maps.**
- **Deserialize on login:** add `lifetime_stats` to the login SELECT (`fn_queryRequest.sqf` — it currently loads `stats` at field 14 but *not* `lifetime_stats`). On `fn_requestReceived`, hydrate `AP_stats_live` from both columns (array→map via the same index maps). This also removes the `APS_fnc_getStatsArr` on-demand read for display (net DB reduction). Watch the #462 hazard: keep the two columns separate; the >17-length guard in `fn_requestReceived.sqf:106` stays as a safety net.
- Delete the vestigial `APV_savedStats`.

---

## 4. Cross-cutting DB wins (surfaced by the audit — high value, low effort)

### 4.1 Kill the `-FNCALL-` audit doubling for routine saves (biggest cheap win)
`fn_MP.sqf:15–31` re-logs every MP call whose lowercased name matches a `AP_logCallList` substring (`"update"`,`"query"`,…) → a second remoteExec + a `log` INSERT per save. `DB_fnc_updatePartial` fires on every cash/gear/position/stat field change → it dominates this volume.

**Fix = an exact-fn-name DENY set in `fn_MP.sqf`, checked before the audit fires.** Deny `DB_fnc_updatePartial`, `DB_fnc_updateRequest`, `APS_fnc_statTableUpdate` (optionally `DB_fnc_queryRequest` — low volume, login-only). 

**Do NOT instead remove the `"query"`/`"update"` substrings from `AP_logCallList`** — `"query"` is precisely what makes a client-invoked raw `DB_fnc_asyncQuery` show up in `-FNCALL-`, which CLANKR's RCE tripwire (`DANGER`) depends on. Keep the substrings; add the exact-name deny set on top.

**CLANKR-safety verified (see §9 cross-check):** clankr.py is the only automated consumer; its `DANGER` set already excludes the DB wrappers, `FNCALL_SPAM_WATCH` is only `APS_fnc_bankRobbery`, and `DISCOVERY_SKIP` already contains `db_fnc_`/`stattableupdate`/`updateremotestat`. So the deny set has **zero** detection impact — pure write-volume reduction. Ship independently (Phase 0), measurable via `log` INSERT rate.

### 4.2 Fix the no-sleep / no-teardown loop bugs (independent of the refactor)
- `fn_medicHexs.sqf:1` — per-frame `Draw3D` over `allPlayers` for the whole session on every on-duty medic, **no gate/teardown** (heaviest steady client loop). Gate on a mode flag + self-remove (mirror `fn_coloredHexes.sqf` / the #561 `fn_gangFortHud` fix).
- `fn_gangBoatDefense.sqf:7` — no-sleep spin for a civ on foot near the boat fortress. Add `uiSleep`.
- `fn_markIllegalAreasMenu.sqf:225` — `while{!isNull _this}` with no `uiSleep`, a `findIf`/row/frame while the menu is open. Add `uiSleep 1`.
- Drug-runner / DP "no-sleep countdown" cluster: `fn_airplaneDrugRunner.sqf:102/233/174/305`, `fn_getDPMission.sqf:159` — spin for multi-minute deliveries. One fix pattern (add the missing `uiSleep`).
- `fn_gangBoatHud.sqf:18` — per-frame Draw3D scoreboard, no self-teardown; lingers to restart.
- `fn_spawnConfirm.sqf:135` — `while{true}` calling `BIS_fnc_findSafePos` with no sleep.

### 4.3 DB mutex note (set expectations)
`DB_fnc_asyncQuery` serializes ALL queries on `DB_Async_Active`. A centralized server tick that fans out DB reads still bottlenecks here — batching *reduces the number of queries* (good) but doesn't parallelize them. Don't promise concurrency the mutex can't give. (A future item: a real per-request queue — the dead `fn_queueManagement` was meant for this — but out of scope here.)

---

## 5. Rollout — incremental, each phase independently shippable & testable

- **Phase 0 — cheap wins. SHIP NOW, standalone (not gated on the refactor).** §4.2 (no-sleep/no-teardown bug fixes) can go immediately. §4.1 (`-FNCALL-` deny-list) goes as soon as the CLANKR watch-list cross-check (§9) confirms which fns are exploit-signals. Isolated, immediately measurable (`log`-INSERT rate, medic-side FPS), low risk.
- **Phase 1 — server scheduler.** Build `AP_fnc_schedule` + wheel + `schedulerDump` (+ jitter + per-job error isolation + in-flight guard). Migrate the 11 EASY server loops (`call` mode). Register the 15 HARD ones in `spawn` mode. *After* consolidation lands: the targeted hot-poller tweaks (§9 — 5s loonybot bridge, `monitorCaptures`). Do NOT delete the dead queue / legacy `flushAllPlayers` here — that's the deferred cleanup pass.
- **Phase 2 — client scheduler finish.** Migrate the 7 EASY client loops onto `addPerFrameHandler`; add per-job error isolation to `fn_onEachFrame`; (the client HOT-loop fixes already shipped in Phase 0).
- **Phase 3a — durable stat buffer (lifetime).** Introduce `AP_stats_live` + `AP_stats_dirty` behind the unchanged `statArrUpdate` API; route reads through a `getStat` getter; add the 120s flush job (§B.4) + double-buffer + ack/merge-back; hydrate `lifetime_stats` at login (§B.6); delete `APV_savedStats`. Serialize to the existing DB format (no migration).
- **Phase 3b — unify `A_stats`.** Fold the 17 counters + their read sites into the same map + flush; retire the standalone 300s `[9]` flush. Higher-touch; land 3a first.
- **Phase 4 — optional.** Multi-field UPDATE coalescing; revive a real DB request queue; the deferred dead-infra cleanup.

Front-load Phase 0 + Phase 1 (owner: highest-return/lowest-risk). Each phase merges to `doomba` and is validated on the isolated test server before the next.

---

## 6. Risks & mitigations
- **Client callback suspends by accident** → aborts the EachFrame handler that frame. Mitigate: enforce non-suspend in review; per-job isolation; the wheel self-heals next frame but log it.
- **Server heavy job blocks the wheel** → use `spawn` mode + `inFlight` guard for anything DB/heavy; never `call` a DB read in the wheel.
- **Stat delta loss during migration** → the double-buffer + ack/merge-back must be correct; add a temporary DB-visible counter (`APS_fnc_logIt`, since the RPT is block-buffered on the box) comparing deltas-sent vs deltas-acked during test.
- **Index drift on serialize** → `fn_statArrUpdate`'s switch is the ONLY source of truth; unit-check the map→array round-trip preserves every index; keep the `fn_requestReceived` >17 guard.
- **JIP double-registration** → idempotent `schedule` by id; mirror the `isNil "AP_civSavePFH"` guard.
- **Infamous's code** → `git blame` each loop before moving it; some `init.sqf` loops may be his — flag + get owner OK; a straight lift-onto-scheduler still counts as touching his code.
- **Live server** → this is a broad refactor. Test on the isolated test-server (the MasterHandler 2-account recipe). Do NOT hot-deploy to live mid-population. Stage → verify → owner-scheduled restart.

## 7. Testing & rollback
- **Test server** for every phase (isolated, real DB copy or the dev schema).
- **Before/after metrics:** count permanent scheduled scripts (via `schedulerDump` + `diag_activeScripts`-style probe), `SQL Query:` RPT lines/min (or `log`-table INSERT rate for the `-FNCALL-` win), server FPS under simulated load, stat deltas-sent vs deltas-persisted.
- **Rollback:** each phase is a self-contained commit range on `doomba`; revert the range. The stat buffer keeps the DB format identical, so reverting the client is safe (DB is unchanged). Keep the old spawn-loop code path behind a `AP_useScheduler` flag during Phase 1/2 bring-up so you can flip back live without a repack.

## 8. Concrete file work-list for Opus
**New:** `server/AP_server/core/system/fn_scheduler.sqf` (or `AP_fnc_schedule` + wheel + dump); register in `config.cpp`. Client: extend `mission/.../evh/eachFrame/fn_onEachFrame.sqf` (isolation) + optionally `fn_addPerFrameHandler.sqf` (name/jitter).
**Edit (scheduler):** `server/AP_server/init.sqf` (convert the loop bodies to `schedule` calls), `initServer.sqf`, `server_init.sqf`, `core/system/fn_spawnGoldBars.sqf`, `fn_laserTag.sqf`, `fn_marketTick.sqf`, `fn_monitorCaptures.sqf`, `core/TON/fn_houseFurnitureSRV.sqf`; client `initPlayerLocal.sqf`, `fn_applyRandomBillboardTexture.sqf`, `npcs/fn_civConvoy.sqf`, `fn_dynamicMapVehicleFix.sqf`.
**Edit (stats):** `core/functions/fn_statArrUpdate.sqf`, `fn_updateRemoteStat.sqf`, `fn_initStats.sqf`, `core/session/fn_ClupdateRequest.sqf` (+`fn_ClupdatePartial.sqf` mode 9), `fn_requestReceived.sqf` (login hydrate), `dialog/function/fn_statsFilter.sqf` + `core/config/fn_titleCfg.sqf` (read via getter), `core/configuration.sqf` (map init, drop `APV_savedStats`); server `core/TON/fn_statTableUpdate.sqf` (ack), `core/DB/fn_queryRequest.sqf` (add `lifetime_stats` to login SELECT), `core/DB/fn_updatePartial.sqf` (optional multi-field).
**Edit (cheap wins):** `core/functions/network/fn_MP.sqf` (`-FNCALL-` deny-list); the §4.2 bug files.
**Delete/retire (confirm unused first):** `APV_savedStats`; dead `fn_addQueue`/`fn_processQueue`/`fn_queueManagement`; legacy `AP_update_buffer` + `fn_flushAllPlayers` path.

## 9. Decisions — RESOLVED (owner, 2026-07-05)

**Driver: "all of it" / cleanliness.** → Build the full phased plan, but front-load Phase 0 + Phase 1 (lowest-risk, highest-return) regardless.

**Stat buffer depth: FULL.**
- Two-hashmap `AP_stats_live` + `AP_stats_dirty` (double-buffer, swap-on-flush, ack + merge-back).
- **Load `lifetime_stats` at login = YES** — add it to the login SELECT (`fn_queryRequest.sqf`), hydrate the live map, drop the on-demand `APS_fnc_getStatsArr` read for display. Keep the columns separate + the `fn_requestReceived.sqf:106` >17 guard (#462 hazard).
- **Unify `A_stats` into the map = YES**, but sequence it as **Phase 3b** (get the durable buffer landed in 3a first, then fold the 17 counters + their read sites).
- Durability flush cadence = **120s** (scheduler-driven PFH), plus all existing event triggers kept as immediate flush.

**Server hard loops (the 15 DB-bearing): CONSOLIDATE-ONLY + tweak the hot pollers.**
- All 15 register on the wheel in `spawn` mode, bodies keep their own DB-await (behavior-identical; gains = fewer permanent scripts, jitter, dashboard, error-isolation, overlap-guard). Rationale: the `DB_Async_Active` mutex serializes queries regardless, so restructuring into state machines would be ~10× the work for a payoff the mutex erases.
- **Targeted tweaks (not a blanket restructure):** the **5s loonybot command bridge** (`init.sqf:1312`) is a hot DB poll — evaluate reducing its cadence or making it event-driven/longer-interval; re-examine **60s `monitorCaptures`** (`fn_monitorCaptures.sqf:11`) for whether it needs its DB touch every tick. Treat these as individual optimizations after the consolidation lands, not blockers.

**Cheap wins (Phase 0): SHIP NOW as standalone `doomba` fixes** (don't gate on the refactor):
- `-FNCALL-` audit deny-list (`fn_MP.sqf`) — **but first cross-check the CLANKR watch-list**: confirm the firehose `-FNCALL-` log isn't relied on as a general audit trail and that only specific exploit-signal fns (`bankRobbery`, etc.) need to survive; then exclude `updatePartial`/`updateRequest`/`statTableUpdate`/`queryRequest`/`saveGear`.
- The no-sleep / no-teardown loop bugs (§4.2): `medicHexs`, `gangBoatDefense`, `markIllegalAreasMenu`, the drug-runner/DP countdown cluster, `gangBoatHud`, `spawnConfirm`.

**Defaults locked (owner did not object):** `AP_useScheduler` feature-flag for Phase 1/2 live rollback-without-repack = YES; server wheel base tick = 1s; retire dead infra (`queueManagement`, legacy `update_buffer`/`flushAllPlayers`) = **defer to a cleanup pass** (confirm-unused first, don't block); the ~130 feature-session loops (sirens/watchdogs) = **leave** (non-goal).

**CLANKR `-FNCALL-` cross-check: DONE — SAFE (2026-07-05).** `clankr.py` is the only automated `-FNCALL-` consumer; it acts on exactly three things, none touched by the trim:
- `DANGER` (RCE tripwire) = `asyncquery | callextension | execvm | bis_fnc_mp | _fnc_compile | preprocessfile` — the code comment explicitly *removed* a broad `db_fnc_` match ("clients DO legitimately remote-call the DB request wrappers … false-spammed HIGH ×12"). DB save wrappers already excluded.
- `FNCALL_SPAM_WATCH` = config `["APS_fnc_bankRobbery"]` only.
- `DISCOVERY_SKIP` = `("db_fnc_", "stattableupdate", "updateremotestat")` — CLANKR *already* ignores exactly the plumbing fns.
Other `log` consumers (`admin.py !logs`, `latoya.py`, `scan_*.py`) use different tags / all-tags manual history. → The trim = zero detection impact, pure write-volume win. See the exact-name deny constraint in §4.1.

**Phase 0 now has ZERO blockers. The whole plan is decided and ready for implementation.**

## 10. Implementation progress (live)
- **medicHexs (2026-07-05): LEAVE ALWAYS-ON** (owner) — no toggle; per-frame Draw3D cost accepted (on-duty medics only). Dropped from the fix list.
- **Deploy safety (2026-07-05): FLAG-GATED, rides b0128 inert** (owner) — Phases 1-3b build behind `AP_useScheduler` (+ a stat-buffer flag) default OFF; safe to auto-deploy, activated by flip + restart (no repack).
- **Phase 0 — DONE** (doomba `eb021e6`, staged b0128): `-FNCALL-` deny-set + 6 no-sleep/no-teardown loop fixes. medicHexs left per decision.
- **Phase 1a — DONE** (foundation): `server/AP_server/core/system/fn_scheduler.sqf` = the wheel + `AP_fnc_schedule`/`unschedule`/`schedulerStart`/`schedulerDump` (transient error-isolated per-job spawns, in-flight + stale-run watchdog, jitter, auto-disable, dump). Registered in `config.cpp`; API installed in `init.sqf`. Fully INERT (no jobs, wheel not started, flag off).
- **Phase 1b — PARTIAL, then PAUSED** (`4b5f6ac`): migrated `copTenure` (20s) + wired `AP_fnc_schedulerStart`. **Finding:** the simple closure-extraction pattern only migrates fully self-contained loops — of 11 targeted "easy" loops only 1 was clean; the rest capture enclosing locals (edge-detector state, once-computed config, spawn args), have one-shot boot setup before the loop, are self-exiting conditional-whiles, or are variable-interval. The high-value DB-jitter payoff lives in the HARD loops (riskiest). Owner (2026-07-05) chose to **pivot to Phase 3** rather than push the server migration. To resume later: enhance the scheduler with per-job persistent state + a first-run init hook, then tailor-migrate.
- **Phase 3a CORE — DONE** (`da7aa39`, INERT behind `AP_useStatBuffer` default off): `AP_stats_dirty`/`AP_stats_inflight` hashMaps; `fn_statArrUpdate` dual-write; `fn_flushStats` (double-buffer swap → same `[[idx,delta]]` wire shape → no schema/server change); `fn_ClupdateRequest` event-flush gated; 120s durability PFH in `fn_initStats`. Legacy `APV_tempStats` path byte-for-byte unchanged when the flag is off.
- **Phase 3a.2 — DONE** (`47c2229`, INERT behind the flag): login SELECT loads `lifetime_stats` → hydrated into `AP_stats_live` at `fn_requestReceived` (reply **index 36**, AFTER the side switch — index 15 is the side slot; the collision was caught in adversarial review before it could ship broken flag-on). `fn_statArrUpdate` keeps `AP_stats_live` current; `fn_getMyStats` builds `APV_statTotals` from the live map (no DB round-trip) when the flag's on — the 100+ inline `APV_statTotals` reads in `fn_titleCfg`/`fn_statsFilter` are untouched (only the source changed). Login change is purely additive → safe even flag-off.
- **Phase 3b — DONE** (`482c15e`, INERT): A_stats flush folded into `fn_flushStats` (dirty-tracked via `AP_astats_dirty`, whole-array mode 9), independent of the lifetime delta buffer; the standalone 300s `[9]` PFH now fires only flag-OFF. Named `A_stats_*` globals + their 100+ read sites + the mode-9 pack UNTOUCHED (light unify by design). **Phase 3 COMPLETE** (durable buffer + login-load + live reads + A_stats unify), all behind `AP_useStatBuffer` default off.
- **Phase 2 — PARTIAL** (`110cb01`, INERT behind `AP_useScheduler`, client default in `configuration.sqf`): migrated `initPlayerLocal` cook-smoke (6s) + Cyber-Ifrit mesh (2s) onto the existing `addPerFrameHandler`; else branches byte-identical. Deferred `fn_onEachFrame` per-job isolation (unconditional every-frame every-client change = blast radius too broad for the gain).

### Scheduler ENHANCED + loop-migration COMPLETE (`eec506a` + `10a0bb1`)
The simple closure pattern only migrated 3 loops (cross-iteration state / boot-setup / leading-sleep blocked the rest). So the scheduler was **enhanced**: each job carries a persistent per-job **state hashMap** (`params ["_st"]`) for cross-iteration state, a **first-run-init** convention (`_st getOrDefault ["init",false]`) for one-shot boot setup that used to sit before the loop, and **self-unschedule** for conditional-while loops. That unlocked the tailor-migration: **20 loops now on the wheel**, all flag-gated (`AP_useScheduler` default off), all adversarially verified (init.sqf change is **purely additive, 0 deletions** → every original loop untouched → flag-off = byte-identical).
- **init.sqf (15):** copTenure, fedAlert, fedOverrideClear, fedGateRelock, oilRubber, bankFunds, gangfortAuto, vehSave, houseTax, cartelOwnSave, storageSave, cleanupCartel, flushPlayers, exchangeTimer, botBridge — incl. the DB-heavy 300s+ jitter targets.
- **separate server (4):** dayNightTime, marketTick, monitorCaptures, houseFurniture.
- **client (2):** civConvoy, billboard (on `addPerFrameHandler`, `_st` via the `createHashMap` args slot).

### Genuinely un-migratable (stay as spawn loops — this is the "everything we can" boundary)
Variable per-iteration interval (earthquake, APB, spawnGoldBars); `waitUntil`-window state machines (turf 900s, laserTag); runs-before-the-scheduler-API (initServer noon); HARD client loops that suspend mid-body (survival, prison-break, dynamicMapSystem, hudSetup, sidechat — client PFHs can't suspend); the ~130 feature-session loops + 92 progress-bar coroutines (non-goal). One marginal client loop (Purge watcher) is migratable but low-value + left.

- **Remaining (optional)**: Phase 4 (multi-field UPDATE coalescing, dead-infra cleanup). **Validation gates before any live flag-flip**: `AP_useScheduler` (`AP_fnc_schedulerDump` + FPS + confirm each migrated job fires on schedule) and `AP_useStatBuffer` (deltas persist byte-identically vs legacy) each get test-server validation first.
- **Validation gate**: the whole stat buffer (3a/3a.2/3b) must be validated on the isolated test-server (flip `AP_useStatBuffer` there, confirm deltas persist byte-identically vs the legacy path) before the flag is flipped anywhere near live.
