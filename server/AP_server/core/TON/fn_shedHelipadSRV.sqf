/*
    APS_fnc_shedHelipadSRV  (LooneyBin, owner 2026-07-10)
    SHED HELIPAD UPGRADE -- owner-designed 3DEN composition (a raised concrete deck w/ guardrails, two pier
    ladders, wall poles + the pad decal) bolted onto any owned industrial shed, plus the flag that turns the
    shed into an AIR garage spawn point.

    DATA: AP_heliPadComp members are SHED-RELATIVE [class, [dx,dy,dz], relDirDeg], captured from the owner's
    Eden composition via tools/compExport.sqf with the reference shed at heading 0. Spawn = rigid transform:
    world = shedPosWorld + Rz(shedDir)*offset, setPosWorld (exact round-trip of the capture frame, slope-proof).

    PERMANENT (owner 2026-07-10, v2): pads spawn at BOOT for every helipad=1 shed and stay up -- the pieces
    are sim-disabled statics (zero per-frame cost; only a one-time spawn + JIP sync burst), so presence
    despawning saved nothing and dropped parked helicopters to their death when the deck vanished under
    them. Spawns instantly on purchase. The only teardown is a server restart.

    Modes:
      ["buy", _house, _player]   owner-gated purchase: writes houses.helipad=1, tags AP_helipad, spawns now
      ["presenceStart"]          boot: build the cache from the DB + start the watcher
    The AIR pull itself rides the standard property garage (fn_vehicleGaragePull): an upgraded shed spawns
    Air pulls dead-centre on the pad, nose along the shed's facing.
*/
params [["_mode", "", [""]]];

