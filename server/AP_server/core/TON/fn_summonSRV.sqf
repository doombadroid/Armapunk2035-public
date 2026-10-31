/*
    APS_fnc_summonSRV  (server) -- SUMMON VEHICLE (SUMMON_SPEC.md section 3).

        ["set", id]               star row id as the caller's recall vehicle (exclusive per pid)
        ["info"]                  push the recall vehicle's facts to the caller
        ["go"]                    validate, reclaim a world copy, ask the caller's client to spawn it
        ["drive", veh, token]     the client spawned it: hand to the HC, monitor, report
        ["spawnfail", why, token] the client could not spawn it
        ["selftest", kind]        bot_commands harness (server-local only)

    The caller is remoteExecutedOwner, never a client-supplied object. Nothing here trusts
    what a client names beyond facts the server can check itself. State in memory:
    AP_summonActive (uid -> [veh, t0, p0]: the vehicle once "drive" arrived, the attempt's
    token, where the caller stood at "go"), AP_summonCooldown (uid -> time),
    AP_summonLastReq (uid -> time). Refuses without a headless client (AP_hcOwner <= 0)
    -- owner's call.

    Hardened by review, 2026-09-02:
      - "drive" corroborates the vehicle with facts a client cannot forge -- the object is
        LOCAL to the caller (it created it), nobody is aboard, it stands in the spawn ring
        measured from where the caller stood at "go" -- because AP_dbInfo is a client-published
        variable and alone would let a modified client point the HC at anyone's car.
      - every attempt carries a token (t0) that the client echoes in "drive"/"spawnfail". A
        "drive" for an attempt the 40 s watchdog already closed is a LATE spawn: never adopted
        into the next attempt, and never acted on either -- the server cannot prove the object is
        what the client says it is, so it stays in the world as the plate's world copy for the
        next "go" to reclaim (or the reaper to store). No write here can be forged.
      - a row that is still `active` with no world copy is refused (a post-restart restore
        stamps a 3-element AP_dbInfo and re-flips active; spawning a second copy was the
        whole-vehicle dupe the garage's active=false filter prevents). Two world copies at once
        is refused too, for the same reason.
      - the per-player slot is CLAIMED before the first suspension, so two "go" calls in
        the DB round-trip window cannot both proceed; every refusal after the claim releases it.
      - the drive monitor has a 330 s wall-clock cap and "spawnfail" only clears a slot that
        has no vehicle yet -- so no path strands AP_summonActive or double-reports.
      - delivery ends LOCKED (lock true), as every other spawn path leaves a vehicle; the
        owner's keys open it. "lock 0" would have handed a stranger the car.
      - a vehicle wrecked while the summon owns it (in flight, on the landing, or in the 20 s
        after touchdown before anyone boards) is REFUNDED to the garage (owner 2026-09-03): the
        row keeps the damage / fuel / ammo it had before the pull, the trunk is read off the
        wreck through the store path, the wreck is deleted. Witnessed by the server on the object
        "drive" bound -- no client report can trigger it -- and covered by the `insured` gate for
        the summon's duration so fn_vehicleDead / the reaper cannot delete the row first.
*/
if (!isServer) exitWith {};
params [["_verb", "", [""]]];
_verb = toLower _verb;
private _arg = _this param [1];   // nil when absent; every read below is isNil-guarded

private _src = remoteExecutedOwner;
private _unit = if (_src in [0, 2]) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_verb isNotEqualTo "selftest" && {isNull _unit}) exitWith {};
private _uid = if (isNull _unit) then { "" } else { getPlayerUID _unit };

if (isNil "AP_summonActive")   then { AP_summonActive = createHashMap; };
if (isNil "AP_summonCooldown") then { AP_summonCooldown = createHashMap; };
if (isNil "AP_summonLastReq")  then { AP_summonLastReq = createHashMap; };

if (isNil "AP_summonLastLog")  then { AP_summonLastLog = createHashMap; };

