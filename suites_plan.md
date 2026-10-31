# Luxe Suites Implementation Plan

> Spec: `suites.md` (owner-approved 2026-08-06). Plan lives at repo root because
> `docs/` is gitignored — verified, same reason the spec does.

**Goal:** Lease whole floors of the Skyscraper30 lux tower as residences — 120 ND
per 30 days, automatic renewal, 10-day grace then repossession, storage, a
lockable front door, furniture.

**Architecture:** A parallel subsystem to houses (see spec §1 for why). New
`suites` table, new `APS_fnc_suite*` server functions, new `AP_fnc_suite*`
client functions, one new dialog, one baked kiosk texture. Reuses the ND wallet,
the scheduler wheel, the mres codec and the hydrate/dehydrate storage pattern.

**Tech stack:** SQF, extDB3 → MariaDB `looneybin_test` (docker `looneybin-db`,
verified reachable), Python + PIL for the kiosk art.

## Global Constraints

Copied verbatim from the spec and the project's rule files; every task inherits
these.

- **Never trust a client-supplied UID or oid for authorization.** Caller identity
  comes from `remoteExecutedOwner`.
- **Every new client→server function needs a `CfgRE.hpp` entry** (`mode = 1`
  whitelist) or it fails silently. `allowedTargets = 2` for client→server.
  `APS_fnc_ndDebitSrv` must be **absent** from CfgRE — that absence is what makes
  it server-only.
- Client fns registered in `Functions.h`; server fns in
  `server/AP_server/config.cpp`. Unregistered = silently missing.
- **Unix stamps are written with `toFixed 0`**, never `format ["%1", …]` — SQF
  renders large numbers in scientific notation and corrupted `houses.miner`.
- **ND arithmetic stays in SQL** on `DECIMAL(20,4)`; amounts move as 4dp strings.
- **`exitWith` inside a nested `else {}` only leaves the inner scope** — every
  payment bail also sets an explicit `_exit` flag (the 2026-07-24 free-item bug).
- Clear `AP_suiteTxn` on **every** exit path including each `exitWith` (the
  aging-barrel hang, BUGS.md:27).
- Brace/bracket balance check before every deploy: `python3 tools/sqf_balance.py <files>`.
- Deploy is `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`; success
  marker is `read from bank` in `/home/timb/arma3server_dev/loonydev.log`.
- Commit trailer: `Co-Authored-By: <defunct AI>`, name only, no email, rotate.

## Testing instrument (no test harness exists)

This codebase has no test runner. TDD discipline is kept by **observing a red
state in the real system before fixing it**. The instruments:

- `docker exec looneybin-db mariadb -ulooneybin -p"$(grep -E '^Password' ~/arma3server_dev/extdb3-conf.ini | sed 's/Password *= *//')" looneybin_test -e "<SQL>"`
- Server log: `grep '\[SUITE\]' /home/timb/arma3server_dev/loonydev.log`
- Client RPT: newest `~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/*.rpt`
- Rig client for in-world checks: `~/Armapunk2035-atmo/tools/gamectl.py` (+
  `join_game.py` to rejoin after a deploy).
- Offline geometry/data checks: python against the tower p3d and manifests.

Every task below names the specific red state to see first.

## File structure

**Create:**
- `sql/suites.sql` — table DDL
- `server/AP_server/core/TON/fn_ndDebitSrv.sqf` — server-only ND debit
- `server/AP_server/core/TON/fn_suiteSRV.sqf` — lease/end/lock authority
- `server/AP_server/core/TON/fn_suiteRentSweep.sqf` — the 300 s rent sweep
- `server/AP_server/core/TON/fn_suiteStorageSRV.sqf` — hydrate/dehydrate
- `server/AP_server/core/TON/fn_suiteFurnitureSRV.sqf` — furniture authority
- `mission/Armapunk2035.Malden/core/suites/fn_suiteKiosk.sqf` — directory dialog
- `mission/Armapunk2035.Malden/core/suites/fn_suiteMenu.sqf` — 3-action menu
- `mission/Armapunk2035.Malden/core/suites/fn_suiteLease.sqf` — purchase flow
- `mission/Armapunk2035.Malden/core/suites/fn_suiteData.sqf` — client cache + helpers
- `mission/Armapunk2035.Malden/core/suites/fn_suiteReceive.sqf` — server→client push
- `mission/Armapunk2035.Malden/dialog/suites.hpp` — kiosk + menu dialogs (idd 941600/941601)
- `scratchpad/suites/bake_kiosk.py` — kiosk art generator

