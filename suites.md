# Luxe Suites — leased floors in the Skyscraper30 lux tower

**Status:** approved 2026-08-06 (owner). Implementation not started.
**Branch:** `skyscraper-latrinite` (PR #7 line). Spec lives at repo root per project convention (`cyberdeck.md`, `security.md`); `docs/` is gitignored.

Players lease a whole floor of the lux tower as a residence: monthly rent in New
Drachma, automatic renewal, storage, a lockable front door, and furniture. It
looks like a house feature and is deliberately **not** built on the house system.

---

## 1. Why this is a separate subsystem

Three facts from the code, each on its own sufficient:

1. **The lux tower is not a house.** It is created with `createSimpleObject`
   from a mission-root `.p3d`. Every house code path resolves properties with
   `nearestObjects [pos, ["House"], 10..18]` filtered against `AP_houseTypes`
   (`fn_CLinitHouses`, `fn_receiveHouses`, `fn_handleHouse`, `fn_manageHouseTax`,
   `fn_spawnPointCfg`, `fn_placeObject`). A simple object is invisible to all of
   them, and it has no `numberOfDoors` config, so the engine door-lock mechanism
   (`bis_disabled_Door_N`) does not exist for it either.
2. **House identity is a position hash.** `oid = format ["%1%2", round x, round y]`
   (`fn_addHouse.sqf:21`), re-derived from position in `fn_srvSellHouse.sqf:33`.
   All 29 floors of a tower share one X/Y, so every floor would collide.
3. **`AP_houseLimit = 5`** counts `AP_houses` rows regardless of type, which
   contradicts the owner's "unlimited suites".

Inheriting the house server functions would also inherit their open holes —
`APS_fnc_bldgUpdateKeys` (AUDIT A8: no authorization at all, grant yourself a key
to any property and loot it), `APS_fnc_updateProperty` (no owner check),
`APS_fnc_houseFurnitureSRV` "add" (no ownership check, raw SQL interpolation),
and client-authoritative purchase money. None of that is carried here.

**Bonus:** "the door cannot be hacked" is free. `fn_cyberdeck.sqf:32` gates on
`_target isKindOf "House_F" && {(typeOf _target) in AP_houseTypes}`. A suite is
neither, so no exclusion code is needed — but see §9, this must be re-checked if
anyone ever registers the tower as a house type.

## 2. What is leased

- Tower: any `skyscraper30_r*` instance. Floors **2–30** (29 suites per tower).
  Floor 1 is the public lobby; the roof is public.
- One suite = one whole floor: kitchen, bath, bedroom, living space.
- Storage: fixed **900 virtual / 3000 physical** (big-house tier 3) from day one.
  No upgrades, no makeovers, no keys, no gang assignment, no resale market.
- A player may hold **unlimited** suites; suites do not count toward
  `AP_houseLimit` and do not appear in `AP_houses`.

## 3. Data model

New table `suites` (fragment in `sql/suites.sql`, applied to dev + documented in
`sql/looneybin_schema.sql`):

```sql
CREATE TABLE IF NOT EXISTS `suites` (
  `id`        INT(11) NOT NULL AUTO_INCREMENT,
  `oid`       VARCHAR(32)  NOT NULL,               -- LUX<x><y>F<nn>, see below
  `tower`     VARCHAR(24)  NOT NULL,               -- <x><y> of the tower instance
  `floor`     TINYINT(4)   NOT NULL,               -- 2..30
  `owner`     VARCHAR(17)  DEFAULT NULL,           -- Steam64, NULL = vacant
  `leased_at` INT(10) UNSIGNED NOT NULL DEFAULT 0, -- unix
  `next_due`  INT(10) UNSIGNED NOT NULL DEFAULT 0, -- unix, rent deadline
  `overdue_since` INT(10) UNSIGNED NOT NULL DEFAULT 0, -- unix, 0 = current
  `locked`    TINYINT(1)   NOT NULL DEFAULT 1,
  `vinv`      TEXT DEFAULT NULL,                   -- mres-encoded, as houses.vinv
  `pinv`      TEXT DEFAULT NULL,                   -- mres-encoded, as houses.pinv
  `furniture` TEXT DEFAULT NULL,                   -- mres-encoded [class,posATL,dir,uid]
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_oid` (`oid`),
  KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Identity.** `oid = format ["LUX%1%2F%3", round px, round py, floor]` where
`px/py` are the *tower object's* world position. Rounded position keys the tower
(same convention as houses, so it is familiar), the floor number disambiguates
within it, and multiple lux towers each get their own 29 rows.

**Rows are created lazily.** No pre-seeding: a row is INSERTed on first lease and
kept forever (so storage/furniture survive an eviction cycle only if we want it —
we do not; see §5, eviction wipes the payload columns but keeps the row).

**Timestamps are raw unix** (`UNIX_TIMESTAMP()`), never DATETIME. Deltas are
timezone-independent, which sidesteps the box-CST/DB-UTC split documented in
`server/AP_server/init.sqf:137`. Never `format ["%1", <unix>]` — SQF renders
large numbers in scientific notation and corrupted `houses.miner` this way; use
`toFixed 0`.

## 4. Rent

- **120 ND per 30 days.** New Drachma only.
- ND has a **single server-authoritative wallet** (`players.new_drachma`); there
  is no cash/bank split for ND, so "bank ND" means that balance.
- **Purchase prepays the first month.** Lease → debit 120 ND → `leased_at = now`,
  `next_due = now + 2592000`.
- **Renewal is automatic and works offline**, because the sweep is a server-side
  SQL debit that does not need the player present.

### The sweep

Registered on the existing scheduler wheel in `server/AP_server/init.sqf`:

```sqf
["suiteRent", { params ["_st"]; call APS_fnc_suiteRentSweep; }, 300, false, true] call AP_fnc_schedule;
```

Every 300 s, for each `owner IS NOT NULL AND next_due <= UNIX_TIMESTAMP()`:

1. Attempt the debit (§4.1).
2. **Success** → `next_due = next_due + 2592000`, `overdue_since = 0`. If the
   tenant is online, push a toast and re-sync their balance.
3. **Failure** (insufficient funds) → if `overdue_since = 0`, set it to now and
   notify. If `now - overdue_since >= 864000` (10 days) → **repossess** (§5).

Rent does not compound: a tenant who is 3 days late still owes one month, and one
successful debit clears the overdue state.

### 4.1 The debit — first server-initiated ND charge in the codebase

Every existing ND debit is a player clicking Buy through `AP_fnc_ndBuySync` →
`APS_fnc_ndSRV`. There is no server-side debit helper, so this spec adds
`APS_fnc_ndDebitSrv` mirroring the `"debit"` case of `APS_fnc_ndSRV`:

- **Deliberately absent from `CfgRE.hpp`** so no client can remoteExec it —
  exactly why `APS_fnc_ndCreditSrv` can skip rate caps.
- Takes the per-UID `AP_ndLocks` lock (8 s bail) so it serializes against a
  player's own purchases.
- Amount validated against `\d{1,14}(\.\d{1,4})?` before interpolation — the
  format check *is* the SQL-injection guard in this codebase.
- Conditional atomic SQL, then a proof read (extDB3 reports no row counts):

```sqf
[format ["UPDATE players SET new_drachma = new_drachma - %1 WHERE playerid='%2' AND new_drachma >= %1", _amt, _uid], 2] call DB_fnc_asyncQuery;
private _new = [_uid] call _ndSelect;                   // SELECT QUOTE(new_drachma)
private _ok  = (_new isNotEqualTo "") && { _new isNotEqualTo _old };
```

- `next_due` advances **only after** the debit verifies — the mining system's
  fail-closed pattern. A failed proof read is treated as non-payment, never as
  payment.
- Arithmetic stays in SQL on `DECIMAL(20,4)`. SQF single-precision floats never
  touch the ledger; amounts move as 4dp strings.

## 5. Ending a lease

Both paths are identical in effect (owner's call: contents forfeit either way):

| Path | Trigger |
|---|---|
| **End Lease** | tenant clicks it in the suite menu, confirms |
| **Repossession** | `now - overdue_since >= 864000` |

Effect: `owner = NULL`, `vinv/pinv/furniture = NULL`, `locked = 1`,
`leased_at/next_due/overdue_since = 0`; spawned furniture deleted; open storage
session invalidated; the floor's front door re-locked and shown as vacant. No
refund of the current month. The floor is immediately leasable again, by anyone
including the previous tenant.

Repossession is logged via `APS_fnc_logIt` with the tenant UID, floor and the
forfeited item counts, so a dispute can be reconstructed.

## 6. Access control

### Front door

Each floor has 3 doors in `lux_doors_data.sqf`, ordered by door id; the floor's
**front door** (the one off the stair core, manifest box x[-4.27,-3.33] z≈3.0) is
flat index `(floor - 2) * 3`. Interior doors (bath, bedroom) are never locked.

The lock hook already exists: `lux_doors.sqf` checks
`_leaf getVariable ["ap_doorLocked", false]` before opening. Suite locking sets
that variable on the front-door leaf on every machine.

Who may open a locked suite door:

- the tenant;
- **MaxSec with `call AP_copLevel >= 5`** (same gate as `fn_lockHouse`'s bypass) —
  cops can force it, and the action is logged;
- nobody else. It **cannot be hacked**: the cyberdeck breach only targets
  `House_F` in `AP_houseTypes`.

### Storage

Modelled on the chokepoint that closed the June "free house keys" read exploit:

- Contents live in the DB. They are hydrated into the world **only** while that
  tenant has the crate open (`AP_suiteHydrated`), and dehydrated on close.
- A session token (`AP_suiteGen`) no-ops stale closes — the TOCTOU fix from
  bug #542.
- The server resolves the caller from **`remoteExecutedOwner`** and re-checks
  `suites.owner` against it. A client-supplied oid is never trusted for
  authorization, only used to look up the row *after* the owner check.
- Item classnames validated against `CfgWeapons`/`CfgMagazines`/`CfgVehicles`/
  `CfgGlasses` and quantities capped, weight recomputed server-side — the
  2026-06-24 gear-vanishing and stack-dupe fixes.
- A tenant can only ever open **their own** suite's storage. There are no keys,
  no gang access, and no cop looting in v1.

## 7. UI

### Kiosk

`GalleryDioramaUnit_01_F` at `[7221.15, 7770.67, 168.52]` in the lux lobby,
tagged at boot with `AP_suiteKiosk` (found by position + classname, like the
door sweep finds towers). Player-side scroll action conditioned on
`cursorObject`, matching `fn_setupActions.sqf` convention.

Screen art: one baked 1024×1024 PAA on hidden selection **`Camo_1`** (slot 0),
applied with `setObjectTextureGlobal`. Static — no live availability overlay.
The stock material `screen.rvmat` is emissive, so it glows at night.

### Directory dialog

Scroll → "Luxe Suites Directory": 29 rows, `Floor NN · <status>` where status is
VACANT / LEASED / **YOUR SUITE** / OVERDUE (own suites only). Selecting a vacant
row shows price and a Lease button; selecting your own row opens the suite menu.
Purchase confirms explicitly ("120 ND now, then 120 ND every 30 days").

### Suite menu — exactly three actions

A small dedicated dialog, not the 24-control `houseMenu` with 21 things hidden:

1. **Buy Furniture** → `[player, player, -1, "homegoods"] spawn AP_fnc_virtualShopMenu`
2. **Storage** → suite inventory (§6)
3. **End Lease** → confirm → §5

Plus a read-only header: floor, next payment date, days remaining, and a red
OVERDUE banner with days left before repossession and a **Pay Now** button when
applicable. A Lock/Unlock toggle sits with the door, not in this menu.

### Notification

- On login, if any suite is overdue: toast with days remaining.
- On successful auto-renewal while online: quiet toast.
- At the kiosk and in the menu, always visible.

## 8. Furniture

Own placement path, not an extension of the house one (which gates on
`nearestObjects [player, ["House"], 20]` and would never see the tower):

- Buying is the existing Homegoods virtual shop, unchanged.
- Placement is allowed only when the player is inside **their own floor's**
  bounds: the tower's model-space XZ footprint, and Y within that floor's slab
  and the one above.
- Cap **20 pieces per suite**, matching houses.
- Server-spawn handoff: the client sends class/pos/dir and deletes its preview,
  the server spawns the one authoritative copy (the fix for the old ladder dupe).
  `APS_fnc_suiteFurnitureSRV` re-checks ownership from `remoteExecutedOwner`.
- Presence-spawned: pieces exist only while the tenant is online, cached like
  `AP_furnCache`, and are removed when the lease ends.

## 9. Risks and standing traps

- **Moving the tower orphans leases.** The oid embeds the tower's rounded
  position; if the tower is re-placed in MaldenEdit the rows no longer match.
  Mitigation: the sweep logs any suite oid whose tower is absent instead of
  silently doing nothing, and `tools/` gets a re-key script if it ever happens.
- **If anyone adds a lux classname to `AP_houseTypes`**, the cyberdeck breach
  starts targeting suites. That registry is the switch; a comment goes in
  `fn_houseConfig.sqf` next to it.
- **`AP_houseTxn` discipline** — the aging-barrel hang (BUGS.md:27) is a stuck
  transaction flag. The suite flow uses its own `AP_suiteTxn` and clears it on
  every exit path, including every `exitWith`.
- **Nested-`exitWith` payment bug** — the 2026-07-24 free-item bug: `exitWith`
  inside a nested `else {}` leaves only the inner scope and the item was granted
  anyway. Every payment bail sets an explicit `_exit` flag, as `fn_ncShop.sqf`
  does.
- **Multi-instance towers** are already real (the door system wires every
  instance). Suite code iterates instances the same way and must never assume
  index 0.

## 10. Build order

Each phase independently testable and separately deployable:

1. **Lease core** — table, oid scheme, kiosk tag + scroll action, directory
   dialog, purchase with prepaid month, `APS_fnc_ndDebitSrv`.
2. **Rent clock** — scheduler sweep, renewal, overdue state, 10-day
   repossession, notifications, Pay Now.
3. **Access** — suite storage with hydrate/dehydrate chokepoint, front-door lock,
   cop force-open.
4. **Furniture + art** — suite placement path, presence spawn, baked kiosk PAA.

## 11. Verification

- **Offline:** brace/bracket balance on every touched SQF; `CfgRE.hpp` entry per
  new client→server function (a missing entry fails silently); `Functions.h` /
  `config.cpp` registration; a static check that `APS_fnc_ndDebitSrv` is *absent*
  from `CfgRE.hpp`.
- **DB:** debit is conditional-SQL + proof read; a forced-failure test (set a
  balance below rent) must leave `next_due` unchanged and flip `overdue_since`.
- **In-game (dev):** lease a floor, verify the 120 ND left the wallet and the
  row; relog and confirm the lease persists; store items, relog, confirm they
  survive; lock the door and confirm a second player cannot open it while a cop
  can; force `next_due` into the past and watch one sweep renew it; force
  `overdue_since` 11 days back and watch repossession wipe the suite.
- **Security:** attempt a storage open with a spoofed oid for another player's
  suite and confirm the server refuses on the `remoteExecutedOwner` check.