private _fnTell = {
    params ["_to", "_hash"];
    if (!isNull _to) then { [_hash] remoteExec ["AP_fnc_summonState", _to]; };
};
// Audit-log gate: at most one line per uid per key per 10 s. The refusal paths of "drive" are reachable
// by any client at any rate and APS_fnc_logIt is an INSERT; without this a spammed verb is a write
// amplifier against the log table (final review, 2026-09-02).
private _fnLogGate = {
    params ["_key"];
    if ((AP_summonLastLog getOrDefault [_key, -100]) > time - 10) exitWith { false };
    AP_summonLastLog set [_key, time];
    true
};
// Per-caller throttle. set/info/go each issue SQL through the serialised async chokepoint;
// a modified client must not be able to spin them. A dropped verb is ANSWERED (the deck's SUMMON
// button disables itself until the next state push, so silence would leave it dead).
if (_verb in ["set", "info", "go"]) then {
    if ((AP_summonLastReq getOrDefault [_uid, -10]) > time - 1) exitWith {
        [_unit, createHashMapFromArray [["msg", "one moment"]]] call _fnTell;
        _verb = "";
    };
    AP_summonLastReq set [_uid, time];
};
if (_verb isEqualTo "") exitWith {};
// The caller's garage side, derived exactly as APS_fnc_getVehicles derives it: engine side,
// then the duty roster overrides. A civilian off duty cannot summon a MaxSec garage vehicle.
private _fnSide = {
    params ["_u"];
    private _s = switch (side _u) do { case west: { "cop" }; case independent: { "med" }; default { "civ" }; };
    private _duty = _u call APS_fnc_dutyLookup;
    if ((localNamespace getVariable ["AP_dutyEnabled", false]) && {_duty param [3, false]}) then {
        switch (_duty param [0, ""]) do { case "maxsec": { _s = "cop"; }; case "trauma": { _s = "med"; }; };
    };
    _s
};
private _fnRow = {   // the caller's starred row for their side, not up for sale; [] if none
    params ["_pid", "_side"];
    private _r = [format ["SELECT id, classname, pid, plate, color, COALESCE(mods,'[]') AS mods, alarm, COALESCE(customplate,'') AS customplate, fuel, damage, alive, active, ammo FROM %1 WHERE pid='%2' AND side='%3' AND listed = false AND recall = true LIMIT 1", "vehicles", _pid, _side], 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { [] };
    if ((_r select 0) isEqualType []) then { _r select 0 } else { _r }
};
// Every live copy of a plate. AP_dbInfo is [uid, plate] on a pull and [uid, plate, ...] after
// a restart restore (fn_restoreVehicles), so match the PREFIX, not the whole array.
private _fnCopies = {
    params ["_pid", "_plate"];
    vehicles select { ((_x getVariable ["AP_dbInfo", []]) select [0, 2]) isEqualTo [_pid, _plate] }
};
private _fnInfo = {   // hashmap for the client from a raw row (or [] -> none)
    params ["_row"];
    if (_row isEqualTo []) exitWith { createHashMapFromArray [["none", true]] };
    private _cls = _row select 1;
    private _plate = _row select 3;
    private _world = ([_uid, _plate] call _fnCopies) param [0, objNull];
    createHashMapFromArray [
        ["none", false],
        ["id", _row select 0], ["class", _cls],
        ["name", getText (configFile >> "CfgVehicles" >> _cls >> "displayName")],
        ["kind", if ([_cls] call AP_fnc_isRotorcraft) then { "AIR" } else { "LAND" }],
        ["plate", _plate],
        ["alive", (_row select 10) in [1, true]],
        ["out", !isNull _world || {(_row select 11) in [1, true]}],
        ["dist", if (isNull _world || {isNull _unit}) then { 0 } else { round (_unit distance _world) }]
    ]
};

switch (_verb) do {

    case "set": {
        if (isNil "_arg" || {!(_arg isEqualType 0)}) exitWith {};
        private _id = _arg;
        private _r = [format ["SELECT classname FROM %1 WHERE id=%2 AND pid='%3' AND listed = false", "vehicles", _id, _uid], 2] call DB_fnc_asyncQuery;
        if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { ["-SEC-", _unit, format ["BLOCKED summon set for a row not theirs (id %1)", _id]] call APS_fnc_logIt; };
        private _cls = format ["%1", ((if ((_r select 0) isEqualType []) then { _r select 0 } else { _r }) select 0)];
        // VTOLs inherit Plane_Base_F: test the rotorcraft classes first, then refuse real planes and boats
        if ((_cls isKindOf "Plane" && {!([_cls] call AP_fnc_isRotorcraft)}) || {_cls isKindOf "Ship"}) exitWith {
            [_unit, createHashMapFromArray [["msg", "that can't be summoned -- no driver for planes or boats"]]] call _fnTell;
        };
        [format ["UPDATE %1 SET recall = (id = %2) WHERE pid='%3'", "vehicles", _id, _uid], 1] call DB_fnc_asyncQuery;
        ["-SUMMON-", _unit, name _unit, format ["starred %1 (row %2)", _cls, _id]] call APS_fnc_logIt;
        [_unit, createHashMapFromArray [["info", [[_uid, [_unit] call _fnSide] call _fnRow] call _fnInfo], ["msg", "recall vehicle set"]]] call _fnTell;
    };

    case "info": {
        [_unit, createHashMapFromArray [["info", [[_uid, [_unit] call _fnSide] call _fnRow] call _fnInfo],
            ["cooldown", ((AP_summonCooldown getOrDefault [_uid, 0]) - time) max 0]]] call _fnTell;
    };

    case "go": {
        private _refuse = {   // every refusal after the claim releases the slot
            params ["_why"];
            AP_summonActive deleteAt _uid;
            [_unit, createHashMapFromArray [["state", "failed"], ["msg", _why]]] call _fnTell;
            ["-SUMMON-", _unit, name _unit, format ["refused: %1", _why]] call APS_fnc_logIt;
        };
        if ((localNamespace getVariable ["AP_hcOwner", 0]) <= 0) exitWith {
            [_unit, createHashMapFromArray [["state", "failed"], ["msg", "no driver available right now"]]] call _fnTell;
        };
        if (_uid in AP_summonActive) exitWith {   // NOT _refuse: the running attempt keeps its slot
            [_unit, createHashMapFromArray [["msg", "your vehicle is already on its way"]]] call _fnTell;
        };
        private _cd = (AP_summonCooldown getOrDefault [_uid, 0]) - time;
        if (_cd > 0) exitWith { [_unit, createHashMapFromArray [["state", "failed"], ["msg", format ["summon again in %1 s", ceil _cd]], ["cooldown", ceil _cd]]] call _fnTell; };
        if (!isNull objectParent _unit) exitWith { [_unit, createHashMapFromArray [["state", "failed"], ["msg", "get out of your vehicle first"]]] call _fnTell; };

        // CLAIM the slot before the first suspension (the DB round trips below sleep): two "go"
        // calls inside that window must not both proceed. t0 is this attempt's token; p0 is
        // where the caller stands now -- the spawn ring is measured from here, not from wherever
        // they have walked to by the time the client answers.
        private _t0 = time;
        private _p0 = getPosATL _unit;
        AP_summonActive set [_uid, [objNull, _t0, _p0]];

        private _row = [_uid, [_unit] call _fnSide] call _fnRow;
        if (_row isEqualTo []) exitWith { ["star a vehicle in the garage first"] call _refuse; };
        if !((_row select 10) in [1, true]) exitWith { ["your recall vehicle is wrecked"] call _refuse; };
        private _cls = _row select 1;
        private _plate = _row select 3;
        if ((_cls isKindOf "Plane" && {!([_cls] call AP_fnc_isRotorcraft)}) || {_cls isKindOf "Ship"}) exitWith { ["that vehicle can't be summoned"] call _refuse; };

        private _copies = [_uid, _plate] call _fnCopies;
        if (count _copies > 1) exitWith { ["more than one copy of that vehicle exists -- tell staff"] call _refuse; };
        private _world = _copies param [0, objNull];
        if (!isNull _world && {({isPlayer _x} count crew _world) > 0}) exitWith { ["someone is in it"] call _refuse; };
        // active with no world copy: it is out somewhere this server cannot see (a restore the
        // lookup missed, a crash). Spawning another would be the whole-vehicle dupe.
        if (isNull _world && {(_row select 11) in [1, true]}) exitWith { ["your vehicle is marked as out -- store it at a garage first"] call _refuse; };

        // RECLAIM a world copy: store it exactly as the idle-reaper does (trunk + fuel + damage
        // into the row, active=false), then delete it. Locality home first, or the delete no-ops.
        if (!isNull _world) then {
            _world setOwner 2;
            uiSleep 1;
            private _al = if ((_row select 6) in [1, true]) then { 1 } else { 0 };
            [_plate, _uid, _world, 0, _al, 0, true, true] call DB_fnc_updateVehicle;
            deleteVehicle _world;
            uiSleep 0.5;
            ["-SUMMON-", _unit, name _unit, format ["reclaimed %1 (%2) from the world", _cls, _plate]] call APS_fnc_logIt;
            _row = [_uid, [_unit] call _fnSide] call _fnRow;   // fuel/damage/inventory now reflect the world copy
        };
        if (_row isEqualTo [] || {(_row select 11) in [1, true]}) exitWith { ["the garage lost track of it -- try again in a moment"] call _refuse; };
        _row params ["_id", "", "", "", "_color", "_modsStr", "_alarm", "_customPlate", "_fuel", "_damage"];

        private _mods = parseSimpleArray _modsStr;
        if (!(_mods isEqualType []) || {count _mods < 9}) then { _mods = [if (_alarm in [1, true]) then { 1 } else { 0 }, 0, 0, 0, 0, 0, 0, 0, 0]; };
        private _clientRow = [_cls, _plate, _color, "", _mods, [((_damage max 0) / 100), ((_fuel max 0) / 100), 0], _customPlate];
        private _isAir = [_cls] call AP_fnc_isRotorcraft;
        [_unit, createHashMapFromArray [["state", "spawning"], ["msg", "your vehicle is being brought out"], ["dist", 0], ["eta", 0]]] call _fnTell;
        [_clientRow, _isAir, _t0] remoteExec ["AP_fnc_summonSpawn", _src];
        // the client has 40 s to come back with "drive". Scoped to THIS attempt's token, so a
        // retry started inside those 40 s is not killed by the previous attempt's watchdog.
        [_uid, _unit, _fnTell, _t0] spawn {
            params ["_uid", "_unit", "_fnTell", "_t0"];
            uiSleep 40;
            private _a = AP_summonActive getOrDefault [_uid, []];
            if (_a isNotEqualTo [] && {isNull (_a select 0)} && {(_a select 1) isEqualTo _t0}) then {
                AP_summonActive deleteAt _uid;
                [_unit, createHashMapFromArray [["state", "failed"], ["msg", "the vehicle never appeared"]]] call _fnTell;
            };
        };
    };

    case "spawnfail": {
        // only THIS attempt's slot, and only while it has no vehicle; a late spawnfail from an
        // attempt the watchdog closed, or a running drive, is not ours to clear
        private _tok = _this param [2, -1];
        private _a = AP_summonActive getOrDefault [_uid, []];
        if (_a isEqualTo [] || {!isNull (_a select 0)} || {(_a select 1) isNotEqualTo _tok}) exitWith {};
        AP_summonActive deleteAt _uid;
        private _why = if (isNil "_arg" || {!(_arg isEqualType "")}) then { "spawn failed" } else { _arg select [0, 80] };
        [_unit, createHashMapFromArray [["state", "failed"], ["msg", _why]]] call _fnTell;
        ["-SUMMON-", _unit, name _unit, format ["spawn failed: %1", _why]] call APS_fnc_logIt;
    };

    case "drive": {
        if (isNil "_arg" || {!(_arg isEqualType objNull)} || {isNull _arg}) exitWith {};
        private _veh = _arg;
        private _tok = _this param [2, -1];
        private _a = AP_summonActive getOrDefault [_uid, []];
        // A "drive" whose token is not the running attempt's is a LATE spawn from an attempt the
        // 40 s watchdog already closed (summonPoint can route-find for a while, then summonSpawn
        // waits up to ~17 s on prepareVehicle). It is never adopted into the attempt running now,
        // and it is deliberately left ALONE. The server cannot tell a genuine late copy from a
        // decoy a modified client stamped with its own uid and plate, and every write it could
        // make here -- store the row, delete the object -- is one such a client could aim at a
        // plate whose real copy is still live (store = active 0 + empty trunk = a garage re-pull
        // dupe). Left where it is, the copy is simply the plate's world copy: active, locked,
        // 1 km out. The next "go" reclaims it exactly like any other world copy, through the
        // one path that checks it is real, or the idle reaper stores it. Nothing is lost, and
        // nothing on this path can be forged into a write.
        if (_a isEqualTo [] || {(_a select 1) isNotEqualTo _tok}) exitWith {
            if ([_uid + ":late"] call _fnLogGate) then {
                ["-SUMMON-", _unit, name _unit, format ["late drive ignored: %1 (attempt %2 is closed)", typeOf _veh, _tok]] call APS_fnc_logIt;
            };
        };
        if (!isNull (_a select 0)) exitWith {};   // this attempt already has its vehicle
        private _p0 = _a param [2, getPosATL _unit];
        private _row = [_uid, [_unit] call _fnSide] call _fnRow;
        // AP_dbInfo and the class are what the honest client set; the last three are facts a
        // client cannot forge: the object is LOCAL to the caller (its own createVehicle), nobody is
        // aboard, and it stands inside the spawn ring around where the caller stood at "go"
        // (summonPoint: 1000 m, then 700 m, snapped up to 150 m). A stranger's parked car fails.
        private _ok = _row isNotEqualTo []
            // the row must be CLAIMED (active): the honest client's vehicleSetActive ran ~17 s before this
            // call; a client that skipped it would otherwise get a driven vehicle on an unclaimed row
            && {(_row select 11) in [1, true]}
            && {((_veh getVariable ["AP_dbInfo", []]) select [0, 2]) isEqualTo [_uid, _row select 3]}
            && {(typeOf _veh) isEqualTo (_row select 1)}
            && {owner _veh isEqualTo _src}
            && {(crew _veh) isEqualTo []}
            && {(_veh distance2D _p0) > 400 && {(_veh distance2D _p0) < 1500}};
        if (!_ok) exitWith {
            if ([_uid + ":sec"] call _fnLogGate) then {
                ["-SEC-", _unit, format ["BLOCKED summon drive: %1 owner=%2 crew=%3 dist=%4", typeOf _veh, owner _veh, count crew _veh, round (_veh distance2D _p0)]] call APS_fnc_logIt;
            };
            AP_summonActive deleteAt _uid;
            [_unit, createHashMapFromArray [["state", "failed"], ["msg", "that is not the vehicle that was summoned"]]] call _fnTell;
        };
        AP_summonActive set [_uid, [_veh, _a select 1, _p0]];
        [_veh, _unit, _uid, _fnTell, _row] spawn {
            params ["_veh", "_unit", "_uid", "_fnTell", "_row"];
            _veh setVariable ["AP_summonFor", _uid, true];
            _veh setVariable ["hc_ap_lock", true, true];
            _veh lock 2;
            _veh setVariable ["hc_ap_arrive", 8, true];
            _veh setVariable ["hc_ap_mode", "normal", true];
            _veh setVariable ["hc_ap_dest", getPosATL _unit, true];
            _veh setVariable ["hc_ap_done", "", true];
            _veh setVariable ["hc_ap_want", true, true];
            // REFUND COVER (owner 2026-09-03): while the summon owns the vehicle its death must not reach the
            // row. fn_vehicleDead deletes an uninsured dead vehicle's row, and the reaper calls it on first
            // sight of any un-stamped wreck -- that would land before, or race, the refund at the end of this
            // script. `insured` is the gate both of them already honour, so the summon insures the vehicle
            // for exactly as long as it owns it and puts the prior value back when it lets go.
            private _wasInsured = _veh getVariable ["insured", false];
            _veh setVariable ["insured", true];
            private _outcome = "";
            // ROTORCRAFT get a real pilot -- captive, invisible, AI OFF until the HC owns him -- so the engine's
            // own helicopter AI flies the aircraft on the HC (AP_fnc_hcFlyAI): real physics, real velocity,
            // smooth for every observer. The scripted core alone moves an unmanned airframe by setPosASL,
            // which other machines see as position steps (owner: "my Blackfish slowly teleports"). Created
            // here because createUnit is allowed on the server and not on the HC; handed over BY GROUP,
            // because a crewed vehicle's locality is its driver's (setOwner on the hull carries no one).
            private _pilotGrp = grpNull; private _pilotU = objNull;
            if ([_veh] call AP_fnc_isRotorcraft) then {
                _pilotGrp = createGroup [civilian, true];
                _pilotU = _pilotGrp createUnit ["C_man_1", [0, 0, 0], [], 0, "NONE"];
                _pilotU disableAI "ALL"; _pilotU setCaptive true; _pilotU allowDamage false;
                _pilotU moveInDriver _veh;
                _pilotU hideObjectGlobal true;
                _veh setVariable ["AP_summonPilot", _pilotU];
                _veh setVariable ["hc_ap_ai", true, true];
                // the hull was CLIENT-local (the owner's client created it); seating a server-local driver
                // moves it here. Let that transfer finish before the next one, or two are in flight at once.
                private _t = time + 6;
                waitUntil { uiSleep 0.5; local _veh || {time > _t} };
                if (!(local _veh)) then { _veh setOwner 2; _t = time + 4; waitUntil { uiSleep 0.5; local _veh || {time > _t} }; };
            };
            private _fnHand = {
                params ["_v", "_owner"];
                private _u = _v getVariable ["AP_summonPilot", objNull];
                if (isNull _u) then { _v setOwner _owner } else { (group _u) setGroupOwner _owner };
            };
            private _hc = localNamespace getVariable ["AP_hcOwner", 0];
            if (_hc <= 0) then { _outcome = "no driver available"; } else { [_veh, _hc] call _fnHand; };
            // hand-off watchdog: setOwner is occasionally a silent no-op. AP_hcOwner is
            // re-read each turn -- it drops to 0 when the HC disconnects (server_init), and setOwner 0
            // is not a hand-off.
            private _giveUp = time + 15;
            if (_outcome isEqualTo "") then {
                waitUntil { uiSleep 1;
                    _hc = localNamespace getVariable ["AP_hcOwner", 0];
                    if (_hc > 0 && {!isNull _veh} && {alive _veh} && {local _veh} && {!(_veh getVariable ["hc_ap_driving", false])} && {(_veh getVariable ["hc_ap_done", ""]) isEqualTo ""}) then {
                        _veh setVariable ["hc_ap_want", true, true];
                        [_veh, _hc] call _fnHand; };
                    (_hc <= 0) || {isNull _veh} || {!alive _veh} || {_veh getVariable ["hc_ap_driving", false]} || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time > _giveUp} };
                if (_hc <= 0) then { _outcome = "the driver went offline"; } else {
                    if (!isNull _veh && {alive _veh} && {!(_veh getVariable ["hc_ap_driving", false])} && {(_veh getVariable ["hc_ap_done", ""]) isEqualTo ""}) then {
                        _outcome = "no driver took the wheel";
                    };
                };
            };
            if (_outcome isEqualTo "") then {
                [_unit, createHashMapFromArray [["state", "enroute"], ["msg", "on its way"]]] call _fnTell;
                private _lastD = _unit distance2D _veh; private _lastT = time; private _spd = 0; private _pubT = time;
                private _hardEnd = time + 360;   // the hosts cap themselves at 280-300 s; this catches a dead HC
                while { _outcome isEqualTo "" } do {
                    uiSleep 2;
                    if (isNull _veh) exitWith { _outcome = "the vehicle vanished"; };
                    if (!alive _veh) exitWith { _outcome = "the vehicle was destroyed on the way"; };
                    if (isNull _unit || {!alive _unit}) exitWith { _outcome = "you were not there to meet it"; };
                    if (time > _hardEnd) exitWith { _outcome = "timeout"; };
                    if ((localNamespace getVariable ["AP_hcOwner", 0]) <= 0) exitWith { _outcome = "the driver went offline"; };
                    private _done = _veh getVariable ["hc_ap_done", ""];
                    if (_done isNotEqualTo "") exitWith { _outcome = _done; };
                    if (time - _pubT >= 5) then { _veh setVariable ["hc_ap_dest", getPosATL _unit, true]; _pubT = time; };
                    private _d = _unit distance2D _veh;
                    _spd = (0.7 * _spd) + (0.3 * (((_lastD - _d) / ((time - _lastT) max 0.1)) max 0));
                    _lastD = _d; _lastT = time;
                    [_unit, createHashMapFromArray [["state", "enroute"], ["dist", round _d], ["eta", if (_spd > 0.5) then { round (_d / _spd) } else { 0 }]]] call _fnTell;
                };
            };
            // ---- finish, on EVERY outcome path: hand back, pilot out, an airborne aircraft landed where it is,
            // then LOCKED like every spawn path in this codebase leaves a vehicle (the owner's keys open it).
            if (!isNull _veh) then {
                _veh setVariable ["hc_ap_want", false, true];
                _veh setVariable ["hc_ap_abort", true, true];
                _veh setVariable ["hc_ap_lock", false, true];
                _veh setVariable ["AP_summonFor", nil, true];
                [_veh, 2] call _fnHand;
                private _t = time + 6;
                waitUntil { uiSleep 0.5; isNull _veh || {local _veh} || {time > _t} };
                // on the ground: engine off, and the pilot's AI off while he is still aboard -- both need the hull /
                // the unit local, which the hand-back just made true. An AI pilot in a running helicopter takes off
                // on its own; the removal below then drops the aircraft (owner, b1010: "lands, goes up, drops").
                if (!isNull _veh && {local _veh} && {alive _veh} && {((getPos _veh) select 2) < 3}) then { _veh engineOn false; };
                if (!isNull _pilotU && {local _pilotU}) then { _pilotU disableAI "ALL"; };
                if (!isNull _veh) then {
                    ["-SUMMON-", _unit, (if (isNull _unit) then { "?" } else { name _unit }), format ["finish: %1, z=%2 engine=%3 ground=%4 local=%5 before pilot removal",
                        _outcome, round (((getPos _veh) select 2) * 10) / 10, isEngineOn _veh, isTouchingGround _veh, local _veh]] call APS_fnc_logIt;
                };
            };
            // the pilot leaves with the job, hull or no hull: deleting a vehicle does not delete its crew, and a
            // VTOL hand-over already removed him on the HC (null here). Unconditional on purpose.
            if (!isNull _pilotU) then { moveOut _pilotU; deleteVehicle _pilotU; };
            if (!isNull _pilotGrp) then { deleteGroup _pilotGrp; };
            if (!isNull _veh) then {
                _veh setVariable ["AP_summonPilot", nil];
                _veh setVariable ["hc_ap_ai", false, true];
                // crewless now: a hull the group hand-back did not return comes home by setOwner
                if (!(local _veh)) then { _veh setOwner 2; private _t = time + 6; waitUntil { uiSleep 0.5; isNull _veh || {local _veh} || {time > _t} }; };
            };
            AP_summonActive deleteAt _uid;
            private _ok = _outcome in ["arrived", "landed", "hover"];
            if (_ok) then { AP_summonCooldown set [_uid, time + 120]; };
            private _name = if (isNull _veh) then { "vehicle" } else { getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName") };
            private _msg = switch (_outcome) do {
                case "arrived"; case "landed": { format ["your %1 is here", _name] };
                case "hover": { format ["couldn't find a flat spot -- your %1 is hovering over you, climb in", _name] };
                default { format ["%1 -- your %2 stopped at %3", _outcome, _name, if (isNull _veh) then { "?" } else { mapGridPosition _veh }] };
            };
            [_unit, createHashMapFromArray [["state", if (_ok) then { "arrived" } else { "failed" }], ["msg", _msg], ["dist", 0], ["eta", 0], ["cooldown", if (_ok) then { 120 } else { 0 }]]] call _fnTell;
            ["-SUMMON-", _unit, name _unit, format ["%1: %2 (%3)", _outcome, _name, if (isNull _veh) then { "?" } else { mapGridPosition _veh }]] call APS_fnc_logIt;
            // R2: the player is told and the slot freed BEFORE the (up to 130 s) emergency landing below
            if (!isNull _veh) then {
                // an aircraft still in the air on a non-landed outcome (timeout, driver offline, summoner gone)
                // is landed by the scripted core right where it is, shield on -- never engine-off at altitude
                // "hover" is an intended end state (a helicopter holding beside the summoner for boarding), not an airborne failure
                if (_outcome isNotEqualTo "hover" && {!isNull _veh} && {alive _veh} && {local _veh} && {[_veh] call AP_fnc_isRotorcraft} && {((getPos _veh) select 2) > 3}) then {
                    _veh setVariable ["hc_ap_abort", false, true];
                    _veh setVariable ["hc_ap_done", "", true];
                    _veh setVariable ["hc_ap_dest", getPosATL _veh, true];   // the core follows hc_ap_dest every frame: land HERE, not at the summoner
                    _veh setVariable ["fly_phase", "", true];
                    _veh setVariable ["fly_alt", nil];
                    ["-SUMMON-", _unit, (if (isNull _unit) then { "?" } else { name _unit }), format ["%1: landing the aircraft where it is (%2 m up)", _outcome, round ((getPos _veh) select 2)]] call APS_fnc_logIt;
                    if ([_veh, getPosATL _veh, 120] call AP_fnc_hcFly) then {
                        private _t = time + 130;
                        waitUntil { uiSleep 1; isNull _veh || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time > _t} };
                    };
                    if (!isNull _veh) then { _veh setVariable ["hc_ap_abort", true, true]; };
                };
                if (!isNull _veh) then {
                    _veh lock true;
                    if (alive _veh && {((getPos _veh) select 2) < 3}) then { _veh engineOn false; };
                };
            };
            // ---- REFUND (owner 2026-09-03): a vehicle wrecked while the summon still owns it -- in the air, on
            // the landing, or in the seconds after touchdown before anyone has climbed in -- goes back to the
            // garage as it was pulled: the row's damage / fuel / ammo from BEFORE the summon (a wreck in transit
            // is not a free repair), the trunk read off the wreck through the one store path (DB_fnc_updateVehicle,
            // contraband kept as the reaper keeps it: the player did not choose to store), then the wreck removed
            // so the plate exists in ONE place. Server-witnessed only: `alive` of the object THIS attempt bound
            // at "drive", never a client report. The grace window closes the moment a player boards -- from then
            // on the vehicle is theirs and a wreck follows the normal path.
            private _refund = false;
            if (!isNull _veh) then {
                if (alive _veh) then {
                    private _t = time + 20; private _boarded = false;
                    while { !isNull _veh && {alive _veh} && {!_boarded} && {time < _t} } do {
                        uiSleep 0.5;
                        if (!isNull _veh && {(crew _veh) findIf { isPlayer _x } >= 0}) then { _boarded = true; };
                    };
                    _refund = !isNull _veh && {!alive _veh} && {!_boarded};
                } else { _refund = true; };
            };
            private _who = if (isNull _unit) then { "?" } else { name _unit };
            if (_refund) then {
                private _plate = _row select 3;
                private _have = [format ["SELECT id FROM %1 WHERE pid='%2' AND plate='%3'", "vehicles", _uid, _plate], 2] call DB_fnc_asyncQuery;
                if (!(_have isEqualType []) || {_have isEqualTo []}) then {
                    ["-SUMMON-", _unit, _who, format ["refund skipped: no row for %1 plate %2", _name, _plate]] call APS_fnc_logIt;
                } else {
                    private _al = if ((_row select 6) in [1, true]) then { 1 } else { 0 };
                    [_plate, _uid, _veh, 0, _al, 0, true, true] call DB_fnc_updateVehicle;   // active=0 + trunk off the wreck, blocking
                    [format ["UPDATE %1 SET alive = true, damage='%2', fuel='%3', ammo='%4' WHERE pid='%5' AND plate='%6'",
                        "vehicles", _row select 9, _row select 8, _row param [12, 0], _uid, _plate], 2] call DB_fnc_asyncQuery;
                    { deleteVehicle _x } forEach (attachedObjects _veh);
                    deleteVehicle _veh;
                    [_unit, createHashMapFromArray [["state", "failed"], ["msg", format ["your %1 was wrecked on the way -- it is back in your garage", _name]], ["dist", 0], ["eta", 0], ["cooldown", 0]]] call _fnTell;
                    ["-SUMMON-", _unit, _who, format ["refund: %1 plate %2 wrecked (%3) -> garage, damage back to %4", _name, _plate, _outcome, _row select 9]] call APS_fnc_logIt;
                };
            } else {
                if (!isNull _veh) then { _veh setVariable ["insured", _wasInsured]; };
            };
        };
    };

    case "selftest": {
        // bot_commands harness: spawn a test vehicle ~1 km from respawn_civilian and bring it there.
        // remoteExecutedOwner 0 = a server-local call (what the bot_commands dispatcher is; a headless
        // client reports 0 too, and it is trusted). Never a player.
        if (_src isNotEqualTo 0) exitWith {};
        private _kind = if (isNil "_arg") then { "car" } else { toLower (format ["%1", _arg]) };
        // "+pilot": seat a hidden, AI-disabled pilot before the hand-off (server-side createUnit is allowed;
        // the HC's is not). With a pilot aboard the flight model integrates setVelocity itself, so the
        // aircraft's velocity is real and goes over the network -- the pilotless kinematic path moves
        // it by setPosASL, which other machines see as position steps with no interpolation (owner:
        // "my Blackfish slowly teleports"). Experiment 2026-09-02; production adopts it if it flies.
        // "+ai": the pilot keeps his AI and the engine flies it (AP_fnc_hcFlyAI); "+pilot": AI off, scripted core
        private _ai = "+ai" in _kind;
        private _pilot = _ai || {"+pilot" in _kind};
        if (_pilot) then { _kind = (_kind splitString "+") select 0; };
        private _hc = localNamespace getVariable ["AP_hcOwner", 0];
        if (_hc <= 0) exitWith { diag_log format ["[SUMMON-TEST] kind=%1 outcome=nohc", _kind]; };
        private _cls = switch (_kind) do { case "heli": { "C_Heli_Light_01_civil_F" }; case "vtol": { "B_T_VTOL_01_infantry_F" }; default { "C_Offroad_01_F" } };
        private _isAir = _kind in ["heli", "vtol"];
        // destination: arg2 as "x:y" or a marker name; default the civilian respawn (a town square, so a
        // rotorcraft ends in "hover" there -- give open ground to exercise "landed")
        private _a2 = format ["%1", _this param [2, ""]];
        private _dest = getMarkerPos "respawn_civilian";
        if (":" in _a2) then {
            private _xy = _a2 splitString ":"; _dest = [parseNumber (_xy select 0), parseNumber (_xy select 1), 0];
        } else { if (_a2 isNotEqualTo "" && {getMarkerType _a2 isNotEqualTo ""}) then { _dest = getMarkerPos _a2; }; };
        private _sp = [_dest, _isAir] call AP_fnc_summonPoint;
        if (_sp isEqualTo []) exitWith { diag_log format ["[SUMMON-TEST] kind=%1 outcome=nospawnpoint", _kind]; };
        private _veh = createVehicle [_cls, [_sp select 0, _sp select 1, 0.6], [], 0, "CAN_COLLIDE"];
        _veh setDir (_sp select 3);
        _veh setVariable ["owner", "summontest", true];
        _veh setVariable ["hc_ap_arrive", 8, true];
        _veh setVariable ["hc_ap_mode", "normal", true];
        _veh setVariable ["hc_ap_dest", _dest, true];
        _veh setVariable ["hc_ap_done", "", true];
        _veh setVariable ["hc_ap_want", true, true];
        _veh setVariable ["hc_ap_probe", true, true];   // hcDrive/hcFly log [HCDRIVE-PROBE] every 2 s for this vehicle
        if (_pilot) then {
            private _grp = createGroup [civilian, true];
            // created at the map corner, never at the aircraft: a unit spawned inside the Blackfish hull collided
            // with it and wrecked it on the server before the hand-off (b0844 vtol+pilot); moveInDriver teleports
            private _u = _grp createUnit ["C_man_1", [0, 0, 0], [], 0, "NONE"];
            // AI OFF here for both variants: an AI pilot live on the server for the second before the hand-off
            // began a take-off that the locality change cut in half (b0855: VTOL airborne and falling at
            // hand-off, pilot named as the crash source). The HC's AI flight host enables it once it owns him.
            _u disableAI "ALL";
            _u setCaptive true; _u allowDamage false;
            if (_ai) then { _veh setVariable ["hc_ap_ai", true, true]; };
            _u moveInDriver _veh;
            _u hideObjectGlobal true;
            _veh setVariable ["AP_summonPilot", _u];
            diag_log format ["[SUMMON-TEST] pilot seated: driver=%1 local=%2", typeOf (driver _veh), local _u];
        };
        private _t0 = time;
        // a CREWED vehicle's locality follows its driver's group: hand the pilot's group over with
        // setGroupOwner (setOwner on the hull left the HC seeing no driver at all -- b0845 probe drv=)
        private _fnHand = {
            params ["_v", "_owner"];
            private _u = _v getVariable ["AP_summonPilot", objNull];
            if (isNull _u) then { _v setOwner _owner } else { (group _u) setGroupOwner _owner };
        };
        [_veh, _hc] call _fnHand;
        [_veh, _dest, _sp] spawn {   // diagnostics: where it spawned, and whether it moves at all
            params ["_veh", "_dest", "_sp"];
            diag_log format ["[SUMMON-TEST] spawn=%1 onRoad=%2 slopeDeg=%3 near8m=%4", _sp apply { round (_x * 10) / 10 }, isOnRoad _veh,
                round (acos ((surfaceNormal (getPosATL _veh)) select 2)), ((nearestObjects [_veh, [], 8]) apply { typeOf _x }) select [0, 6]];
            private _p0 = getPosATL _veh;
            for "_i" from 1 to 18 do {
                uiSleep 5;
                if (isNull _veh) exitWith {};
                diag_log format ["[SUMMON-TEST] t=%1 pos=%2 spd=%3 dir=%4 driving=%5 done=%6 owner=%7 dist=%8", _i * 5,
                    (getPosATL _veh) apply { round _x }, round (speed _veh), round getDir _veh, _veh getVariable ["hc_ap_driving", false],
                    _veh getVariable ["hc_ap_done", ""], owner _veh, round (_veh distance2D _dest)];
                // fast fail: a vehicle that has not moved 5 m in 60 s is not going to; abort so the run ends in
                // a minute with the probes above as the evidence, not five minutes later as a bare timeout
                if (_i >= 12 && {((getPosATL _veh) distance _p0) < 5} && {(_veh getVariable ["hc_ap_done", ""]) isEqualTo ""}) exitWith {
                    diag_log "[SUMMON-TEST] no movement in 60 s -> hc_ap_abort";
                    _veh setVariable ["hc_ap_abort", true, true];
                };
            };
        };
        private _pilotU = _veh getVariable ["AP_summonPilot", objNull];
        [_veh, _dest, _kind, _t0, _fnHand, _pilotU] spawn {
            params ["_veh", "_dest", "_kind", "_t0", "_fnHand", "_pilotU"];
            private _giveUp = time + 15;
            waitUntil { uiSleep 1;
                private _hc = localNamespace getVariable ["AP_hcOwner", 0];
                if (_hc > 0 && {!isNull _veh} && {local _veh} && {!(_veh getVariable ["hc_ap_driving", false])} && {(_veh getVariable ["hc_ap_done", ""]) isEqualTo ""}) then { [_veh, _hc] call _fnHand; };
                (isNull _veh) || {_veh getVariable ["hc_ap_driving", false]} || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time > _giveUp} };
            waitUntil { uiSleep 2; (isNull _veh) || {!alive _veh} || {(_veh getVariable ["hc_ap_done", ""]) isNotEqualTo ""} || {time - _t0 > 330} };
            private _done = if (isNull _veh) then { "vanished" } else { _veh getVariable ["hc_ap_done", "timeout"] };
            if (_done isEqualTo "") then { _done = "timeout"; };
            private _d = if (isNull _veh) then { -1 } else { round (_veh distance2D _dest) };
            diag_log format ["[SUMMON-TEST] kind=%1 outcome=%2 dist=%3 t=%4 dmg=%5", _kind, _done, _d, round (time - _t0), if (isNull _veh) then { -1 } else { round ((damage _veh) * 100) / 100 }];
            if (!isNull _veh) then { [_veh, 2] call _fnHand; uiSleep 1; };
            if (!isNull _pilotU) then { private _g = group _pilotU; deleteVehicle _pilotU; if (!isNull _g) then { deleteGroup _g; }; };
            if (!isNull _veh) then { deleteVehicle _veh; };
        };
    };
};
