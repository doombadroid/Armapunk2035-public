/*
    APS_fnc_loonyBinSRV  --  THE NAMESAKE HEIST, MALDEN REWORK (owner spec 2026-08-01).
    Server half / state machine. Client half: core/actions/fn_loonyBin.sqf + core/fn_setupActions.sqf.
    Local-prop mirror: core/functions/fn_lbScene.sqf (every client applies the scene to ITS OWN copies).

    WHY THIS IS A REWRITE AND NOT A PORT. The Altis version drove everything off NAMED mission.sqm
    objects (AP_mentalGate1/2/3, AP_mentalLaptop1..5, the two bomb trolleys). On Malden the whole
    compound is a mapData delivery: fn_createVehicleLocal spawns those rows with _xIsServer = false,
    i.e. **the server has no copy of any of them** and no client's copy is networked. Passing one
    through remoteExec arrives objNull server-side; setVariable ... true on one is a no-op. So:
      - every gate/prop STATE lives in publicVariable'd arrays, never on the objects;
      - the server validates by POSITION (player distance to the anchor), never by object identity;
      - visual changes to local props (trolley gone, satchel gone, doors unlocked) are applied by
        AP_fnc_lbScene on each client, pushed after every state change and re-run on JIP;
      - anything the HEIST creates (loot, keypadless tablet is a prop, the getaway truck) is a
        server-side createVehicle, so it is global and JIP-safe like every other heist's loot.
    The two compound gates ARE mission.sqm entities (global), so the server locks/opens those itself.

    FLOW (owner spec):
      1. Sequence-Breach the explosives on the bomb trolley at the west gate ->  it detonates, is gone
         until reset, and BOTH compound gates swing open. This is the event start (map marker, alerts).
      2. Sequence-Breach the laptop inside the courtyard -> arms the satchel charge on the main door:
         a 5-minute fuse with a bank-style draining bar. Everyone civilian within 500 m is charged with
         "Loony Bin Robbery" (id 74) the moment it is armed. When it blows, the hotel doors unlock.
      3. Terminal-Breach the rugged laptop upstairs -> starts a 10-minute "Breaching Patient Record
         Database" timer (same bar treatment). When it completes, the 4-digit code is posted in chat.
      4. Enter the code at the tablet by the church -> church opens, the 4 coffins are loaded with the
         loot table, and the unlimited-trunk Tempest spawns outside with keys for every civ within 200 m.
      5. Ending, unchanged: the grave digger buries the remains 10 min after the tomb opened, but only
         once no un-restrained civilian player is within 500 m; 45-minute hard cap; the MaxSec counter is
         the firewall re-enable ON THE RUGGED LAPTOP (owner 2026-08-01 -- one contested terminal).

    STATE
      SRV_loonyBinData = [lastBreach, breached, 0, keycode, tombLocked, remainsObj, copsRequired]
        -- shape UNCHANGED: fn_activeFederalEvent reads [1], fn_impoundAction reads [4],
           fn_openInventory / fn_inventoryOpened / fn_doorAnimate read it too. Do not reorder.
      AP_lbState = [trolleyBlown, doorFuseEndsAt, doorBlown, dbEndsAt, dbDone, tombOpen, firewall,
                     trolleyArming]
        -- the new phases. serverTime stamps are 0 when that phase has not started. trolleyArming
           covers the few seconds between slicing the detonator and the charge actually going off.
      AP_lbPos_*  = resolved prop world positions (see the resolver below).
      APS_lbLoot  = every object this event spawned, deleted on reset.
    All of it is SERVER-PRIVATE (localNamespace) -- see the block under params.
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];

// ── SERVER-PRIVATE STATE (audit r2heist 2026-09-26) ───────────────────────────────────────────
// A client publicVariable overwrites a missionNamespace global on the server too. A modified client
// could publish SRV_loonyBinData [6]=0 / [0]=-2700 (no cops, no cooldown), or a finished AP_lbState
// plus its own keycode and AP_lbPos_tablet and open the tomb for a fresh loot drop on every call.
// So every gate here reads the localNamespace copies (same names; init.sqf seeds both arrays). They are
// mutated in place, never replaced, so a timer thread handed one keeps seeing the live state.
// AP_lbState, SRV_loonyBinData and AP_lbPos_* are display copies for clients; nothing here reads them.
private _st  = localNamespace getVariable ["AP_lbState", []];
private _lb  = localNamespace getVariable ["SRV_loonyBinData", []];
private _pos = localNamespace getVariable "APS_lbPos";   // prop key -> resolved position
if (isNil "_pos") then { _pos = createHashMap; localNamespace setVariable ["APS_lbPos", _pos]; };
// "loonyBinReset" is server-internal, but this function is CfgRE-whitelisted, so any client could
// cancel a live heist (and bin its loot) on demand. The internal callers pass this key, which no client
// can read or write. Keyed rather than isRemoteExecuted-gated: three of those callers run inside spawns
// of remote-executed cases, and whether a spawned child inherits isRemoteExecuted is undocumented.
if (isNil {localNamespace getVariable "APS_lbKey"}) then {
    localNamespace setVariable ["APS_lbKey", ((random 1e9) toFixed 0) + ((random 1e9) toFixed 0)]; };

// ── ANCHORS ────────────────────────────────────────────────────────────────────────────────────
// Owner-surveyed positions, 2026-08-01. These are ANCHORS, not gospel: the resolver below re-reads
// the real position out of the map table by class, so moving a prop in Eden and re-applying
// the map keeps the heist attached to it. The anchor is what we fall back to (and what tells us the
// prop has been deleted, because then nothing resolves within the radius and we log it).
// Private locals, not globals: a published copy of any of these would be client-writable.
private _lbSiteAnchor    = [4254.90, 3907.50, 0];          // compound centre -- all radii measure from here
private _lbAnchorTrolley = [4201.07, 3940.99, 27.78];      // Land_Bomb_Trolley_01_F   -- step 1
private _lbAnchorLaptop  = [4245.09, 3910.81, 27.76];      // Item_Laptop_Unfolded     -- step 2
private _lbAnchorSatchel = [4245.98, 3911.65, 28.07];      // DemoCharge_F on the door -- blows on step 2
private _lbAnchorRugged  = [4250.00, 3910.94, 31.57];      // Land_Laptop_03_olive_F   -- step 3 + MaxSec counter
private _lbAnchorTablet  = [4269.54, 3931.75, 27.74];      // Land_Tablet_02_F         -- step 4 (keycode)
private _lbAnchorHotel   = [4254.58, 3909.33, 30.30];      // Land_Hotel_02_F          -- doors open on step 2
private _lbAnchorChurch  = [4278.21, 3933.19, 32.38];      // Land_Church_05_F         -- doors open on step 4
private _lbGatePositions = [[4203.11, 3941.99, 0], [4291.17, 3956.17, 0]];   // mission.sqm gates (GLOBAL)
private _lbTempestPos    = [4301.94, 3939.70, 0];          // getaway spawn, bearing 315
private _lbTempestDir    = 315;
private _lbCoffins       = [[4276.726, 3932.723, 26.621], [4277.186, 3933.484, 26.621],
                       [4277.668, 3934.291, 26.621], [4278.181, 3935.139, 26.586]];   // 4 loot coffins

// ── PROP RESOLVER ──────────────────────────────────────────────────────────────────────────────
// APS_fnc_mapLoad keeps a boot snapshot of every map row (localNamespace APS_mapEntities) even though
// the server spawns almost nothing from it, so it is a readable INDEX of the compound here. Look the prop up by
// class near its anchor and take the delivered position; that way an Eden nudge + `edit-map.sh
// apply` moves the heist with the prop instead of silently detaching it.
if !(isFinal "AP_fnc_lbResolve") then {AP_fnc_lbResolve = compileFinal {
    params ["_class", "_anchor", ["_radius", 15]];
    private _best = []; private _bestD = _radius;
    {
        _x params ["_cls", "_pos"];
        if (_cls isEqualTo _class) then {
            private _d = _anchor distance2D _pos;
            if (_d < _bestD) then { _bestD = _d; _best = +_pos; };
        };
    } forEach (localNamespace getVariable ["APS_mapEntities", []]);
    if (_best isEqualTo []) then {
        diag_log format ["[LooneyBin][heist] WARNING %1 not found within %2 m of %3 -- using the anchor. If the prop was deleted from the map this step is unreachable.", _class, _radius, _anchor];
        +_anchor
    } else { _best };
}};

// "Is the caller actually at this prop?" mapData props are placed with setPosWorld, so their z lives
// in the WORLD frame; `_unit distance <array>` reads the unit in the AGL frame and the mismatch alone
// measured ~28 m at point-blank range, refusing every step (caught live 2026-08-01). Compare
// getPosWorld to getPosWorld and it is both correct and genuinely 3D, so the two laptops on different
// floors of the hotel cannot be confused for each other.
if !(isFinal "AP_fnc_lbAtSrv") then {AP_fnc_lbAtSrv = compileFinal {
    params ["_unit", "_pos", ["_r", 8]];
    ((getPosWorld _unit) distance _pos) < _r
}};

// Broadcast the scene to every client (they apply it to their own local copies) + publish state.
// The globals are rebuilt from the server-private copies on every push: display only, never read back.
if !(isFinal "AP_fnc_lbPush") then {AP_fnc_lbPush = compileFinal {
    AP_lbState = +(localNamespace getVariable ["AP_lbState", []]);
    SRV_loonyBinData = +(localNamespace getVariable ["SRV_loonyBinData", []]);
    publicVariable "AP_lbState";
    publicVariable "SRV_loonyBinData";
    [] remoteExec ["AP_fnc_lbScene", -2, false];
}};
if (_caseType isEqualTo "boot") exitWith {};   // server init.sqf: define the helpers above at boot (security 2026-09-26)

switch (_caseType) do {

    // ── SEALED / RESET ─────────────────────────────────────────────────────────────────────────
    // Runs at boot (initServer, after the map has been delivered) and at every event end.
    case "loonyBinReset": {
        // server-internal only: every legitimate caller passes the key (see SERVER-PRIVATE STATE above)
        if ((_data param [0, ""]) isNotEqualTo (localNamespace getVariable ["APS_lbKey", "-"])) exitWith {
            ["-SEC-", (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull],
                "BLOCKED loonyBin reset without the server key"] call APS_fnc_logIt;
        };
        _pos set ["trolley", ["Land_Bomb_Trolley_01_F", _lbAnchorTrolley] call AP_fnc_lbResolve];
        _pos set ["laptop",  ["Item_Laptop_Unfolded",   _lbAnchorLaptop ] call AP_fnc_lbResolve];
        _pos set ["satchel", ["DemoCharge_F",           _lbAnchorSatchel] call AP_fnc_lbResolve];
        _pos set ["rugged",  ["Land_Laptop_03_olive_F", _lbAnchorRugged ] call AP_fnc_lbResolve];
        _pos set ["tablet",  ["Land_Tablet_02_F",       _lbAnchorTablet ] call AP_fnc_lbResolve];
        _pos set ["hotel",   ["Land_Hotel_02_F",        _lbAnchorHotel, 25] call AP_fnc_lbResolve];
        _pos set ["church",  ["Land_Church_05_F",       _lbAnchorChurch, 25] call AP_fnc_lbResolve];
        _pos set ["site",    +_lbSiteAnchor];
        // The coffins are the loot points, so read them off the map rather than trusting a constant:
        // every Coffin_01_F within 25 m of the church counts. Add a fifth in Eden and it gets loot.
        private _coffins = [];
        {
            _x params ["_cls", "_cpos"];
            if ((_cls isEqualTo "Coffin_01_F") && {(_cpos distance2D _lbAnchorChurch) < 25}) then {
                _coffins pushBack (+_cpos);
            };
        } forEach (localNamespace getVariable ["APS_mapEntities", []]);
        if (_coffins isEqualTo []) then {
            diag_log "[LooneyBin][heist] WARNING no coffins found near the church -- falling back to the surveyed four.";
            _coffins = +_lbCoffins;
        };
        _pos set ["coffins", _coffins];
        // A placed marker always wins over the hardcoded anchor (markers-live-in-the-map-layer rule);
        // this reads it if the owner adds one, and never creates it.
        if !((getMarkerPos "AP_mentalHospital") isEqualTo [0,0,0]) then {
            _pos set ["site", getMarkerPos "AP_mentalHospital"];
        };
        // display copies AP_lbPos_<key> for the client half (fn_lbScene, fn_setupActions, fn_loonyBin)
        {
            missionNamespace setVariable ["AP_lbPos_" + _x, +_y];
            publicVariable ("AP_lbPos_" + _x);
        } forEach _pos;

        // The two compound gates are mission.sqm objects, so the SERVER owns them: lock and shut.
        // A lock alone is not enough -- a gate a player already swung open stays passable, which is
        // the same trap the Altis version documented for the hospital doors.
        private _gates = [];
        {
            private _g = (nearestObjects [_x, ["Land_ConcreteWall_01_l_gate_F"], 14]) param [0, objNull];
            if (!isNull _g) then {
                // owner 2026-08-01: the hack is the ONLY way in. Without this a satchel just blows
                // the gate off its hinges and the whole first phase is optional.
                _g allowDamage false;
                _gates pushBack _g;
            };
        } forEach _lbGatePositions;
        localNamespace setVariable ["APS_lbGates", _gates];
        {
            // The inner forEach rebinds _x to the animation name, so hold the gate in its own variable
            // first -- writing _x for both is how this loop shipped an undefined-variable error once.
            private _gate = _x;
            _gate setVariable ["bis_disabled_Door_1", 1, true];
            _gate animateDoor ["Door_1", 0];
            { _gate animateSource [_x, 0]; } forEach ["Door_1_source", "Door_1_sound_source", "Door_1_noSound_source"];
        } forEach _gates;
        diag_log format ["[LooneyBin][heist] reset -- gates resolved %1/2, props: trolley %2 laptop %3 rugged %4 tablet %5",
            count _gates, _pos get "trolley", _pos get "laptop", _pos get "rugged", _pos get "tablet"];
        diag_log format ["[LooneyBin][heist] reset -- %1 coffin loot point(s) resolved", count _coffins];

        // Clear everything the event spawned. The getaway Tempest is deliberately NOT deleted here
        // (owner 2026-06-20): it stays where the crew left it until the next restart, exempt from
        // fn_cleanup via AP_eventVeh. Just drop our reference.
        // (localNamespace: as globals, a client publicVariable of AP_lbLoot made this delete any object it named)
        { if (!isNull _x) then { deleteVehicle _x; }; } forEach (localNamespace getVariable ["APS_lbLoot", []]);
        localNamespace setVariable ["APS_lbLoot", []];
        // The getaway truck deliberately outlives the event (exempt from fn_cleanup via AP_eventVeh,
        // reaped only at restart). Strip the heist tag off it on the way out, or an abandoned Tempest
        // stays permanently un-impoundable and device-blocked long after the robbery is over.
        private _old = localNamespace getVariable ["APS_lbTempest", objNull];
        if (!isNull _old) then {
            _old setVariable ["AP_mentalTruck", nil, true];
            _old setVariable ["AP_mentalCarLocked", nil, true];
        };
        localNamespace setVariable ["APS_lbTempest", objNull];
        { deleteMarker _x; } forEach ["AP_mentalEventMarker", "AP_mentalHospitalPatient"];

        { _st set [_forEachIndex, _x]; } forEach [false, 0, false, 0, false, false, false, false];   // in place (see top)
        _lb set [1, false];
        _lb set [3, ""];
        _lb set [4, true];
        _lb set [5, objNull];
        call AP_fnc_lbPush;
    };

    // ── STEP 1: SEQUENCE-BREACH THE EXPLOSIVES -> gates open, event starts ──────────────────────
    case "lbTrolley": {
        // Never trust the payload for identity. remoteExecutedOwner is the engine's own answer to
        // "which machine sent this" and cannot be forged client-side; 0 means server-internal or HC.
        private _src = remoteExecutedOwner;
        private _caller = if (_src isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
        if (isNull _caller) exitWith {};
        if (_st param [0, false]) exitWith {};
        if (_st param [7, false]) exitWith {};      // already fizzing
        if ((_lb param [0, -2700]) > serverTime - 2700) exitWith {};
        if !("trolley" in _pos) then { ["loonyBinReset", [localNamespace getVariable "APS_lbKey"]] call APS_fnc_loonyBinSRV; };
        // The whole point of the step is being AT the explosives -- validate that server-side, since
        // the client's cursorObject check lives on a machine we do not control.
        if (!([_caller, _pos get "trolley"] call AP_fnc_lbAtSrv)) exitWith {
            ["-SEC-", _caller, format ["BLOCKED loonyBin trolley breach from %1 m away", round ((getPosWorld _caller) distance (_pos get "trolley"))]] call APS_fnc_logIt;
        };
        if (["loonybin"] call APS_fnc_fedEventActive) exitWith {
            [[2, "Another major crime is already in progress -- the Loony Bin breach won't trigger."], "AP_fnc_broadcast", _caller, false, false] spawn AP_fnc_MP;
        };
        // Cop requirement mirrored server-side (index 6; 0 legitimately means "no requirement" --
        // do NOT floor it at 1, that would invent a gate the config says does not exist).
        // Server-private copy: a published [6] = 0 used to skip this gate entirely (audit r2heist).
        private _lbReq = _lb param [6, 0];
        if (_lbReq > 0 && {([] call AP_fnc_tenuredCops) < _lbReq} && {!(localNamespace getVariable ["AP_betaZeroCops", false])}) exitWith {
            [[2, format ["The Loony Bin cannot be breached with fewer than %1 police officer(s) online.", _lbReq]], "AP_fnc_broadcast", _caller, false, false] spawn AP_fnc_MP;
            ["-SEC-", _caller, format ["BLOCKED loonyBin breach (needs %1 tenured cops)", _lbReq]] call APS_fnc_logIt;
        };
        // Server-authoritative cross-heist lockout. The client checks this too, but only this copy
        // is trustworthy -- same 900 s interval as every other reader so the two cannot drift.
        if (!isNil "SRV_lastRobbery" && {SRV_lastRobbery > (serverTime - (60 * 15))}) exitWith {
            [[2, format ["Security is high due to a recent robbery. Try again in %1 minute(s).", ceil ((SRV_lastRobbery - (serverTime - (60 * 15))) / 60)]], "AP_fnc_broadcast", _caller, false, false] spawn AP_fnc_MP;
        };

        // Arm it. Slicing a detonator does not make it explode in your face -- normally it starts
        // fizzing and you get out of the blast. Owner 2026-08-01: keep the instant, hilarious
        // face-full as a 1-in-10 outcome and give the other nine tries four seconds to clear the
        // gate. Everything downstream waits for the actual bang, so the gates open when it blows
        // rather than when the minigame ends.
        private _instant = (random 1) < 0.1;
        _st set [7, true];
        call AP_fnc_lbPush;
        if (_instant) then {
            [[0, "The detonator went off in the breacher's hands!"], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        } else {
            [[0, "The gate charge is fizzing -- CLEAR THE GATE!"], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        };
        ["-LOONYBIN-", _caller, format ["sliced the gate detonator (%1)", if (_instant) then { "INSTANT -- point blank" } else { "4s fuse" }]] call APS_fnc_logIt;

        [_instant, _caller, _st, _pos] spawn {
            params ["_instant", "_caller", "_st", "_pos"];
            // The trolley itself is a client-local prop, so the SERVER only makes the bang -- the
            // disappearance is scene state every client applies to its own copy (AP_fnc_lbScene).
            private _boom = "ModuleExplosive_DemoCharge_F" createVehicle (_pos get "trolley");
            uiSleep (if (_instant) then { 0.4 } else { 4 });
            _boom setDamage 1;

            // Both compound gates: unlock and swing open.
            {
                private _gate = _x;
                _gate setVariable ["bis_disabled_Door_1", 0, true];
                _gate animateDoor ["Door_1", 1];
                { _gate animateSource [_x, 1]; } forEach ["Door_1_source", "Door_1_sound_source", "Door_1_noSound_source"];
            } forEach (localNamespace getVariable ["APS_lbGates", []]);

            _st set [0, true];
            _st set [7, false];
            call AP_fnc_lbPush;
            diag_log format ["[LooneyBin][heist] gate charge detonated (%1)", if (_instant) then { "instant" } else { "fused" }];
        };

        _lb set [0, serverTime];
        _lb set [1, true];
        _lb set [3, ""];
        _lb set [4, true];
        _lb set [5, objNull];
        SRV_lastRobbery = serverTime; publicVariable "SRV_lastRobbery";
        call AP_fnc_lbPush;

        if ((getMarkerPos "AP_mentalEventMarker") isEqualTo [0,0,0]) then {
            private _mk = createMarker ["AP_mentalEventMarker", _pos get "site"];
            _mk setMarkerType "loc_Hospital";
            _mk setMarkerColor "ColorRed";
            _mk setMarkerText "Loony Bin Breach";
        } else { "AP_mentalEventMarker" setMarkerPos (_pos get "site"); };

        [[0, "The Loony Bin gates have been BLOWN OPEN! MaxSec must respond!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        [["The Loony Bin gates have been blown -- respond immediately!", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
        diag_log format ["[LooneyBin][heist] gates breached by %1", name _caller];
        ["-LOONYBIN-", _caller, "blew the Loony Bin gates"] call APS_fnc_logIt;

        // 45-minute hard cap. Every other phase runs in its own spawn; this one is the backstop that
        // re-seals the site if the crew simply walks away mid-heist.
        [_st, _lb] spawn {
            params ["_st", "_lb"];
            private _endAt = serverTime + 2700;
            // Key this off the event-active flag, NOT trolleyBlown: during the detonator fuse
            // trolleyBlown is still false, and testing it here made the backstop exit immediately.
            waitUntil { uiSleep 5; (serverTime > _endAt) || {!(_lb param [1, false])} || {_st param [5, false]} };
            if (!(_lb param [1, false]) || {_st param [5, false]}) exitWith {};   // ended, or the tomb phase owns the clock now
            [[0, "The Loony Bin breach has gone cold -- the site has been re-secured."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            ["loonyBinReset", [localNamespace getVariable "APS_lbKey"]] call APS_fnc_loonyBinSRV;
        };
    };

    // ── STEP 2: SEQUENCE-BREACH THE COURTYARD LAPTOP -> 5-minute satchel fuse ───────────────────
    case "lbDoorHack": {
        private _src = remoteExecutedOwner;
        private _caller = if (_src isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
        if (isNull _caller) exitWith {};
        if !(_st param [0, false]) exitWith {};
        if ((_st param [1, 0]) > 0) exitWith {};        // fuse already armed
        if (_st param [2, false]) exitWith {};          // door already blown
        if (_st param [6, false]) exitWith {};          // MaxSec already killed it
        if (!([_caller, _pos get "laptop"] call AP_fnc_lbAtSrv)) exitWith {
            ["-SEC-", _caller, format ["BLOCKED loonyBin door hack from %1 m away", round ((getPosWorld _caller) distance (_pos get "laptop"))]] call APS_fnc_logIt;
        };

        private _fuseEnds = serverTime + 300;
        _st set [1, _fuseEnds];
        call AP_fnc_lbPush;

        // Arming the satchel is the point of no return -- charge every civilian in the blast radius,
        // exactly as the thermite step did on Altis (crime id 74, "Loony Bin Robbery", $15k).
        private _robbers = [];
        {
            if ((side _x isEqualTo civilian) && {alive _x} && {(_x distance (_pos get "site")) < 500}) then {
                [74, _x] call APS_fnc_wantedAdd;
                _robbers pushBack _x;
            };
        } forEach allPlayers;
        [[0, "The door charge is armed at the Loony Bin! Everyone nearby is wanted for Loony Bin Robbery!"], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        [["A satchel charge is counting down on the Loony Bin main door!", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
        ["-LOONYBIN-", _caller, "armed the Loony Bin door charge (5 min)"] call APS_fnc_logIt;
        // The bank's draining red bar, retimed to 5 minutes -- it clears itself the moment the
        // condition goes false, so a firewall abort or the blast both wipe it with no extra plumbing.
        // (The condition runs on the robbers' clients, so it reads the AP_lbState display copy.)
        ["Door Charge Burning!", "lb_doorfuse", { (AP_lbState param [1, 0]) > 0 && {!(AP_lbState param [2, false])} && {!(AP_lbState param [6, false])} }] remoteExec ["AP_fnc_handleMessage", _robbers];

        [_fuseEnds, _st, _lb, _pos] spawn {
            params ["_fuseEnds", "_st", "_lb", "_pos"];
            waitUntil { uiSleep 2; (serverTime > _fuseEnds) || {_st param [6, false]} || {!(_lb param [1, false])} };
            if ((_st param [6, false]) || {!(_lb param [1, false])}) exitWith {};
            private _boom = "ModuleExplosive_DemoCharge_F" createVehicle (_pos get "satchel");
            [_boom] spawn { params ["_b"]; uiSleep 0.4; _b setDamage 1; };
            _st set [1, 0];
            _st set [2, true];
            call AP_fnc_lbPush;
            [[0, "The Loony Bin main door has been blown open! Get to the records terminal upstairs!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            diag_log "[LooneyBin][heist] door satchel detonated -- hotel open";
        };
    };

    // ── STEP 3: TERMINAL-BREACH THE RUGGED LAPTOP -> 10-minute database breach -> code ──────────
    case "lbDbHack": {
        private _src = remoteExecutedOwner;
        private _caller = if (_src isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
        if (isNull _caller) exitWith {};
        if !(_st param [2, false]) exitWith {};         // door not blown yet
        if ((_st param [3, 0]) > 0) exitWith {};        // already running
        if (_st param [4, false]) exitWith {};          // already done
        if (_st param [6, false]) exitWith {};
        if (!([_caller, _pos get "rugged"] call AP_fnc_lbAtSrv)) exitWith {
            ["-SEC-", _caller, format ["BLOCKED loonyBin database hack from %1 m away", round ((getPosWorld _caller) distance (_pos get "rugged"))]] call APS_fnc_logIt;
        };

        private _dbEnds = serverTime + 600;
        _st set [3, _dbEnds];
        call AP_fnc_lbPush;

        private _robbers = allPlayers select { (side _x isEqualTo civilian) && {alive _x} && {(_x distance (_pos get "site")) < 500} };
        [[0, "The patient record database is being breached -- 10 minutes. Hold the building!"], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        [["The robbers are breaching the Loony Bin patient record database!", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
        ["-LOONYBIN-", _caller, "started the patient record database breach (10 min)"] call APS_fnc_logIt;
        ["Breaching Patient Record Database", "lb_database", { (AP_lbState param [3, 0]) > 0 && {!(AP_lbState param [4, false])} && {!(AP_lbState param [6, false])} }] remoteExec ["AP_fnc_handleMessage", _robbers];

        [_dbEnds, _st, _lb, _pos] spawn {
            params ["_dbEnds", "_st", "_lb", "_pos"];
            waitUntil { uiSleep 2; (serverTime > _dbEnds) || {_st param [6, false]} || {!(_lb param [1, false])} };
            if ((_st param [6, false]) || {!(_lb param [1, false])}) exitWith {};
            private _code = format ["%1%2%3%4", floor random 10, floor random 10, floor random 10, floor random 10];
            _lb set [3, _code];
            _lb set [4, true];
            _st set [3, 0];
            _st set [4, true];
            call AP_fnc_lbPush;

            if ((getMarkerPos "AP_mentalHospitalPatient") isEqualTo [0,0,0]) then {
                private _mk = createMarker ["AP_mentalHospitalPatient", _pos get "tablet"];
                _mk setMarkerType "loc_Church";
                _mk setMarkerText "Patient Tomb";
                _mk setMarkerColor "ColorRed";
            } else { "AP_mentalHospitalPatient" setMarkerPos (_pos get "tablet"); };

            [[0, format ["Database breached. Patient transfer code is %1 -- enter it at the tomb tablet on your map!", _code]], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
            [["The robbers cracked the patient database! Defend the tomb at the map marker!", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
            diag_log format ["[LooneyBin][heist] database breached, code %1", _code];
        };
    };

    // ── STEP 4: KEYCODE AT THE TABLET -> tomb opens, coffins load, getaway spawns ───────────────
    case "enterKeyCode": {
        _data params [["_entered", "", [""]]];
        private _src = remoteExecutedOwner;
        private _caller = if (_src isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
        if (isNull _caller) exitWith {};
        if !(_st param [4, false]) exitWith {};         // no code issued yet
        if (_st param [5, false]) exitWith {};          // tomb already open
        if (_st param [6, false]) exitWith {};
        if (!([_caller, _pos get "tablet"] call AP_fnc_lbAtSrv)) exitWith {
            ["-SEC-", _caller, format ["BLOCKED loonyBin keycode entry from %1 m away", round ((getPosWorld _caller) distance (_pos get "tablet"))]] call APS_fnc_logIt;
        };
        // The code is validated HERE, not on the client, against the server-private copy. It reaches
        // clients through the SRV_loonyBinData[3] display copy because the chat broadcast has to say it
        // out loud anyway, but the client never decides whether the tomb opens.
        if !(_entered isEqualTo (_lb param [3, ""])) exitWith {
            [[2, "That code is incorrect."], "AP_fnc_broadcast", _caller, false, false] spawn AP_fnc_MP;
        };

        _st set [5, true];
        _lb set [4, false];
        call AP_fnc_lbPush;

        // ---- loot: one case per coffin (owner 2026-08-01: 4 coffins x 5 bars = the same 20 bars the
        // 5 Altis suitcases held). The coffins themselves are client-local props and cannot carry a
        // networked AP_droppedItems, so the loot is a server-side case resting on each lid -- looted
        // through the same locked, dupe-safe pickup menu as every other heist.
        private _loot = [];
        localNamespace setVariable ["APS_lbLoot", _loot];
        private _coffins = _pos get "coffins";
        private _cryptoCoffin = floor random 4;
        {
            private _cp = +_x;
            private _case = "Land_Suitcase_F" createVehicle _cp;
            _case setPosWorld [_cp select 0, _cp select 1, (_cp select 2) + 0.45];
            _case setDir (random 360);
            _case enableSimulationGlobal false;   // the church floor only exists on CLIENTS -- physics here would drop it to terrain
            _case allowDamage false;
            private _lbLoot = [["goldbar", 5]];
            if (_forEachIndex isEqualTo _cryptoCoffin) then {
                _lbLoot pushBack [selectRandom ["cryptoCPU", "cryptoGPU", "cryptoPSU", "cryptoStorage", "cryptoMotherboard", "cryptoRam", "cryptoCooler", "cryptoCase"], 1];
            };
            _case setVariable ["AP_droppedItems", _lbLoot, true];
            // fn_cleanup reaps ownerless objects almost immediately -- every heist object gets tagged.
            _case setVariable ["owner", "loonybin_gold", true];
            _loot pushBack _case;
        } forEach _coffins;

        // Patient remains -- the object the grave digger is waiting to bury, and the one the
        // "Loot Patient Remains" action reads out of SRV_loonyBinData[5].
        private _rp = _coffins param [1, _lbAnchorChurch];
        private _remains = "Land_Suitcase_F" createVehicle _rp;
        _remains setPosWorld [(_rp select 0) - 1.2, (_rp select 1) + 0.6, (_rp select 2) + 0.2];
        _remains enableSimulationGlobal false;
        _remains allowDamage false;
        _remains setVariable ["AP_droppedItems", [["patientbag", 3]], true];
        _remains setVariable ["owner", "loonybin_remains", true];
        _loot pushBack _remains;
        _lb set [5, _remains];

        // Weapons crate, unchanged from Altis.
        private _wp = _coffins param [2, _lbAnchorChurch];
        private _crate = "Box_NATO_Wps_F" createVehicle _wp;
        _crate setPosWorld [(_wp select 0) - 1.6, (_wp select 1) + 0.9, (_wp select 2) + 0.2];
        clearWeaponCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearItemCargoGlobal _crate; clearBackpackCargoGlobal _crate;
        _crate addWeaponCargoGlobal ["MMG_02_camo_F", 2];
        _crate addWeaponCargoGlobal ["srifle_GM6_F", 2];
        _crate addWeaponCargoGlobal ["srifle_DMR_02_F", 2];
        _crate addMagazineCargoGlobal ["5Rnd_127x108_Mag", 8];
        _crate addMagazineCargoGlobal ["130Rnd_338_Mag", 8];
        _crate addMagazineCargoGlobal ["10Rnd_338_Mag", 8];
        // NO enableSimulation false here, unlike the suitcases. The cases are looted through the
        // custom AP_droppedItems scroll menu, which does not care about simulation; this crate is
        // read with the VANILLA inventory, and a simulation-disabled container cannot be opened at
        // all -- that is exactly why its weapons and magazines could not be taken (owner 2026-08-01).
        // The cost is that the server, which has no church floor (the church is a client-local
        // object), settles it onto the terrain a few centimetres below. Altis shipped it the same way.
        _crate allowDamage false;
        _crate setVariable ["owner", "loonybin_weapons", true];
        _loot pushBack _crate;

        // ---- getaway: iridescent Tempest (Device), unlimited virtual trunk, keys to every civ within
        // 200 m. AP_eventVeh exempts it from fn_cleanup and it deliberately survives the event reset.
        private _tempest = "O_Truck_03_device_F" createVehicle _lbTempestPos;
        _tempest setPosATL [_lbTempestPos select 0, _lbTempestPos select 1, 0.2];
        _tempest setDir _lbTempestDir;
        _tempest lock 0;
        _tempest setFuel 1;
        _tempest setVariable ["AP_eventVeh", true, true];
        // AP_mentalTruck marks this as the heist getaway: fn_deviceMine refuses to run the Tempest
        // Device's mining rig on it, and fn_impoundAction gates seizing it. Its companion
        // AP_mentalCarLocked is READ by evh/fn_getInMan with a default of TRUE and is written
        // NOWHERE in this codebase, so tagging the truck without also clearing this made it
        // permanently undrivable ("can't be driven whilst the tomb is locked, slacker"). The truck
        // only ever exists after the tomb is open, so locked is never the correct state for it.
        _tempest setVariable ["AP_mentalTruck", true, true];
        _tempest setVariable ["AP_mentalCarLocked", false, true];
        _tempest setVariable ["AP_vcap", 999999, true];
        {
            _tempest setObjectTextureGlobal [_x, "#(rgb,8,8,3)color(0.1,0.1,0.1,0.08,no)"];
            _tempest setObjectMaterialGlobal [_x, "\a3\characters_f_kart\civil\data\c_RacingHelmet_VisorEffectMetalic.rvmat"];
        } forEach [0, 1];
        private _keys = [];
        {
            if ((side _x isEqualTo civilian) && {alive _x} && {(_x distance _lbTempestPos) < 200}) then {
                _keys pushBack [getPlayerUID _x, name _x];
                [[_tempest], "AP_fnc_addVehicle2Chain", _x, false, false] spawn AP_fnc_MP;
            };
        } forEach allPlayers;
        _tempest setVariable ["AP_vehOwners", _keys, true];
        _tempest setVariable ["owner", "loonybin_tempest", true];
        localNamespace setVariable ["APS_lbTempest", _tempest];

        [[0, "The tomb is open! A getaway Tempest is waiting outside -- load the coffins and run!"], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        ["-LOONYBIN-", _caller, "opened the Loony Bin tomb with the transfer code"] call APS_fnc_logIt;
        diag_log "[LooneyBin][heist] tomb open, loot + getaway spawned";

        // ---- ending: the grave digger buries the remains 10 min after the tomb opened, but only once
        // the site is clear. An un-restrained, alive civilian player within 500 m holds it open, so the
        // crew keeps the digger away until they leave or MaxSec cuffs them. The 45-min cap is the
        // backstop against one AFK civilian parking the event forever.
        [_st, _pos] spawn {
            params ["_st", "_pos"];
            private _buryAt = serverTime + 600;
            private _endAt = serverTime + 2700;
            private _nextNag = 0;
            private _fnc_holding = {
                ({ (side _x isEqualTo civilian) && {alive _x} && {isPlayer _x}
                    && {!(_x getVariable ["AP_restrained", false])}
                    && {(_x distance (_pos get "site")) < 500} } count allPlayers) > 0
            };
            private _done = false;
            while { !_done } do {
                uiSleep 2;
                // The firewall case does its own announcing, so this only has to stop the clock --
                // broadcasting here as well double-posted the same line to everyone.
                if (_st param [6, false]) exitWith { _done = true; };
                if (serverTime > _endAt) exitWith { _done = true; };
                if ((serverTime > _buryAt) && {!(call _fnc_holding)}) exitWith {
                    [[0, "The grave digger arrived and buried the patient remains -- the Loony Bin robbery is over!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
                    _done = true;
                };
                if ((serverTime > _buryAt) && {serverTime > _nextNag}) then {
                    _nextNag = serverTime + 60;
                    [[0, "The grave digger is waiting -- he won't bury the patient while robbers still hold the Loony Bin. MaxSec: clear or restrain everyone on site to end it!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
                };
            };
            ["loonyBinReset", [localNamespace getVariable "APS_lbKey"]] call APS_fnc_loonyBinSRV;
            diag_log "[LooneyBin][heist] event ended";
            ["-LOONYBIN-", objNull, "heist event ended"] call APS_fnc_logIt;
        };
    };

    // ── MAXSEC COUNTER: re-enable the firewall on the rugged laptop ───────────────────────────────
    case "lbFirewall": {
        private _src = remoteExecutedOwner;
        private _caller = if (_src isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
        if (isNull _caller) exitWith {};
        if !(_caller call APS_fnc_isDutyCop) exitWith {
            ["-SEC-", _caller, "BLOCKED loonyBin firewall re-enable (not police)"] call APS_fnc_logIt;
        };
        if !(_st param [0, false]) exitWith {};
        if (_st param [6, false]) exitWith {};
        if (!([_caller, _pos get "rugged"] call AP_fnc_lbAtSrv)) exitWith {
            ["-SEC-", _caller, format ["BLOCKED loonyBin firewall from %1 m away", round ((getPosWorld _caller) distance (_pos get "rugged"))]] call APS_fnc_logIt;
        };

        _st set [6, true];
        call AP_fnc_lbPush;
        [[0, format ["MaxSec Officer %1 re-activated the Loony Bin firewall and stopped the breach!", name _caller]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        ["-LOONYBIN-", _caller, "re-enabled the Loony Bin firewall (heist stopped)"] call APS_fnc_logIt;
        diag_log format ["[LooneyBin][heist] firewall re-enabled by %1 -- event ending", name _caller];
        // If the tomb was never opened nobody owns the end-of-event reset, so do it here. When the
        // tomb IS open its own loop sees the firewall flag and resets, and this would double up.
        if !(_st param [5, false]) then {
            [] spawn { uiSleep 5; ["loonyBinReset", [localNamespace getVariable "APS_lbKey"]] call APS_fnc_loonyBinSRV; };
        };
    };

    default { diag_log format ["[LooneyBin][heist] unhandled case: %1", _this]; };
};
