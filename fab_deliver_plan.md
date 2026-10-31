# Fabricator Auto-Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A finished fabricator job deposits itself into the house the machine stands in, online or
offline, and the Collect step stops existing.

**Architecture:** A server loop (`APS_fnc_fabDeliver`) polls `house_printer_jobs` for due rows,
resolves each printer's building, and writes the output into that house's `vinv`/`pinv` through the
existing `APS_fnc_updateHouseTrunk` server-internal path. Capacity is refused at queue time; the
residual full-house case holds the job and retries. XP pays the uid that queued the job, from a new
`queued_by` column, through a `fabXp` that can read and write progression from the database when the
earner is offline.

**Tech Stack:** SQF (Arma 3), PostgreSQL 18 via `DB_fnc_asyncQuery`, the mission's HTML deck
(`ui/html/deck.html`) and native dialog (`dialog/fab_menu.hpp`).

**Design record:** `fab_deliver.md`. Read it before Task 1 — it carries the reasoning this plan only
executes.

## Global Constraints

- Work on `main`, in `~/Armapunk2035`. Commit per task.
- Server SQF lives under `server/AP_server/`, mission SQF under `mission/Armapunk2035.Malden/`.
- Every new server function must be registered in `server/AP_server/config.cpp`; every new mission
  function in `mission/Armapunk2035.Malden/Functions.h`. An unregistered function is undefined at
  runtime with no build error.
- **`APS_fnc_fabDeliver` and `APS_fnc_fabXp` must NOT appear in `mission/Armapunk2035.Malden/CfgRE.hpp`.**
  That absence is the security model: a client that could reach `fabXp` grants itself level 20 in one
  packet. `fn_fabXp.sqf`'s own header says so.
- SQL is native PostgreSQL. No MySQL-isms — `tools/pgmigrate/harvest_corpus.py --lint` fails the
  build on any. After changing any SQL, re-run `python3 tools/pgmigrate/harvest_corpus.py` to
  re-harvest the corpus, or `--check` fails.
- Never `QUOTE()` an mres column on read (`houses.vinv` / `houses.pinv`).
- A bare 17-digit Steam64 in SQL compiles to a number and loses precision. Quote uid comparisons.
- Deploy to the dev server with `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`. It repacks,
  seeds the client cache and restarts; it takes about 90 s and drops anyone in-game.

## Verification instruments (there is no unit-test harness for SQF)

TDD's value here is the **confirmed-failing observation**, not a runner. Every task below names a red
state you must SEE before writing the fix.

| Instrument | Command |
|---|---|
| Static gates | `bash tools/run_checks.sh` |
| Fabricator gate alone | `python3 tools/fab_check.py` |
| SQF brace/parse | `python3 tools/sqf_balance.py <files>` |
| Deck JS parse | `python3 tools/html_js_check.py` |
| Dev database | `docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch -c "<SQL>"` |
| Server log | `tail -f /home/timb/arma3server_dev/loonydev.log` |
| Server RPT | newest of `/home/timb/arma3server_dev/profiles/looneybin_server_*.rpt` |

**The dev database is `pgm_full_scratch`, NOT `armapunk`** — the names are backwards from what
anyone would guess, and `HANDOFF.md` §Hazards says this has cost time twice. `armapunk` is an empty
13-table shell nothing has ever used; querying it shows `houses` and `house_printer_jobs` absent and
invites exactly the wrong conclusion. **This plan hit that trap during its own writing.** Every
`psql` command below names `pgm_full_scratch` deliberately.

Verified there on 2026-08-30: `houses` holds 4 rows, `house_printer_jobs` exists with
`(id, printer_id, recipe, qty, finish_at)` and **no `queued_by`**, and `players` already carries
`fab_level smallint`, `fab_xp integer` and `fab_schematics text`. So Task 1's red state is real and
Task 4 needs no column migration.

---

### Task 1: Record who queued a job

**Files:**
- Modify: `server/AP_server/core/TON/fn_fabSRV.sqf` — `_ensure` (≈ line 79) and the `queue` INSERT (≈ line 436)

**Interfaces:**
- Produces: `house_printer_jobs.queued_by varchar(17)` — the Steam64 of the player who queued the
  job, NULL for rows that predate this change. Tasks 4 and 5 read it.

- [ ] **Step 1: Create the dev world state and observe the red state**

The world state already exists — verified 2026-08-30, `house_printers` holds four machines
(ids 5-8, tier 1) across three owned houses, all owned by `76561190000000001`, and
`house_printer_jobs` is empty. So you only need to queue a job:

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

In game: open the staff deck (**Admin → EVENT tab → FREE BUILD ON**), stand at one of the placed
fabricators and queue any recipe. Free build is what lets you queue without first grinding the
ingredients; it skips ingredients, level and schematic and nothing else.

Now look at the row:

```bash
docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch -c "\d house_printer_jobs"
```

Expected (the red state): the column list is `id, printer_id, recipe, qty, finish_at` — **no
`queued_by`**. There is no record of who queued anything.

- [ ] **Step 2: Add the column to the self-healing schema block**

In `fn_fabSRV.sqf`, inside `_ensure`, directly after the `CREATE INDEX … house_printer_jobs_idx_printer`
line:

```sqf
    // owner 2026-08-30 (auto-delivery): a job has to remember WHO queued it. Collect used to pay
    // whoever pressed the button; with no button there is no such player, and the printer's
    // installer is the wrong answer on a gang machine -- the gang member who queued the job is the
    // one who earned it. NULL on rows that predate this, which pay no XP rather than pay a guess.
    ["ALTER TABLE house_printer_jobs ADD COLUMN IF NOT EXISTS queued_by varchar(17)", 2] call DB_fnc_asyncQuery;
```

- [ ] **Step 3: Write the uid at queue time**

Replace the INSERT in the `queue` arm:

