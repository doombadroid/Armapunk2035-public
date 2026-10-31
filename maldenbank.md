# Malden bank — design and implementation plan

Owner brief 2026-07-27, immediately after `maldenfed.md`: *"Wire the bank. There's a back alley wire
fence gate at [6234.72, 2863.93, 0.34]. Have it locked until complete. Works identically to Altis,
just a different door. Spawn briefcases here [6228.43, 2864.01, 0.38]."*

Small on purpose. The 15-minute drill, the dirty-money payout, the MaxTac call, the cop **Disable
Drill** counterplay, the 3-minute grab window and the 20-minute re-rob cooldown all already exist in
`fn_bankDrillVault.sqf` and are not touched. What is missing is that **none of the objects the bank
addresses exist on Malden** — so it addresses new ones.

---

## 1. What is actually missing

Three names carry the whole Altis bank, and on this map all three are unbound:

| Name | On Altis | On Malden today |
|---|---|---|
| `AP_bank_door` (marker) | drill action anchor, drill prop position, briefcase anchor | **does not exist** |
| `AP_bank_door_2` (marker) | the vault's second door, cop-side checks | **does not exist** |
| `AP_bank_building` (object) | dispatch position, alarm sound source, the vault door it animates (`door_4_rot` / `bis_disabled_Door_4`), the 60 m crew-holding radius | **unbound** |

`getMarkerPos` on a missing marker returns `[0,0,0]` — a real, reachable spot on the map, not an
error. That is the bug class that stacked half the gathering economy into Malden's south-west corner,
and here it would put `player distance getMarkerPos "AP_bank_door_2" < 4` **true** for anyone
standing in the corner of the map. Both markers get created; neither is left to default.

## 2. The objects

| Anchor | Position | Object |
|---|---|---|
| `BANK_GATE` | `[6234.72, 2863.93, 0.34]` | `Land_BackAlley_01_l_gate_F` — confirmed in mission.sqm at `[6234.07, 2864.02]`, 0.7 m away |
| `BANK_CASES` | `[6228.43, 2864.01, 0.38]` | open floor 5.6 m inside the gate |

**The gate class is not unique on this map** — there are more `Land_BackAlley_01_l_gate_F` up at the
Federal Reserve. It is resolved by proximity to the owner's coordinate, never by a class scan.

Its animation names are **not assumed**. They are enumerated with `animationNames` at boot and
logged, the way the Fed's terrain anchors are, because the Altis code hardcodes `door_4_rot` — an
animation this class does not have. Everything door-ish is driven; the log says what that turned out
to be.

## 3. Behaviour

Identical to Altis except where the object forced a change:

- **Locked by default**, at boot and after every completed robbery: doors disabled, animations shut.
- Drill starts at the gate (`AP_bank_door` is the gate). The existing action already requires a
  Cyberdeck and the Terminal Breach; that is unchanged.
- 15-minute drill, unchanged. Cop **Disable Drill** unchanged. The draining `bank_robbery` box in the
  top right is unchanged.
- On success: the **gate** unlocks and swings open instead of `AP_bank_building`'s `door_4_rot`,
  and the briefcases spawn at `BANK_CASES` instead of the computed vault-interior offset.
- The 3-minute grab window is unchanged, and at the end of it the gate re-locks — the same shape the
  Altis vault door has, applied to the gate.
- Payout unchanged: $50,000 + $50,000 per cop online, split across briefcases, plus the one crypto
  mining component beside the cash.

**Cop requirement: 0 while testing**, matching the call already made for the Fed, with the
public-launch value (4 tenured) in the comment beside it. Filed in TODO.md with the Fed's.

## 4. Files

| File | Change |
|---|---|
| `mission/Armapunk2035.Malden/initServer.sqf` | create `AP_bank_door` and `AP_bank_door_2` markers |
| `server/AP_server/core/TON/fn_maldenBankSRV.sqf` | **new** — resolve the gate at boot, log its animations, bind `AP_bank_building`, lock it down; `["open"]` / `["seal"]` modes |
| `server/AP_server/core/bank/fn_bankDrillVault.sqf` | drive the gate instead of `door_4_rot`; briefcases at `BANK_CASES`; cop gate 0 |
| `server/AP_server/config.cpp`, `init.sqf` | register and boot-call the new function |
| `TODO.md` | restore the cop requirement before launch |

---

## Implementation plan

Same rules as `maldenfed_plan.md`: every SQF file passes `python3 tools/sqf_balance.py` before it is
committed; verification is an RPT line or an in-game check, never an argument; commit only the paths
each task names.

**Do Task 0 of `maldenfed_plan.md` first.** `initPlayerLocal` currently aborts on every client, so
nothing client-side — including the drill action — can be trusted to be running.

### Task B1: Resolve the gate, log its animations, lock it

- [ ] **Step 1: Assert it fails now**

```bash
grep -c '\[maldenBank\]' /home/timb/arma3server_dev/loonydev.log
```

