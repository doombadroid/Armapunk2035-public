/*
    APS_fnc_fedGoldSpawn  (LooneyBin NEW 2026-06-09 -- Federal Reserve rework)
    Called by APS_fnc_maldenFedSRV case "domeOpen" when the 10:00 vault clock expires: [domeObject].
    It is called DIRECTLY, not through AP_fnc_MP, so remoteExecutedOwner stays 0 and the client-call
    block below is skipped -- see the note at that call site. The client's own breach (AP_fnc_openVault)
    only STARTS the clock, by asking for ["dome"]; it does not reach this function.
    Spawns ONE briefcase per building in AP_fedSafes -- the ten Land_Medevac_house_V1_F safes resolved
    once at boot, NOT a class search around the dome -- each holding 1-5 GOLD BARS as a lootable suitcase
    (AP_droppedItems -- same mechanic as death-drop suitcases / treasure chests). Once-per-dome per
    robbery (AP_goldSpawned; the boot/reset lockdown clears it). Cases self-delete when emptied or
    after 30 min.
*/
params [["_dome", objNull, [objNull]]];
diag_log format ["[LooneyBin][fed] fedGoldSpawn called: dome=%1 already=%2", _dome, if (isNull _dome) then {"NULL"} else {_dome getVariable ["AP_goldSpawned", false]}];
if (isNull _dome) exitWith {};
// owner 2026-06-16 (#302): SERVER-side mutual-exclusion backstop. If a breach slipped past the client gate
// during another event's window, refuse the payoff -- no gold spawns while another federal event is live.
if (["fed"] call APS_fnc_fedEventActive) exitWith {
    diag_log "[LooneyBin][fed] fedGoldSpawn ABORTED -- another federal event already active (#302 server gate)";};
// owner 2026-07-24 SECURITY (audit): CfgRE allowedTargets=2 with no caller derivation, no proximity check
// and no proof the vault was ever breached -- a client could remoteExec [<dome>] from anywhere and collect
// the entire Federal Reserve gold payout without touching the heist. The per-dome AP_goldSpawned flag
// limited it to once per dome per reset, which bounded the theft but did not prevent it.
// Require, for a client call: a resolvable caller, that caller standing at the dome, and the dome actually
// UNLOCKED -- fn_openVault sets AP_vaultlocked = 0 at :153 immediately before calling this at :165, and
// fn_fedLockdown re-seals it to 1, so 0 means a breach really happened.
// NOTE (residual, not fixable here): AP_vaultlocked is set CLIENT-side in fn_openVault with public=true,
// so a modified client can still assert it. Combined with the proximity gate, the once-per-dome flag and
// the existing #302 event-exclusion check this is much harder to abuse, but a full fix needs the door
// break itself validated server-side. Tracked in AUDIT.md.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _blockGold = false;
if (_src isNotEqualTo 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _caller || {(_caller distance _dome) > 120} || {(_dome getVariable ["AP_vaultlocked", 1]) isNotEqualTo 0}) then {
        ["-SEC-", _caller, format ["BLOCKED fedGoldSpawn (dist %1, vaultlocked %2) by %3",
            if (isNull _caller) then {-1} else {round (_caller distance _dome)},
            _dome getVariable ["AP_vaultlocked", 1], getPlayerUID _caller]] call APS_fnc_logIt;
        _blockGold = true;   // nested exitWith would only leave this then-block
    };};
if (_blockGold) exitWith {};
if (_dome getVariable ["AP_goldSpawned", false]) exitWith {};
_dome setVariable ["AP_goldSpawned", true, true];

private _buildings = missionNamespace getVariable ["AP_fedSafes", []];
if (_buildings isEqualTo []) exitWith {
    diag_log "[maldenFed] fedGoldSpawn: AP_fedSafes is empty -- no gold spawned (boot resolve failed?)";};