```sqf
        [format ["INSERT INTO house_printer_jobs (printer_id, recipe, qty, finish_at)
                 VALUES (%1,'%2',%3, extract(epoch from now())::bigint + %4)",
                 _id, _key, _qty, _secs], 2, true] call DB_fnc_asyncQuery;
```

with:

```sqf
        // queued_by rides the INSERT rather than being back-filled: the delivery loop may run
        // before this player is ever seen again, and a job with no earner is a job that pays nobody.
        // The uid comes from the SERVER's getPlayerUID on the resolved player, never from the packet.
        [format ["INSERT INTO house_printer_jobs (printer_id, recipe, qty, finish_at, queued_by)
                 VALUES (%1,'%2',%3, extract(epoch from now())::bigint + %4, '%5')",
                 _id, _key, _qty, _secs, getPlayerUID _p], 2, true] call DB_fnc_asyncQuery;
```

- [ ] **Step 4: Re-harvest the SQL corpus and run the static gates**

```bash
cd ~/Armapunk2035
python3 tools/pgmigrate/harvest_corpus.py
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fabSRV.sqf
python3 tools/pgmigrate/harvest_corpus.py --lint
python3 tools/pgmigrate/harvest_corpus.py --check
```

Expected: `ok` from `sqf_balance`, and both `harvest_corpus` gates exit 0.

- [ ] **Step 5: Deploy and observe green**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

Queue another job in game, then:

```bash
docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch \
  -c "SELECT id, recipe, qty, queued_by FROM house_printer_jobs ORDER BY id"
```

Expected: the new row carries your Steam64 in `queued_by`; the row from Step 1 shows NULL.

- [ ] **Step 6: Commit**

```bash
git add server/AP_server/core/TON/fn_fabSRV.sqf tools/pgmigrate/sqlcorpus/corpus.json
git commit -m "feat(fab): record who queued a job

Collect paid whoever pressed the button. Auto-delivery has no button, and the
printer's installer is the wrong earner on a gang machine. queued_by rides the
INSERT so a job that finishes while everyone is offline still knows who earned it."
```

---

### Task 2: One weight oracle, shared by the queue gate and the depositor

**Files:**
- Create: `server/AP_server/core/TON/fn_fabRoom.sqf`
- Modify: `server/AP_server/config.cpp` — register `fabRoom`

**Interfaces:**
- Produces: `[_house, _key, _qty] call APS_fnc_fabRoom` → `[_fits, _need, _free, _isPhys]`
  - `_fits` BOOL — the batch fits the house's remaining capacity
  - `_need` NUMBER — weight the batch will add
  - `_free` NUMBER — the house's remaining capacity in the column this batch lands in
  - `_isPhys` BOOL — TRUE if the output is physical gear (`pinv`), FALSE if virtual (`vinv`)
- Consumed by Task 3 (queue gate) and Task 4 (deposit).

This is one function rather than two copies on purpose. A duplicated capacity calculation drifts the
moment either side changes, and the two sides here are a *refusal* and a *deposit* — if they disagree,
the queue accepts jobs the depositor will not deliver, and the machine stalls with no explanation.

- [ ] **Step 1: Observe the red state**

```bash
grep -rn "fabRoom" ~/Armapunk2035/server ~/Armapunk2035/mission
```

Expected: no matches. Nothing can currently answer "does this batch fit that house".

- [ ] **Step 2: Write the function**

Create `server/AP_server/core/TON/fn_fabRoom.sqf`:

```sqf
/*
    APS_fnc_fabRoom  (Armapunk 2026-08-30) -- will this batch fit in that house?

        [_house, _recipeKey, _qty] call APS_fnc_fabRoom   ->   [_fits, _need, _free, _isPhys]

    ONE oracle, deliberately, called by BOTH sides of the capacity rule: the queue gate that refuses
    a job the house has no room for, and the depositor that has to decide again at delivery time.
    Two copies of this arithmetic would drift, and the failure that drift produces is silent -- the
    queue accepts a job the depositor then refuses forever, and the machine stalls with no message
    anywhere.

    A recipe's KEY IS ITS OUTPUT CLASS (the collect arm granted _key directly), so the column this
    lands in is decided the same way collect decided it: a virtItemCfg row means a virtual item, and
    anything else is physical gear.

    THE WEIGHT ORACLES MAY BE ABSENT. AP_fnc_virtItemCfg and AP_fnc_physicalInventoryWeight are
    mission functions; fn_updateHouseTrunk guards every call to them with !isNil for the same reason
    this does. With an oracle missing we return _fits = TRUE rather than blocking every job on a
    momentary compile gap -- the depositor re-checks, and a wrong ACCEPT costs a held job while a
    wrong REFUSE costs the player their materials.
*/
params [["_house", objNull, [objNull]], ["_key", "", [""]], ["_qty", 1, [0]]];
if (!isServer) exitWith { [true, 0, 0, false] };
if (isNull _house || {_key isEqualTo ""}) exitWith { [true, 0, 0, false] };
_qty = (round _qty) max 1;

private _haveVirt = !isNil "AP_fnc_virtItemCfg";
private _isPhys = if (_haveVirt) then { (["getItemRow", _key] call AP_fnc_virtItemCfg) isEqualTo [] } else { false };

private _need = -1;
if (_isPhys) then {
    if (!isNil "AP_fnc_physicalInventoryWeight") then { _need = [[[_key, _qty]]] call AP_fnc_physicalInventoryWeight; };
} else {
    if (_haveVirt) then {
        private _w = ["getItemWeight", _key] call AP_fnc_virtItemCfg;
        if (_w isEqualType 0) then { _need = _w * _qty; };
    };
};
if (_need < 0) exitWith { [true, 0, 0, _isPhys] };   // oracle absent -> do not block; the depositor re-checks

private _capVar = ["AP_vcap", "AP_phys_cap"] select _isPhys;
private _invVar = ["AP_vinv", "AP_pinv"] select _isPhys;
private _cap = _house getVariable [_capVar, 0];
private _used = (_house getVariable [_invVar, [[], 0]]) param [1, 0];
private _free = (_cap - _used) max 0;

[(_need <= _free), _need, _free, _isPhys]
```

