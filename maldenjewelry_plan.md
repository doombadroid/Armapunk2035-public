# Jewelry Emporium (Malden) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Jewelry Emporium heist run on Malden, and finish the safe stage that has never worked on either map.

**Architecture:** The heist already exists and mostly runs. This plan binds it to Malden's objects, replaces two hardcoded Altis coordinates, enforces a cases-then-safe order, completes the weld → open → loot mechanic, and adds a loaded getaway. `APS_fnc_jewelryEmporiumSRV` stays the single server authority; clients keep driving their own progress bars and request transitions.

**Tech Stack:** Arma 3 SQF; mission PBO `mission/Armapunk2035.Malden/`; server addon `server/AP_server/`; dev server at `/home/timb/arma3server_dev`; `deploy/reload-armapunk2035.sh` packs and restarts it.

## Global Constraints

- **The spec is `maldenjewelry.md` in the repo root.** Where this plan and the spec disagree, the spec wins; fix the plan.
- **Every `.sqf` touched must pass `python3 tools/sqf_balance.py <file>` before commit.** A brace fault in a client function raises nothing at load — it silently deletes the player's entire scroll menu.
- **Flat top-level `exitWith`, never nested inside a `then {}` or `else {}`.** An `exitWith` inside such a block leaves only that block. This codebase has shipped that bug twice.
- **Clients request, the server decides.** Every client-facing case in `fn_jewelryEmporiumSRV` re-derives its caller from `remoteExecutedOwner` and re-checks identity, distance and state. The existing `weldSafe` and `createCase` cases already do this — match their shape.
- **`fn_setupActions.sqf` is formatter-mangled**: action conditions are strings on one line. Match neighbouring spacing exactly; never reformat.
- Log prefix: `[maldenJewel]`. Server RPT: `/home/timb/arma3server_dev/loonydev.log`.
- Never run a destructive git command — no `checkout`, `reset`, `stash`, `revert`, `clean`. Commit only the paths each task names.
- Branch `main` is intended. `.superpowers/` is gitignored scratch; never commit it.
- Commit messages: sentence-case subject, body saying why, `Co-Authored-By:` naming a **defunct AI** not already in `git log -70 --format='%b' | grep Co-Authored`. No Anthropic address.

### Anchors

```sqf
AP_JEWEL_SAFEPOS  = [7538.99, 10583.70, 0.15];   // owner-clipboarded; the safe
AP_JEWEL_QILINPOS = [7515.07, 10599.30, 0.19];   // owner-clipboarded; getaway, dir 180 (south)
AP_JEWEL_GATEPOS  = [7535.70, 10578.80];         // nearest back-alley gate; the drill point
AP_JEWEL_CENTRE   = [7545.757, 10570.099];       // the emporium building
```

### State

`SRV_jewelryEmporiumSRV = [lastBreach, active, safeDrilled, safeWelded, casesLootable, 0, copsRequired]`

### Agreed quantities

- **8** display cases at the Malden site; **all 8** must be smashed before the safe unlocks.
- Safe yields **5 `jewelBag`s total**: 4 spawned `Land_Trophy_01_gold_F` (the existing trophy pickup action converts each to a bag) plus the safe's own single `takeSafeContents` grab.
- Qilin preloaded with **10 `jewelBag`s**. `jewelBag` weight is **8** (`fn_virtItemCfg`), so `AP_vinv` total weight is **80**.

### Deploy / verify loop

```bash
cd /home/timb/Armapunk2035
bash deploy/reload-armapunk2035.sh
# wait for boot — use Monitor with an until-loop, never a bare foreground sleep:
timeout 240 bash -c 'until grep -q "\[maldenJewel\] boot complete" /home/timb/arma3server_dev/loonydev.log; do sleep 5; done' && echo BOOTED
grep -n '\[maldenJewel\]' /home/timb/arma3server_dev/loonydev.log
```

---

## File Structure

**New**

| File | Responsibility |
|---|---|
| `server/AP_server/core/TON/fn_maldenJewelSRV.sqf` | Boot-time anchor resolution: spawn the safe, bind the three Eden variables, publish anchors, log. Single place the Malden wiring lives. |