// ---- THE CASES ARE FROZEN. THIS IS THE RING-SAFE HALF OF THE FED BRIEFCASE BUG (owner, 2026-07-29:
//      "the briefcases have sim enabled and half of them fall through the floor onto the terrain way
//      below the composition"). The Reserve has 16 gold/loot cases in total and only 5 of them are in
//      APS_fnc_maldenFedSRV (the Alamo centre); the 10 ring-safe cases and the mining component below
//      are these, which is most of what the owner was looking at.
//
//      Land_Suitcase_F inherits ThingX, so it is a live PhysX body under gravity -- APS_fnc_createItem's
//      own header records that these "spawned overlapping and violently ejected nearby vehicles/players"
//      before it started disabling simulation on them.
//
//      ---- CORRECTED 2026-07-29. The paragraph that stood here said "the ten Land_Medevac_house_V1_F
//      ring safes are not server-created". THEY ARE, and the same sentence had also been copied into
//      the WARN line at the bottom of this file, where a wrong claim is worse than no claim at all --
//      it sends whoever reads that warning hunting a missing-object bug that does not exist.
//
//      What the code actually does. The ten ring safes are mission.sqm entities in the Eden layer named
//      FEDERAL RESERVE (ids 26910-26919), each carrying init = "_serverObject =true;" and
//      disableSimulation = 1. A mission.sqm object is instantiated by the engine on every machine
//      including the dedicated server, so they are real server-side objects with real geometry. The
//      proof is three lines above this comment and does not need anyone to load in: AP_fedSafes is
//      filled by a SERVER-side nearestObjects in APS_fnc_maldenFedSRV case "boot", and if these
//      buildings did not exist on the server that list would be empty and the guard at the top of this
//      block would have exited with "AP_fedSafes is empty". Every case below is placed at
//      `_x buildingPos`, i.e. inside one of them, so it has a server-side floor under it.
//
//      What IS client-only is the DECK, and only the fn_mapData half of it. Measured against the
//      shipped file: 486 rows lie within 70 m of AP_FED_CENTRE (not 620), spanning z -21.88 to z 29.35
//      (not -21.9 to 31.3), of which 206 are Land_Sidewalk_02_8m_F (not 237); exactly TWO of those rows
//      carry _xIsServer = true, the dome and the Alamo centre. initServer.sqf spawns only the
//      _xIsServer rows, so the sidewalk plates, cobblestone squares and canal plates exist on a client
//      alone, as createSimpleObject copies. mission.sqm contributes 23 further objects inside that same
//      70 m which DO exist on the server. So "no server-side collision under the compound" was never
//      true; what is true is that the open ground between the buildings has none.
//
//      That matters for exactly one object below: the mining component, which is seeded beside a random
//      gold case with a +/-0.6 m XY jitter and can therefore be nudged off the safe's floor onto deck
//      that is not there on this machine. The gold cases themselves are inside their buildings.
//      THE FREEZE STAYS REGARDLESS, on the general argument rather than the floor one: every other
//      Land_Suitcase_F in the build is frozen the moment APS_fnc_createItem makes it, and a simulated
//      case is free to be shoved by a player, a vehicle or an explosion for the thirty minutes it sits
//      there. The settle read at the bottom of this file is what decides whether they actually drift --
//      it measures, it does not argue.
//
//      The order is fn_bankDrillVault's, which drives this identical class at the bank vault and is the
//      proven shape: create -> enableSimulationGlobal false -> setPos* -> setVectorUp. Freezing FIRST
//      is what makes the re-assert stick, and the re-assert still replicates afterwards (BIKI,
//      enableSimulation: "After using enableSimulation false or enableSimulationGlobal false on an
//      object, setPos will still update its position across the network in MP"). THE ORDER IS UNCHANGED
//      BY THE 2026-07-29 FRAME FIX BELOW and must stay that way: the probe read every case back at
//      EXACTLY the number the placement wrote, twice, minutes apart, so the freeze holds and a write
//      made after it still lands. Only the FRAME of that write changed, which means the case is frozen
//      and then put at the CORRECT position -- and nothing can undo it afterwards, because with
//      simulation off there is no gravity left to pull on it.
//
//      ---- THE POSITION FRAME. THIS, NOT THE FREEZE, IS WHAT THE OWNER WAS LOOKING AT (2026-07-29).
//      The placement below used to read `_case setPosATL _pos` with _pos taken straight from
//      `buildingPos`, and those are two different frames:
//        * BIKI buildingPos -- return value: "PositionAGL - a single building position".
//        * BIKI Position#PositionAGL -- "Z is the same as PositionASLW when over sea and is the same as
//          PositionATL when over land."
//        * BIKI setPosATL -- "Sets the position of an object relative to the terrain", i.e. it wants a
//          PositionATL, Z measured from the TERRAIN.
//      The Reserve composition is built OUT OVER THE SEA. The terrain under it is the seabed and runs
//      from -3.68 m at the deep end to +0.23 m where it comes ashore, while the ten safes' floors are
//      flat at ASL ~16.8. Handing an AGL height to setPosATL therefore sank every case by exactly the
//      depth of the seabed beneath it. A live probe of all eleven objects during a running robbery,
//      repeated minutes apart with identical results, measured -2.72 m below the deck at the deep end,
//      -1.1 to -1.7 m across the middle, and the two cases nearest the waterline sitting ON the floor
//      instead of on the shelf above it. The error is zero wherever the terrain is at sea level and
//      NEGATIVE-ZERO inland, which is why the Jewelry Emporium (terrain ~+28.9, so its cases float
//      ~29 m UP rather than sinking) never presented this way, and why freezing the cases in 3bd494a
//      looked like it had not worked. The freeze always worked -- the same probe reports
//      simulationEnabled false on all eleven.
//
//      THE FIX IS AGLToASL + setPosASL, NOT "read the buildingPos z as a world height". Reinterpreting
//      the number is right only where the terrain is under water; over land AGL IS ATL, so a naive ASL
//      read would sink a case by the terrain height instead -- the same bug mirrored, and this compound
//      already crosses the waterline (one of the eleven probed objects stands over terrain at +0.23).
//      AGLToASL is the engine's own conversion and is correct on both sides of that line. ASL is also
//      the only absolute frame Arma has (BIKI Position: "the only absolute position format in Arma for
//      3D calculations is the ASL format"), which is what makes the settle log at the bottom of this
//      file able to say anything meaningful about where a case actually is.
//
//      THE REPOSITION STAYS -- IT IS NOT REDUNDANT WITH createVehicle, and deleting it was considered.
//      BIKI createVehicle, R3vo's note on the main syntax: "The main syntax creates vehicles at ground
//      level ignoring the Z in pos", equivalent to createVehicle [cls, [pos#0, pos#1, 0], [], 0, "NONE"].
//      So the Z handed to createVehicle here is inert, the object lands on the GROUND -- which under
//      this compound is the seabed, 20 m down -- and the setPos is the only thing that places it. Delete
//      it and every case ends up further below the deck than the bug being fixed here put it. (The array
//      syntax was rejected for the same reason in reverse: BIKI records it as taking a PositionATL for
//      anything that is not amphibious, which would put the ATL frame straight back in.)
//
//      IT COSTS THE LOOT FLOW NOTHING. Every path that touches these cases is a setVariable or a SPATIAL
//      query, and a non-simulated object answers both: fn_setupActions.sqf:99 offers "Pick Up Item(s)"
//      on cursorObject, fn_pickupSelected.sqf reads cursorObject with a nearestObject fallback, and
//      cursorObject is documented to return an object "even if the simulation is not enabled" since
//      Arma 3 1.56 (BIKI, enableSimulation). cursorTARGET is the one that goes objNull on a frozen
//      object, and nothing in this flow uses it. The proof is that APS_fnc_createItem already freezes
//      EVERY Land_Suitcase_F it makes -- every death drop, manual drop and login bonus in the build is a
//      frozen case with AP_droppedItems, and players loot those daily.
//
//      allowDamage false: these sit in the open through a cop-vs-crew firefight and a destroyed holder
//      takes the payout with it. fn_createItem sets it on every drop; simulation-off does not imply
//      damage-off, so it is a separate write. NOT AP_questloot: that flag's only load-bearing reader is
//      fn_pickupItem.sqf:82, which deletes the holder once its last item is taken UNLESS the flag is
//      set. A briefcase IS the loot container and is MEANT to vanish when emptied -- setting it would
//      strand an empty case in the safe and fight the self-delete spawn below. `owner` is the tag that
//      matters, and it is already set.
//      HOW fn_cleanup ACTUALLY LEAVES THESE ALONE -- corrected 2026-07-29, the claim that "both sweeps
//      refuse an object whose `owner` var is set" does not survive reading the file. fn_cleanup.sqf:179,
//      the `vehicles` sweep, deletes when the object is not whitelisted AND has no AP_furniture AND no
//      `item` var AND an EMPTY AP_droppedItems AND ( idleTime stamped more than 1800 s ago OR
//      (idleTime == 0 AND no Revive/owner/Trunk and not roped) ). `owner` is in the SECOND disjunct
//      only, so a stale-stamped object is deleted whatever `owner` says; what keeps a LOADED case out
//      of that sweep is the AP_droppedItems clause several tests earlier, and once it is emptied
//      nothing has ever stamped an idleTime on it, so the idleTime == 0 branch applies and `owner` does
//      exempt it there. fn_cleanup.sqf:181, the Thing sweep, is the one that names Land_Suitcase_F by
//      class, and it only reaches an object with `!isNil "_item"` AND `isNil "_owner"` (:186) -- these
//      cases set `owner` and never set `item`, so they are exempt twice over.
private _spawned = 0;
private _placed  = [];   // [case, authored ASL position, the safe it belongs to], for the settle read at the bottom
private _fedCases = []; {private _spots = _x buildingPos -1;
    // ONE FRAME FROM HERE DOWN. buildingPos hands back a PositionAGL, so it is converted to ASL at the
    // point it is read and everything downstream -- the placement, the component's anchor read and the
    // settle log -- speaks ASL and only ASL.
    // ---- THE FALLBACK WAS NEVER BROKEN. RETRACTED 2026-07-29, same day it was written. The note that
    //      stood here said the old `getPosATL _x` was "the same frame mistake one branch further out"
    //      and would have put a case at the seabed depth below its own building. That is wrong, and it
    //      is wrong in the direction that matters -- it invents a second bug where there was one, in a
    //      file whose whole point is now that frames must be reasoned about rather than assumed.
    //      getPosATL RETURNS a PositionATL and setPosATL TAKES a PositionATL (BIKI, both: "the position
    //      of an object relative to the terrain"), so that branch never crossed frames. It also read
    //      and wrote at the SAME x/y, so the terrain term cancels identically:
    //          world z written = terrain(x,y) + (world z of the safe - terrain(x,y)) = world z of the safe
    //      -- an identity, whatever the seabed underneath is doing. The fallback put the case exactly on
    //      its safe's own origin, which is what it was written to do. Only the buildingPos branch, which
    //      fed an AGL number to a command wanting ATL, ever had the bug.
    //      It still moved to getPosASL, for a reason that is real but is NOT "it was broken": the settle
    //      log at the bottom of this file differences a getPosASL read against the authored z carried in
    //      _placed. Leave one branch authoring in ATL and that subtraction stops measuring drift on that
    //      case and starts reporting the terrain depth instead. The fallback follows the frame so the
    //      log stays meaningful on every case; it is a consistency change, not a fix.
    //      (In practice this branch has never fired -- the probe read a buildingPos off all ten safes.)
    private _pos = if (_spots isEqualTo []) then { getPosASL _x } else { AGLToASL (selectRandom _spots) };
    diag_log format ["[maldenFed] gold case %1 -> %2 asl (%3)", _forEachIndex, _pos,
        if (_spots isEqualTo []) then {"FALLBACK: object centre -- check this one is INSIDE"} else {"buildingPos, AGL -> ASL"}];
    private _case = "Land_Suitcase_F" createVehicle _pos;   // z is inert here -- see the createVehicle note above
    _case enableSimulationGlobal false;   // BEFORE the placement -- the freeze is what makes it stick
    _case setPosASL _pos;
    _case setVectorUp [0, 0, 1];          // a frozen case otherwise keeps whatever tilt createVehicle gave it
    _case allowDamage false;
    _case setVariable ["owner", "fed_gold", true];                       // cleanup-sweep spare
    _case setVariable ["AP_droppedItems", [["goldbar", 1 + floor random 5]], true];
    _spawned = _spawned + 1;
    // The case AND the safe it belongs to. The building is what lets the settle log measure this case
    // against something INDEPENDENT of the number that placed it -- see the bottom of this file.
    _fedCases pushBack [_case, _x];
    _placed pushBack [_case, _pos, _x];
    [_case] spawn {params ["_c"];
        private _endAt = serverTime + 1800;
        waitUntil { uiSleep 2; isNull _c || {(_c getVariable ["AP_droppedItems", []]) isEqualTo []} || {serverTime > _endAt} };
        if (!isNull _c) then { deleteVehicle _c; };};} forEach _buildings;