- [ ] **Step 3: Register it**

In `server/AP_server/config.cpp`, beside the other TON entries (`fabDebugSRV` is at line 332):

```cpp
 class fabRoom {}; // capacity oracle shared by the fab queue gate and the delivery loop
```

- [ ] **Step 4: Verify it parses and is reachable**

```bash
cd ~/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fabRoom.sqf
python3 deploy/cfgfn_audit.py . | grep -c '^   line '
```

Expected: `ok` from `sqf_balance`; the audit count is unchanged from before your edit (a new
unresolved registration would raise it).

- [ ] **Step 5: Commit**

```bash
git add server/AP_server/core/TON/fn_fabRoom.sqf server/AP_server/config.cpp
git commit -m "feat(fab): one capacity oracle for the queue gate and the depositor

Two copies of this arithmetic drift, and the drift is silent: the queue accepts
a job the depositor then refuses forever and the machine stalls with no message."
```

---

### Task 3: Refuse a job the house has no room for

**Files:**
- Modify: `server/AP_server/core/TON/fn_fabSRV.sqf` — the `queue` arm, immediately before the `_secs`
  calculation (≈ line 434)

**Interfaces:**
- Consumes: `APS_fnc_fabRoom` from Task 2.

- [ ] **Step 1: Observe the red state**

Deploy, fill a house's virtual storage to its cap (buy a small house and store items until the weight
bar is full), then queue a printer job in that house.

Expected (the red state): the job is **accepted**. There is no capacity check anywhere in the queue
arm — confirm by reading it:

```bash
grep -n "AP_vcap\|fabRoom" server/AP_server/core/TON/fn_fabSRV.sqf
```

Expected: no matches.

- [ ] **Step 2: Add the gate**

In the `queue` arm, immediately **before** the `private _secs = round (…)` line:

```sqf
        // CAPACITY, refused here rather than at delivery (owner call 2026-08-30). The output goes
        // into the house now, so a house with no room means a job that can never be delivered --
        // and a job that cannot be delivered after its materials are spent is the worst of the
        // three possible failures. Refuse before the INSERT, while _refund still means something.
        //
        // This cannot be airtight: someone else can fill the house while the job runs. That case is
        // the depositor's HOLD path, not this one. This gate catches the common case loudly.
        private _house = [getPosATL _anchor] call _resolveHouse;
        ([_house, _key, _qty] call APS_fnc_fabRoom) params ["_fits", "_needW", "_freeW", "_phys"];
        if (!_fits) exitWith {
            call _refund;
            [_p, format ["No room in the house for that batch -- it needs %1 %2 and there is %3 free. Clear some space first.",
                         _needW, ["virtual weight", "gear weight"] select _phys, _freeW]] call _say;
        };
```

- [ ] **Step 3: Verify it parses**

```bash
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fabSRV.sqf
```

Expected: `ok`.

- [ ] **Step 4: Deploy and observe green**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

With the house still full, queue the same job. Expected: refused with the shortfall named, and your
materials are returned (check the inventory, and check no row landed):

```bash
docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch \
  -c "SELECT count(*) FROM house_printer_jobs"
```

Then empty some storage and queue again. Expected: accepted.

- [ ] **Step 5: Commit**

```bash
git add server/AP_server/core/TON/fn_fabSRV.sqf
git commit -m "feat(fab): refuse a job the house has no room to receive

The output goes into the house now, so a full house means a job that can never be
delivered. Refusing before the INSERT is the only point where a refund still means
something."
```

---

### Task 4: Pay XP to a player who is not there

**Files:**
- Modify: `server/AP_server/core/TON/fn_fabXp.sqf` — whole file

**Interfaces:**
- Produces: `[_uid, _count] call APS_fnc_fabXp` — **signature change**, was `[_player, _count]`.
  Resolves the player object from `_uid` itself; falls back to the database when they are offline.
- The only current caller is the `collect` arm, which Task 6 deletes. Task 5 is the new caller.

- [ ] **Step 1: Observe the red state**

```bash
grep -n "getVariable \[\"AP_fabLevelSrv\"\|params \[\[\"_player\"" server/AP_server/core/TON/fn_fabXp.sqf
```

Expected: the function takes a player object and reads `AP_fabLevelSrv` off it. It has **no path**
that can pay an offline uid — which is now the normal case, since the machine runs offline by design.

- [ ] **Step 2: Rewrite the function**

Replace `server/AP_server/core/TON/fn_fabXp.sqf` from the `params` line down (keep the existing
header comment, and append the note below to it):