AP_heliPadComp = [["Land_ConcretePanels_02_single_v2_F", [-8.799, 7.246, 4.791], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-7.055, 7.252, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-3.672, 7.264, 4.799], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [-5.416, 7.258, 4.803], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [-1.822, 7.266, 4.791], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-0.078, 7.272, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [3.305, 7.284, 4.799], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [1.561, 7.278, 4.803], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [-8.789, 3.407, 4.791], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-7.045, 3.412, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-8.791, -0.441, 4.799], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-7.047, -0.435, 4.803], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-3.664, -0.423, 4.791], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [-5.408, -0.429, 4.795], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [-3.662, 3.424, 4.799], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [-5.406, 3.418, 4.803], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [-1.812, 3.426, 4.791], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-0.068, 3.432, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-1.814, -0.421, 4.799], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [-0.070, -0.416, 4.803], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [3.313, -0.404, 4.791], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [1.569, -0.410, 4.795], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [3.315, 3.444, 4.799], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [1.571, 3.438, 4.803], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [5.121, 7.278, 4.791], 0.0], ["Land_ConcretePanels_02_single_v2_F", [6.865, 7.284, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [10.248, 7.295, 4.799], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [8.504, 7.289, 4.803], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [12.098, 7.297, 4.791], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [13.842, 7.303, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [15.481, 7.309, 4.799], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [5.131, 3.438, 4.803], 0.0], ["Land_ConcretePanels_02_single_v2_F", [6.875, 3.444, 4.791], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [5.129, -0.410, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [6.873, -0.404, 4.799], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [10.256, -0.392, 4.803], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [8.512, -0.398, 4.791], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [10.258, 3.455, 4.795], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [8.514, 3.450, 4.799], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [12.108, 3.457, 4.803], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [13.852, 3.463, 4.791], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [12.106, -0.390, 4.795], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [13.850, -0.384, 4.799], 0.0],
    ["Land_ConcretePanels_02_single_v2_F", [15.488, -0.379, 4.803], 180.0],
    ["Land_ConcretePanels_02_single_v2_F", [15.490, 3.469, 4.791], 180.0], ["Land_PipeFence_02_s_4m_F", [14.356, -2.236, 4.139], 0.0],
    ["Land_PipeFence_02_s_4m_F", [14.340, 9.075, 4.139], 358.8], ["Land_PipeFence_02_s_4m_F", [-7.652, 9.045, 4.139], 180.3],
    ["Land_PipeFence_02_s_4m_F", [-7.527, -2.142, 4.139], 179.0], ["Land_PipeFence_02_s_4m_F", [-2.732, 9.090, 4.139], 180.3],
    ["Land_PipeFence_02_s_4m_F", [2.328, 9.088, 4.139], 180.3], ["Land_PipeFence_02_s_4m_F", [6.326, 9.069, 4.139], 180.3],
    ["Land_PipeFence_02_s_4m_F", [10.326, 9.045, 4.139], 180.3], ["Land_PipeFence_02_s_4m_F", [10.340, -2.230, 4.139], 180.3],
    ["Land_PipeFence_02_s_4m_F", [6.332, -2.226, 4.139], 180.3], ["Land_PipeFence_02_s_4m_F", [2.330, -2.207, 4.139], 180.3],
    ["Land_PierLadder_F", [-10.193, 3.061, 2.237], 89.3], ["Land_HelipadSquare_F", [3.351, 3.436, 5.341], 0.0]];

if (isNil "AP_heliPads") then { AP_heliPads = createHashMap; };   // oid -> [shed, ownerUID, spawned[], gangMembers[], gangTs]

// rigid spawn of the whole comp anchored to a shed -> returns spawned objects
if !(isFinal "AP_fnc_heliPadSpawn") then {AP_fnc_heliPadSpawn = compileFinal {params ["_shed"];
    private _a = getPosWorld _shed;
    private _dir = getDir _shed;
    private _c = cos _dir; private _s = sin _dir;
    private _made = []; {_x params ["_cls", "_off", "_rel"];
        _off params ["_ox", "_oy", "_oz"];
        private _o = createVehicle [_cls, [0, 0, -100], [], 0, "CAN_COLLIDE"];
        _o setDir (_dir + _rel);
        _o setPosWorld [(_a select 0) + (_ox * _c) + (_oy * _s), (_a select 1) - (_ox * _s) + (_oy * _c), (_a select 2) + _oz];
        _o enableSimulationGlobal false;
        _o allowDamage false;
        _o setVariable ["owner", "AP_helipad"];   // exempt from the ownerless-object reap (fn_cleanup)
        _made pushBack _o;} forEach AP_heliPadComp;
    _made}};

switch (toLower _mode) do {case "buy": {params ["", ["_house", objNull, [objNull]], ["_player", objNull, [objNull]]];
        if (isNull _house || isNull _player) exitWith {};
        private _uid = getPlayerUID _player;
        if !(typeOf _house isEqualTo "Land_i_Shed_Ind_F") exitWith {};
        // owner 2026-07-28, caught in review: resolve the AUTHENTICATED caller and credit the -SEC- row
        // below to THAT, never to _player. _player is client-supplied -- the client action sends [player]
        // (core/housing/fn_buyHelipad.sqf:27) and this case performs NO caller authentication at all (the
        // ownership guard below tests the NAMED player, not the sender), so a modified client can put any
        // player's object in the payload and manufacture ban-table evidence against them.
        // remoteExecutedOwner is the engine's own answer to which machine actually sent the call and cannot
        // be forged client-side; it reads 0 for a server-internal call and for a Headless Client, and both
        // of those log objNull rather than guessing. Same shape as f41e47c (jewelry weldSafe) and a761d6e
        // (Loony Bin breach). Resolved HERE rather than at the top of the case: nothing above this line
        // logs, and the cheap null/class guards should not pay for an allPlayers scan.
        // NESTED-exitWith NOTE: the exitWith below sits inside case "buy", so it leaves the CASE BLOCK, not
        // the function. That is terminal in effect ONLY because this switch is the last statement in the
        // file -- relied on deliberately here, and it stops being true the moment anything is appended
        // after the switch. Anyone adding a statement after it must re-check every exitWith in both cases.
        private _srcHP = remoteExecutedOwner;   // 0 == server-internal (or HC) = no client to blame
        private _hpCaller = if (_srcHP isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _srcHP }) param [0, objNull] };
        // owner 2026-09-26 SECURITY (audit TONd-0-0): the gate tested the NAMED _player against the client-writable
        // AP_homeOwner, and the oid came from AP_houseID. The buyer is now the caller and owner + oid come from the
        // houses ROW (APS_fnc_houseRights).
        if (_srcHP isNotEqualTo 0) then { _player = _hpCaller; _uid = getPlayerUID _hpCaller; };
        private _rights = [_house] call APS_fnc_houseRights;
        if (isNull _player || {(_rights select 1) isEqualTo ""} || {(_rights select 1) isNotEqualTo _uid}) exitWith {
            ["-SEC-", _hpCaller, format ["BLOCKED helipad buy (not owner) oid=%1", _rights select 0]] call APS_fnc_logIt;
        };
        if (_house getVariable ["AP_helipad", false]) exitWith {};
        private _oid = _rights select 0;
        if (_oid in ["-1", ""]) exitWith {
            [["The realtor can't register a helipad on this building (no house record).", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        ["UPDATE houses SET helipad = 1 WHERE oid = %s", 1, false, [_oid]] call DB_fnc_asyncQuery;
        _house setVariable ["AP_helipad", true, true];
        private _objs = [_house] call AP_fnc_heliPadSpawn;   // buyer is online -> occupied -> spawn NOW
        AP_heliPads set [_oid, [_house, _uid, _objs, [], -1e9]];
        ["-HELIPAD-", _player, format ["bought shed helipad oid=%1 (%2 pieces up)", _oid, count _objs]] call APS_fnc_logIt;
        [["Helipad constructed! Your air vehicles can now be pulled from this shed's Helipad Garage.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        diag_log format ["[LooneyBin][helipad] BUY oid=%1 by %2 -> %3 pieces", _oid, _uid, count _objs];};
    case "presencestart": {
        // boot-only (init.sqf); a client-sent one re-spawned every helipad on top of the live set (houses review 2026-09-26).
        // Leaves the case = the file's last statement.
        if (remoteExecutedOwner isNotEqualTo 0) exitWith {};
        private _rows = ["SELECT oid, worldspace, owners FROM houses WHERE helipad=1", 2, true] call DB_fnc_asyncQuery;
        if (_rows isEqualType []) then {{private _oid = format ["%1", _x param [0, ""]];
                private _ws = parseSimpleArray format ["%1", _x param [1, "[]"]];
                private _own = format ["%1", _x param [2, ""]];
                if (_ws isEqualType [] && {count _ws >= 2}) then {
                    private _shed = (nearestObjects [_ws, ["Land_i_Shed_Ind_F"], 18]) param [0, objNull];
                    if (!isNull _shed) then {_shed setVariable ["AP_helipad", true, true];
                        private _objs = [_shed] call AP_fnc_heliPadSpawn;
                        AP_heliPads set [_oid, [_shed, _own, _objs, [], -1e9]];} else {
                        diag_log format ["[LooneyBin][helipad] presenceStart: no shed at %1 for oid=%2", _ws, _oid];};};} forEach _rows;};
        private _up = 0;
        { _up = _up + count (_y select 2); } forEach AP_heliPads;
        diag_log format ["[LooneyBin][helipad] boot: %1 upgraded shed(s), %2 pieces spawned (permanent)", count AP_heliPads, _up];};};