// owner 2026-07-18: 1 crypto MINING COMPONENT per fed event, in a small case beside a RANDOM gold briefcase
// in the FIRST dome breached. Per-EVENT guard AP_fedComponentSpawned (re-armed with AP_goldSpawned in
// fn_fedLockdown + boot). Replaces the retired standalone APS_fnc_miningSRV ["drop"] crate.
if (!(missionNamespace getVariable ["AP_fedComponentSpawned", false]) && {_fedCases isNotEqualTo []}) then {
    missionNamespace setVariable ["AP_fedComponentSpawned", true, true];
    (selectRandom _fedCases) params ["_anchor", "_anchorSafe"];
    // The anchor is read AFTER the freeze above, which is a second, quieter fix: while the gold cases
    // were simulated this line sampled a case that had already begun to fall, so the component was
    // seeded at whatever height that case had reached and then fell from there too. Frozen, the anchor
    // reports its authored buildingPos and the component lands on the same floor as its gold.
    // getPosASL, matching the frame the anchor was PLACED in -- and this read is a frame bug in its own
    // right, not just a copy of the one above. The jitter moves the component up to 0.6 m in XY, and an
    // ATL height transplanted across that step silently changes world height by however much the seabed
    // rose or fell between the two spots; the terrain under this compound falls away by nearly 4 m
    // across it, so that is not a rounding error. The deck is FLAT, so in ASL the transplant is exact.
    private _cp = (getPosASL _anchor) vectorAdd [0.6 - random 1.2, 0.6 - random 1.2, 0];
    private _comp = "Land_Suitcase_F" createVehicle _cp;   // z inert -- see the createVehicle note above
    _comp enableSimulationGlobal false;   // BEFORE the placement, exactly as the gold cases above
    _comp setPosASL _cp;
    _comp setVectorUp [0, 0, 1];
    _comp allowDamage false;
    // Measured against the safe its ANCHOR belongs to. The component can legitimately be jittered off
    // that building's floor plate, but it is on the same flat deck, so the safe is still the right
    // independent reference for the settle log.
    _placed pushBack [_comp, _cp, _anchorSafe];
    _comp setVariable ["owner", "fed_component", true];                       // cleanup-sweep spare
    _comp setVariable ["AP_droppedItems", [[selectRandom ["cryptoCPU","cryptoGPU","cryptoPSU","cryptoStorage","cryptoMotherboard","cryptoRam","cryptoCooler","cryptoCase"], 1]], true];
    [_comp] spawn {params ["_c"];
        private _endAt = serverTime + 1800;
        waitUntil { uiSleep 2; isNull _c || {(_c getVariable ["AP_droppedItems", []]) isEqualTo []} || {serverTime > _endAt} };
        if (!isNull _c) then { deleteVehicle _c; };};
    diag_log format ["[LooneyBin][fed] mining component seeded beside gold at %1 asl", _cp];};