Expected: `0`.

- [ ] **Step 2: Create `server/AP_server/core/TON/fn_maldenBankSRV.sqf`**

```sqf
/*
    APS_fnc_maldenBankSRV -- the Malden bank's door.

    The 15-minute drill, the payout, the MaxTac call and the cop's Disable Drill are all unchanged in
    fn_bankDrillVault; what did not exist on this map were the three names that code addresses:
    the AP_bank_door / _2 markers and the AP_bank_building object. This binds them.

    THE DOOR IS A BACK-ALLEY GATE, not Altis's vault. The Altis code animates "door_4_rot", which this
    class does not have, so the animation names are ENUMERATED at boot and logged rather than assumed,
    and everything door-ish is driven. The class is NOT unique on this map -- there are more of them at
    the Federal Reserve -- so the gate is resolved by proximity to the owner's coordinate.

    MODES
      ["boot"]   resolve, bind, log, lock
      ["open"]   drill succeeded: unlock and swing
      ["seal"]   grab window over (or boot): lock and shut
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]]];

AP_BANK_GATEPOS  = [6234.72, 2863.93, 0.34];
AP_BANK_CASESPOS = [6228.43, 2864.01, 0.38];

private _fnc_doorAnims = {
    params ["_obj"];
    (animationNames _obj) select {
        private _a = toLower _x;
        ((_a find "door") >= 0 || {(_a find "gate") >= 0}) && {(_a find "locked") isEqualTo -1}
    }
};

switch (toLower _mode) do {

    case "boot": {
        private _g = (nearestObjects [AP_BANK_GATEPOS, ["Land_BackAlley_01_l_gate_F"], 10]) param [0, objNull];
        AP_bankGate = _g;
        publicVariable "AP_bankGate";
        if (isNull _g) exitWith {
            diag_log format ["[maldenBank] NO GATE within 10 m of %1 -- the bank is unwired", AP_BANK_GATEPOS]; };

        AP_bank_building = _g;      // dispatch position, alarm source, crew-holding radius
        publicVariable "AP_bank_building";

        diag_log format ["[maldenBank] gate = %1 at %2, %3 m from the brief",
            typeOf _g, getPosATL _g, ((getPosATL _g) distance AP_BANK_GATEPOS) toFixed 1];
        diag_log format ["[maldenBank] gate animations = %1", animationNames _g];
        diag_log format ["[maldenBank] gate DOOR animations = %1 (these are the ones driven)", [_g] call _fnc_doorAnims];
        diag_log format ["[maldenBank] gate numberOfDoors = %1",
            getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors")];

        ["seal"] call APS_fnc_maldenBankSRV;
    };

    case "seal": {
        private _g = missionNamespace getVariable ["AP_bankGate", objNull];
        if (isNull _g) exitWith {};
        private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors");
        for "_i" from 1 to _n do { _g setVariable [format ["bis_disabled_Door_%1", _i], 1, true]; };
        { _g animate [_x, 0, true]; } forEach ([_g] call _fnc_doorAnims);
        _g setVariable ["gate_max", 0, true];
        diag_log "[maldenBank] gate SEALED";
    };

    case "open": {
        if (remoteExecutedOwner isNotEqualTo 0) exitWith {
            diag_log "[maldenBank] open refused -- client-originated"; };
        private _g = missionNamespace getVariable ["AP_bankGate", objNull];
        if (isNull _g) exitWith {};
        private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors");
        for "_i" from 1 to _n do { _g setVariable [format ["bis_disabled_Door_%1", _i], 0, true]; };
        { _g animate [_x, 1, true]; } forEach ([_g] call _fnc_doorAnims);
        _g setVariable ["gate_max", 1, true];
        diag_log "[maldenBank] gate OPEN";
    };

    default { diag_log format ["[maldenBank] unknown mode '%1'", _mode]; };
};
true
```

- [ ] **Step 3: Register and boot-call**

`server/AP_server/config.cpp`, beside `class maldenFedSRV {};`:

```cpp
 class maldenBankSRV {};     // the Malden bank's door: resolve, bind AP_bank_building, lock/unlock
```

`server/AP_server/init.sqf`, beside the Fed's boot call:

```sqf
["boot"] call APS_fnc_maldenBankSRV;   // Malden bank: resolve the back-alley gate, bind it, seal it
```

- [ ] **Step 4: Create both markers**

In `mission/Armapunk2035.Malden/initServer.sqf`, beside the `fed_reserve` marker:

```sqf
// The bank's drill action, the drill prop, the cop's Disable Drill and the cyberdeck's bank hack all
// key off these two markers. Neither exists on this map, and getMarkerPos on a missing marker returns
// [0,0,0] -- a real, reachable spot -- so leaving AP_bank_door_2 unmade would put the cop action
// live for anyone standing in the map's south-west corner. Malden's bank has one door; the second
// marker is created on top of the first so the distance test can only ever mean the real door.
{
    if ((getMarkerPos _x) isEqualTo [0,0,0]) then {
        createMarker [_x, [6234.72, 2863.93, 0.34]];
        _x setMarkerAlpha 0;
        diag_log format ["[maldenBank] %1 marker created at %2", _x, getMarkerPos _x];
    };
} forEach ["AP_bank_door", "AP_bank_door_2"];
```