```sqf
/*
    … existing header unchanged …

    2026-08-30 (auto-delivery): now keyed on a UID, not a player object. The machine finishes jobs
    while its owner is offline -- that is the whole point of the server clock -- so the earner is
    usually not in allPlayers when the XP is due. State comes off the player object when they are
    online (so a live session's published UI stays in step) and out of players.fab_level / fab_xp
    when they are not. ONE roll-up loop serves both: duplicating the level arithmetic per state
    source is how the two paths silently disagree about what level someone is.
*/
params [["_uid", "", ["", objNull]], ["_count", 1, [0]]];
if (!isServer) exitWith {};
if (_uid isEqualType objNull) then { _uid = getPlayerUID _uid; };
if !(_uid regexMatch "\d{17}") exitWith {};

private _player = (allPlayers select { (getPlayerUID _x) isEqualTo _uid }) param [0, objNull];
private _online = !isNull _player;

// STATE IN. Online: the object is authoritative and already in step with the published UI copy.
// Offline: the row is. QUOTE() on the uid -- a bare 17-digit Steam64 compiles to a number and
// loses precision, so an unquoted match silently finds nobody (fn_offlineMsgDeliver's lesson).
private _lvl = 1;
private _xp  = 0;
if (_online) then {
    _lvl = _player getVariable ["AP_fabLevelSrv", 1];
    _xp  = _player getVariable ["AP_fabXpSrv", 0];
} else {
    private _row = [format ["SELECT (fab_level)::text AS lvl, (fab_xp)::text AS xp FROM players WHERE playerid = QUOTE(%1)", _uid], 2, true] call DB_fnc_asyncQuery;
    if (_row isEqualType [] && {_row isNotEqualTo []}) then {
        private _r = _row param [0, []];
        _lvl = parseNumber format ["%1", _r param [0, 1]] max 1;
        _xp  = parseNumber format ["%1", _r param [1, 0]] max 0;
    };
};

// THE ROLL-UP, once. A 20-unit batch at a low level can legitimately cross two thresholds, and
// stopping at one would silently eat the remainder.
_xp = _xp + ((round _count) max 1);
private _levelled = false;
while {_lvl < 20} do {
    private _need = ["xpFor", _lvl] call AP_fnc_fabCfg;
    if (_need <= 0 || {_xp < _need}) exitWith {};
    _xp = _xp - _need;
    _lvl = _lvl + 1;
    _levelled = true;
};
if (_lvl >= 20) then { _xp = 0 };

// STATE OUT. The database is written either way -- it is the only copy that survives a restart.
// The object pair is written only when there is an object: AP_*Srv unpublished (the authority),
// AP_fabLevel published (the UI reads it, and a client can forge it, which is why nothing gates on it).
[format ["UPDATE players SET fab_level = %1, fab_xp = %2 WHERE playerid = QUOTE(%3)", _lvl, _xp, _uid], 2] call DB_fnc_asyncQuery;
if (_online) then {
    _player setVariable ["AP_fabLevelSrv", _lvl, false];
    _player setVariable ["AP_fabXpSrv", _xp, false];
    _player setVariable ["AP_fabLevel", _lvl, true];
    _player setVariable ["AP_fabXp", _xp, true];
    if (_levelled) then {
        [["Fabrication level up.", "success"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
    };
};
```

> **Unverified in this plan:** the tail of the existing `fn_fabXp.sqf` (below the roll-up) may already
> publish `AP_fabXp` and message the player. Read the current file end-to-end before pasting and keep
> whatever it already does on the online path — do not drop behaviour to match this block.

- [ ] **Step 3: Confirm the DB columns exist**

```bash
docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch -c "\d players" | grep -E "fab_level|fab_xp"
```

Expected — **confirmed present 2026-08-30**: `fab_level smallint not null default 1` and
`fab_xp integer not null default 0`. This step is a guard against a differently-migrated database,
not an open question.

- [ ] **Step 4: Static gates**

```bash
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fabXp.sqf
python3 tools/pgmigrate/harvest_corpus.py
python3 tools/pgmigrate/harvest_corpus.py --lint
```

Expected: `ok`, then both corpus gates exit 0.

- [ ] **Step 5: Commit**

```bash
git add server/AP_server/core/TON/fn_fabXp.sqf tools/pgmigrate/sqlcorpus/corpus.json
git commit -m "feat(fab): pay fabrication XP to an offline earner

The machine finishes jobs while its owner is logged off, so the earner is usually
not in allPlayers when XP is due. One roll-up loop, two state sources: the player
object when online, players.fab_level/fab_xp when not."
```

---

### Task 5: The depositor

**Files:**
- Create: `server/AP_server/core/TON/fn_fabDeliver.sqf`
- Modify: `server/AP_server/core/TON/fn_fabSRV.sqf` — extract `_resolveHouse` into a registered function
- Create: `server/AP_server/core/TON/fn_fabHouseAt.sqf`
- Modify: `server/AP_server/config.cpp` — register `fabDeliver`, `fabHouseAt`
- Modify: `server/AP_server/init.sqf` — start the loop (beside the existing `uiSleep 22` fab reload, line 218)

**Interfaces:**
- Consumes: `APS_fnc_fabRoom` (Task 2), `APS_fnc_fabXp` (Task 4), `house_printer_jobs.queued_by` (Task 1).
- Produces: `[] call APS_fnc_fabDeliver` — one pass, server-only, returns nothing.
- Produces: `[_pos] call APS_fnc_fabHouseAt` → the building object under a printer, or `objNull`.

- [ ] **Step 1: Observe the red state**

Queue a short job, wait for it to finish, and leave it alone — do not press Collect.

```bash
docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch \
  -c "SELECT id, recipe, qty, finish_at - extract(epoch from now())::bigint AS secs_left FROM house_printer_jobs"
```

Expected (the red state): `secs_left` is negative and the row **stays there indefinitely**. Nothing
in the server ever looks at a finished job unless a player presses Collect.

- [ ] **Step 2: Extract the house resolver**

Create `server/AP_server/core/TON/fn_fabHouseAt.sqf`:

```sqf
/*
    APS_fnc_fabHouseAt  (Armapunk) -- the building a printer at _pos belongs to, or objNull.

    Lifted verbatim out of APS_fnc_fabSRV's private _resolveHouse when the delivery loop needed the
    same answer. It is the greenhouse's resolver: buyable-shed spots hold TWO buildings at ~0 m --
    the hidden derelict and the intact createVehicle'd shed, which is not reliably isKindOf House_F.
    Attaching a printer to the hidden derelict makes it invisible to every menu, and would now also
    deliver its output into a building nobody can open.
*/
params [["_pos", [0,0,0], [[]]]];
private _c = (nearestObjects [_pos, ["House_F", "Land_i_Shed_Ind_F"], 12]) select { !isObjectHidden _x };
private _s = _c select { (typeOf _x) isEqualTo "Land_i_Shed_Ind_F" };
if (_s isNotEqualTo []) then { _s select 0 } else { _c param [0, objNull] }
```

In `fn_fabSRV.sqf`, replace the body of `private _resolveHouse` (≈ line 112) with a delegation so the
existing four call sites keep working and there is exactly one copy of the rule:

```sqf
private _resolveHouse = { [_this param [0, [0,0,0]]] call APS_fnc_fabHouseAt };
```

