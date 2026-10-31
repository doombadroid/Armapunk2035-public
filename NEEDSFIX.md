# NEEDSFIX

Deferred fixes that need a careful/vetted change (usually config-level = mission-load risk).

---

## Jet passive radar — true sensor removal (config patch)

**Status:** PARTIAL. Runtime mitigation is LIVE-staged; the real fix is deferred.

**What's done (runtime, safe):** `server/AP_server/core/system/fn_spawnVehicle.sqf` — every spawned `isKindOf "Plane"` gets `setVehicleRadar 0` + `setVehicleReceiveRemoteTargets/ReportRemoteTargets/ReportOwnPosition false` on spawn. Kills the ACTIVE radar HUD + datalink targeting.

**What's still needed:** the **PASSIVE radar sensor** is a `CfgVehicles` component — no runtime command removes it, and a pilot can re-toggle the active radar with the radar key. To actually kill passive radar:
- Add a `CfgVehicles` patch in `mission/LooneyBin.Altis/config.cpp` (currently has NO CfgVehicles block) that, per buyable jet class, does `delete PassiveRadarSensorComponent` inside `Components >> SensorsManagerComponent >> Components` (or zeroes its ranges).
- Buyable jet classes: `B_Plane_CAS_01_dynamicLoadout_F` (Wipeout), `I_Plane_Fighter_03_CAS_F`, `I_Plane_Fighter_04_F` (Gryphon), `Plane_Fighter_03_F`.

**Why deferred / RISK:** a wrong parent-class chain or sensor class name = config fails to bind = mission won't load = **mass kick** (the 2026-06-16 deploy disaster). Must verify the exact base-class hierarchy + `SensorsManagerComponent` structure against the real Arma configs and test before deploying. Do it as its own isolated, vetted deploy — not bundled.

---

## #260 — suicide + alt+F4 → reconnect ALIVE with no gear

**Status:** DEFERRED (high impact — gear loss). Reporter: player006, 2026-06-15.

Player picks suicide on the death screen, alt+F4s during the death/respawn window, then reconnects **alive** (death never committed) but **stripped of all gear** (death already wiped it). Classic combat-log-during-death = inconsistent persisted state.

**Why deferred / RISK:** needs the full death→disconnect→DB→reconnect flow mapped (`fn_onPlayerKilled` → `fn_playerDisconnected` → flushPlayer/save → `fn_requestReceived` on rejoin). Wrong fix risks corrupting the alive/dead flag or the loadout column for EVERY disconnect. Right fix: on disconnect while dead/downed, COMMIT the death (so they rejoin fresh at spawn-select), OR on rejoin detect alive+no-gear and route to spawn-select. Vet against the disconnect-dupe house-save patch already in `fn_playerDisconnected`.

---

## #268 — spectating a player who disconnects → stuck on the dead body

**Status:** DEFERRED (admin-only). Reporter 2026-06-16.

Admin EG spectator (`core/admin/fn_adminSpectate.sqf`, `BIS_fnc_EGSpectator`). When the spectated unit disconnects, the BI spectator loses its focus unit, the camera sticks on the gone body, and F8/terminate doesn't fully restore input ("can't open anything, even phone").

**Why deferred / RISK:** it's a BI module — patching its null-target handling blind is risky and the feature is admin-only (low blast radius). Right fix: harden the F8 terminate path (always `["Terminate",[player]] call BIS_fnc_EGSpectator` + remove the KeyDown EH + restore camera) and add a guard that drops the admin out cleanly if the focused unit becomes null. Test with a real DC.

---

## #265 — Kavala drug dealer interaction tanks FPS

**Status:** NEEDINFO / investigate. Reporter 2026-06-16 (during a weed run).

FPS craters when interacting with the Kavala drug dealer (`AP_fnc_virtualShopMenu` sell NPC). Could be the menu rebuild, a per-frame addAction condition, or the dynamic-market price recompute querying on open.

**Need from reporter:** is the drop while the **menu is open**, or just standing near the NPC? Which exact dealer/location? Then profile the open path (virtualShopMenu populate + market price calc).

---

## #254 — drug-cartel vehicle garage spawns Hatchback Sport into the pole