**Modified**

| File | Change |
|---|---|
| `server/AP_server/config.cpp`, `init.sqf` | register + boot-call the new function |
| `mission/Armapunk2035.Malden/initPlayerLocal.sqf` | client-side bind of the three Eden variables |
| `mission/Armapunk2035.Malden/core/configuration.sqf` | Malden `AP_jewelryEmporiumPoly` |
| `server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf` | Malden coords; sequence change; new `casesDone` case; finish `weldSafe`; spawn the Qilin |
| `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` | drill offers by proximity to the gate anchor |
| `TODO.md` | deferred items |

---

### Task 1: Bind Malden's three jewelry objects, and stop the scroll menu throwing

**This fixes a live defect.** `AP_jewerlySafe`, `AP_jewerlyEmporium` and `AP_jewerlyContainer` are bound on Altis by `mission.sqm` init lines and exist nowhere in the tree. All three are read inside scroll-menu **conditions** (`fn_setupActions.sqf:689`, `:695`, `:701`). An undefined variable in an expression raises rather than warning, so those conditions throw every time the menu is built near the emporium.

**Files:**
- Create: `server/AP_server/core/TON/fn_maldenJewelSRV.sqf`
- Modify: `server/AP_server/config.cpp` (beside `class maldenBankSRV {};`), `server/AP_server/init.sqf` (beside the bank's boot call)
- Modify: `mission/Armapunk2035.Malden/initPlayerLocal.sqf`

**Interfaces:**
- Consumes: nothing.
- Produces: `AP_jewelSafe`, `AP_jewelGate` (publicVariable'd objects); `AP_JEWEL_SAFEPOS`, `AP_JEWEL_QILINPOS`, `AP_JEWEL_GATEPOS`, `AP_JEWEL_CENTRE` (publicVariable'd positions); `AP_jewerlySafe`, `AP_jewerlyEmporium`, `AP_jewerlyContainer` bound on server and clients.

- [ ] **Step 1: Prove the fault is live**

```bash
grep -c 'jewerlySafe\|jewerlyEmporium\|jewerlyContainer' /home/timb/arma3server_dev/loonydev.log
grep -rn 'jewerlySafe *=\|jewerlyEmporium *=\|jewerlyContainer *=' --include=*.sqf /home/timb/Armapunk2035/mission /home/timb/Armapunk2035/server
```

Expected: the second command returns **nothing** — no assignment anywhere. (The RPT count may be 0; the server does not compile client conditions, so the throw happens client-side.)

- [ ] **Step 2: Create the server-side resolver**

`server/AP_server/core/TON/fn_maldenJewelSRV.sqf`:

```sqf
/*
    APS_fnc_maldenJewelSRV -- Malden wiring for the Jewelry Emporium heist.

    Altis binds three Eden-named objects from mission.sqm init lines -- AP_jewerlySafe,
    AP_jewerlyEmporium and AP_jewerlyContainer -- which is why none of them has an assignment
    anywhere in the tree. Malden's sqm has none of them, and all three are read inside SCROLL-MENU
    CONDITIONS, where an undefined variable raises rather than warning. So they are bound here even
    where the heist does not use them: an objNull binding makes a condition simply not match, which
    is the difference between "the action never offers" and "the menu throws".

    The safe does not exist on this map at all, so it is spawned. The drill anchors on the compound's
    back-alley gate rather than on the building: the building is a client-local createSimpleObject,
    and the Fed's gate already proved cursorObject on a large flat structure returns the paving
    underfoot. The drill therefore gates on PROXIMITY to this anchor, not on cursor identity.
*/
if (!isServer) exitWith {};

AP_JEWEL_SAFEPOS  = [7538.99, 10583.70, 0.15];
AP_JEWEL_QILINPOS = [7515.07, 10599.30, 0.19];
AP_JEWEL_GATEPOS  = [7535.70, 10578.80];
AP_JEWEL_CENTRE   = [7545.757, 10570.099];

// the drill point: the nearest back-alley gate. Exact class, tight radius -- there are three of these
// gates at the compound and this resolves the one the owner nominated.
AP_jewelGate = (nearestObjects [AP_JEWEL_GATEPOS, ["Land_BackAlley_01_l_gate_F"], 12]) param [0, objNull];

// the safe: spawned, because this map has none. Fridge_01_closed_F is the class Altis uses, and it is
// the closed half of the pair whose open half (Fridge_01_open_F) the client's takeSafeContents reads.
AP_jewelSafe = createVehicle ["Fridge_01_closed_F", AP_JEWEL_SAFEPOS, [], 0, "CAN_COLLIDE"];
AP_jewelSafe setPosATL AP_JEWEL_SAFEPOS;
AP_jewelSafe allowDamage false;
AP_jewelSafe enableSimulationGlobal false;
AP_jewelSafe setVariable ["AP_furniture", true, true];   // exempt from fn_cleanup's sweep

AP_jewerlySafe      = AP_jewelSafe;
AP_jewerlyEmporium  = AP_jewelGate;
AP_jewerlyContainer = objNull;    // no deposit container on Malden; the reward is the Qilin

{ publicVariable _x; } forEach ["AP_JEWEL_SAFEPOS", "AP_JEWEL_QILINPOS", "AP_JEWEL_GATEPOS",
                                "AP_JEWEL_CENTRE", "AP_jewelSafe", "AP_jewelGate"];

diag_log format ["[maldenJewel] gate  = %1 at %2, %3 m from the anchor",
    typeOf AP_jewelGate, getPosATL AP_jewelGate,
    ((getPosATL AP_jewelGate) distance2D AP_JEWEL_GATEPOS) toFixed 1];
diag_log format ["[maldenJewel] safe  = %1 at %2 (terrain %3)",
    typeOf AP_jewelSafe, getPosATL AP_jewelSafe,
    (getTerrainHeightASL [AP_JEWEL_SAFEPOS select 0, AP_JEWEL_SAFEPOS select 1]) toFixed 2];
diag_log format ["[maldenJewel] display cases within 40 m of the emporium: %1",
    count (nearestObjects [AP_JEWEL_CENTRE, ["Coffin_02_F"], 40])];
diag_log format ["[maldenJewel] boot complete -- gate %1, safe %2",
    !isNull AP_jewelGate, !isNull AP_jewelSafe];
```

- [ ] **Step 3: Register and boot-call it**

In `server/AP_server/config.cpp`, beside `class maldenBankSRV {};`:

```cpp
 class maldenJewelSRV {};    // Malden wiring for the Jewelry Emporium (binds the three Eden objects, spawns the safe)
```

In `server/AP_server/init.sqf`, beside the bank's boot call:

```sqf
[] call APS_fnc_maldenJewelSRV;   // Malden Jewelry Emporium: bind the Eden objects, spawn the safe
```

- [ ] **Step 4: Bind the same three variables on clients**

The scroll conditions run client-side, so the client needs its own bindings. In `mission/Armapunk2035.Malden/initPlayerLocal.sqf`, immediately after the `AP_fed_gates` line (search for `AP_fed_gates =`):

```sqf
// Jewelry Emporium: Altis binds these three from mission.sqm init lines; Malden's sqm has none of
// them, and all three are read inside scroll-menu CONDITIONS where an undefined variable RAISES.
// The server publishes the objects; bind whatever has arrived, defaulting to objNull so a condition
// that runs before the publicVariable lands simply does not match instead of throwing.
AP_jewerlySafe      = missionNamespace getVariable ["AP_jewelSafe", objNull];
AP_jewerlyEmporium  = missionNamespace getVariable ["AP_jewelGate", objNull];
AP_jewerlyContainer = objNull;
```

- [ ] **Step 5: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenJewelSRV.sqf \
    server/AP_server/init.sqf mission/Armapunk2035.Malden/initPlayerLocal.sqf
```

Expected: `ok` for all three.

- [ ] **Step 6: Confirm the staged set and commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_maldenJewelSRV.sqf server/AP_server/config.cpp server/AP_server/init.sqf mission/Armapunk2035.Malden/initPlayerLocal.sqf
git diff --cached --stat   # must list exactly these four files
git commit   # subject: "Bind Malden's jewelry objects so the scroll menu stops throwing"
```

---

### Task 2: Give Malden its own emporium polygon

`AP_jewelryEmporiumPoly` holds Altis coordinates, so the `inPolygon` test that validates a smashed display case (`fn_jewelryEmporium.sqf`, `breakGlassCase`) can never pass here, and the scroll condition at `fn_setupActions.sqf:684` never offers.

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/configuration.sqf`

**Interfaces:**
- Consumes: Task 1's anchors (for reference only — the polygon is a literal).
- Produces: `AP_jewelryEmporiumPoly` covering the Malden site.

- [ ] **Step 1: Confirm the current value is Altis**

```bash
cd /home/timb/Armapunk2035
grep -o 'AP_jewelryEmporiumPoly=\[\[[^;]*\]\]' mission/Armapunk2035.Malden/core/configuration.sqf
```

Expected: the four Altis corners around `[20700, 16620]`.

- [ ] **Step 2: Replace it with the Malden box**

The 8 display cases span roughly x 7538.8–7551.9, y 10559.4–10570.2, and the building sits at
`[7545.757, 10570.099]`. This box encloses all of them, the building and the safe at
`[7538.99, 10583.70]`, with a working margin:

```sqf
AP_jewelryEmporiumPoly=[[7525,10595,0],[7562,10595,0],[7562,10548,0],[7525,10548,0]]
```

`configuration.sqf` line 2 is a single minified megaline. Replace the existing
`AP_jewelryEmporiumPoly=[...]` assignment **in place** on that line — do not reformat the line, do
not add newlines, and do not touch any neighbouring assignment.

- [ ] **Step 3: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/configuration.sqf
```

Expected: `ok`.

- [ ] **Step 4: Verify every case falls inside the polygon**

```bash
cd /home/timb/Armapunk2035
python3 - <<'PY'
poly=[(7525,10595),(7562,10595),(7562,10548),(7525,10548)]
cases=[(7542.04,10570.17),(7540.76,10568.41),(7543.09,10564.27),(7538.83,10569.89),
       (7541.27,10562.57),(7543.57,10561.12),(7551.87,10560.55),(7549.86,10559.37)]
extra={"safe":(7538.99,10583.70),"building":(7545.757,10570.099),"gate":(7535.70,10578.80)}
xs=[p[0] for p in poly]; ys=[p[1] for p in poly]
def inside(p): return min(xs)<=p[0]<=max(xs) and min(ys)<=p[1]<=max(ys)
print("cases inside:", sum(inside(c) for c in cases), "of", len(cases))
for k,v in extra.items(): print(f"  {k}: {'inside' if inside(v) else 'OUTSIDE'}")
PY
```

Expected: `cases inside: 8 of 8`, and safe, building and gate all `inside`.

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/configuration.sqf
git commit   # subject: "Give the emporium a Malden polygon instead of an Altis one"
```

---

### Task 3: Point the server function at Malden, and enforce cases-before-safe

Two hardcoded Altis coordinates and the sequence bug, together — they are the same three lines of `robberyStarted`.

**Files:**
- Modify: `server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf`

**Interfaces:**
- Consumes: `AP_JEWEL_CENTRE` (Task 1).
- Produces: `robberyStarted` no longer sets slot 2; a new `"casesDone"` internal case that does.

- [ ] **Step 1: Replace both hardcoded Altis coordinates**

In `robberyStarted`, the wanted-charge sweep currently reads `_x distance2D [20720, 16620, 0]`. Replace with:

```sqf
        {if ((side _x isEqualTo civilian) && {(_x distance2D AP_JEWEL_CENTRE) < 90}) then { [76, _x] call APS_fnc_wantedAdd; };
        } forEach allPlayers;
```

In the window-close spawn, the scene reset currently reads `nearestObjects [[20720, 16620, 0], ["Coffin_02_F"], 120]`. Replace with:

```sqf
            {_x setVariable ["AP_jewelCaseLooted", false, true];
                _x setVariable ["AP_droppedItems", [], true];
            } forEach (nearestObjects [AP_JEWEL_CENTRE, ["Coffin_02_F"], 120]);
```

- [ ] **Step 2: Stop `robberyStarted` unlocking the safe**

The state line currently sets slot 2 (`safeDrilled`) true at start. Change it so the safe stays locked:

```sqf
        // owner 2026-07-28: cases before the safe. Slot 2 (safeDrilled) is the SAFE's gate, and setting
        // it here unlocked the safe the instant the alarm went off -- there was no order to the job at
        // all (jewelry-redesign.md #304). It now flips only when every display case is done, in
        // case "casesDone" below.
        SRV_jewelryEmporiumSRV = [serverTime, true, false, false, true, 0, SRV_jewelryEmporiumSRV param [6, 6]];
```

- [ ] **Step 3: Add the case that unlocks the safe**

The client already tells the server about each smashed case via `createCase`. At the end of that case's body — after the loot trophy is spawned — add the completion check:

```sqf
        // owner 2026-07-28: all display cases smashed -> the safe unlocks. Counted from the world, not
        // from a tally, so a case that was already looted when the event started (or one the designer
        // adds later) cannot desynchronise the count.
        private _cases = nearestObjects [AP_JEWEL_CENTRE, ["Coffin_02_F"], 120];
        private _left  = { !(_x getVariable ["AP_jewelCaseLooted", false]) } count _cases;
        diag_log format ["[maldenJewel] case smashed -- %1 of %2 remaining", _left, count _cases];
        if (_left isEqualTo 0 && {!(SRV_jewelryEmporiumSRV param [2, false])}) then {
            SRV_jewelryEmporiumSRV set [2, true];
            publicVariable "SRV_jewelryEmporiumSRV";
            [[0, "Every display case at the Jewelry Emporium has been emptied -- the crew is going for the safe!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            [["The emporium's display cases are all gone -- they are cutting the safe. Move NOW.", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
            diag_log "[maldenJewel] all cases done -- safe unlocked";
        };
```

- [ ] **Step 4: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf
```

Expected: `ok`.

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf
git commit   # subject: "Make the emporium's cases gate its safe, and aim the sweep at Malden"
```

---

### Task 4: Finish the safe — weld it open and put the prize in it

**This repairs Altis as well as Malden.** `weldSafe` sets slot 3 and nothing else: it never swaps the closed safe for the `Fridge_01_open_F` the client's `takeSafeContents` targets, and never spawns loot. The safe has therefore never been lootable on either map (`jewelry-redesign.md` #306).

The safe yields **5 `jewelBag`s**: 4 spawned `Land_Trophy_01_gold_F` — the existing trophy pickup action (`fn_setupActions.sqf:692`) already converts each to one bag, and spawning them lets a crew share — plus the single bag from `takeSafeContents` on the open safe itself.

**Files:**
- Modify: `server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf`

**Interfaces:**
- Consumes: `AP_jewelSafe`, `AP_JEWEL_SAFEPOS` (Task 1); slot 2 gating from Task 3.
- Produces: a `Fridge_01_open_F` bound as `AP_jewelSafeOpen`; 4 trophies; slot 3 true.

- [ ] **Step 1: Replace the body of `weldSafe`'s success path**

Keep every existing guard exactly as it is — the not-drilled check, the caller/distance re-derivation and the `_data isEqualTo []` bail. Only the part after them changes. Where it currently sets slot 3 and logs, use:

```sqf
        SRV_jewelryEmporiumSRV set [3, true];
        publicVariable "SRV_jewelryEmporiumSRV";
        ["resolve", "jewelry", "yes"] call APS_fnc_sportsbookResolve;

        // owner 2026-07-28 (#306): the safe has never actually OPENED on either map -- this case set the
        // flag and stopped, so the Fridge_01_open_F that takeSafeContents targets never existed and no
        // loot was ever spawned. Swap the closed safe for the open one and put the prize in it.
        private _sp = getPosATL AP_jewelSafe;
        private _sd = getDir AP_jewelSafe;
        hideObjectGlobal AP_jewelSafe;
        AP_jewelSafeOpen = createVehicle ["Fridge_01_open_F", _sp, [], 0, "CAN_COLLIDE"];
        AP_jewelSafeOpen setPosATL _sp;
        AP_jewelSafeOpen setDir _sd;
        AP_jewelSafeOpen allowDamage false;
        AP_jewelSafeOpen enableSimulationGlobal false;
        AP_jewelSafeOpen setVariable ["AP_furniture", true, true];   // exempt from fn_cleanup
        AP_jewelSafeOpen setVariable ["AP_safeLooted", false, true];
        publicVariable "AP_jewelSafeOpen";

        // 4 grabbable trophies + the open safe's own single take = the agreed 5 bags. Trophies rather
        // than one big grant so a crew shares the prize instead of the first player taking all of it;
        // the existing trophy pickup action already converts each to a jewelBag.
        for "_i" from 0 to 3 do {
            private _tp = _sp vectorAdd [(_i - 1.5) * 0.7, 0.8, 0];
            private _t = createVehicle ["Land_Trophy_01_gold_F", _tp, [], 0, "CAN_COLLIDE"];
            _t setPosATL _tp;
            _t setDir _sd;
            _t setVariable ["AP_furniture", true, true];
        };
        [[0, "The Jewelry Emporium safe is OPEN."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        diag_log format ["[maldenJewel] safe welded open by %1 at %2 -- 4 trophies + the safe's own bag", name _robber, _sp];
```

- [ ] **Step 2: Restore the safe when the window closes**

In the window-close spawn, beside the existing `AP_jewerlySafe` reset, undo the swap so the next run starts from a closed safe:

```sqf
            // undo the weld: delete the open safe and its un-grabbed trophies, un-hide the closed one.
            if (!isNil "AP_jewelSafeOpen" && {!isNull AP_jewelSafeOpen}) then {
                { deleteVehicle _x; } forEach (nearestObjects [getPosATL AP_jewelSafeOpen, ["Land_Trophy_01_gold_F"], 6]);
                deleteVehicle AP_jewelSafeOpen;
            };
            AP_jewelSafeOpen = objNull;
            publicVariable "AP_jewelSafeOpen";
            if (!isNil "AP_jewelSafe" && {!isNull AP_jewelSafe}) then { AP_jewelSafe hideObjectGlobal false; };
```

- [ ] **Step 3: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf
```

Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf
git commit   # subject: "Actually open the emporium safe, on both maps"
```

---

### Task 5: The loaded getaway Qilin

**Files:**
- Modify: `server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf`

**Interfaces:**
- Consumes: `AP_JEWEL_QILINPOS`, `AP_JEWEL_CENTRE` (Task 1); the weld path (Task 4).
- Produces: `AP_jewelQilin`.

- [ ] **Step 1: Spawn it when the safe opens**

At the end of `weldSafe`'s success path, after the trophies:

```sqf
        // owner 2026-07-28: the loaded getaway. Same pattern as the Fed's boat and the asylum Tempest.
        // NOTE the despawn mechanism: AP_eventVeh does NOT control persistence -- it only exempts the
        // vehicle from fn_cleanup's sweep. What keeps this from surviving a restart is having no DB
        // identity: fn_saveVehicles writes only vehicles carrying dbInfo/AP_dbInfo, so one with
        // neither is never written to vehicle_mem and does not come back. Do not "fix" that by
        // registering it.
        private _qp = AP_JEWEL_QILINPOS;
        AP_jewelQilin = createVehicle ["O_LSV_02_armed_F", _qp, [], 0, "NONE"];
        AP_jewelQilin setPosATL _qp;
        AP_jewelQilin setDir 180;                       // facing south, per the owner
        AP_jewelQilin lock 0;
        AP_jewelQilin setFuel 1;
        AP_jewelQilin setVariable ["AP_eventVeh", true, true];
        AP_jewelQilin setVariable ["owner", "jewelry_qilin", true];
        AP_jewelQilin setVariable ["AP_vcap", 999999, true];              // unlimited T inventory
        AP_jewelQilin setVariable ["AP_vinv", [[["jewelBag", 10]], 80], true];   // 10 bags; jewelBag weighs 8

        private _keys = [];
        {
            if ((side _x isEqualTo civilian) && {alive _x} && {(_x distance AP_JEWEL_CENTRE) < 400}) then {
                _keys pushBack [getPlayerUID _x, name _x];
                [[AP_jewelQilin], "AP_fnc_addVehicle2Chain", _x, false, false] spawn AP_fnc_MP;
            };
        } forEach allPlayers;
        AP_jewelQilin setVariable ["AP_vehOwners", _keys, true];
        publicVariable "AP_jewelQilin";

        [[0, "A getaway Qilin has been delivered outside the emporium -- it is already carrying part of the haul."], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        diag_log format ["[maldenJewel] getaway Qilin spawned at %1 dir 180, keys to %2 player(s)", getPosATL AP_jewelQilin, count _keys];
```

- [ ] **Step 2: Do NOT delete it on window close**

Leave the Qilin alone in the reset block. It belongs to whoever earned it, exactly like the asylum Tempest, and the restart removes it because it has no DB identity. Add a one-line comment in the reset block recording that this is deliberate:

```sqf
            // the Qilin is deliberately NOT deleted here -- it is the crew's reward and survives the
            // window closing. It disappears at the next restart because it has no DB identity.
```

- [ ] **Step 3: Balance-check and commit**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf
git add server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf
git commit   # subject: "Deliver a loaded Qilin when the emporium safe comes open"
```

---

### Task 6: Offer the drill by proximity to the gate

The drill's scroll condition requires `cursorObject isEqualTo AP_jewerlyEmporium`. On Altis that is the emporium building; on Malden it is the back-alley gate — and the Fed's gate already proved that `cursorObject` on a large flat structure returns the paving underfoot instead of the object, which is exactly how that action became unreachable.

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf`

**Interfaces:**
- Consumes: `AP_jewelGate`, `AP_JEWEL_GATEPOS` (Task 1).
- Produces: nothing.

- [ ] **Step 1: Read the current entry**

```bash
cd /home/timb/Armapunk2035
sed -n '686,690p' mission/Armapunk2035.Malden/core/fn_setupActions.sqf | cut -c1-260
```

Note the `Start Drilling Door` entry and the `<=3` distance test that wraps it.

- [ ] **Step 2: Replace the cursor test with proximity**

In the `Start Drilling Door` entry, replace the `(cursorObject isEqualTo AP_jewerlyEmporium) && !isNull cursorObject` clauses with a proximity test against the gate anchor at **6 m**, keeping every other clause — `!(SRV_jewelryEmporiumSRV param [ 1, false ] )`, civilian side, and whatever else the entry already carries. Keep it on one line, matching the neighbouring entries' spacing.

The proximity clause to use:

```
(!isNull (missionNamespace getVariable [ "AP_jewelGate", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_jewelGate", objNull ] )) <= 6)
```

Then align the function: in `mission/Armapunk2035.Malden/core/actions/fn_jewelryEmporium.sqf`, the `startDrill` case must refuse past the same **6 m** so nothing is offered and then refused. If it currently has no distance check of its own, add one as a flat top-level `exitWith` beside the existing gates:

```sqf
            if (isNull AP_jewelGate || {(player distance AP_jewelGate) > 6}) exitWith {
                [2, "You are not at the emporium's back gate."] call AP_fnc_broadcast};
```

- [ ] **Step 3: Balance-check both files**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/fn_setupActions.sqf \
    mission/Armapunk2035.Malden/core/actions/fn_jewelryEmporium.sqf
```

Expected: `ok` for both.

- [ ] **Step 4: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/fn_setupActions.sqf mission/Armapunk2035.Malden/core/actions/fn_jewelryEmporium.sqf
git commit   # subject: "Offer the emporium drill by proximity instead of cursor"
```

---

### Task 7: Parse probe, TODO entries, and the full verification pass

**Files:**
- Modify: `mission/Armapunk2035.Malden/initServer.sqf` (temporary probe), `TODO.md`

- [ ] **Step 1: Add a temporary parse probe**

A dedicated server never compiles client functions, so a syntax fault in one shows up only as a player's whole scroll menu vanishing. In `initServer.sqf`, at the end:

```sqf
// TEMPORARY PARSE PROBE -- remove after one deploy. compile PARSES without running.
{
    private _ok = true;
    try { private _c = compile preprocessFileLineNumbers _x; } catch { _ok = false; };
    diag_log format ["[maldenJewel] parse %1 : %2", _x, ["FAILED", "ok"] select _ok];
} forEach ["core\actions\fn_jewelryEmporium.sqf", "core\fn_setupActions.sqf", "core\configuration.sqf"];
```

Note when reading the result: Arma's `compile` usually **logs** a parse error rather than throwing, so the pass condition is three `ok` lines with no engine compile errors between them — not merely the absence of `FAILED`.

- [ ] **Step 2: File the deferred items**

Append to `TODO.md`:

```markdown
## Jewelry Emporium (Malden, built 2026-07-28, see maldenjewelry.md)

- **Back-gate collision (#303).** On Altis the emporium's back gate has no blocking collision and
  vehicles drive through it. Malden's gates are ordinary mission.sqm objects and are expected to
  collide normally — confirm in game rather than pre-emptively scripting a barrier.
- **No deposit container on Malden.** `AP_jewerlyContainer` is bound to objNull, so the
  "load outside container" action never offers. The reward is the Qilin instead. If a container is
  wanted later, place one and bind it in `APS_fnc_maldenJewelSRV`.
- **Cop requirement** stays at `SRV_jewelryEmporiumSRV` slot 6, floored at 1, matching the Fed and
  bank during testing.
```

- [ ] **Step 3: Deploy and read the boot log**

```bash
cd /home/timb/Armapunk2035
bash deploy/reload-armapunk2035.sh
timeout 240 bash -c 'until grep -q "\[maldenJewel\] boot complete" /home/timb/arma3server_dev/loonydev.log; do sleep 5; done' && echo BOOTED
grep -n '\[maldenJewel\]' /home/timb/arma3server_dev/loonydev.log
```

Expected: the gate resolves as `Land_BackAlley_01_l_gate_F` within a couple of metres of the anchor; the safe spawns as `Fridge_01_closed_F` at the owner's coordinate with a plausible terrain height; **8** display cases counted; three `parse … : ok` lines; `boot complete -- gate true, safe true`.

**If the safe's logged position looks buried or floating relative to the terrain height on the same line, stop and report it** — the owner's z is in the ATL frame the display cases use, and a mismatch shows up here rather than in game.

- [ ] **Step 4: Remove the probe and redeploy**

Delete the probe block added in Step 1, then deploy again and confirm the boot lines still appear.

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/initServer.sqf TODO.md
git commit   # subject: "File the emporium's deferred items and drop the parse probe"
```

---

## In-game pass (the owner's, after all tasks land)

1. Before anything: the safe exists at `[7538.99, 10583.7]` and cannot be welded; cases cannot be smashed.
2. Stand at the back gate → **Start Drilling Door** offers within 6 m regardless of where the cursor points.
3. Drill → alarm, MaxSec alert, charge 76 applied within 90 m, cases become breakable.
4. Smash 7 of 8 → the safe still refuses ("You have yet to meet the requirments"). Smash the 8th → the broadcast fires and the safe unlocks.
5. Weld the safe with a plasma cutter → it visibly opens, 4 trophies are beside it, and `takeSafeContents` gives the 5th bag.
6. The Qilin is at `[7515.07, 10599.3]` facing south, loaded with 10 bags, keyed to everyone on site, unlimited T inventory.
7. Wait out the 20-minute window → cases and safe reset, the Qilin stays, 30-minute cooldown blocks a retry.
8. Restart → the Qilin is gone.