**Modify:**
- `sql/looneybin_schema.sql` (document the table)
- `server/AP_server/config.cpp` (register 5 server fns)
- `server/AP_server/init.sqf` (scheduler job + boot reload + kiosk tag)
- `mission/Armapunk2035.Malden/Functions.h` (register client fns)
- `mission/Armapunk2035.Malden/CfgRE.hpp` (whitelist entries)
- `mission/Armapunk2035.Malden/dialog/MasterHandler.h` (include suites.hpp)
- `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (kiosk scroll action)
- `mission/Armapunk2035.Malden/custom_p3ds/lux_doors.sqf` (suite lock check)
- `mission/Armapunk2035.Malden/core/config/fn_houseConfig.sqf` (comment: adding a
  lux classname here arms the cyberdeck breach against suites)

---

## Phase 1 — Lease core

### Task 1.1: Table + oid scheme

**Files:** create `sql/suites.sql`; modify `sql/looneybin_schema.sql`.

- [ ] **Observe red:** `... -e "SHOW TABLES LIKE 'suites'"` → empty.
- [ ] Write the DDL from spec §3 verbatim into `sql/suites.sql`.
- [ ] Apply it to `looneybin_test`; re-run SHOW TABLES → one row.
- [ ] `DESCRIBE suites` and confirm `oid` is `varchar(32)` UNIQUE and every unix
      column is `int(10) unsigned`.
- [ ] Append the same DDL to `sql/looneybin_schema.sql` under a `-- suites`
      heading so the documented schema matches live.
- [x] Commit.

### Task 1.2: Suite identity helper (shared, exact)

The oid must be derived identically on client and server or every lookup misses —
this is the bug that made house tax double-charge (#374).

**Files:** create `mission/.../core/suites/fn_suiteData.sqf`.

- [ ] Implement `AP_fnc_suiteOid`: `params ["_tower", "_floor"]` →
      `format ["LUX%1%2F%3", round ((getPosWorld _tower) select 0), round ((getPosWorld _tower) select 1), _floor]`.
- [ ] Implement `AP_fnc_suiteTowers`: `(allSimpleObjects []) select { "skyscraper30_r" in toLower ((getModelInfo _x) select 0) }`
      — never assume index 0 (multi-instance is already real).
- [ ] **Observe:** paste both into the dev console via gamectl and log the oid for
      floor 7 of the Latrinite tower; confirm it matches
      `LUX72177777F7` (derive the expected value offline from
      `malden_buildings.sqf`'s placement `[7216.602, 7777.412]` → `LUX72177777F7`).
- [x] Commit.

### Task 1.3: `APS_fnc_ndDebitSrv` — server-initiated ND charge

**Files:** create `server/AP_server/core/TON/fn_ndDebitSrv.sqf`; modify
`config.cpp`. **Must NOT be added to CfgRE.hpp.**

- [ ] Copy the `_ndValid` / `_ndPad` / `_ndGE` / `_ndSelect` / `_lockAcquire` /
      `_lockRelease` helpers from `fn_ndSRV.sqf` (they are file-local there).
- [ ] Signature: `["<uid>", "<amt>", "<reason>"] call APS_fnc_ndDebitSrv` → returns
      `[_ok, _newBalanceString]`.
- [ ] Body mirrors the `"debit"` case: take the per-uid lock, SELECT old,
      conditional UPDATE, re-SELECT, `_ok = (_new != "") && {_new != _old}`,
      release, `diag_log "[SUITE][ND] …"`.
- [ ] If the payer is online, push `AP_fnc_ndSync` so their HUD balance matches.
- [ ] **Observe red then green:** set a test player's balance to `50.0000`, call
      with `"120.0000"` → expect `[false, "50.0000"]` and the balance unchanged.
      Set it to `500.0000`, call again → `[true, "380.0000"]`. Both verified by
      re-querying the DB, not by the return value alone.
- [ ] Static check: `grep -c ndDebitSrv mission/Armapunk2035.Malden/CfgRE.hpp` → 0.
- [x] Commit.

### Task 1.4: Kiosk tagging + scroll action

**Files:** modify `server/AP_server/init.sqf`, `core/fn_setupActions.sqf`.

- [ ] At boot (and on the same delayed-spawn pattern the door sweep uses, so it
      survives placements appended at EOF), find the kiosk:
      `nearestObjects [[7221.15, 7770.67, 0], ["GalleryDioramaUnit_01_F"], 12]`
      → `setVariable ["AP_suiteKiosk", true, true]`.
- [ ] **Observe red:** before the change, console
      `count ((allMissionObjects "GalleryDioramaUnit_01_F") select {_x getVariable ["AP_suiteKiosk", false]})` → 0.
- [ ] Add the player-side scroll action in `fn_setupActions.sqf`, following the
      file's existing convention (`AP_actions pushBack(_plb_obj addAction [...])`)
      with condition
      `!isNull cursorObject && {cursorObject getVariable ["AP_suiteKiosk", false]} && {player distance cursorObject < 4} && {playerSide isEqualTo civilian}`.
- [ ] **Observe green:** deploy, rejoin, walk to the kiosk, action appears; the
      count query returns 1.
- [x] Commit.

### Task 1.5: Directory dialog + lease purchase

**Files:** create `dialog/suites.hpp`, `core/suites/fn_suiteKiosk.sqf`,
`fn_suiteLease.sqf`, `server/.../TON/fn_suiteSRV.sqf`; modify `MasterHandler.h`,
`Functions.h`, `CfgRE.hpp`, `config.cpp`.

- [ ] Dialog `suiteKiosk` idd **941600** (next free after the qh console 941500),
      listbox of 29 rows + status column + Lease button + info panel. **`UI_GRID_*`
      macros must be BARE, never inside quotes** — quoted macros produce an
      invisible dialog with no error.
- [ ] `APS_fnc_suiteSRV` modes: `"list"` (returns `[oid, floor, ownerUid, state]`
      per row for one tower), `"lease"`, `"end"`.
- [ ] `"lease"` on the server: resolve caller from `remoteExecutedOwner`; re-check
      the row is vacant (`owner IS NULL`) **inside** the same guarded UPDATE
      (`UPDATE suites SET owner='%1' … WHERE oid='%2' AND owner IS NULL`) so two
      players clicking at once cannot both win; then charge via
      `APS_fnc_ndDebitSrv`; on payment failure, roll the ownership back.
- [ ] Order matters: claim-then-charge with rollback, because the reverse
      (charge-then-claim) can take money for a floor someone else just took.
- [ ] `next_due = UNIX_TIMESTAMP() + 2592000` written with `toFixed 0`.
- [ ] CfgRE entry: `class APS_fnc_suiteSRV { allowedTargets = 2; };` and
      `class AP_fnc_suiteReceive { allowedTargets = 1; };`.
- [ ] **Observe red:** with no CfgRE entry, click Lease → nothing happens and the
      client RPT logs nothing. Add the entry → it works. (This is the silent-fail
      trap; seeing it once is worth the minute.)
- [ ] **Observe green:** lease floor 7 → `SELECT * FROM suites WHERE oid='LUX72177777F7'`
      shows the owner UID and a `next_due` ≈ now + 2592000; the player's
      `new_drachma` dropped by exactly 120.0000; relog and the lease persists.
- [ ] Race check: set balance to 100 (below rent), click Lease → row must remain
      `owner IS NULL` (rollback proven), no money moved.
- [x] Commit.

---

## Phase 2 — Rent clock

### Task 2.1: The sweep

**Files:** create `server/.../TON/fn_suiteRentSweep.sqf`; modify `init.sqf`,
`config.cpp`.

- [ ] Register: `["suiteRent", { params ["_st"]; call APS_fnc_suiteRentSweep; }, 300, false, true] call AP_fnc_schedule;`
      (signature verified: `[_id, _fn, _interval, _runAtStart, _jitter]`).
- [ ] Query due rows: `SELECT id, QUOTE(oid), QUOTE(owner), next_due, overdue_since FROM suites WHERE owner IS NOT NULL AND next_due <= UNIX_TIMESTAMP()`.
- [ ] Per row: charge 120 via `APS_fnc_ndDebitSrv`. Success → `next_due = next_due + 2592000`, `overdue_since = 0`.
      Failure → set `overdue_since = UNIX_TIMESTAMP()` if currently 0.
- [ ] **`next_due` advances only after the debit verifies** (fail-closed, the
      mining pattern). A failed proof read counts as non-payment.
- [ ] `diag_log` every outcome with the `[SUITE]` tag.
- [ ] **Observe red then green:** `UPDATE suites SET next_due = UNIX_TIMESTAMP() - 10 WHERE oid='…'`,
      wait one sweep, then confirm in the DB that `next_due` jumped forward ~30
      days and the wallet dropped 120. Then set the balance below 120, force
      `next_due` past again, and confirm `overdue_since` became non-zero while
      `next_due` did **not** move.
- [x] Commit.

### Task 2.2: Repossession

**Files:** modify `fn_suiteRentSweep.sqf`.

- [ ] In the same sweep: `WHERE owner IS NOT NULL AND overdue_since > 0 AND (UNIX_TIMESTAMP() - overdue_since) >= 864000`
      → wipe (`owner=NULL, vinv=NULL, pinv=NULL, furniture=NULL, locked=1,
      leased_at=0, next_due=0, overdue_since=0`).
- [ ] Delete that suite's spawned furniture and invalidate any open storage
      session before the wipe.
- [ ] Log tenant UID, floor and forfeited item counts via `APS_fnc_logIt` so a
      dispute is reconstructable.
- [ ] **Observe green:** `UPDATE suites SET overdue_since = UNIX_TIMESTAMP() - 864100 …`,
      wait one sweep → row is vacant, log line present.
- [x] Commit.

### Task 2.3: Notifications + Pay Now

**Files:** modify `fn_suiteMenu.sqf`, `fn_suiteReceive.sqf`, `fn_suiteSRV.sqf`.

- [ ] On login (after the suite list pushes), toast if any owned suite is overdue,
      with days remaining before repossession.
- [ ] Suite menu header: floor, next payment date, days remaining; red OVERDUE
      banner + **Pay Now** button when `overdue_since > 0`.
- [ ] `"payNow"` mode: same debit, clears `overdue_since`, advances `next_due`.
- [ ] **Observe green:** force overdue, relog → toast appears; Pay Now clears it
      in the DB.
- [x] Commit.

---

## Phase 3 — Access

### Task 3.1: Suite storage

**Files:** create `server/.../TON/fn_suiteStorageSRV.sqf`; modify
`core/suites/fn_suiteMenu.sqf`, `Functions.h`, `CfgRE.hpp`, `config.cpp`.

- [ ] Hydrate on open / dehydrate on close, gated by `AP_suiteHydrated`, with a
      `AP_suiteGen` session token that no-ops stale closes (the #542 TOCTOU fix).
- [ ] Server resolves the caller from `remoteExecutedOwner` and matches it against
      `suites.owner` **before** using the client's oid for anything.
- [ ] Capacity 900 virtual / 3000 physical, weight recomputed server-side, item
      classnames validated against `CfgWeapons`/`CfgMagazines`/`CfgVehicles`/
      `CfgGlasses`, stack cap 100000.
- [ ] Reuse `DB_fnc_mresArray` (write) and `DB_fnc_mresToArray` + `parseSimpleArray`
      (read), and escape single quotes the same way `fn_updateHouseTrunk.sqf:137`
      does: `(([_vinv] call DB_fnc_mresArray) splitString "'") joinString "''"`.
- [ ] **Observe green:** store items, relog, items still there. **Security check:**
      call the open with another player's oid → server refuses, `-SEC-` log line
      names the caller from `remoteExecutedOwner`, never the payload.
- [x] Commit.

### Task 3.2: Front-door lock + cop override

**Files:** modify `custom_p3ds/lux_doors.sqf`, `fn_suiteSRV.sqf`,
`fn_suiteReceive.sqf`.

- [ ] Front door of floor F is flat leaf index `(F - 2) * 3` (verified against the
      manifest: door_1 of floor 2 is the stair-core door at x[-4.27,-3.33] z≈3.0).
- [ ] On lease/lock change, set `ap_doorLocked` on that leaf on every machine; the
      existing open path already refuses when it is true.
- [ ] Permit: tenant, or `call AP_copLevel >= 5` (same gate as `fn_lockHouse`).
      Log cop force-opens.
- [ ] Lock/Unlock action lives with the door, not in the suite menu.
- [ ] **Observe green:** lock from the rig client, confirm the leaf's variable is
      true; confirm the Open action refuses for a non-tenant and succeeds for a
      cop-level test unit.
- [ ] Confirm the cyberdeck still refuses: the breach's `isKindOf "House_F"` gate
      is false for the tower — verify by running the breach at a suite door and
      seeing the "not a valid target" path, not an unlock.
- [x] Commit.

---

## Phase 4 — Furniture + art

### Task 4.1: Kiosk art

**Files:** create `scratchpad/suites/bake_kiosk.py`; output
`mission/Armapunk2035.Malden/images/suites/kiosk_welcome.paa`.

- [x] Generate a 1024×1024 cyberpunk "WELCOME TO LUXE SUITES" panel with PIL
      (dark base, cyan/magenta neon, scanlines — match the tower's
      `neon_cyan 0.05/0.72/1.0` and `neon_magenta 1.0/0.06/0.55`).
- [x] Convert with the existing `tools/make_paa.py` (DXT1, no alpha needed).
- [x] Apply: `_kiosk setObjectTexture [0, "images\suites\kiosk_welcome.paa"]`
      — hidden selection `Camo_1`, slot 0, verified from the AoW config.
- [x] **Observe green:** owner confirmed in game 2026-08-08 (kiosk panel + hologram).
- [x] Commit.

### Task 4.2: Suite furniture

**Files:** create `server/.../TON/fn_suiteFurnitureSRV.sqf`; modify
`core/items/fn_placeObject.sqf`, `fn_suiteMenu.sqf`, `config.cpp`, `CfgRE.hpp`.

- [x] Placement allowed when inside the tenant's own floor bounds: tower model-space
      XZ footprint and Y between that floor's slab and the next.
- [x] Cap 20 per suite; server-spawn handoff (client sends class/pos/dir and
      deletes its preview, server spawns the authoritative copy — the ladder-dupe
      fix); ownership re-checked from `remoteExecutedOwner`.
- [x] Presence-spawned: pieces exist only while the tenant is online; removed on
      lease end.
- [ ] **Observe green:** place a chair on floor 7, relog, it is still there;
      try to place while standing on floor 8 → refused.
- [x] Commit.

---

## Self-review

**Spec coverage:** §3 → 1.1/1.2; §4 → 1.3/2.1; §5 → 2.2 + the `"end"` mode in
1.5; §6 door → 3.2, storage → 3.1; §7 kiosk → 1.4/1.5, menu → 1.5/2.3, art → 4.1;
§8 → 4.2; §9 traps → Global Constraints; §11 → the observe steps in each task.

**Verified-by-execution (extras rule — plan code is unexecuted code):**
- DB reachable and `suites` absent → confirmed via `mariadb` in the
  `looneybin-db` container.
- `AP_fnc_schedule` signature `[_id, _fn, _interval, _runAtStart, _jitter]` →
  read from `fn_scheduler.sqf:55`.
- The ND debit SQL + old/new compare → read from `fn_ndSRV.sqf:99-116`.
- `GalleryDioramaUnit_01_F` hidden selection `Camo_1` = screen, 1024×1024,
  emissive `screen.rvmat` → derapified from `props_f_aow.pbo`.
- Front-door index `(floor-2)*3` → derived from `lux-doors-manifest.json` and the
  stair geometry in `lux_dump.json`.
- **Unverified, flagged:** the exact `_ndSelect`/`_lockAcquire` helper bodies are
  copied from `fn_ndSRV.sqf` at implementation time, not reproduced here; the
  dialog `idd` 941600/941601 are assumed free and must be grepped before use.

**Lifecycle owners of things we reuse:** `lux_doors.sqf` owns the door leaves and
their state array — the suite lock sets `ap_doorLocked` and must not touch
placement, the open/close animation or the flat-index bookkeeping. `fn_cleanup`
reaps objects without an `owner` variable, so suite furniture must carry
`AP_furniture` like house furniture does.