// ---- THE SETTLE READ, REBUILT 2026-07-29 SO IT CAN SEE A FRAME ERROR.
//      What it used to be: read each case back 3 s later and compare its height against the SAME number
//      that had just been written to it. That can only ever answer one question -- did the object move
//      after it was placed -- so it detects a failed freeze and nothing else. It was green through the
//      entire lifetime of the AGL-into-setPosATL bug above, and it was green precisely BECAUSE the bug
//      was working correctly: every case sat exactly where it had been put, which is what "no drift"
//      means. A log that compares a write against itself is a tautology with a threshold on it.
//      What it is now: every case is measured against something the placement did not choose --
//        * ITS OWN SAFE. The ring buildings' floors are flat at ASL ~16.8 and a case belongs 0.5-1.0 m
//          above one, so `case ASL - safe ASL` is the number that says whether the loot is in the
//          building. Under the old bug it read -2.76 at the deep end of the compound and +0.13 at the
//          shallow end; correct, it reads +0.57 to +1.02 for every case on the ring.
//        * THE TERRAIN under it, printed as the ATL equivalent. That is the frame the old code wrote
//          in, so seeing it next to the ASL makes the size of any future frame confusion obvious in one
//          line rather than requiring a player to stand there.
//      Both failure modes are still reported and they are now DISTINGUISHABLE, which is the whole point:
//      drift ~0 with a bad height means the placement frame is wrong; a large negative drift means the
//      freeze did not take and a PhysX suitcase fell. EACH GETS ITS OWN WARN and its own marker on the
//      line, so the log never makes the reader infer which fault it is looking at.
//      ---- WHY THE BAND IS 0.40 AND NOT 0.25 (tightened 2026-07-29, after review). Both numbers catch
//      every case in the probe, so this is not a correctness fix; it is a MARGIN fix. The probe pins
//      both ends of the interesting range:
//        * correct, post-fix: every one of the eleven sits +0.57 to +1.02 above its own safe.
//        * broken, as the owner found it: the two cases he called "on the floor" read +0.24 and +0.13.
//      A 0.25 bound therefore passes judgement on +0.24 by ONE CENTIMETRE. It is not wrong, it is
//      brittle -- it sits essentially ON a known-broken value, so any variation at all in the same
//      direction lets that exact fault through silently, and it leaves 0.32 m of slack under the true
//      minimum, enough for a case to sink a third of a metre and still read green.
//      0.40 sits near the middle of the gap the probe leaves open, (+0.24, +0.57), with deliberately
//      symmetric margins: 0.16 m of clearance above the worst broken value it must catch, 0.17 m of
//      clearance below the tightest correct one it must not trip. It roughly halves the blind spot at
//      the shallow end while keeping the false-positive margin an order of magnitude larger than the
//      only variation this placement actually has -- the waves. That is a real term, not a hedge:
//      buildingPos is AGL, AGL over sea is PositionASLW, and BIKI Position#PositionASLW is explicit
//      that "Z is measured from the surface of water at that position. Both waves and pond objects
//      affect the result." So AGLToASL resolves against the INSTANTANEOUS water surface and the
//      authored height carries a few centimetres of wave offset that differs from robbery to robbery,
//      while the safe it is measured against does not move at all. 0.17 m absorbs that many times over.
//      Do not tighten it to hug +0.57. The band is a sanity bound, not a spec -- the raw numbers print
//      either way, so a shifted reference cannot hide a real problem, and a bound that trips on weather
//      trains whoever reads this log to ignore it.
//      The UPPER bound is left at 3.00 on purpose: nothing in the probe speaks to how high is too high
//      (the observed maximum is +1.02), and inventing a tight ceiling from data that does not exist is
//      the mistake this comment block has already had to retract once.
//      Read in the SAME frame the placement wrote (setPosASL -> getPosASL). Reading ATL after an ASL
//      write would report a "drift" of the terrain depth on every case and be pure noise.
//      A case can legitimately be GONE by then (looted clean, or a reset landed), so the null case is
//      reported rather than counted. Deferred in its own thread: this function is called synchronously
//      from APS_fnc_maldenFedSRV case "domeOpen", which still has work to run after it returns.
[_placed] spawn {
    params ["_cases"];
    uiSleep 3;
    private _bad   = 0;
    private _moved = 0;
    {
        _x params ["_c", "_authored", "_ref"];
        if (isNull _c) then {
            diag_log format ["[maldenFed] fed gold settle %1: GONE -- looted clean or a reset landed, not drift", _forEachIndex];
        } else {
            private _p     = getPosASL _c;
            private _asl   = _p select 2;
            private _drift = _asl - (_authored select 2);
            private _terr  = getTerrainHeightASL _p;
            private _known = !isNull _ref;
            private _floor = if (_known) then { (getPosASL _ref) select 2 } else { 0 };
            private _above = _asl - _floor;
            private _wrong = _known && {_above < 0.4 || {_above > 3}};
            // The old 0.05 m drift gate, restored 2026-07-29 after review: the rebuild printed drift on
            // every line but counted only band failures, so a case that MOVED raised no warning at all
            // unless it also happened to leave the band. Those are two different faults with two
            // different causes and they need to stay separately alarmable -- a frozen case that moves
            // means the freeze failed, which is the exact thing 3bd494a was chasing, and it can happen
            // while the height still looks reasonable. Frozen and correctly placed, this reads 0.000:
            // the probe returned every case at exactly the number written to it, twice, minutes apart.
            private _slid = (abs _drift) > 0.05;
            if (_wrong) then { _bad   = _bad   + 1; };
            if (_slid)  then { _moved = _moved + 1; };
            diag_log format ["[maldenFed] fed gold settle %1: %2 m above its own safe | case %3 asl, safe %4 asl, terrain %5 asl (%6 atl) | %7 m from the height it was placed at%8%9",
                _forEachIndex,
                if (_known) then {_above toFixed 2} else {"?"},
                _asl toFixed 3,
                if (_known) then {_floor toFixed 2} else {"?"},
                _terr toFixed 2,
                (_asl - _terr) toFixed 3,
                _drift toFixed 3,
                if (_wrong) then {"   <<< WRONG HEIGHT"} else {""},
                if (_slid) then {"   <<< MOVED"} else {""}];
        };
    } forEach _cases;
    if (_moved > 0) then {
        diag_log format ["[maldenFed] WARN %1 of %2 fed gold case(s) MOVED after placement -- more than 0.05 m from the height they were written to, marked <<< MOVED on their line. This is the FREEZE fault, not the frame fault: Land_Suitcase_F inherits ThingX and is a live PhysX body, so a case that shifts means the enableSimulationGlobal false above did not take and it is falling, being shoved, or resting on something that is not where it was put. It is reported separately from WRONG HEIGHT on purpose -- a case can move without leaving the height band, and a case can be at the wrong height without ever having moved (that one is the placement frame, see the other WARN). If BOTH fire on the same line, the case was placed wrong AND did not stay there.",
            _moved, count _cases];
    };
    if (_bad > 0) then {
        diag_log format ["[maldenFed] WARN %1 of %2 fed gold case(s) are at the WRONG HEIGHT -- outside 0.40 to 3.00 m above their own safe's origin, i.e. under the floor they belong on or floating above it. READ THAT AGAINST THE LAST NUMBER ON EACH LINE. If a case is ~0.000 m from the height it was placed at, it is sitting exactly where this function PUT it and the placement FRAME is what is wrong -- that is the 2026-07-29 bug, a PositionAGL from buildingPos handed to setPosATL, which sank every case by the depth of the seabed under this compound (-2.72 m at the deep end, and the two nearest the waterline landed flat on the floor at +0.24 and +0.13, which is why this band stops at 0.40 rather than hugging the correct 0.57-1.02). If instead the line also carries <<< MOVED, the case did not stay where it was put and the separate MOVED warning above explains that fault -- it is the freeze, not the frame. The ten ring safes ARE server-created (mission.sqm, _serverObject), so a case at one of their buildingPos has a real floor under it on this machine; the mining component is the only one that can legitimately be jittered off that plate onto deck that exists on clients only. Either way the server owns these objects, so wherever they are replicates to every client.",
            _bad, count _cases];
    };
};
diag_log format ["[LooneyBin][fed] spawned %1 gold case(s) for dome at %2", _spawned, getPosATL _dome];
["-FED-", objNull, format ["gold spawned: %1 case(s) at dome %2", _spawned, getPosATL _dome]] call APS_fnc_logIt;