- [ ] **Step 3: Write the depositor**

Create `server/AP_server/core/TON/fn_fabDeliver.sqf`:

```sqf
/*
    APS_fnc_fabDeliver  (Armapunk 2026-08-30) -- put finished fabricator jobs into the house the
    machine stands in. Server-only, called on a loop from init.sqf.

    A LOOP RATHER THAN A TIMER PER JOB, for the reason APS_fnc_offlineMsgDeliver states in its own
    header: polling catches the condition for free a few seconds later and cannot break anything if
    it fails. Jobs are durable rows; a pass that declines one loses nothing.

    HOUSE STORAGE IS THE MOST DATA-LOSS-PRONE SUBSYSTEM HERE. Three incidents are written into its
    own source: the b0093 hydrate-display wipe, the #542 rapid open/close TOCTOU that clobbered a
    live session, and the Jeff Stall gun dupe that came from reading AP_pinv off the object mid-take.
    So this is deliberately timid about exactly those:

      * it NEVER writes a house that has a live session (AP_invHydrated / AP_activeTrunk /
        AP_trunkLock). It skips and retries in 30 s. Racing an open trunk costs somebody's stash;
        waiting costs nothing.
      * it re-reads the authoritative contents through APS_fnc_initHouseInventory "dehydrate", which
        reloads the server-local copy straight from the row, rather than trusting whatever is on the
        object.
      * it writes through APS_fnc_updateHouseTrunk server-internal (_src == 0), the proven path that
        owns the mres encode and the sanitize -- not a second UPDATE houses SET vinv=... . Same rule
        fn_vehicleToHouseStore follows and states.

    ORDER PER JOB, and it matters: both retry exits sit BEFORE the delete, so a skipped or held job
    still has its row. Steps 4-5 keep the old collect arm's fail-closed order -- delete, prove the
    delete committed, then write -- which prefers losing a job to duplicating one.
*/
if (!isServer) exitWith {};
if (isNil "AP_fabTableReady") exitWith {};   // no fabricator has ever been placed; nothing to deliver

private _due = [format ["SELECT id, printer_id, recipe, qty, queued_by FROM house_printer_jobs
    WHERE finish_at <= extract(epoch from now())::bigint ORDER BY id LIMIT 30"], 2, true] call DB_fnc_asyncQuery;
if (isNil "_due" || {!(_due isEqualType [])} || {_due isEqualTo []}) exitWith {};

{
    private _jid  = parseNumber format ["%1", _x param [0, 0]];
    private _pid  = parseNumber format ["%1", _x param [1, 0]];
    private _key  = format ["%1", _x param [2, ""]];
    private _qty  = (parseNumber format ["%1", _x param [3, 0]]) max 0;
    private _uid  = format ["%1", _x param [4, ""]];

    if (_key isNotEqualTo "" && {_qty > 0} && {!(AP_fabBusy getOrDefault ["j" + str _jid, false])}) then {
        private _anchor = AP_fabAnchors getOrDefault [_pid, objNull];
        private _house  = if (isNull _anchor) then { objNull } else { [getPosATL _anchor] call APS_fnc_fabHouseAt };

        // 1. a machine whose building is gone delivers nowhere. Leave the row: the building may be
        //    a shed that has not streamed in yet, and deleting it would destroy a paid-for job.
        if (!isNull _house) then {

            // 2. LIVE SESSION -> skip. See the header.
            private _live = (_house getVariable ["AP_invHydrated", false])
                         || {!isNull (_house getVariable ["AP_activeTrunk", objNull])}
                         || {_house getVariable ["AP_trunkLock", false]};
            if (!_live) then {

                // 3. authoritative re-read, then room. "dehydrate" broadcasts empty and restores the
                //    server-local copy from the row -- with no session open that is exactly a fresh
                //    authoritative read, and it is the codebase's own primitive for one.
                [_house, "", "dehydrate"] call APS_fnc_initHouseInventory;
                ([_house, _key, _qty] call APS_fnc_fabRoom) params ["_fits", "_needW", "_freeW", "_phys"];

                if (!_fits) then {
                    // HOLD. The queue gate already refused what it could see; someone filled the
                    // house since. Keep the row and say so once an hour rather than every 30 s.
                    private _t = AP_fabHeldSaid getOrDefault [_jid, -1e9];
                    if (diag_tickTime - _t > 3600) then {
                        AP_fabHeldSaid set [_jid, diag_tickTime];
                        diag_log format ["[Armapunk][fab] HELD job %1 (%2 x%3): needs %4, house has %5 free", _jid, _key, _qty, _needW, _freeW];
                        private _who = (allPlayers select { (getPlayerUID _x) isEqualTo _uid }) param [0, objNull];
                        if (!isNull _who) then {
                            [[format ["A finished job (%1 x%2) is waiting -- the house it is in has no room. Clear some space.", _key, _qty], "basic"],
                             "AP_fnc_handleMessage", _who, false, false] spawn AP_fnc_MP;
                        };
                    };
                } else {
                    // 4. LOCK, DELETE, PROVE.
                    AP_fabBusy set ["j" + str _jid, true];
                    [format ["DELETE FROM house_printer_jobs WHERE id=%1", _jid], 2, true] call DB_fnc_asyncQuery;
                    private _left = format ["%1", ((([format ["SELECT (COUNT(*))::text AS n FROM house_printer_jobs WHERE id=%1", _jid], 2, true] call DB_fnc_asyncQuery) param [0, []]) param [0, "1"])];

                    if (_left isEqualTo "0") then {
                        // 5. MERGE + WRITE. Stack onto an existing entry rather than appending a
                        //    duplicate line -- both columns are [[class, qty], ...] and the storage
                        //    UI renders one row per entry.
                        private _col = _house getVariable [(["AP_vinv", "AP_pinv"] select _phys), [[], 0]];
                        private _items = +(_col param [0, []]);
                        private _idx = _items findIf { (format ["%1", _x param [0, ""]]) isEqualTo _key };
                        if (_idx isEqualTo -1) then { _items pushBack [_key, _qty]; }
                        else { _items set [_idx, [_key, ((_items select _idx) param [1, 0]) + _qty]]; };
                        private _new = [_items, (_col param [1, 0]) + _needW];

                        private _vinv = if (_phys) then { [] } else { _new };
                        private _pinv = if (_phys) then { _new } else { [] };
                        // _genArg -1 = server-internal, always proceed. An empty array for the OTHER
                        // column means "not supplied": updateHouseTrunk falls back to the object read
                        // for it, which is the value the dehydrate above just made authoritative.
                        [objNull, _house, _vinv, _pinv, -1] call APS_fnc_updateHouseTrunk;

                        // XP under the level +/-1 window, evaluated at DELIVERY (it was at collect).
                        if (_uid isNotEqualTo "" && {_uid isNotEqualTo "<null>"}) then {
                            private _lvl = (["getRecipe", _key] call AP_fnc_fabCfg) param [0, 1];
                            private _plvl = [_uid] call APS_fnc_fabLevelOf;
                            if (_lvl >= (_plvl - 1) && {_lvl <= _plvl}) then { [_uid, _qty] call APS_fnc_fabXp; };
                            [format ["INSERT INTO fab_quest_queue (uid, recipe, qty) VALUES ('%1','%2',%3)", _uid, _key, _qty], 2] call DB_fnc_asyncQuery;
                        };

                        diag_log format ["[Armapunk][fab] delivered %1 x%2 (job %3, printer %4) into house %5", _key, _qty, _jid, _pid, _house getVariable ["AP_houseID", -1]];
                    } else {
                        diag_log format ["[Armapunk][fab] deliver WITHHELD: job %1 did not clear", _jid];
                    };
                    AP_fabBusy deleteAt ("j" + str _jid);
                };
            };
        };
    };
} forEach _due;
```