- [ ] **Step 5: Balance-check, deploy, read the log**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenBankSRV.sqf \
    server/AP_server/init.sqf mission/Armapunk2035.Malden/initServer.sqf
bash deploy/reload-armapunk2035.sh
# wait with Monitor, then:
grep -n '\[maldenBank\]' /home/timb/arma3server_dev/loonydev.log
```

Expected: the gate resolved under 1 m from the brief, both markers created, and a **non-empty** DOOR
animations list. **If that list is empty, stop** — the class names its animation something neither
"door" nor "gate" matches, and the real names are in the line above it; widen `_fnc_doorAnims` to
those exact names before going on.

In game: the gate will not open by hand.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_maldenBankSRV.sqf server/AP_server/config.cpp server/AP_server/init.sqf mission/Armapunk2035.Malden/initServer.sqf
git commit   # subject: "Bind Malden's bank to the back-alley gate and seal it at boot"
```

### Task B2: Drive the gate from the drill, and put the briefcases where the owner asked

- [ ] **Step 1: Read what the drill does with the door today**

```bash
cd /home/timb/Armapunk2035
grep -n 'bis_disabled_Door_4\|door_4_rot\|door4_rot\|_vaultPos\|_casePos' server/AP_server/core/bank/fn_bankDrillVault.sqf
```

- [ ] **Step 2: Replace the three door operations**

In `fn_bankDrillVault.sqf`:

At the start of the robbery, the pair that shuts the Altis vault door becomes a no-op — the gate is
already sealed at boot and stays sealed until the drill finishes:

```sqf
// owner 2026-07-27: Malden's bank door is a back-alley gate, sealed at boot by APS_fnc_maldenBankSRV
// and opened only on success. The Altis pair here animated "door_4_rot" on AP_bank_building, an
// animation this class does not have, so it did nothing but look like it did.
```

On success, replace `AP_bank_building setVariable ["bis_disabled_Door_4", 0, true]; AP_bank_building animate ["door_4_rot", 1];` with:

```sqf
["open"] call APS_fnc_maldenBankSRV;
```

and in the 3-minute close-up spawn, replace the re-lock pair with:

```sqf
["seal"] call APS_fnc_maldenBankSRV;
```

- [ ] **Step 3: Anchor the briefcases on the owner's coordinate**

Replace the `_vaultPos` `switch (worldName)` block with:

```sqf
// owner 2026-07-27: Malden's payout spot, given directly rather than derived. The Altis code computed
// this from the door marker and an inside-offset, which had already been re-anchored twice (#377/#349)
// because the cases kept landing outside the building.
private _vaultPos = missionNamespace getVariable ["AP_BANK_CASESPOS", [6228.43, 2864.01, 0.38]];
```

Leave the 5×2 grid that clusters ten case positions around `_vaultPos`, the payout split, the
component case and the 3-minute sweep exactly as they are.

- [ ] **Step 4: Drop the cop gate for testing**

Change the tenured-cop test from `< 4` to `< 0`, and make the comment read:

```sqf
// owner 2026-07-27: Malden testing -- bank cop requirement 0, matching the Fed. Restore to < 4 at public launch.
```

- [ ] **Step 5: Balance-check, deploy, run it**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/bank/fn_bankDrillVault.sqf
```

In game: start the drill at the gate — the Cyberdeck terminal gate works, the drill prop appears at
the gate, the draining red box appears top right, and a cop gets **Disable Drill**. Let it run the
full fifteen minutes: the gate swings open, ten briefcases are on the floor at the owner's
coordinate, each pays its share of $50k + $50k per cop online, and the mining component is beside
them. Three minutes later the gate re-seals. Trying again inside twenty minutes is refused.

```bash
grep -n 'maldenBank\] gate OPEN\|maldenBank\] gate SEALED\|vault success' /home/timb/arma3server_dev/loonydev.log
```

- [ ] **Step 6: File the follow-up and commit**

Append to the Malden section of `TODO.md`:

```markdown
- **Restore the bank's cop requirement.** `fn_bankDrillVault`'s tenured-cop gate is `< 0` for Malden
  testing; the public-launch value is `< 4` and is in the comment beside it.
```

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/bank/fn_bankDrillVault.sqf TODO.md
git commit   # subject: "Open Malden's bank through its gate and pay out where the owner asked"
```

---

## Deferred

- Restoring the bank cop requirement to 4 before public launch (in TODO.md).
- Nothing about the bank's own economy, shops or NPC placement — that is the `fn_mapData` pass.