**Status:** DEFERRED (map work). Reporter 2026-06-15.

Pulling a Hatchback Sport at the drug-cartel garage spawns it too close to the pole → desync → kills nearby players (had to revive 1). Spawn point is too tight / no clearance check.

**Fix path:** move the drug-cartel garage spawn point clear of the pole (map-data / `fn_spawnVehicle` spot), or add an occupancy/clearance check + offset like the airDrop `findSafePos` pattern. Needs the exact spawn coords + a test pull.

---

## #275 — no actual oil cartel to cap

**Status:** DEFERRED (map work). Reporter 2026-06-16.

Oil cartel has no cappable flag/zone on the map. The cap system references `oil_flag` / `oil_cartel` (see `fn_airDrop`, `fn_captureCartel`) but the flag object / marker isn't placed.

**Fix path:** verify `oil_flag` object + `oil_cartel` marker + the `fn_spawnCaptures` setup for oil exist and are placed on Altis; add via the map-data / Eden pipeline if missing. Cross-check against arms/drug/wongs which DO work.

---

## #273 — player has a title they didn't earn

**Status:** NEEDINFO. Reporter player095, 2026-06-16 (screenshot attached).

Player shows a title (`AP_title`) they say they didn't unlock. Could be a title-grant/achievement-condition bug or a default seeded wrong.

**Need:** which exact title, and the screenshot detail. Then trace the title source (`AP_fnc_titleCfg` / `getMyStats` / the achievement that grants it) to see if its unlock condition is too loose or seeded by default.

## 2026-08-20 — dev-env round (parked, owner moving on)

- **MariaDB schema drift vs duty code (FIXED on dev, unfixed anywhere else):** `fn_queryRequest`'s
  login SELECT reads `faction_rep`/`faction_talents` and ArmaQuest needs `armaquest_state`; both
  migrations (`sql/faction_rep.sql`, `sql/armaquest_state.sql`) had only ever been applied to the
  PostgreSQL scratch DB — every evening playtest silently ran on the PG engine (pysqfd carried
  `AP_DB_POSTGRES=1` since 10:42), so extDB3/MariaDB never saw the queries until the daemon was
  restarted flagless. Applied to `looneybin_test` 2026-08-20. **Any other MariaDB target (live!)
  needs the same two files before this branch reaches it.**
- **`createlocation` disabled-command flood — FIXED 2026-09-01 (b0825).** Root cause: `CfgDisabledCommands`
  blocked `createLocation` on all three targets, and that command is CBA's namespace primitive
  (`CBA_fnc_createNamespace`). A disabled command returns nil, so every CBA cache guarded by "namespace is
  null -> build it" could never populate and retried at its caller's frame rate (22,570 blocked calls in 16
  minutes on 2026-09-01; only ever seen with the six editor mods loaded, never with `@Armapunk2035` + CBA
  alone). Nothing in the mission or server calls `createLocation`, locations are local, and `CfgRemoteExec`
  already sets `class Commands {mode = 0;}` — so the client block protected nothing. Now `{0, 1, 0}`:
  enabled on the client, still blocked on server and HC.
- **Evening-of-08-20 progress lives in PostgreSQL, not MariaDB:** everything saved during the
  b0703/b0704 playtests (money deltas, positions, the duty flushes) went to `pgm_full_scratch`.
  extDB3 dev play resumes from the morning state. Dev-only, no action, just don't chase "my money
  reverted" as a bug.

## 2026-08-20 (later) — extDB3/MariaDB RIPPED from dev (owner call), fallout inventory

Supersedes the "apply migrations to MariaDB" bullet above: there is no MariaDB any more. The dev box
runs **PySQF/PostgreSQL only** (`pgm_full_scratch`). `looneybin-db` container + volume deleted after a
final all-databases dump; `@extDB3` parked; both live at `~/db_final_dumps/`. `sql/` deleted from the
repo (git history keeps it; PG schema authority is the pgmigrate corpus). `run-armapunk2035.sh` no
longer loads `@extDB3`; `server/AP_server/init.sqf` now waits for the engine decision and tolerates the
absent extension when PG is live (unwaited, the old guard aborted the whole init — b0707 half-boot).