> **Two symbols this block uses that do not exist yet** — resolve them in this task before deploying:
> - `AP_fabHeldSaid` — a `createHashMap` initialised beside `AP_fabBusy` in `fn_fabSRV.sqf`'s globals.
> - `APS_fnc_fabLevelOf` — the level of a uid, online or off. It is three lines and it is the same
>   two-source read Task 4 already wrote; **factor that read out of `fn_fabXp.sqf` into
>   `fn_fabLevelOf.sqf` and have both call it** rather than writing it twice.

- [ ] **Step 4: Create the quest queue table**

In `fn_fabSRV.sqf`'s `_ensure`, after the `queued_by` ALTER from Task 1:

```sqf
    // Quest credit for a job that finished while its earner was offline. AP_fnc_fabQuestEvent runs
    // on the CLIENT, so it cannot fire for an absent player -- the event waits here and is handed
    // over on their next login, the APS_fnc_offlineMsgDeliver model.
    ["CREATE TABLE IF NOT EXISTS fab_quest_queue (
        id bigint NOT NULL GENERATED BY DEFAULT AS IDENTITY,
        uid varchar(17) NOT NULL,
        recipe varchar(64) NOT NULL,
        qty integer NOT NULL DEFAULT 1,
        CONSTRAINT fab_quest_queue_pkey PRIMARY KEY (id))", 2] call DB_fnc_asyncQuery;
```

- [ ] **Step 5: Drain the quest queue in the same loop**

At the **end** of `fn_fabDeliver.sqf`, after the `forEach`:

```sqf
// Quest credit for jobs delivered while their earner was away. Same pass, same 30 s cadence -- a
// separate loop for thirty rows would be a second thing to reason about for no gain.
private _q = ["SELECT id, uid, recipe, qty FROM fab_quest_queue ORDER BY id LIMIT 30", 2, true] call DB_fnc_asyncQuery;
if (!isNil "_q" && {_q isEqualType []} && {_q isNotEqualTo []}) then {
    {
        private _qid = parseNumber format ["%1", _x param [0, 0]];
        private _u   = format ["%1", _x param [1, ""]];
        private _k   = format ["%1", _x param [2, ""]];
        private _n   = parseNumber format ["%1", _x param [3, 0]];
        private _who = (allPlayers select { (getPlayerUID _x) isEqualTo _u }) param [0, objNull];
        if (!isNull _who) then {
            [[_k, _n], "AP_fnc_fabQuestEvent", _who, false, false] spawn AP_fnc_MP;
            [format ["DELETE FROM fab_quest_queue WHERE id=%1", _qid], 2] call DB_fnc_asyncQuery;
        };
    } forEach _q;
};
```

- [ ] **Step 6: Register and start the loop**

`server/AP_server/config.cpp`:

```cpp
 class fabDeliver {};  // finished jobs -> the house the machine stands in (loop, init.sqf)
 class fabHouseAt {};  // the building under a printer (shared by fabSRV and fabDeliver)
 class fabLevelOf {};  // fabrication level of a uid, online or offline
```

`server/AP_server/init.sqf`, directly after line 218's fab reload:

```sqf
// Deliver finished fabricator jobs into their houses. 25 s settle so the +22 s fab reload has
// respawned the anchors first -- a pass that runs before AP_fabAnchors is populated resolves every
// printer to objNull and holds every job for no reason.
[] spawn { uiSleep 25; while { true } do { [] call APS_fnc_fabDeliver; uiSleep 30; }; };
```

- [ ] **Step 7: Static gates**

```bash
cd ~/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fabDeliver.sqf \
    server/AP_server/core/TON/fn_fabHouseAt.sqf server/AP_server/core/TON/fn_fabLevelOf.sqf \
    server/AP_server/core/TON/fn_fabSRV.sqf server/AP_server/core/TON/fn_fabXp.sqf
python3 tools/pgmigrate/harvest_corpus.py && python3 tools/pgmigrate/harvest_corpus.py --lint
python3 deploy/cfgfn_audit.py . | grep -c '^   line '
```

