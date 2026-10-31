/*
    APS_fnc_maldenFedSRV -- the Malden Federal Reserve heist, end to end.

    ONE AUTHORITY. Phase, both countdowns, the gold, the boat, the sweep and every reset live here.
    Clients REQUEST a transition and RENDER the result; they never own state. Each client-facing mode
    re-derives its caller from remoteExecutedOwner and re-checks identity, distance and phase, because
    the CfgRE whitelist makes this callable by any client with any arguments (model: fn_fedRadarSRV,
    fn_chopShopSell).

    The server-internal modes are guarded differently. Refusing a non-zero remoteExecutedOwner would
    only work if a spawned child does NOT inherit its parent's value, and the BIKI does not say either
    way -- it documents the value as holding "in this scope" and is silent on child scripts. Every
    internal call here is made from inside a spawn, so if that assumption is wrong the mode refuses
    ITSELF and the doors silently never open. Instead they take AP_fedInternalKey, generated at boot
    and kept in localNamespace: a client can neither read it nor overwrite it. (It was a missionNamespace
    global until audit r2heist -- unread by clients, but one publicVariable of it SET the key.)

    SRV_maldenFed is the same: the server's copy lives in localNamespace and every gate here reads that;
    the global is the display copy _fnc_setState publishes for the client actions (audit r2heist).

    WHERE THE ANCHORS COME FROM (corrected 2026-07-29 -- this paragraph used to say the dome and the
    centre "belong to Malden's terrain", which the data does not support). The gates and the ten ring
    safes are mission.sqm entities in the Eden layer named FEDERAL RESERVE, each carrying
    init = "_serverObject =true;" and disableSimulation = 1. The dome (Land_Dome_Big_F) and the centre
    (Land_Medevac_HQ_V1_F) are fn_mapData rows promoted to _xIsServer = true, which initServer.sqf
    spawns through AP_fnc_createVehicleLocal. Every anchor here is therefore a REAL server-side
    object with a real class -- none of them is terrain -- and each is still resolved by proximity at
    boot and LOGGED (class, model, position, distance) so the RPT proves what was bound.

    THE PERIMETER IS FIVE GATES, NOT ONE, AND ONLY THREE OF THEM ARE OURS. The FEDERAL RESERVE layer
    holds three Land_ConcreteWall_01_l_gate_F (Eden ids 26449, 26452, 26440) and two
    Land_BackAlley_01_l_gate_F (25114, 25111). The three concrete ones are vehicle entrances through
    the compound wall -- each is flanked by Land_ConcreteWall_01_l_8m_F segments and a cobblestone
    square -- so all three are sealed and all three open together. The two back-alley ones are
    pedestrian fence gates on the pier approach; they have NO wall segments near them (their
    neighbours are Land_MultistoryBuilding_03_F and a fire escape) and they are deliberately left
    alone -- see the note in case "boot".

    AP_fedGate IS STILL ONE OBJECT. It is the gate the owner nominated at [11237.5, 4382.56] and it
    is the only breachable one: fn_setupActions offers "Breach Perimeter Gate" within 6 m of it,
    fn_openGate refuses beyond 6 m, and case "gate" anchors _fnc_caller on it at 8 m. The full list is
    the SEPARATE variable AP_fedGates, added rather than substituted precisely so that no existing
    reader of the scalar has to change -- `player distance AP_fedGate` inside a scroll-action
    condition string would throw on an array, and a throwing condition makes the action silently
    vanish instead of erroring.

    THE DOOR-KEY CASING WAS NEVER A BUG -- AND THE PARAGRAPH THAT USED TO SAY OTHERWISE HERE WAS WRONG.
    Corrected 2026-07-29. It asserted that "bis_disabled_Door_%1" is case-sensitive, that the lowercase
    spelling this file and APS_fnc_fedLockdown carried until 4633e92/3bd494a addressed a key the engine
    never read, and that reverting one of those commits alone would seal the Reserve forever or leave it
    permanently open. None of that holds. SQF variable names are CASE-INSENSITIVE -- BIKI Identifier:
    "Identifiers are case-insensitive"; BIKI allVariables documents its return value as "array of
    variable names. All names are in lower case (see toLower)", which is the variable store folding case
    on the way in. bis_disabled_door_1 and bis_disabled_Door_1 are the SAME variable, so the old spelling
    worked, the locks and unlocks in this file were always effective, and the two commits changed the
    text of these lines and nothing else. The capital D is retained only because it matches the engine's
    own documented spelling in BIS_fnc_Door and the other 25 write sites in this build; either spelling
    is correct and neither is load-bearing.

    WHAT ACTUALLY BROKE THE GATES, since the wrong story above stood in its place: the owner reported
    "both gates are unlocked and can be manually opened when no fed is in place", and the cause was
    resolution, not casing. Case "boot" used to search a 15 m nearestObjects bubble around the breach
    anchor, and two of the compound's three Land_ConcreteWall_01_l_gate_F sit 65.27 m and 70.16 m out
    (Eden ids 26452 and 26440), so they were never resolved, never published and never sealed by
    anything in the build. e7e7c01 widened the resolver to the compound and published AP_fedGates; the
    paragraph above this one records the resulting shape.

    MODES
      ["boot"]            server-internal: resolve anchors, lock down, start the sweep
      ["gate"]            client: perimeter gate breached  (phase 0 -> 1)
      ["dome"]            client: dome terminal breached   (phase 1 -> 2, 10:00)
      ["safe", _obj]      client: one of the ten ring safes cracked open (phase >= 2)
      ["alamo"]           client: centre terminal breached (alamo 0 -> 1, 20:00)
      ["secure"]          cop:    force the reset when the compound is already empty
      ["domeOpen", _key]  server-internal: the 10:00 timer expired -- throw the dome open (phase 2 -> 3)
      ["alamoOpen", _key] server-internal: the 20:00 timer expired -- throw the centre open (alamo 1 -> 2)
      ["boat", _key]      server-internal: alamoOpen delivers the getaway boat and hands out its keys
      ["reset", _key, _reason]  server-internal: the ONE ending -- re-lock, bin the loot, HIGH SECURITY

    The reason is the THIRD argument, not the second. Slot 2 is the internal key in every server-internal
    mode here, and the reset is keyed for exactly the reasons domeOpen, alamoOpen and boat are, so the
    human-readable reason had to move out of its way rather than take its place.
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]], ["_arg", "", ["", objNull, 0]], ["_reason", "unspecified", [""]]];
if (_mode isEqualTo "safe") then { if (!isNil "AP_fnc_telemetryEvent") then { ["robbery_fed"] call AP_fnc_telemetryEvent; }; };   // telemetry event counter

AP_FED_CENTRE  = [11197.8, 4459.3];
AP_FED_BOATPOS = [11153.3, 4534.19];
// ---- THE DOME TERMINAL IS A COORDINATE, NOT THE DOME. The brief put it "at the door of the side
//      dome ... at [11218.9, 4471.06, 18.16]", and that spot is 24 m from the dome's own model
//      centre. Anchoring the breach on AP_fedDome therefore put the action 24 m from the only place
//      the owner was ever told to stand, and it simply never appeared -- his own DOMEDIAG at the
//      terminal read distDome=26.28 against a 12 m offer bound, with every other clause passing.
//      There is no object at the terminal to bind to (the dome is one big terrain-side structure and
//      the cursor lands on the ground, the same trap the perimeter gate fell into), so the bare
//      coordinate IS the anchor.
//      Assigned HERE and not inside case "boot", exactly as the two above are: these lines re-run on
//      every call to this file, so case "dome" can never evaluate `distance` against an undefined
//      variable -- which halts the calling thread -- in the boot-was-refused state.
AP_FED_TERMPOS = [11218.9, 4471.06, 18.16];
private _gatePos = [11237.5, 4382.56];
private _domePos = [11197.993, 4459.207, 18.803]; // Land_Dome_Big_F
private _ctrPos  = [11196.290, 4457.902, 18.449]; // Land_Medevac_HQ_V1_F
private _safePos = [
    [11219.5, 4460.22, 18.02], [11219.7, 4453.85, 17.51], [11216.9, 4447.24, 17.15],
    [11186.5, 4438.64, 17.66], [11180.4, 4443.68, 18.54], [11177.5, 4449.53, 19.33],
    [11174.6, 4456.98, 19.14], [11195.7, 4480.83, 21.32], [11202.8, 4480.58, 20.93],
    [11209.5, 4477.60, 20.08]
];

// ---- describe one object for the log: class, model, distance. Terrain objects report an empty
//      typeOf, which is exactly why the model name is logged next to it.
private _fnc_describe = {
    params ["_obj", "_from"];
    if (isNull _obj) exitWith { "NULL" };
    format ["%1 (model %2) at %3, %4 m",
        typeOf _obj,
        (getModelInfo _obj) param [0, "?"],
        getPosATL _obj,
        ((getPosATL _obj) distance _from) toFixed 1];
};

// ---- the ONLY writer of SRV_maldenFed. -1 in any slot means "leave that one alone".
//      AP_fed_robbed is kept in lockstep as a compatibility shim: the evidence-bomb fuse, the cop
//      actions and several client conditions still read it, and none of them need to learn a new name.
private _fnc_setState = {
    params ["_p", "_pEnd", "_a", "_aEnd", "_lock"];
    // Start from the SERVER-PRIVATE copy: starting from the published global would absorb a client's
    // publicVariable of it into the real state on the next write (audit r2heist).
    private _s = localNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
    if (_p    isNotEqualTo -1) then { _s set [0, _p]; };
    if (_pEnd isNotEqualTo -1) then { _s set [1, _pEnd]; };
    if (_a    isNotEqualTo -1) then { _s set [2, _a]; };
    if (_aEnd isNotEqualTo -1) then { _s set [3, _aEnd]; };
    if (_lock isNotEqualTo -1) then { _s set [4, _lock]; };
    localNamespace setVariable ["SRV_maldenFed", _s];
    SRV_maldenFed = +_s;   // display copy only; nothing on the server reads it back
    publicVariable "SRV_maldenFed";
    AP_fed_robbed = [((_s select 0) > 0), serverTime];
    publicVariable "AP_fed_robbed";
    diag_log format ["[maldenFed] state %1", _s];
    _s
};

// ---- open every door-ish animation on an object and re-enable its door actions. Deliberately NOT
//      "animate everything to 1": a terrain structure has animation sources that are not doors, and the
//      Altis vault code learned this the hard way.
private _fnc_throwOpen = {
    params ["_obj"];
    if (isNull _obj) exitWith {};
    private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _obj) >> "numberOfDoors");
    // CAPITAL D, matching APS_fnc_fedLockdown's seal and the engine's own spelling -- and NOT because
    // the casing matters. Corrected 2026-07-29: the note that stood here said this line "must spell the
    // key the way the engine does, or the seal stays on and the dome and the centre never open". It
    // does not. SQF variable names are case-insensitive (BIKI Identifier; BIKI allVariables returns
    // every name in lower case), so the lowercase spelling this carried until 3bd494a wrote the SAME
    // variable and unlocked the dome and the centre exactly as it does now. Consistency with the seal
    // is the only reason to spell it either way.
    for "_i" from 1 to _n do { _obj setVariable [format ["bis_disabled_Door_%1", _i], 0, true]; };
    _obj setVariable ["AP_vaultlocked", 0, true];
    { _obj animate [_x, 1, true]; } forEach ((animationNames _obj) select {
        private _a = toLower _x;
        ((_a find "door") >= 0) && {(_a find "locked") isEqualTo -1}
    });
};

// ---- who really called this. 0 = the server itself (trusted). Anything else must resolve to a live,
//      un-restrained civilian ON FOOT standing at the anchor they claim -- the whitelist means the
//      arguments themselves prove nothing.
//
//      READ THIS BEFORE WRITING A NEW MODE. It returns [_ok, _caller] and BOTH halves matter, because
//      objNull comes back for TWO UNRELATED reasons:
//        * [true,  objNull] -- a trusted server-internal call (remoteExecutedOwner is 0): approved,
//                              but there is no player object to hand back
//        * [true,  <unit>]  -- a client call that passed every check below
//        * [false, objNull] -- a client call that was REJECTED
//      So a mode MUST destructure both, and MUST NEVER write `if (isNull _caller) exitWith {}` -- that
//      reads as a security check but actually refuses the server's own internal calls, and the doors
//      then silently never open. The shape is:
//          ([AP_fedGate, 8] call _fnc_caller) params ["_ok", "_caller"];
//          if (!_ok) exitWith {};
//
//      This used to be signalled through a GLOBAL out-parameter, AP_fedReject, written by this helper
//      and read by the mode on the NEXT line. That was a race, not a discriminator: AP_fnc_MP uses
//      remoteExec, not remoteExecCall, so every client request runs this file in the SCHEDULED
//      environment and can be suspended between those two lines. Two overlapping requests were enough
//      -- a rejected caller set the flag, an accepted caller cleared it, and the rejected one resumed
//      to find false and carried on with objNull. For "gate" that meant opening the gate and advancing
//      the phase with a null unit passed to the alarm, which then exited on its own null check: the
//      whole heist, unopposed, reachable from anywhere on the map by a modified client. A return value
//      is local to the call, so there is nothing left to race and the global is gone.
//
//      The vehicle check lives here rather than in each mode so that every mode inherits it, the ones
//      below and the ones still to come: fn_openGate / fn_openVault refuse from inside a vehicle
//      client-side, and a forged call parked at the anchor has to hit the same wall.
private _fnc_caller = {
    params ["_anchor", "_maxDist"];
    private _src = remoteExecutedOwner;
    if (_src isEqualTo 0) exitWith { [true, objNull] };               // server-internal: no check, no caller
    private _c = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _c
        || {!alive _c}
        || {side _c isNotEqualTo civilian}
        || {_c getVariable ["AP_restrained", false]}
        || {!(isNull objectParent _c)}
        || {(_c distance _anchor) > _maxDist}) exitWith {
        ["-SEC-", _c, format ["BLOCKED maldenFedSRV (dist %1) by %2",
            if (isNull _c) then {-1} else {round (_c distance _anchor)},
            if (isNull _c) then {"?"} else {getPlayerUID _c}]] call APS_fnc_logIt;
        [false, objNull]
    };
    [true, _c]
};

switch (toLower _mode) do {

    case "boot": {
        // SERVER-ONLY SENTINEL -- DO NOT REMOVE AS REDUNDANT.
        // The CfgRE whitelist entry for this function is allowedTargets = 2 with no argument
        // restriction, so EVERY mode here is reachable by any client with any arguments. boot resets
        // the state to phase 0 and re-locks the compound, so without this a player could spam ["boot"]
        // from anywhere on the map and force an in-progress robbery back to the start on demand.
        // The `if (!isServer) exitWith` at the top of the file does NOT close that: it guards the code
        // path, not the caller -- a client's remoteExec targeted at the server RUNS on the server, so
        // that check passes. AP_fedInternalKey cannot guard it either, because boot is what GENERATES
        // the key. So init.sqf sets AP_fedBootAllowed on the line immediately before its own call, in
        // localNamespace: a client CAN assign into the server's missionNamespace (publicVariable /
        // publicVariableServer), which is how this sentinel was forgeable as a global (audit r2heist).
        // There is no race window either, because the sentinel does not exist until the server itself is about to boot.
        if !(localNamespace getVariable ["AP_fedBootAllowed", false]) exitWith {
            diag_log "[maldenFed] boot refused -- not invoked by the server's own startup"; };
        localNamespace setVariable ["AP_fedBootAllowed", nil];   // one-shot: consumed, so a replay cannot re-run boot

        // ---- RESOLVE THE WHOLE PERIMETER, NOT A BUBBLE ROUND ONE GATE.
        //      This used to be nearestObjects [_gatePos, ["Land_ConcreteWall_01_l_gate_F"], 15] -- a 15 m
        //      radius on the owner's breach anchor. The compound has THREE gates of that class and the
        //      other two sit 65.27 m and 70.16 m from that anchor, so they were never resolved, never
        //      published and never sealed: nothing in the build had ever written a lock variable to them,
        //      and they stayed hand-openable through every phase of every robbery. That is the owner's
        //      report -- "both gates are unlocked and can be manually opened when no fed is in place".
        //      The Altis original this was ported from had AP_fed_gates = three objects; the Malden
        //      port collapsed it to one, and Malden genuinely has three.
        //
        //      Search from the COMPOUND CENTRE, which is what the thing being sealed actually is. The
        //      search is a 250 m sphere filtered to 150 m in 2D rather than a bare 150 m nearestObjects:
        //      the compound stands on a raised composition, so a 3D radius measured from a z of 0 would
        //      have to absorb the deck height as well, and the 2D filter is the bound that is actually
        //      meant. It cannot over-collect: the nearest Land_ConcreteWall_01_l_gate_F outside this
        //      compound is Eden id 29485, 1507 m away, so 150 m is unambiguous by a factor of ten.
        private _ctr3 = [AP_FED_CENTRE select 0, AP_FED_CENTRE select 1, 0];
        AP_fedGates = (nearestObjects [_ctr3, ["Land_ConcreteWall_01_l_gate_F"], 250])
            select { (_x distance2D AP_FED_CENTRE) < 150 };

        // The ANCHOR is whichever of them is nearest the coordinate the owner nominated, and it stays a
        // single object under its old name -- the client's breach path binds to AP_fedGate and must not
        // learn a new shape. In the shipped sqm that is Eden id 26449 at 2.10 m; the runners-up are at
        // 65.27 m and 70.16 m, so the pick is not close.
        private _anchorD = 1e9;
        AP_fedGate = objNull;
        {
            private _d = _x distance2D _gatePos;
            if (_d < _anchorD) then { _anchorD = _d; AP_fedGate = _x; };
        } forEach AP_fedGates;

        // ---- PROVE IT IN THE LOG rather than asserting a count. One line per gate: class, model,
        //      position, and how far it is from the breach anchor, plus which one IS the anchor.
        {
            diag_log format ["[maldenFed] anchor GATE %1/%2 [%3] = %4 -- %5 m from the breach anchor %6",
                _forEachIndex + 1, count AP_fedGates,
                if (_x isEqualTo AP_fedGate) then {"ANCHOR   "} else {"perimeter"},
                [_x, _gatePos] call _fnc_describe,
                (_x distance2D _gatePos) toFixed 2,
                _gatePos];
        } forEach AP_fedGates;
        if (AP_fedGates isEqualTo []) then {
            diag_log format ["[maldenFed] WARN no Land_ConcreteWall_01_l_gate_F within 150 m of %1 -- the perimeter cannot be sealed and the breach action has nothing to anchor on", AP_FED_CENTRE];
        };
        if (AP_fedGates isNotEqualTo [] && {_anchorD > 15}) then {
            diag_log format ["[maldenFed] WARN the nearest perimeter gate to the owner's breach anchor %1 is %2 m away (expected ~2 m) -- AP_fedGate may have bound the wrong gate and the scroll action will be offered in the wrong place",
                _gatePos, _anchorD toFixed 2];
        };

        // ---- THE TWO PEDESTRIAN GATES ARE DELIBERATELY NOT SEALED, and the log says so rather than
        //      leaving the next person to wonder whether they were missed a second time.
        //      Land_BackAlley_01_l_gate_F 25114 and 25111 sit 133.8 m and 156.6 m from the breach anchor
        //      on the west/pier approach toward the getaway boat. Three reasons they stay open:
        //        * They are not perimeter. Every concrete gate has Land_ConcreteWall_01_l_8m_F segments
        //          within 14 m; neither of these has a single one. Their neighbours are
        //          Land_MultistoryBuilding_03_F, a fire escape and a shoot-house wall -- they are gates
        //          in a back-alley fence against a building, not holes in the compound wall.
        //        * Sealing them would be PERMANENT. The seal is applied by every lockdown and released
        //          only by case "gate", which opens what it breached; a gate that is never breached is
        //          never released, so these two would be welded shut for the life of the server on a
        //          public pier route that cops, medics and fishermen use.
        //        * It would buy nothing. Walking through them does not advance the phase, open the dome
        //          or spawn a bar; and anyone inside them is already inside the 200 m the empty-compound
        //          sweep measures, so the heist keeps running either way.
        {
            diag_log format ["[maldenFed] gate NOT SEALED (pedestrian, deliberate) = %1 -- %2 m from the breach anchor",
                [_x, _gatePos] call _fnc_describe, (_x distance2D _gatePos) toFixed 2];
        } forEach ((nearestObjects [_ctr3, ["Land_BackAlley_01_l_gate_F"], 250])
            select { (_x distance2D AP_FED_CENTRE) < 150 });

        // The dome and the centre are fn_mapData objects, promoted to isServer = true so the server
        // spawns them for real (see the commit). Both are known classes at known positions now, so
        // this is an isKindOf match with a 25 m radius -- the next same-class object on this map
        // is ~1.7 km away, so the match is unambiguous. A NULL here means the promotion did not
        // take, which is exactly what the log needs to say.
        AP_fedDome   = (nearestObjects [_domePos, ["Land_Dome_Big_F"], 25]) param [0, objNull];
        AP_fedCentre = (nearestObjects [_ctrPos, ["Land_Medevac_HQ_V1_F"], 25]) param [0, objNull];
        diag_log format ["[maldenFed] anchor DOME   = %1", [AP_fedDome, _domePos] call _fnc_describe];
        diag_log format ["[maldenFed] anchor CENTRE = %1", [AP_fedCentre, _ctrPos] call _fnc_describe];
        // No _fnc_describe for this one -- it is a bare coordinate, not an object, so there is no
        // class or model to report. What matters in the log is that it is NOT the dome, and by how far.
        diag_log format ["[maldenFed] anchor TERM   = %1 (bare coordinate -- the dome terminal, %2 m from the dome centre)",
            AP_FED_TERMPOS, (AP_FED_TERMPOS distance _domePos) toFixed 1];

        // The ten safes: one Land_Medevac_house_V1_F per owner coordinate. Log the match distance and
        // whether the building reports interior positions -- a safe with none would drop its briefcase
        // at the owner's coordinate, ~3 m OUTSIDE its own door, i.e. lootable without breaching.
        AP_fedSafes = [];
        {
            private _cands = nearestObjects [_x, ["Land_Medevac_house_V1_F"], 12];
            private _s = _cands param [0, objNull];
            if (isNull _s) then {
                diag_log format ["[maldenFed] anchor SAFE %1 = NULL -- no medevac house within 12 m of %2", _forEachIndex, _x];
            } else {
                if !(_s in AP_fedSafes) then { AP_fedSafes pushBack _s; };
                // A swap does not show up as a LARGE distance -- once a coordinate crosses the midpoint
                // between two of these buildings the wrong one becomes the nearest, and the reported
                // distance SHRINKS. The real signature of an ambiguous match is a small gap between the
                // best and second-best candidate, so that is what is checked. Worst real margin: 2.26 m.
                if ((count _cands) > 1) then {
                    private _m = ((getPosATL (_cands select 1)) distance _x) - ((getPosATL _s) distance _x);
                    if (_m < 1.5) then {
                        diag_log format ["[maldenFed] WARN safe %1 is ambiguous -- nearest and second-nearest differ by only %2 m; it may have bound the neighbouring building", _forEachIndex, _m toFixed 2];
                    };
                };
                diag_log format ["[maldenFed] anchor SAFE %1 = %2, buildingPos %3",
                    _forEachIndex, [_s, _x] call _fnc_describe, count (_s buildingPos -1)];
            };
        } forEach _safePos;

        [0, -1, 0, -1, -1] call _fnc_setState;
        [] call APS_fnc_fedLockdown;

        // ---- THE FAILURE CONDITION. Two consecutive empty sweeps, 30 s apart, end the heist. One is
        //      not enough: a wipe or a thirty-second retreat to the treeline would otherwise close a
        //      job the crew is still fighting for.
        //      The key is read with getVariable rather than named bare (every call site does now, since
        //      the key moved to localNamespace). This is a while{true} loop that has to survive the
        //      whole session, and an undefined variable in an expression HALTS the thread that evaluates
        //      it (the same failure that killed fn_fedAlarm's own loop on `position fed_alarm`). If this
        //      thread dies there is no ending at all: the siren runs until the next restart. A "" key is
        //      refused loudly by the reset instead.
        [] spawn {
            private _empty = 0;
            while { true } do {
                uiSleep 30;
                private _phase = (localNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0];
                if (_phase isEqualTo 0) then { _empty = 0; } else {
                    private _inside = {
                        (side _x isEqualTo civilian)
                        && {alive _x}
                        && {isPlayer _x}
                        && {!(_x getVariable ["AP_restrained", false])}
                        && {(_x distance AP_FED_CENTRE) < 200}
                    } count allPlayers;
                    if (_inside isEqualTo 0) then {
                        _empty = _empty + 1;
                        diag_log format ["[maldenFed] compound empty (%1/2)", _empty];
                        if (_empty >= 2) then { _empty = 0;
                            private _k = localNamespace getVariable ["AP_fedInternalKey", ""];
                            ["reset", _k, "compound empty"] call APS_fnc_maldenFedSRV; };
                    } else { _empty = 0; };
                };
            };
        };

        // The pass the server's own timers hand back to the internal modes. It is generated here and
        // is deliberately ABSENT from the publish list immediately below -- that omission IS the
        // security property, so do not "fix" it by adding it. localNamespace, so no client can SET it
        // either; two full-digit randoms, because str of one printed only six significant figures.
        localNamespace setVariable ["AP_fedInternalKey", ((random 1e9) toFixed 0) + ((random 1e9) toFixed 0)];

        // AP_fedGates is published alongside AP_fedGate because initPlayerLocal builds AP_fed_gates
        // from it. It is a list of objects, so it replicates the same way AP_fedSafes already does.
        { publicVariable _x; } forEach ["AP_fedGate", "AP_fedGates", "AP_fedDome", "AP_fedCentre",
                                        "AP_fedSafes", "AP_FED_CENTRE", "AP_FED_BOATPOS", "AP_FED_TERMPOS"];
        diag_log format ["[maldenFed] boot complete -- %1 perimeter gate(s) (anchor bound: %2), dome %3, centre %4, %5 safe(s)",
            count AP_fedGates, !isNull AP_fedGate, !isNull AP_fedDome, !isNull AP_fedCentre, count AP_fedSafes];
    };

    case "gate": {
        ([AP_fedGate, 8] call _fnc_caller) params ["_ok", "_caller"];
        if (!_ok) exitWith {};
        private _s = localNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        if ((_s param [0, 0]) isNotEqualTo 0) exitWith {};
        if ((_s param [4, -1]) > serverTime) exitWith {};
        if (["fed"] call APS_fnc_fedEventActive) exitWith {};

        // ---- SCRUB A STALE AP_bank_inProgress BEFORE ASKING THE ALARM. The veto the alarm gained
        //      (see the block below) refuses outright on that flag, and NOTHING clears it at phase 0:
        //      case "reset" is its only clearer, the reset exits early when the phase is already 0, and
        //      the sweep only calls the reset when the phase is NON-zero. So a flag left true at phase 0
        //      is permanent -- the alarm returns false, the veto leaves the gate sealed, the phase never
        //      moves off 0, and the reset that would have cleared it is therefore unreachable. Every
        //      breach for the rest of the session is refused, and only !srv resetfed or a restart gets
        //      the event back.
        //      It is reachable from a client: APS_fnc_fedRobbery is a bare passthrough into the alarm
        //      and CfgRE whitelists it at allowedTargets = 2 with no phase, caller or distance check, so
        //      a single call sets this flag, mints a dispatch, starts the siren, drops the map marker
        //      and leaves the wanted-charge recruitment loop running for the rest of the session.
        //      Clearing it here is safe precisely BECAUSE of the three lines above: they have proved the
        //      phase is 0 and that no other federal event is live, and APS_fnc_fedAlarm is the only thing
        //      in the build that ever sets this flag true (the bank drill uses AP_bank_robbed, which
        //      fedEventActive checks). A true flag at this point is therefore stale by definition, and
        //      clearing it cannot cut short a robbery that is actually running.
        if (AP_bank_inProgress) then { AP_bank_inProgress = false; publicVariable "AP_bank_inProgress";
            diag_log "[maldenFed] cleared a stale AP_bank_inProgress before the alarm (phase 0, no other event)"; };

        // ---- THE ALARM COMMITS FIRST. It used to be called AFTER the gate was thrown open and the
        //      phase advanced, and APS_fnc_fedAlarm has refusals of its own that run before it commits
        //      anything: a null unit, a robbery already in progress, another federal event, and the
        //      tenured-cop threshold. That last one is 0 for Malden testing and TODO.md tells the owner
        //      to put it back to 6 at public launch -- and the moment he does, breaching this gate with
        //      5 cops online opened the gate and advanced to phase 1 with NO alarm, no dispatch, no map
        //      marker, no robber recruitment and no wanted charges. The crew walked the whole heist
        //      unopposed and the only way out was the empty-compound sweep. So the order is inverted:
        //      the alarm now returns whether it actually engaged, and if it declines, the gate stays
        //      shut and the phase stays at 0. Its own refusals already message the player for the two
        //      that are the player's business (cops, another event); the refusal below covers the two
        //      that are not, so the breach can never fail silently.
        if !([_caller] call APS_fnc_fedAlarm) exitWith {
            diag_log "[maldenFed] gate breach ABORTED -- the alarm declined to engage, gate left sealed";
            if (!isNull _caller) then {
                [[2, "The Reserve's alarm system did not engage -- the breach is called off."],
                    "AP_fnc_broadcast", _caller, false] spawn AP_fnc_MP; };
        };

        // ---- ONE BREACH OPENS THE WHOLE PERIMETER, not just the gate that was cut.
        //      This is a decision, not a convenience, and the deciding argument is what the ALTERNATIVE
        //      does over time. The lockdown seals every gate in AP_fedGates; the ONLY release in the
        //      build is this block. So if this opened only the breached gate, the other two concrete
        //      gates would be sealed at the first boot and never opened again for the life of the
        //      server -- which destroys exactly the resting state the owner described ("can be manually
        //      opened when no fed is in place") and replaces one bug (never sealed) with a worse one
        //      (sealed forever). Opening the set keeps every gate on the same cycle the anchor is on:
        //      shut at boot and after every reset, open from phase 1, shut again when the reset lands.
        //      It also matches the shape of the rest of the event -- domeOpen and alamoOpen each throw
        //      a whole structure open on one transition -- and the Altis original acted on
        //      AP_fed_gates as a set for the same reason.
        //      BREACHABILITY IS UNCHANGED AND STAYS ON ONE GATE. fn_setupActions offers the action
        //      within 6 m of AP_fedGate only, fn_openGate refuses beyond 6 m of AP_fedGate, and
        //      _fnc_caller above anchored this call on AP_fedGate at 8 m. Nobody can start the event
        //      at gate 26452 or 26440; they simply roll back when the nominated one is cut.
        //
        //      BOTH animation sources per gate, not just the sound one: BIS_fnc_Door drives the pair
        //      together for this class, so opening one and sealing one is what leaves them split. The
        //      pair and the reason are documented at the matching block in APS_fnc_fedLockdown, which
        //      was read out of CfgVehicles >> Land_ConcreteWall_01_l_gate_F >> AnimationSources; same
        //      shape as APS_fnc_maldenBankSRV ["open"]. The locked source stays untouched, as it does
        //      there.
        //      _g IS NOT DECORATION. The inner forEach over the source names rebinds _x, so the gate
        //      has to be captured before it, or the animateSource lands on a string.
        private _opened = 0;
        {
            private _g = _x;
            if (!isNull _g) then {
                _g setVariable ["gate_max", 1, true];
                // ---- THE RELEASE DERIVES ITS DOOR COUNT THE WAY THE SEAL DOES (2026-07-29). This line
                //      used to hardcode index 1 while APS_fnc_fedLockdown's _fnc_seal shuts
                //      `for "_i" from 1 to numberOfDoors`. That asymmetry was safe only because every
                //      gate in the list is a Land_ConcreteWall_01_l_gate_F, which declares
                //      numberOfDoors = 1 -- a property of the class the list happens to hold, not of
                //      this code. It is now load-bearing across three gates instead of one, and the
                //      failure it invites is permanent: this block is the ONLY release anywhere in the
                //      build, so any door the seal shuts and this loop misses stays shut for the life of
                //      the server. Deriving the count here means the pair cannot drift if a gate class
                //      with more doors ever joins AP_fedGates.
                //      The two animation SOURCES below stay named because the seal names exactly the same
                //      pair; that half of the contract is already symmetric.
                //      `max 1` IS NOT PADDING -- it is what makes this the exact inverse of the seal.
                //      APS_fnc_fedLockdown shuts Door_1..numberOfDoors through _fnc_seal AND writes
                //      bis_disabled_Door_1 unconditionally in its own gate block, so the set it seals is
                //      Door_1..max(numberOfDoors, 1). getNumber returns 0 for a class that declares no
                //      numberOfDoors, and a bare `1 to _nd` would then release NOTHING while the seal had
                //      still welded Door_1 shut -- permanently, since this is the only release. Releasing
                //      max(_nd, 1) covers the seal exactly, whatever the class declares.
                private _nd = getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors");
                for "_i" from 1 to (_nd max 1) do { _g setVariable [format ["bis_disabled_Door_%1", _i], 0, true]; };
                _g setVariable ["AP_vaultlocked", 0, true];
                { _g animateSource [_x, 1]; } forEach ["door_1_sound_source", "door_1_noSound_source"];
                { _g animate [_x, 1, true]; } forEach (animationNames _g);
                _opened = _opened + 1;
            };
        } forEach (missionNamespace getVariable
            ["AP_fedGates", [missionNamespace getVariable ["AP_fedGate", objNull]]]);
        // ---- BOTH AP_fedGate READS HERE ARE GUARDED (2026-07-29). e7e7c01 introduced them bare, as
        //      `["AP_fedGates", [AP_fedGate]]` and `getPosATL AP_fedGate`. The outer getVariable
        //      protects AP_fedGates but NOT its default: SQF evaluates argument expressions eagerly, so
        //      the array literal [AP_fedGate] is constructed -- and raises on an undefined
        //      AP_fedGate -- before getVariable is ever entered. A guarded outer form does not make its
        //      own default lazy.
        //      Scoped honestly: neither read is the FIRST raise point in this mode. The _fnc_caller
        //      anchor at the top of case "gate" reads AP_fedGate bare, predates e7e7c01 (fbcd865), and
        //      halts a boot-never-ran thread before either of these is reached. These are consistency
        //      with the same treatment APS_fnc_fedLockdown's three anchors got in e7e7c01, not a fix for
        //      a halt that is reachable past line 371.
        diag_log format ["[maldenFed] perimeter breached -- %1 gate(s) thrown open (anchor %2)",
            _opened, getPosATL (missionNamespace getVariable ["AP_fedGate", objNull])];

        [1, -1, -1, -1, -1] call _fnc_setState;
        // The alarm has just re-created "robberyMarker" for THIS robbery, so any deletion still pending
        // from the previous reset no longer owns it. Bumping the generation here is what tells that
        // timer to stand down -- see the matching block in case "reset".
        AP_fedMarkerGen = (missionNamespace getVariable ["AP_fedMarkerGen", 0]) + 1;
        ["-FED-", _caller, "perimeter gate breached -- Malden Fed phase 1"] call APS_fnc_logIt;
    };

    case "dome": {
        // ANCHORED ON THE TERMINAL, NOT ON AP_fedDome -- see AP_FED_TERMPOS at the top of this file.
        // _fnc_caller takes the anchor as its first argument and only ever does `_c distance _anchor`,
        // and `distance` takes an Object or a Position on either side, so a bare coordinate is a
        // first-class anchor here. 10 m against the client's 8 m offer and fn_openVault's own 8 m
        // refusal: the looser outer bound, deliberately, for the same reason case "gate" is 8 against
        // the client's 6 -- it absorbs the round trip without ever refusing a caller who was offered
        // the action. AP_fedDome is still the object case "domeopen" throws open when the 10:00 runs
        // out; what moved is only WHERE the player has to be standing to start it.
        ([AP_FED_TERMPOS, 10] call _fnc_caller) params ["_ok", "_caller"];
        if (!_ok) exitWith {};
        private _s = localNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        if ((_s param [0, 0]) isNotEqualTo 1) exitWith {};

        private _ends = serverTime + 600;
        [2, _ends, -1, -1, -1] call _fnc_setState;
        ["-FED-", _caller, "dome terminal cracked -- 10:00 running"] call APS_fnc_logIt;

        // the top-right draining box, to everyone who can see the fight
        private _near = allPlayers select { (_x distance AP_FED_CENTRE) < 400 };
        ["RESERVE VAULT CYCLING -- 10 MINUTES", "fed_countdown",
            {((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isEqualTo 2}]
            remoteExec ["AP_fnc_handleMessage", _near];
        [[[0,1,2], "The Federal Reserve vault is cycling open. Ten minutes."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;

        [_ends] spawn {
            params ["_ends"];
            waitUntil { uiSleep 2;
                serverTime >= _ends
                || {((localNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isNotEqualTo 2} };
            if (((localNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isNotEqualTo 2) exitWith {
                diag_log "[maldenFed] 10:00 timer abandoned -- phase changed under it (reset)"; };
            ["domeOpen", localNamespace getVariable ["AP_fedInternalKey", ""]] call APS_fnc_maldenFedSRV;
        };
    };

    case "domeopen": {   // server-internal only -- reached from the timer above, and only with the key
        // The empty-key case has to be refused EXPLICITLY. If boot never ran the key was never generated,
        // the getVariable default is "" and _arg's own params default is "" too -- so a bare
        // ["domeOpen"] from anywhere would compare "" against "" and PASS, approving precisely the
        // broken state this guard exists to catch. No key means no open, full stop.
        private _key = localNamespace getVariable ["AP_fedInternalKey", ""];
        if (_key isEqualTo "" || {_arg isNotEqualTo _key}) exitWith {
            diag_log "[maldenFed] domeOpen refused -- missing internal key"; };
        // The timer's waitUntil polls every 2 s, so a reset landing inside that window is missed and
        // the post-wait phase re-check can still observe a stale 2. Re-check HERE, where the check and
        // the open are atomic, so this path is safe whatever the timer saw.
        if (((localNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isNotEqualTo 2) exitWith {
            diag_log "[maldenFed] domeOpen abandoned -- phase is no longer 2 (reset landed inside the poll window)"; };
        [AP_fedDome] call _fnc_throwOpen;
        [3, -1, -1, -1, -1] call _fnc_setState;
        // Called DIRECTLY, not through AP_fnc_MP: fn_fedGoldSpawn's security block reads
        // remoteExecutedOwner and treats 0 as "the server asked, trust it". Routing a server-side call
        // back through the MP layer would put a non-zero owner on it and trip its own proximity gate.
        [AP_fedDome] call APS_fnc_fedGoldSpawn;
        [[[0,1,2], "The Reserve vault is OPEN."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
        ["-FED-", objNull, "dome opened -- phase 3, gold spawning"] call APS_fnc_logIt;
    };

    case "safe": {
        // Client: one of the ten ring buildings cracked open -- the Sequence Breach or a demolition
        // charge, both from fn_openSafe, which now REQUESTS this instead of doing it.
        //
        // Until 2026-07-28 the client did it itself: it wrote AP_vaultlocked and the bis_disabled_door_N
        // flags with public = true and the server never heard about it, so a modified client could
        // unlock all ten from anywhere on the map. The briefcases spawn inside those buildings
        // unconditionally when the dome opens, so the safe-cracking layer was the only thing between
        // the crew and the gold -- this was the last client-authority hole left in the event.
        //
        // The lowercase "bis_disabled_door_N" named above is NOT a typo and was NOT inert -- correcting
        // a note added here on 2026-07-29 that called it both. SQF variable names are case-insensitive
        // (BIKI Identifier; BIKI allVariables returns every name in lower case), so the client was
        // writing the same variable the engine reads. BOTH halves of the old client write were live,
        // which makes the client-authority hole described above straightforwardly real: the doors WERE
        // locked, and a modified client genuinely unlocked them. That is why the decision moved here.
        //
        // MEMBERSHIP IS CHECKED FIRST, BEFORE _fnc_caller, and the order is load-bearing twice over.
        // _arg is an anchor the CALLER chose: handing it straight to the helper would prove only that
        // the caller is standing next to whatever it named, and `distance` against a String or a
        // Number (both of which this file's params accepts in that slot) is a type error the client
        // could throw on demand. AP_fedSafes holds exactly the ten buildings resolved at boot, so one
        // membership test settles both -- it is not a class test, and objNull and the non-object
        // defaults are not in the list either. The refusal logs objNull for the unit because the
        // caller is not resolved yet; APS_fnc_logIt still stamps @SRC= with the submitting machine's
        // UID, so the attempt stays attributable.
        private _safes = missionNamespace getVariable ["AP_fedSafes", []];
        private _safe  = _arg;
        if !(_safe in _safes) exitWith {
            ["-SEC-", objNull, format ["BLOCKED maldenFedSRV safe -- '%1' is not a Reserve safe", _safe]] call APS_fnc_logIt; };

        // Now the object is known to be ours it is safe to anchor on. 10 m from the building centre:
        // the client's own bound is 3 m from the nearest door selection, which fn_setupActions records
        // as inside 6 m of the centre, so this clears a legitimate caller with room for the round trip
        // and still refuses one who is not at the building.
        ([_safe, 10] call _fnc_caller) params ["_ok", "_caller"];
        if (!_ok) exitWith {};

        // NEAR THAT SAFE, not near A safe -- and the test is NEAREST, not a second radius. The ring
        // buildings sit 6.4 to 8 m apart, so the 10 m bound above clears a caller standing at a
        // NEIGHBOUR'S door just as readily as at this one, and no radius can separate them: that is why
        // the previous attempt here settled for "at least it was not sent from off-site". Ranking does
        // separate them, and exactly. Of the ten, one is closest; so if ANY other Reserve safe is nearer
        // to the caller than the one he named, he is not at the one he named. The two bounds together
        // are the proof: the outer one says he is AT a safe, this one says WHICH.
        //
        // It also drops this mode's last dependency on server-side LOD data. The test replaced here
        // walked `selectionNames`, which reads LOD 0 -- a VISUAL LOD a dedicated server has no reason to
        // load. Had that list come back empty, findIf would have returned -1 and NO safe would ever have
        // opened: a silent server refusal sitting behind a client that had already told the player the
        // doors were open. (A temporary probe in this file did log ["door_1"] for this class on this
        // server, so it was populated in practice -- but the mode no longer has to depend on that.)
        if ((_safes findIf { (_caller distance _x) < (_caller distance _safe) }) >= 0) exitWith {
            ["-SEC-", _caller, "BLOCKED maldenFedSRV safe -- a different Reserve safe is closer"] call APS_fnc_logIt;
            // AND TELL HIM. fn_openSafe grants the experience, bumps fedsafeopened and says "The safe
            // doors have been breached" purely on its own minigame result, so a refusal that returns
            // nothing reads in game as "it said it opened and it didn't" -- and the owner would spend a
            // test pass chasing it. Same mechanism case "secure" uses to talk to one player. Only THIS
            // refusal messages: the membership, phase and already-open refusals are all states the
            // client's own gates have already ruled out before it ever sends.
            [[2, "You are not at that safe -- stand at the one you are breaching."],
                "AP_fnc_broadcast", _caller, false] spawn AP_fnc_MP; };

        // The same gate the client checks: the safes open from the moment the vault starts cycling, so
        // the ten-minute countdown is prep time. Anything below phase 2 is sealed.
        if (((localNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) < 2) exitWith {
            diag_log "[maldenFed] safe breach refused -- the vault is not cycling yet (phase < 2)"; };
        // Already open is not an attack -- two crew members can finish against the same building. Refuse
        // quietly rather than logging a second breach for a door that is already hanging open.
        if ((_safe getVariable ["AP_vaultlocked", 1]) isEqualTo 0) exitWith {};

        // The unlock, exactly as the client used to write it -- same two variables, same public = true.
        // The door flags re-enable the vanilla door actions; AP_vaultlocked is what every scroll
        // condition and fn_openSafe itself read. Deliberately NOT _fnc_throwOpen: that animates, and the
        // demolition route plays its own door animation client-side while the Sequence Breach never had
        // one. What moved here is the decision, not the presentation.
        //
        // CAPITAL D, matching the seal in APS_fnc_fedLockdown and the engine's own spelling. Corrected
        // 2026-07-29: the note here claimed fn_openSafe's inherited lowercase key meant "the safes were
        // never actually locked and this unlock never actually unlocked anything". False -- SQF variable
        // names are case-insensitive (BIKI Identifier; BIKI allVariables returns every name in lower
        // case), so both spellings address the same variable and both the seal and this unlock have
        // always worked. "Exactly as the client used to write it" is true of the casing too; it simply
        // never mattered. Land_Medevac_house_V1_F reports numberOfDoors = 1, so this loop writes
        // bis_disabled_Door_1 for the one safe named.
        private _doors = getNumber (configFile >> "CfgVehicles" >> (typeOf _safe) >> "numberOfDoors");
        for "_i" from 1 to _doors do { _safe setVariable [format ["bis_disabled_Door_%1", _i], 0, true]; };
        _safe setVariable ["AP_vaultlocked", 0, true];

        private _open = { (_x getVariable ["AP_vaultlocked", 1]) isEqualTo 0 } count _safes;
        ["-FED-", _caller, format ["Reserve safe %1 cracked -- %2 of %3 open",
            _safes find _safe, _open, count _safes]] call APS_fnc_logIt;
    };

    case "alamo": {
        ([AP_fedCentre, 15] call _fnc_caller) params ["_ok", "_caller"];
        if (!_ok) exitWith {};
        private _s = localNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        if ((_s param [0, 0]) isNotEqualTo 3) exitWith {};
        if ((_s param [2, 0]) isNotEqualTo 0) exitWith {};

        private _ends = serverTime + 1200;
        [-1, -1, 1, _ends, -1] call _fnc_setState;
        ["-FED-", _caller, "ALAMO started -- 20:00 running"] call APS_fnc_logIt;

        // A SECOND draining box, amber, so it is visibly not the dome's. By now the first one is gone:
        // it clears itself when the phase leaves 2, and this mode cannot run before phase 3.
        private _near = allPlayers select { (_x distance AP_FED_CENTRE) < 400 };
        ["ALAMO FED -- 20 MINUTES", "alamo_countdown",
            {((missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isEqualTo 1}]
            remoteExec ["AP_fnc_handleMessage", _near];
        [[[0,1,2], "An ALAMO FED has been started at the Reserve. Twenty minutes."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;

        [_ends] spawn {
            params ["_ends"];
            waitUntil { uiSleep 2;
                serverTime >= _ends
                || {((localNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isNotEqualTo 1} };
            if (((localNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isNotEqualTo 1) exitWith {
                diag_log "[maldenFed] 20:00 Alamo timer abandoned -- state changed under it (reset)"; };
            ["alamoOpen", localNamespace getVariable ["AP_fedInternalKey", ""]] call APS_fnc_maldenFedSRV;
        };
    };

    case "alamoopen": {   // server-internal only -- reached from the timer above, and only with the key
        // Keyed for the same reason domeOpen is: this transition is made from inside a spawn, and
        // whether a spawned child inherits its parent's remoteExecutedOwner is undocumented, so a
        // caller-identity guard could refuse the server's own timer and the doors would never open.
        // The empty key still has to be refused EXPLICITLY -- if boot never ran the key was never
        // generated, the getVariable default is "" and _arg's own params default is "" too, so a bare
        // ["alamoOpen"] from anywhere would compare "" against "" and PASS. No key means no open.
        private _key = localNamespace getVariable ["AP_fedInternalKey", ""];
        if (_key isEqualTo "" || {_arg isNotEqualTo _key}) exitWith {
            diag_log "[maldenFed] alamoOpen refused -- missing internal key"; };
        // The timer's waitUntil polls every 2 s, so a reset landing inside that window is missed and
        // the post-wait re-check can still observe a stale 1. Re-check HERE, where the check and the
        // open are atomic, so this path is safe whatever the timer saw.
        if (((localNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isNotEqualTo 1) exitWith {
            diag_log "[maldenFed] alamoOpen abandoned -- alamo is no longer 1 (reset landed inside the poll window)"; };
        [AP_fedCentre] call _fnc_throwOpen;
        [-1, -1, 2, -1, -1] call _fnc_setState;

        // Ten bars, as FIVE cases of two, so the crew shares instead of one player taking the lot.
        // ---- AGL -> ASL ONCE, HERE, BEFORE THE FIVE CASES ARE SPREAD ALONG X (2026-07-29). buildingPos
        //      returns a PositionAGL; the placement below writes ASL. Converting at THIS point and not
        //      inside the loop is deliberate: AGLToASL resolves against the terrain column under the
        //      position it is handed, so converting each case's own spread position would sample five
        //      different columns of seabed and rake the row across a floor that is actually flat. One
        //      conversion at the anchor, then a pure XY spread off it, keeps all five level.
        //      ---- THE FALLBACK WAS NOT THE SAME BUG. RETRACTED 2026-07-29, same day it was written.
        //      The note that stood here said the old `getPosATL AP_fedCentre` was "the identical frame
        //      mistake one level out" and would have dropped the whole row to the seabed depth below the
        //      centre building. It would not have. getPosATL RETURNS a PositionATL and setPosATL TAKES
        //      one (BIKI, both: "the position of an object relative to the terrain"), so that branch
        //      never crossed frames at all; the row sat on the centre building's own origin, which is
        //      what it was written to do. Only the buildingPos branch, feeding an AGL number to a
        //      command that wants ATL, had the bug the owner saw.
        //      What the ATL fallback DID carry is the transplant problem, and only in miniature: the z
        //      was read at the centre's x/y and then written at five x/y positions 0.6 m apart, and an
        //      ATL z re-resolves against the terrain column under wherever it is finally written. So the
        //      row raked by whatever the seabed does across those 2.4 m -- nonzero on a slope that falls
        //      3.92 m across this compound, but a small fraction of it, and nothing like the metres the
        //      frame confusion produced. Converting once at the anchor removes even that, and getPosASL
        //      additionally keeps the fallback in the frame the settle read below differences against;
        //      leave one branch authoring in ATL and that subtraction reports terrain depth, not drift.
        //      The full frame argument is at the freeze note below.
        //      STILL TRUE AFTER THE GROUND-FLOOR PIN BELOW, which converts every CANDIDATE to ASL before
        //      the pick. That is a comparison, not an authoring step: the anchor is still ONE already-ASL
        //      position and the five cases are still spread off it in XY only. The rule this note states
        //      -- one conversion, at the anchor, before the spread -- is unchanged and still load-bearing.
        private _spots = AP_fedCentre buildingPos -1;
        // ---- GROUND FLOOR ONLY (2026-07-29, the owner's call). A live probe of this building's THIRTEEN
        //      positions, each converted to ASL and differenced against the centre's own origin at
        //      16.71 ASL, came back as two clean clusters: EIGHT at 0.785-0.957 m (ground floor) and FIVE
        //      at exactly 3.410 m (upper floor). selectRandom over the raw set therefore put the entire
        //      prize upstairs on roughly 38% of opens, and that is what the owner's test run got -- he
        //      breached the centre and could not find the cases, because they were on the second floor.
        //      Pin them downstairs: predictable, no hunting, and the loot is where a player expects it.
        //      THE CLUSTER IS DERIVED, NOT HARDCODED. A literal 0.85 would be a fact about a building the
        //      designer is free to move or replace, and it would go silently wrong the day he does. Take
        //      the LOWEST position and keep every position within EPSILON of it.
        //      EPSILON = 1.0 m, and both bounds it has to sit between are measured, not guessed:
        //        * it must EXCEED the ground cluster's own internal spread, 0.957 - 0.785 = 0.172 m, or
        //          the filter splits a single floor. 1.0 is 5.8x that, so a lumpier ground floor -- a
        //          landing, a raised shelf position -- still survives whole.
        //        * it must stay UNDER the gap up to the next floor, 3.410 - 0.957 = 2.453 m, or the upper
        //          floor is let straight back in and the bug returns. 1.0 is 2.45x under that, and under
        //          HALF a storey, so it cannot reach a floor above whatever building ends up standing here.
        //      ERR SMALL, DELIBERATELY, because the two failure directions are NOT symmetric. Too small
        //      only narrows the pick to fewer ground-floor spots -- still the ground floor, still correct,
        //      just less variety, which is what the owner asked for anyway. Too large reinstates the exact
        //      bug this is fixing. So 1.0 sits nearer the measured spread than the measured gap on purpose.
        //      COMPARE IN ASL, NOT IN THE RAW buildingPos NUMBERS. This is the part that is easy to get
        //      wrong here. buildingPos returns PositionAGL, and BIKI Position#PositionAGL is explicit that
        //      its z is measured off what is underneath ("the same as PositionASLW when over sea and the
        //      same as PositionATL when over land"), so two spots on the SAME flat floor report DIFFERENT
        //      AGL z whenever the ground beneath them differs. This compound is built out over a seabed
        //      that swings metres -- the sibling fix next door measures a 1.9 m swing under the ring --
        //      so a raw-AGL cluster test would be reading seabed relief as storey height, 1.9 m of noise
        //      against a 2.45 m gap. Converting each candidate at its OWN xy first makes the numbers
        //      absolute and makes the epsilon above mean exactly what the probe measured.
        //      selectRandom of the converted set is the same value `AGLToASL (selectRandom _spots)` gave;
        //      the conversion has only moved ahead of the pick so the pick can see what it is choosing.
        private _floorEps  = 1.0;
        private _aslSpots  = _spots apply { AGLToASL _x };
        //      selectMin is never handed an empty array -- guarded here, not inside it.
        private _lowest    = if (_aslSpots isEqualTo []) then { 0 } else { selectMin (_aslSpots apply { _x select 2 }) };
        //      _ground CANNOT be empty while _spots is not: the element that achieved the minimum
        //      differences to exactly 0 against itself, and 0 <= _floorEps always. A single-storey
        //      building keeps every position and behaves exactly as this line did before the pin; a
        //      building with three or more floors keeps only the lowest, because every floor above is at
        //      least a storey up and a storey is wider than _floorEps.
        private _ground    = _aslSpots select { ((_x select 2) - _lowest) <= _floorEps };
        private _base      = if (_spots isEqualTo []) then { getPosASL AP_fedCentre } else { selectRandom _ground };
        if (_spots isEqualTo []) then {
            diag_log "[maldenFed] alamo gold FALLBACK: centre has no buildingPos -- cases at the object centre, verify they are INSIDE"; };
        // The pick has to be auditable from the log alone -- the whole point of this change is that nobody
        // should have to stand in the building to find out which floor the gold landed on.
        private _haveCentre = !isNull AP_fedCentre;
        private _originZ    = if (_haveCentre) then { (getPosASL AP_fedCentre) select 2 } else { 0 };
        diag_log format ["[maldenFed] alamo gold floor pick: %1 buildingPos found, %2 survived the ground-floor filter (within %3 m of the lowest, %4 asl), chose %5 asl = %6 m above the centre's origin (%7 asl). This building probes at ~0.85 m for the ground floor and 3.41 m for the upper floor, so a value near 3.4 here means the filter let the upper floor back in.",
            count _spots,
            count _ground,
            _floorEps toFixed 2,
            if (_aslSpots isEqualTo []) then {"n/a"} else {_lowest toFixed 3},
            (_base select 2) toFixed 3,
            if (_haveCentre) then {((_base select 2) - _originZ) toFixed 2} else {"?"},
            if (_haveCentre) then {_originZ toFixed 2} else {"?"}];
        // ---- THE CASES ARE FROZEN. Land_Suitcase_F inherits ThingX, so it is a live PhysX body under
        //      gravity -- APS_fnc_createItem's own header records that these "spawned overlapping and
        //      violently ejected nearby vehicles/players" before it started disabling simulation on them.
        //      WHAT IS AND IS NOT SERVER-SIDE HERE -- corrected 2026-07-29, the numbers and one claim in
        //      this paragraph were wrong when 3bd494a wrote them. Counted against the shipped
        //      fn_mapData: 486 rows (not 620) lie within 70 m of AP_FED_CENTRE, spanning z -21.88 to
        //      z 29.35 (not -21.9 to 31.3), of which 206 (not 237) are Land_Sidewalk_02_8m_F. Exactly
        //      TWO of those rows carry _xIsServer = true -- this centre building and the dome -- and
        //      that part was right: the deck itself (the sidewalk plates, the cobblestone squares, the
        //      canal plates) exists on a client only, as createSimpleObject copies made by
        //      AP_fnc_createVehicleLocal, because initServer.sqf spawns _xIsServer rows only.
        //      BUT fn_mapData is not the whole compound. mission.sqm's FEDERAL RESERVE layer puts 23
        //      more objects inside that same 70 m, every one of them a real engine entity that exists
        //      on the server -- including the ten Land_Medevac_house_V1_F ring safes. So "there is no
        //      server-side collision under the compound at all" is NOT true, and it is stated correctly
        //      at the other half of this fix in APS_fnc_fedGoldSpawn. The five cases below are placed at
        //      AP_fedCentre buildingPos, i.e. inside a server-created building, so they do have a floor
        //      on this machine.
        //      THE FREEZE STAYS ANYWAY, on its own merits and not on that argument: Land_Suitcase_F is a
        //      live PhysX body, every other Land_Suitcase_F in the build is frozen the moment
        //      APS_fnc_createItem makes it, and a case left simulated is free to be shoved by a player,
        //      a vehicle or an explosion for the thirty minutes it sits there. The settle read further
        //      down is what actually decides whether these drift -- it measures, it does not argue.
        //
        //      The order below is fn_bankDrillVault's, which drives this identical class at the bank
        //      vault and is the proven shape here: create -> enableSimulationGlobal false -> setPos*
        //      -> setVectorUp. Freezing FIRST is what makes the re-assert stick, and the re-assert still
        //      replicates afterwards (BIKI, enableSimulation: "After using enableSimulation false or
        //      enableSimulationGlobal false on an object, setPos will still update its position across
        //      the network in MP"). setVectorUp puts the case level -- a frozen case otherwise keeps
        //      whatever tilt createVehicle gave it. THE ORDER IS UNCHANGED BY THE FRAME FIX BELOW and
        //      must stay: a live probe read every case back at EXACTLY the height the placement wrote,
        //      twice, minutes apart, so the freeze holds and a write made after it still lands. Only the
        //      FRAME of that write changed, so the case is frozen and then put at the CORRECT position,
        //      and with simulation off there is no gravity left to move it afterwards.
        //
        //      ---- THE POSITION FRAME. THIS, NOT THE FREEZE, IS THE BUG THE OWNER SAW (2026-07-29).
        //      The placement below used to be `_c setPosATL _p` with _p descended from `buildingPos`,
        //      and those are two different frames:
        //        * BIKI buildingPos -- return value: "PositionAGL - a single building position".
        //        * BIKI Position#PositionAGL -- "Z is the same as PositionASLW when over sea and is the
        //          same as PositionATL when over land."
        //        * BIKI setPosATL -- "Sets the position of an object relative to the terrain."
        //      The Reserve composition is built OUT OVER THE SEA: the terrain under it is the seabed,
        //      running -3.68 m at the deep end to +0.23 m where it comes ashore, while the deck and the
        //      safe floors are flat at ASL ~16.8. Feeding an AGL height to setPosATL therefore sank
        //      every case by exactly the depth of the seabed beneath it -- probed at -2.72 m below the
        //      deck at the deep end, with the two cases nearest the waterline sitting flat ON the floor
        //      instead of on the shelf above it. It reads as nothing at all where the terrain is at sea
        //      level, which is why the Jewelry Emporium (terrain ~+28.9) never showed this and why
        //      freezing the cases in 3bd494a looked like it had failed. It had not: the same probe
        //      reports simulationEnabled false on every object.
        //      THE FIX IS AGLToASL + setPosASL, NOT "read the buildingPos z as a world height".
        //      Reinterpreting the number is only right over water; over land AGL IS ATL, so a naive ASL
        //      read sinks a case by the terrain height instead -- the same bug mirrored, and this
        //      compound already crosses the waterline. AGLToASL is the engine's own conversion and is
        //      correct on both sides of it, and ASL is the only absolute frame Arma has (BIKI Position).
        //      THE REPOSITION STAYS -- IT IS NOT REDUNDANT WITH createVehicle, and deleting it was
        //      considered. BIKI createVehicle, R3vo's note on the main syntax: "The main syntax creates
        //      vehicles at ground level ignoring the Z in pos". The z below is therefore inert, the
        //      object lands on the GROUND -- the seabed, 20 m under this deck -- and the setPos is the
        //      only thing that places it. Deleting it puts the cases further under the compound than the
        //      bug being fixed here did. The array syntax was rejected in turn: BIKI records it as
        //      taking a PositionATL for anything not amphibious, which would reinstate the ATL frame.
        //
        //      IT COSTS THE LOOT FLOW NOTHING, and that is checked rather than assumed. Every path that
        //      touches these cases is either a setVariable or a SPATIAL query, and a non-simulated
        //      object answers both: fn_setupActions.sqf:99 offers "Pick Up Item(s)" on cursorObject,
        //      fn_pickupSelected.sqf reads cursorObject with a nearestObject fallback, and cursorObject
        //      is documented to return an object "even if the simulation is not enabled" since Arma 3
        //      1.56 (BIKI, enableSimulation). cursorTARGET is the one that goes objNull on a frozen
        //      object, and nothing in this flow uses it. The reset's own sweep at the bottom of this file
        //      finds them with nearestObjects, also spatial. The strongest evidence is simply that
        //      APS_fnc_createItem already freezes EVERY Land_Suitcase_F it makes -- every death drop,
        //      manual drop and login bonus in the build is a frozen case with AP_droppedItems, and
        //      players loot those daily.
        //
        //      allowDamage false: these sit in the open through a cop-vs-crew firefight, and a destroyed
        //      holder takes the payout with it. fn_createItem sets it on every drop and fn_loonyBinSRV
        //      sets it on its own suitcase; simulation-off does not imply damage-off, so it is a separate
        //      write. NOT AP_questloot -- see the settle-read note below for why that flag is wrong here.
        private _alamoCases = [];
        for "_i" from 0 to 4 do {
            private _p = _base vectorAdd [(_i - 2) * 0.6, 0, 0];   // XY spread only; _base is already ASL
            private _c = "Land_Suitcase_F" createVehicle _p;       // z inert here -- see the note above
            _c enableSimulationGlobal false;   // BEFORE the placement -- the freeze is what makes it stick
            _c setPosASL _p;
            _c setVectorUp [0, 0, 1];
            _c allowDamage false;
            _c setVariable ["owner", "alamo_gold", true];
            _c setVariable ["AP_droppedItems", [["goldbar", 2]], true];
            _alamoCases pushBack [_c, _p];
            diag_log format ["[maldenFed] alamo gold case %1 at %2 asl", _i, _p];
            // The same 30-minute self-delete fn_fedGoldSpawn gives its own cases: wait until the case
            // is emptied, deleted, or the deadline passes, then remove it. It is a backstop, not the
            // primary path -- the reset still deletes these. It is needed because fn_cleanup's periodic
            // sweep will not reap these cases, so without it a reset that never ran would leave them
            // standing in the open building until the next restart. The exemption is spelled out at the
            // settle-read note below; the short version is that the Thing sweep only ever touches an
            // object that has an `item` var and no `owner` var, and these have the opposite of both.
            [_c] spawn {params ["_c"];
                private _endAt = serverTime + 1800;
                waitUntil { uiSleep 2; isNull _c || {(_c getVariable ["AP_droppedItems", []]) isEqualTo []} || {serverTime > _endAt} };
                if (!isNull _c) then { deleteVehicle _c; };};
        };

        // ---- THE SETTLE READ, REBUILT 2026-07-29 SO IT CAN SEE A FRAME ERROR.
        //      What it used to be: read each case back 3 s later and compare its height against the SAME
        //      number that had just been written to it. That answers exactly one question -- did the
        //      object move after it was placed -- so it detects a failed freeze and nothing else. It was
        //      green through the entire lifetime of the AGL-into-setPosATL bug above, and green BECAUSE
        //      of it: every case sat precisely where it had been put, which is what "no drift" means.
        //      A log that compares a write against itself is a tautology with a threshold on it.
        //      What it is now: each case is measured against something the placement did not choose --
        //      the CENTRE BUILDING it is standing in, plus the terrain under it printed as the ATL
        //      equivalent (the frame the old code wrote in, so any future frame confusion is one glance
        //      wide). Both failure modes are still reported and they are now distinguishable: drift ~0
        //      with a bad height means the placement frame is wrong; a large negative drift means the
        //      freeze did not take and a PhysX suitcase fell. EACH GETS ITS OWN WARN and its own marker
        //      on the line -- the 0.05 m drift gate below was restored 2026-07-29 after review, because
        //      the rebuild printed drift on every line but counted only band failures, so a case that
        //      moved raised nothing unless it also left the band.
        //      ---- WHY THIS BAND STAYS 0.25 WHILE fn_fedGoldSpawn's WENT TO 0.40 (2026-07-29). That is
        //      not an oversight and it must not be "tidied up" into matching. The tightened bound over
        //      there is derived from a live probe of eleven objects standing in the ten
        //      Land_Medevac_house_V1_F ring safes: correct, they read +0.57 to +1.02 above their own
        //      safe; broken, the two the owner found on the floor read +0.24 and +0.13. That measured
        //      gap is what justifies 0.40 -- for THOSE buildings.
        //      These five cases are measured against AP_fedCentre, which is a Land_Medevac_HQ_V1_F: a
        //      DIFFERENT class, with its own model origin and its own interior floor height, so a 0.40
        //      bound copied across from the ring safes would be a number with no evidence under it, and
        //      the failure it would produce -- a WARN that fires every single Alamo open -- is the kind
        //      that teaches whoever reads this log to stop reading it. 0.25 is the loose, safe bound.
        //      ---- "IT HAS NEVER BEEN PROBED" IS NO LONGER TRUE. CORRECTED 2026-07-29, and the band was
        //      re-checked against the new numbers rather than left on the old excuse. The Land_Medevac_HQ_V1_F
        //      has now been probed: all thirteen of its buildingPos, converted to ASL against its own
        //      origin at 16.71 ASL, sit at 0.785-0.957 m (eight, ground floor) and 3.410 m (five, upper
        //      floor). Since the ground-floor pin above places each case AT its buildingPos and the spread
        //      is XY only, `_above` on the lines below IS that number.
        //      THE RULING IS: LEAVE 0.25 TO 3.00 ALONE. Both behaviours the band now owes are satisfied
        //      with margin. Pinned to the ground floor it passes cleanly -- 0.785 clears the floor of the
        //      band by 0.535 and 0.957 sits 2.043 under its ceiling -- so it will not cry wolf. And a
        //      regression back to the upper floor lands at 3.410, which is 0.410 OVER the ceiling, so it
        //      trips WRONG HEIGHT on all five cases and the fix cannot rot silently. Tightening the lower
        //      bound to 0.40 buys nothing: the fault it exists to catch, an AGL height fed to an ATL
        //      command, sank these cases by METRES, and 0.25 catches that as surely as 0.40 would.
        //      Tightening the CEILING (to, say, 2.00) would catch a half-storey regression that no probe
        //      has ever seen, at the cost of false WARNs on any replacement building whose model origin
        //      sits lower -- and this bound is now the regression detector for the pin above, so a false
        //      positive here is expensive. Do not change it without an Alamo-open probe that justifies it.
        //      The raw numbers print on every line either way, which is what makes that measurement a
        //      one-line read rather than a job.
        //      The band is a sanity bound, not a spec.
        //      Read in the SAME frame the placement writes (setPosASL -> getPosASL); reading ATL after
        //      an ASL write would report the terrain depth as drift on every case and be pure noise.
        //      A case can legitimately be GONE by then (looted clean, or a reset landed), so the null case
        //      is reported rather than treated as drift.
        //
        //      NO AP_questloot ON THESE, deliberately, and it is the opposite call from the jewelry
        //      display cases. That flag's only load-bearing reader is fn_pickupItem.sqf:82, which
        //      deleteVehicle's the holder once its last item is taken UNLESS the flag is set. A display
        //      case has to survive being looted -- it is scenery the heist counts, and deleting it would
        //      permanently destroy one for everyone. A gold briefcase is the OPPOSITE: it is the loot
        //      container itself and is MEANT to disappear when emptied. Setting the flag here would leave
        //      an empty case standing in the vault, contradict the self-delete spawn above (which waits
        //      for AP_droppedItems to empty and then deletes it anyway), and make the two paths race for
        //      no gain. The right tag is the one already on the line above: `owner`, which is what every
        //      sibling heist tags its loot holder with.
        //      HOW fn_cleanup ACTUALLY LEAVES THESE ALONE -- corrected 2026-07-29. The claim 3bd494a
        //      wrote here, that "both sweeps refuse to touch an object whose `owner` var is set", does
        //      not survive reading the file:
        //        * fn_cleanup.sqf:179, the `vehicles` sweep, deletes when the object is not whitelisted
        //          AND has no AP_furniture AND no `item` var AND an EMPTY AP_droppedItems AND
        //          ( idleTime stamped more than 1800 s ago OR (idleTime == 0 AND no Revive/owner/Trunk
        //          and not roped) ). `owner` sits in the SECOND disjunct only -- a stale-stamped object
        //          is deleted no matter what its `owner` says. What keeps a loaded case out of that
        //          sweep is the AP_droppedItems clause, several tests earlier; and once it is emptied
        //          nothing has ever stamped an idleTime on it, so the idleTime == 0 branch is the one
        //          that applies and `owner` does exempt it there.
        //        * fn_cleanup.sqf:181, the Thing sweep, is the one that lists Land_Suitcase_F by class.
        //          It only reaches an object with `!isNil "_item"` AND `isNil "_owner"` (:186). These
        //          cases set `owner` and never set `item`, so they are exempt twice over.
        //      AP_furniture is still not the tag to use here: it is the scenery exemption, it is inert
        //      in the Thing sweep, and no sibling heist tags a loot suitcase with it.
        [_alamoCases, AP_fedCentre] spawn {
            params ["_cases", "_ref"];
            uiSleep 3;
            private _bad   = 0;
            private _moved = 0;
            {
                _x params ["_c", "_authored"];
                if (isNull _c) then {
                    diag_log format ["[maldenFed] alamo gold settle %1: GONE -- looted clean or a reset landed, not drift", _forEachIndex];
                } else {
                    private _p     = getPosASL _c;
                    private _asl   = _p select 2;
                    private _drift = _asl - (_authored select 2);
                    private _terr  = getTerrainHeightASL _p;
                    private _known = !isNull _ref;
                    private _floor = if (_known) then { (getPosASL _ref) select 2 } else { 0 };
                    private _above = _asl - _floor;
                    private _wrong = _known && {_above < 0.25 || {_above > 3}};
                    private _slid  = (abs _drift) > 0.05;   // the restored freeze check -- see the note above
                    if (_wrong) then { _bad   = _bad   + 1; };
                    if (_slid)  then { _moved = _moved + 1; };
                    diag_log format ["[maldenFed] alamo gold settle %1: %2 m above the centre building | case %3 asl, centre %4 asl, terrain %5 asl (%6 atl) | %7 m from the height it was placed at%8%9",
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
                diag_log format ["[maldenFed] WARN %1 of %2 alamo gold case(s) MOVED after placement -- more than 0.05 m from the height they were written to, marked <<< MOVED on their line. This is the FREEZE fault, not the frame fault: Land_Suitcase_F inherits ThingX and is a live PhysX body, so a case that shifts means the enableSimulationGlobal false above did not take and it is falling or being shoved. It is counted separately from WRONG HEIGHT on purpose -- a case can move without leaving the height band, and a case can be at the wrong height without ever having moved, which is the placement frame and has its own warning. Both markers on one line means it was placed wrong AND did not stay there.",
                    _moved, count _cases];
            };
            if (_bad > 0) then {
                diag_log format ["[maldenFed] WARN %1 of %2 alamo gold case(s) are at the WRONG HEIGHT -- outside 0.25 to 3.00 m above the centre building's origin, i.e. under the floor they belong on or floating above it. READ THAT AGAINST THE LAST NUMBER ON EACH LINE. If a case is ~0.000 m from the height it was placed at, it is exactly where this mode PUT it and the placement FRAME is wrong -- that is the 2026-07-29 bug, a PositionAGL from buildingPos handed to setPosATL, which sank every case at this compound by the depth of the seabed under it. If the line also carries <<< MOVED, the case did not stay where it was put and the separate MOVED warning above covers that fault -- freeze, not frame. Note this band is the LOOSE 0.25 one: AP_fedCentre (Land_Medevac_HQ_V1_F) has never been probed, unlike the ring safes, so treat a value just under 0.25 here as worth measuring rather than as a proven fault. AP_fedCentre IS server-created, so these cases have a real floor under them on this machine either way, and because the server owns them wherever they end up replicates to every client.",
                    _bad, count _cases];
            };
        };

        [[[0,1,2], "The Alamo vault is OPEN."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
        ["-FED-", objNull, "ALAMO opened -- 10 bars in 5 cases"] call APS_fnc_logIt;
        // The key has to be handed on. This call is made from inside the 20:00 timer's spawn, so the
        // boat mode is keyed exactly as this one is and would refuse a bare ["boat"].
        ["boat", localNamespace getVariable ["AP_fedInternalKey", ""]] call APS_fnc_maldenFedSRV;
    };

    case "boat": {   // server-internal only -- reached from alamoOpen above, and only with the key
        // Keyed for the same reason domeOpen and alamoOpen are, and it inherits their problem exactly:
        // alamoOpen is itself running inside the 20:00 timer's spawn when it calls this, so a
        // remoteExecutedOwner check here would depend on whether a spawned child inherits its parent's
        // value -- undocumented -- and could refuse the server's own delivery, leaving the crew stranded
        // with ten bars and no boat. The empty key still has to be refused EXPLICITLY: if boot never ran
        // the key was never generated, the getVariable default is "" and _arg's own params default is ""
        // too, so a bare ["boat"] from anywhere would compare "" against "" and PASS. No key, no boat.
        private _key = localNamespace getVariable ["AP_fedInternalKey", ""];
        if (_key isEqualTo "" || {_arg isNotEqualTo _key}) exitWith {
            diag_log "[maldenFed] boat refused -- missing internal key"; };
        // The state precondition every other internal mode has, and for the same reason domeOpen and
        // alamoOpen re-check theirs: this is called from inside alamoOpen, which is itself inside the
        // 20:00 timer's spawn, so a reset can land between alamoOpen setting alamo to 2 and this
        // running. Without the check that reset re-locked the compound and binned the loot while this
        // mode went on to deliver an unlocked boat with ten bars aboard -- and AP_fedBoat was assigned
        // AFTER the reset had already read and nulled it, so the reset's own tracking handle was gone
        // and nothing would ever clean it up. Check and deliver are atomic here.
        if (((localNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isNotEqualTo 2) exitWith {
            diag_log "[maldenFed] boat abandoned -- alamo is no longer 2 (a reset landed between alamoOpen and the delivery)"; };

        // AP_FED_BOATPOS is XY ONLY, deliberately. The owner clipboarded the spot while standing on the
        // pier, so the coordinate he read back carried a z of 8.65 -- above the waterline here, where the
        // piers alongside sit at -4.8. That z is dropped and the hull is put on the surface instead.
        // CHECKED AND DELIBERATELY LEFT ALONE BY THE 2026-07-29 FRAME FIX. Nothing here descends from
        // buildingPos: the XY is the owner's clipboarded coordinate, the z handed to createVehicle is a
        // literal 0, and 0.6 is written through setPosASL -- an ABSOLUTE height, 0.6 m above sea level,
        // which is what a floating hull wants and is the same on any terrain. It is already the frame
        // the gold cases were moved to. Do not "make it consistent" by changing it to setPosATL: out
        // here the terrain is the seabed ~5 m down and the boat would be launched into the air.
        // The boat's ten bars are VIRTUAL (AP_vinv, a setVariable further down) -- there is no spawned
        // object in the boat to place, so the loot aboard it has no frame to get wrong.
        private _pos  = [AP_FED_BOATPOS select 0, AP_FED_BOATPOS select 1, 0];
        private _boat = createVehicle ["B_Boat_Armed_01_minigun_F", _pos, [], 0, "NONE"];
        _boat setPosASL [_pos select 0, _pos select 1, 0.6];
        _boat setDir 150;
        _boat lock 0;
        _boat setFuel 1;
        _boat setVariable ["AP_eventVeh", true, true];
        _boat setVariable ["owner", "malden_fed_boat", true];
        // Unlimited virtual (T) inventory, the Loony Bin getaway Tempest's mechanism (fn_loonyBinSRV) --
        // fn_openInventory reads AP_vcap and defaults it to 100, which would not hold a single haul out
        // of here.
        _boat setVariable ["AP_vcap", 999999, true];
        // Ten bars already aboard. AP_vinv is [[[item, qty], ...], totalWeight]; a gold bar weighs 64 in
        // fn_virtItemCfg, so ten of them is 640. That 640 is hardcoded on purpose: fn_virtItemCfg is a
        // MISSION function and the server has no business reaching into the client catalogue for it.
        _boat setVariable ["AP_vinv", [[["goldbar", 10]], 640], true];

        // Keys go to everyone who was in the compound, measured from the FED CENTRE and not from the
        // boat: it sits ~120 m offshore, so a boat-centred radius would miss the crew still inside the
        // walls -- the people who actually earned it.
        private _keys = [];
        {
            if ((side _x isEqualTo civilian) && {alive _x} && {(_x distance AP_FED_CENTRE) < 400}) then {
                _keys pushBack [getPlayerUID _x, name _x];
                [[_boat], "AP_fnc_addVehicle2Chain", _x, false, false] spawn AP_fnc_MP;
            };
        } forEach allPlayers;
        _boat setVariable ["AP_vehOwners", _keys, true];

        AP_fedBoat = _boat;
        // The reset's "un-driven" test measures back to here (empty and still within 150 m). It is read
        // only server-side, so unlike AP_fedBoat it is deliberately NOT published.
        AP_fedBoatSpawn = getPosATL _boat;
        publicVariable "AP_fedBoat";
        [[0, "The getaway boat has arrived on the west shore -- it is already carrying ten bars."],
            "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        diag_log format ["[maldenFed] getaway boat spawned at %1 dir 150, keys to %2 player(s)", getPosASL _boat, count _keys];
        ["-FED-", objNull, format ["getaway boat delivered, %1 key holder(s)", count _keys]] call APS_fnc_logIt;
    };

    case "reset": {   // server-internal only -- the boot sweep above, and only with the key
        // Keyed exactly as domeOpen, alamoOpen and boat are, and for the same reason: the sweep makes
        // this call from inside its own spawn, so a remoteExecutedOwner guard would depend on whether a
        // spawned child inherits its parent's value -- undocumented -- and could refuse the server's own
        // ending. That is the worst refusal in the file: this mode is the ONLY thing that stops the
        // siren, so a reset that refuses itself leaves the alarm ringing until the next restart.
        // The empty key still has to be refused EXPLICITLY: if boot never ran the key was never
        // generated, the getVariable default is "" and _arg's own params default is "" too, so a bare
        // ["reset"] from anywhere would compare "" against "" and PASS -- and a client CAN send that,
        // because the CfgRE entry is allowedTargets = 2 with no argument restriction. No key, no reset.
        // The reason it is being reset is the THIRD argument (_reason); slot 2 belongs to the key.
        private _key = localNamespace getVariable ["AP_fedInternalKey", ""];
        if (_key isEqualTo "" || {_arg isNotEqualTo _key}) exitWith {
            diag_log "[maldenFed] reset refused -- missing internal key"; };
        private _s = localNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        // Read the phase HERE, before anything writes state. _s is a REFERENCE to the live array, not a
        // copy (SQF arrays are references, and _fnc_setState fetches and mutates that same array), so a
        // phase read taken after the setState call below would see the post-reset 0 and never the 3.
        private _phase = _s param [0, 0];
        if (_phase isEqualTo 0) exitWith {};   // already secure
        // Success is "did the vault ever open": phase 3 was reached, so gold was on the floor.
        private _success = (_phase isEqualTo 3);

        [] call APS_fnc_fedLockdown;

        // un-looted payout goes with it
        private _killed = 0;
        {
            if ((_x getVariable ["owner", ""]) in ["fed_gold", "fed_component", "alamo_gold"]) then {
                deleteVehicle _x; _killed = _killed + 1; };
        } forEach (nearestObjects [AP_FED_CENTRE, ["Land_Suitcase_F"], 400]);

        // ---- kill the siren. fn_fedAlarm creates a Sound_Alarm source and, on Altis, deleted it in the
        //      end-detector branch that this plan cut (Task 6) -- so nothing stops it any more. The alarm
        //      now publishes its handle as AP_fedAlarmSound for exactly this.
        private _siren = missionNamespace getVariable ["AP_fedAlarmSound", objNull];
        if (!isNull _siren) then { deleteVehicle _siren; };
        AP_fedAlarmSound = objNull;
        publicVariable "AP_fedAlarmSound";

        // the boat only dies if nobody ever took it: empty, and still where it was put
        private _boat = missionNamespace getVariable ["AP_fedBoat", objNull];
        private _boatGone = false;
        if (!isNull _boat) then {
            private _spawn = missionNamespace getVariable ["AP_fedBoatSpawn", [0,0,0]];
            if ((crew _boat isEqualTo []) && {((getPosATL _boat) distance2D _spawn) < 150}) then {
                deleteVehicle _boat; _boatGone = true; };
        };
        AP_fedBoat = objNull;
        publicVariable "AP_fedBoat";

        [0, -1, 0, -1, serverTime + 300] call _fnc_setState;   // TODO lengthen after testing (owner 2026-07-27)

        // ---- everything the alarm's deleted end-detector used to do, now that this is the only ending.
        if (!isNil "AP_bank_inProgress") then { AP_bank_inProgress = false; publicVariable "AP_bank_inProgress"; };
        AP_bank_robbers = [];
        publicVariable "AP_bank_robbers";
        // Every other heist closes its dispatch when it ends (fn_bankDrillVault, fn_robStore,
        // fn_startPrisonBreak); the Fed never did, so MaxSec got the "respond immediately" line and
        // then nothing. Same shape as fn_bankDrillVault: the flag is POLICE success, so it is the
        // inverse of _success ("did the vault ever open"). The id is the one APS_fnc_fedAlarm minted
        // for this robbery and now parks in AP_fedDispatch -- it was a local there, unreachable from
        // here, and inventing one would leave the id the cops were briefed under unresolved.
        private _dispatch = missionNamespace getVariable ["AP_fedDispatch", -1];
        if (_dispatch isNotEqualTo -1) then {
            [[_dispatch, !_success], "AP_fnc_finishDispatch", west, false] spawn AP_fnc_MP;
            AP_fedDispatch = -1; };
        [[[0,1,2], "The federal reserve security is no longer tracking unauthorized persons. Continue with standard duties."],
            "AP_fnc_broadcast", west, false] spawn AP_fnc_MP;
        "robberyMarker" setMarkerText "Elevated Security";
        // ---- THE MARKER DELETION BELONGS TO THIS RESET, NOT TO WHATEVER IS RUNNING IN 300 s.
        //      This used to be a bare `[] spawn { uiSleep 300; deleteMarker "robberyMarker"; }` racing a
        //      HIGH SECURITY lockout of exactly 300 s -- a coin flip in ordinary play, and a certainty
        //      under FED OVERRIDE, the owner's own back-to-back testing toggle: its loop clears slot 4
        //      within 4 s, so the next robbery is usually live long before this fires and it deleted
        //      THAT robbery's "Robbery in Progress" marker about five minutes in. Lengthening the sleep
        //      only moves the collision. So take a generation token now and only delete if it is still
        //      current: case "gate" bumps it when the alarm re-creates the marker for a new robbery, and
        //      every reset bumps it here, so a superseded timer stands down. Server-only and
        //      deliberately NOT publicVariable'd -- nothing client-side reads it.
        AP_fedMarkerGen = (missionNamespace getVariable ["AP_fedMarkerGen", 0]) + 1;
        [AP_fedMarkerGen] spawn {
            params ["_gen"];
            uiSleep 300;
            if ((missionNamespace getVariable ["AP_fedMarkerGen", 0]) isEqualTo _gen) then {
                deleteMarker "robberyMarker";
            } else {
                diag_log "[maldenFed] stale robberyMarker deletion stood down -- a newer robbery owns the marker"; };
        };
        [[[0,1,2], "The Federal Reserve has re-secured. Security is HIGH."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
        diag_log format ["[maldenFed] RESET (%1) -- %2 case(s) removed, boat removed: %3", _reason, _killed, _boatGone];
        ["-FED-", objNull, format ["Reserve reset (%1)", _reason]] call APS_fnc_logIt;
    };

    case "secure": {
        // Cop-side. Deliberately NOT routed through _fnc_caller, which demands a civilian. Because it
        // is longhand it has to REPEAT the checks that helper applies, and it was missing two of them:
        // on foot (isNull objectParent) and not restrained. Without those a cop could end the robbery
        // from the passenger seat of a moving car, or while cuffed by the crew he is standing in front
        // of -- the same two holes _fnc_caller closes centrally for every civilian mode.
        // NOTE the shape: a flat _bad flag, never a nested exitWith. An exitWith inside a then{} only
        // leaves the then-block, so the rest of the case would run anyway -- the exact footgun called
        // out in fn_fedAlarm and fn_bankDrillVault, where it once let understaffed robberies start.
        private _src = remoteExecutedOwner;
        private _cop = if (_src isEqualTo 0) then { objNull }
                       else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
        private _bad = (_src isNotEqualTo 0)
            && {isNull _cop || {!alive _cop} || {!(_cop call APS_fnc_isDutyCop)}
                || {_cop getVariable ["AP_restrained", false]}
                || {!(isNull objectParent _cop)}
                || {(_cop distance AP_FED_CENTRE) > 50}};
        if (_bad) exitWith {
            ["-SEC-", _cop, "BLOCKED maldenFedSRV secure (not a cop on site)"] call APS_fnc_logIt; };
        if (((localNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isEqualTo 0) exitWith {};

        // The whole point is that it cannot cut a live fight short: robbers on site means no.
        private _inside = {
            (side _x isEqualTo civilian) && {alive _x} && {isPlayer _x}
            && {!(_x getVariable ["AP_restrained", false])}
            && {(_x distance AP_FED_CENTRE) < 200}
        } count allPlayers;
        if (_inside > 0) exitWith {
            [[2, format ["There are still %1 suspect(s) inside the Reserve.", _inside]], "AP_fnc_broadcast", _cop, false] spawn AP_fnc_MP; };

        // The reset is key-guarded (see "Guarding the server-internal modes"): key in slot 2, reason
        // in slot 3. Without the key this call is refused and the cop action silently does nothing.
        ["reset", (localNamespace getVariable ["AP_fedInternalKey", ""]), "secured by MaxSec"] call APS_fnc_maldenFedSRV;
    };

    default { diag_log format ["[maldenFed] unknown mode '%1' -- ignored", _mode]; };
};
true