Open fallout, by owner "rip now, fix fallout":
- ~~**ArmaQuest store is broken on PG**, two ways: its flush tick calls `apdb.query` from an unscheduled
  context (refused by design) and even the scheduled saves fail chunk read-back
  (`#aq.sqlcorrupt:missing-chunk`, sent 164 chars / reassembled 28). Quests don't persist.~~
  **RESOLVED — verified 2026-08-30.** Both halves were fixed and this entry was simply never closed.
  The unscheduled path went in `e1f3aa63` ("U1+U2 -- the last unscheduled DB path scheduled, and the
  chokepoint guards the class"); the chunk round-trip was root-caused upstream and re-vendored across
  the `chore(aq)` series (payload-shaped canary, first-divergence diagnostic, no-escaping discipline,
  single reassemble-and-compare save).

  Evidence, from the 2026-08-30 13:47 dev boot rather than from the code having been changed:
    - `[AQ] storeSql init: escaping calibrated to 'quote' -- a canary containing a quote, a backslash
      and a double quote round-tripped byte-identically under it.`
    - `[AQ] srvInit: restored 18 board offer(s) across 6 giver(s).` — the `board` record is 16,685
      chars across **12** chunks, so that line is a successful multi-chunk reassembly, which is the
      exact operation that used to fail.
    - `grep -c sqlcorrupt` and `grep -c DBGUARD` over the whole current log: **0** and **0**.
    - `armaquest_state` rows carry `updated_at` values LATER than that boot, so the flush tick is
      writing, not just reading.

  The "QUOTE(data) on the PG path is suspect" lead was wrong and is recorded here so nobody chases it
  again: `case "load"` and `_loadReassemble` both issue a plain `SELECT data`, neither wraps, and
  running the exact chunk SELECT through `apdb.query` directly returns the stored string byte-for-byte
  (164 chars in, 164 chars out). The stale suspicion came from `init`'s own canary comment, which
  still describes the readback as "the same QUOTE(data) SELECT `load` uses" — it is not, and that
  comment should be corrected the next time that file is re-vendored upstream.
- **mres decode noise at every PG login** ("Missing ]" on gear/licenses/crimes, 4×/login): the
  be582da9 re-wrap compensation doesn't cover every column shape on the apdb path. Gear appeared to
  load anyway in tonight's playtests — noise now, wrong-data risk later. pg workstream.
- **loonybot is pymysql→127.0.0.1:3306** (latoya/enrique) — target gone. Service was already stopped,
  nothing broke; port to psycopg/PG before re-enabling (its tables exist in `pgm_full_scratch`).
- extDB3 stored-proc calls (`resetLifeVehicles`, `updateLifeHouses`) now go through the translator —
  verify they actually do anything on PG, or reimplement as plain SQL.


## 2026-09-07 — live (.96) go-live leftovers
- `AP_fnc_mapSelfTest` phase 7 ("production focus") is inconsistent on a headless client: the tick
  (`fn_mapTick.sqf:20-22`) uses `AP_mapFoci` when `!hasInterface`, but the test computes `_want7`
  from `AP_fnc_mapFocus` (the player position). Live HC: 1,209 vs 2,401 FAIL; dev HC passes by
  coincidence. Skip or recompute the phase for `!hasInterface`. Everything else 9/10 PASS on live.
- `Server: Object 2:344 not found` once at live boot (mission.sqm reference) — identify the entity.
- NAS pull cron for `.96:~/pg_backups/` needs root on samurai (cron spool dir missing) — MIGRATION_96.md §12.
- **FIXED 2026-09-07 22:05 (05cf88b1):** mapdb load sat inside init.sqf's once-per-PROCESS `uiNamespace AP_sql_id` block → skipped on every soft `#restart`, `APS_mapReady` nil, all clients refused ("cache not ready"), nothing streamed ("all custom buildings gone"). Watch for the same class: anything else that must run per MISSION must not live inside a uiNamespace-guarded block.
- HC's first map fetch after joining is refused (`fetch: no resolvable requester`, remoteExecutedOwner 0 while the HC is not yet in allPlayers) and the client retries only after `retry` (90 s). Shorten the HC retry or resolve the requester by unit earlier.