Expected: `ok` for every file, both corpus gates exit 0, audit count unchanged.

- [ ] **Step 8: Deploy and observe green**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
tail -f /home/timb/arma3server_dev/loonydev.log | grep -i "\[Armapunk\]\[fab\]"
```

In game: queue a short job, walk away, and **do not** touch the machine. Within ~30 s of it
finishing, expect a log line:

```
[Armapunk][fab] delivered <recipe> x<n> (job <id>, printer <id>) into house <oid>
```

Then confirm the row is gone and the item is in the house:

```bash
docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch \
  -c "SELECT count(*) FROM house_printer_jobs"
docker exec armapunk-pg psql -U armapunk -d pgm_full_scratch \
  -c "SELECT oid, vinv, pinv FROM houses ORDER BY oid"
```

Expected: no job rows; the recipe's classname and quantity present in `vinv` (or `pinv` for a
weapon). Open the house's storage in game and confirm the item is there and takeable.

- [ ] **Step 9: Prove the live-session guard**

Open the house's storage in game and **leave it open**. Queue a 1-minute job elsewhere in the same
house and let it finish while the trunk is still open.

Expected: no `delivered` line while the trunk is open; the job row survives; the line appears within
30 s of closing the trunk. This is the guard that protects against the #542 clobber — if it does not
hold, stop and fix it before continuing.

- [ ] **Step 10: Commit**

```bash
git add server/AP_server/core/TON/fn_fabDeliver.sqf server/AP_server/core/TON/fn_fabHouseAt.sqf \
        server/AP_server/core/TON/fn_fabLevelOf.sqf server/AP_server/core/TON/fn_fabSRV.sqf \
        server/AP_server/core/TON/fn_fabXp.sqf server/AP_server/config.cpp server/AP_server/init.sqf \
        tools/pgmigrate/sqlcorpus/corpus.json
git commit -m "feat(fab): finished jobs deliver themselves into the house

The machine runs on a server clock while you are offline and then made you walk to
it anyway. Now the job lands in the house's own storage: virtual into vinv, gear
into pinv, through the proven updateHouseTrunk path rather than a second writer.

Never writes a house with a live session -- it skips and retries in 30 s. Racing an
open trunk is what wiped stashes in #542; waiting costs nothing."
```

---

### Task 6: Remove Collect

**Files:**
- Delete: `mission/Armapunk2035.Malden/core/items/fn_fabCollect.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h` — drop the `fabCollect` registration
- Modify: `mission/Armapunk2035.Malden/dialog/fab_menu.hpp` — remove `Collect_Button` (idc 1831)
- Modify: `mission/Armapunk2035.Malden/ui/html/deck.html:3899, 5412` — remove the button and its handler
- Modify: `mission/Armapunk2035.Malden/core/web/fn_deckFab.sqf:147-151` — remove the `"collect"` verb
- Modify: `server/AP_server/core/TON/fn_fabSRV.sqf` — delete the `collect` arm (≈ lines 460-506)
- Modify: `mission/Armapunk2035.Malden/core/items/fn_fabJobFill.sqf` — job rows gain a destination line

**Interfaces:**
- Consumes: nothing. This task only removes the old path once Task 5 has proven the new one works.

Do this task **after** Task 5 is green, never before. Deleting collect while delivery is unproven
leaves finished jobs with no way out at all.

- [ ] **Step 1: Enumerate every surface and observe the red state**

```bash
cd ~/Armapunk2035
grep -rn "fabCollect" mission/Armapunk2035.Malden | grep -v '\.md:'
grep -n '"collect"' mission/Armapunk2035.Malden/core/web/fn_deckFab.sqf server/AP_server/core/TON/fn_fabSRV.sqf
```

Scope the second grep to those two files. A bare repo-wide `"collect"` also matches gathering,
fishing, the spirit barrel and the mining rig, none of which are this feature.

Expected, verified 2026-08-30 — **five `fabCollect` sites and five `"collect"` sites**:

| Site | What it is |
|---|---|
| `Functions.h:895` | `class fabCollect {};` registration |
| `core/items/fn_fabCollect.sqf` | the client function (whole file) |
| `dialog/fab_menu.hpp:130` | `Collect_Button` onButtonClick |
| `ui/html/deck.html:3899` | the COLLECT button markup |
| `ui/html/deck.html:5412` | `case "fabCollect":` handler |
| `core/web/fn_deckFab.sqf:11,147,150` | header line, verb, and the remoteExec |
| `server/.../fn_fabSRV.sqf:13,460` | header line and the `collect` arm |

That list is the task.

- [ ] **Step 2: Remove them, one file at a time**

Delete `core/items/fn_fabCollect.sqf` and its `class fabCollect {};` line in `Functions.h`. Delete
`class Collect_Button` from `fab_menu.hpp`. Delete the `<button class="jact" data-act="fabCollect">COLLECT</button>`
fragment and the `case "fabCollect":` handler from `deck.html`. Delete `case "collect":` from
`fn_deckFab.sqf` and from `fn_fabSRV.sqf`.

In `fn_fabSRV.sqf`, leave the header comment above the deleted arm replaced by:

```sqf
    // ------------------------------------------------------------------------- (collect: removed)
    // Jobs deliver themselves into the house now -- APS_fnc_fabDeliver, on a loop from init.sqf.
    // The fail-closed order that lived here (delete, prove the delete, then grant) moved with it.
```

- [ ] **Step 3: Say where the output goes**

In `fn_fabJobFill.sqf`, where a job row's text is built, append the destination to the finished
state so a player is never left wondering what happened to a completed job. Read the current
formatting in that file and match it; the string to add is:

```sqf
"Delivered to this house's storage."
```

and for a job the depositor is holding:

```sqf
"HELD -- no room in the house. Clear some space."
```

> **Unverified in this plan:** `fn_fabJobFill.sqf` has not been read. Open it first and match its
> existing row format rather than pasting a new one.

- [ ] **Step 4: Static gates**

```bash
python3 tools/html_js_check.py
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fabSRV.sqf \
    mission/Armapunk2035.Malden/core/web/fn_deckFab.sqf \
    mission/Armapunk2035.Malden/core/items/fn_fabJobFill.sqf
python3 tools/dialog_reachability.py
python3 deploy/cfgfn_audit.py . | grep -c '^   line '
grep -rn "fabCollect" mission/ server/ | grep -v '\.md:' || echo "no references left"
```

Expected: all pass; the final grep prints `no references left`.

- [ ] **Step 5: Deploy and observe green**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

Open a fabricator in game. Expected: no Collect button in either the native dialog or the deck app;
a finished job still lands in the house within 30 s; the job list names its destination.

- [ ] **Step 6: Commit**

```bash
git add -A mission/Armapunk2035.Malden server/AP_server/core/TON/fn_fabSRV.sqf
git commit -m "feat(fab): remove Collect

Delivery has been proven on the dev server, so the manual path goes. Six surfaces
carried it: the client fn, its registration, the dialog button, the deck button and
its handler, the deck bridge verb, and the server arm."
```

---

### Task 7: Documentation and the full gate

**Files:**
- Modify: `FAB.md` — the shape table, the collect description, the playtest section
- Modify: `fab_deliver.md` — mark implemented

- [ ] **Step 1: Update FAB.md**

In the shape table, replace the `Authority` row's `place / queue / collect / pickup` with
`place / queue / pickup`, and add:

```markdown
| Delivery | `server/.../TON/fn_fabDeliver.sqf` — a loop from `init.sqf`; output goes into the house |
| Capacity | `server/.../TON/fn_fabRoom.sqf` — one oracle, shared by the queue gate and the depositor |
```

Add a section under *Decisions that are load-bearing*:

```markdown
**Output goes into the house, not your pockets** (owner, 2026-08-30). The machine runs on a server
clock while you are logged off; making you walk back to it to press Collect contradicted the premise.
A finished job deposits itself into the building's own `vinv`/`pinv` through
`APS_fnc_updateHouseTrunk` server-internal — never a second writer, because house storage is the most
data-loss-prone subsystem here and it already has three named incidents to prove it. The depositor
skips any house with a live session and retries in 30 s: racing an open trunk is what wiped stashes
in #542, and waiting costs nothing.

Capacity is refused at **queue** time, while a refund still means something. The residual case — the
house filling while a job runs — holds the job in the machine and retries. Nothing is lost.
```

- [ ] **Step 2: Run every gate**

```bash
cd ~/Armapunk2035
bash tools/run_checks.sh
```

Expected: `-- N passed, 0 failed`. Anything failing is in scope for this task; do not commit around it.

- [ ] **Step 3: Commit**

```bash
git add FAB.md fab_deliver.md
git commit -m "docs(fab): auto-delivery is the collect path now"
```

---

## Self-review

**Spec coverage.** `fab_deliver.md` §1 depositor → Task 5. §2 deposit safety → Task 5 steps 3 and 9.
§3 capacity → Tasks 2 and 3, with the hold path in Task 5. §4 XP → Tasks 1 and 4. §5 quest credit →
Task 5 steps 4–5. §6 UI removal → Task 6. §7 "must not break" → Task 7 step 2.

**Executed during review** (per the plan-code-is-unexecuted-code rule):

- `\d house_printer_jobs`, `\d players` and `SELECT count(*) FROM houses` — ran against
  `pgm_full_scratch`. The first draft of this plan ran them against `armapunk`, found nothing, and
  asserted the feature had never run on this box. That is the exact trap `HANDOFF.md` §Hazards
  documents; the claim was wrong and is corrected above. The real red state (`queued_by` absent) is
  confirmed, and `players.fab_level` / `fab_xp` are confirmed present.
- `python3 tools/html_js_check.py` (all scripts parse), `python3 tools/sqf_balance.py` on the two
  staff files, and `python3 tools/fab_check.py` (exit 0) — all ran green on the current tree, so a
  failure during execution is yours, not pre-existing.
- `grep -rn "fabCollect"` and the file-scoped `'"collect"'` grep — both ran; the site table in
  Task 6 Step 1 is copied from their output, not estimated. The first draft of that step used a
  repo-wide `"collect"` grep, which returns 22 matches across gathering, fishing, the barrel and the
  mining rig; the step now scopes it.

**Explicitly unverified** — flagged inline where they appear:

- Every SQF block in this plan is unexecuted. Arma compiles at mission load; the first real syntax
  check is the deploy in each task's own verify step.
- `fn_fabXp.sqf`'s tail below the roll-up (Task 4 Step 2) and `fn_fabJobFill.sqf`'s row format
  (Task 6 Step 3) were not read. Both tasks say so and require reading the file first.
- `AP_fnc_physicalInventoryWeight`'s exact argument shape is taken from `fn_updateHouseTrunk`'s call
  (`_kept call AP_fnc_physicalInventoryWeight`, where `_kept` is `[[class, qty], …]`). Task 2's
  `fabRoom` passes `[[[_key, _qty]]]` on that reading — confirm against the function before trusting
  the number, and fix the arity if it differs.
- `players.fab_level` / `fab_xp` are asserted by `FAB.md`, not observed. Task 4 Step 3 checks them.

**Lifecycle owners.** `APS_fnc_updateHouseTrunk` dehydrates and re-asserts on every call, including
the server-internal one — that is why Task 5 only calls it on a house with no live session. Nothing
else in this plan ends a house session. `AP_fabBusy` is owned by `fn_fabSRV.sqf`; `fabDeliver`
borrows the same `"j<id>"` namespace deliberately, so a delivery and a (now-deleted) collect could
never have raced.

**Paths.** All artefacts land under `~/Armapunk2035` in tracked directories; nothing hits a
gitignored path. `fab_deliver.md` (design) and `fab_deliver_plan.md` (this file) follow the repo's
own `<topic>.md` / `<topic>_plan.md` convention.
