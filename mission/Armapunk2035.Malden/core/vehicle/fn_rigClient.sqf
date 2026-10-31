/*
    AP_fnc_rigClient -- the RESOURCE EXTRACTOR / PROCESSOR visuals (traded in
    2026-08-27; implemented to the donor's contract, renamed to this project).

    The networked HEMTT is the authoritative gameplay entity. Everything this
    file makes is CLIENT-LOCAL presentation: three simple objects (pivot, arm,
    bit) for an extractor, one for a processor, attachTo'd to the truck.
    Nothing here is networked, simulated, or trusted -- the server owns the
    logical state (AP_rigState) and this renders it.

        ["init", _truck]        (server -> every client, JIP-keyed) idempotent
        ["cleanup", _truck]     delete this client's parts

    The transition/mining animation runs from the truck's published state vars:
        AP_rigKind        "extractor" | "processor"
        AP_rigState       compact | deploying | deployed | startingMining |
                          mining | stoppingMining | folding
        AP_rigTransition  [from, to, startServerTime, duration]
    Clients >350m from the truck snap instead of animating.
*/
// HC/server draw nothing, and must not define or run the helpers below: rigSRV targets 0, and a
// lazily defined helper there is one another client could publicVariable first (security 2026-09-26).
// Clients define them at init (core\init.sqf calls this with "boot"; no truck, so it stops at params).
if (!hasInterface) exitWith {};

if (isRemoteExecuted && {!isRemoteExecutedJIP} && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only; a JIP replay was queued by the server (CfgRE jip = 0 bars client JIP)
// ── tuned configuration (the donor's exact numbers; the formulas are the
//    authority, the comment-table in rig.md is the debugging check) ──────────
AP_rigAllPosAdd        = [0.0420, 1.00, 0.10];
AP_rigSharedPivotPos   = [0.00, -5.35, -0.32];
AP_rigPivotPos         = [0.127, -2.75, -0.40];
AP_rigPivotRot         = [180, 0, 0];
AP_rigArmCompactPos    = [0.00, -3.25, 0.00];
AP_rigArmCompactRot    = [180, 0, 0];
AP_rigArmDeployedRot   = [180, -90, 0];
AP_rigBitCompactPos    = [0.00, -3.75, 0.32];
AP_rigBitCompactRot    = [180, 0, 0];
AP_rigBitDeployedRot   = [180, -90, 0];
AP_rigBitMiningDrop    = 1.50;
AP_rigBitMiningDur     = 1.15;
AP_rigBitSpinDps       = 1080;
AP_rigBitSpinTick      = 0.025;
AP_rigTransitionDur    = 5.00;
AP_rigAnimDistance     = 350;
AP_rigProcessorPos     = [0.05, -0.23, 0.18];
AP_rigProcessorRot     = [180, 0, 0];

// ── rotation math (Rodrigues; SQF trig is degrees) ──────────────────────────
if !(isFinal "AP_fnc_rigRotAxis") then {AP_fnc_rigRotAxis = compileFinal {
    params ["_vector", "_axis", "_degrees"];
    private _axisLength = sqrt ((_axis vectorDotProduct _axis) max 0.0001);
    private _a = _axis vectorMultiply (1 / _axisLength);
    private _c = cos _degrees;
    private _s = sin _degrees;
    private _dot = _a vectorDotProduct _vector;
    private _cross = _a vectorCrossProduct _vector;
    (_vector vectorMultiply _c)
        vectorAdd (_cross vectorMultiply _s)
        vectorAdd (_a vectorMultiply (_dot * (1 - _c)))
}};
if !(isFinal "AP_fnc_rigRotToVec") then {AP_fnc_rigRotToVec = compileFinal {
    params ["_rot"];
    private _yaw = _rot param [0, 0];
    private _pitch = _rot param [1, 0];
    private _roll = _rot param [2, 0];
    private _dir = [(sin _yaw) * (cos _pitch), (cos _yaw) * (cos _pitch), sin _pitch];
    private _up  = [-((sin _yaw) * (sin _pitch)), -((cos _yaw) * (sin _pitch)), cos _pitch];
    if !(_roll isEqualTo 0) then { _up = [_up, _dir, _roll] call AP_fnc_rigRotAxis; };
    [_dir, _up]
}};
// The arm and bit ORBIT the shared hinge -- interpolating their rotations in
// place spins each part around its own centre and the assembly comes apart.
if !(isFinal "AP_fnc_rigOrbit") then {AP_fnc_rigOrbit = compileFinal {
    params ["_compactPos", "_pivotPos", "_compactRot", "_targetRot", "_extraPos"];
    private _vectors = [_compactRot] call AP_fnc_rigRotToVec;
    private _dir = _vectors select 0;
    private _up = _vectors select 1;
    private _right = _dir vectorCrossProduct _up;
    private _deltaPitch = (_targetRot select 1) - (_compactRot select 1);
    private _relative = _compactPos vectorDiff _pivotPos;
    private _rotated = [_relative, _right, _deltaPitch] call AP_fnc_rigRotAxis;
    (_pivotPos vectorAdd _rotated) vectorAdd _extraPos
}};

// deployed positions, computed ONCE from the orbit (then AllPosAdd, once)
AP_rigArmDeployedPos = ([AP_rigArmCompactPos, AP_rigSharedPivotPos, AP_rigArmCompactRot, AP_rigArmDeployedRot, [0,0,0]] call AP_fnc_rigOrbit) vectorAdd AP_rigAllPosAdd;
AP_rigBitDeployedPos = ([AP_rigBitCompactPos, AP_rigSharedPivotPos, AP_rigBitCompactRot, AP_rigBitDeployedRot, [0,0,0]] call AP_fnc_rigOrbit) vectorAdd AP_rigAllPosAdd;
AP_rigBitMiningPos   = AP_rigBitDeployedPos vectorAdd [0, 0, -AP_rigBitMiningDrop];
AP_rigArmCompactPosF = AP_rigArmCompactPos vectorAdd AP_rigAllPosAdd;
AP_rigBitCompactPosF = AP_rigBitCompactPos vectorAdd AP_rigAllPosAdd;
AP_rigPivotPosF      = AP_rigPivotPos vectorAdd AP_rigAllPosAdd;

private _applyPart = {
    params ["_part", "_truck", "_pos", "_rot"];
    if (isNull _part) exitWith {};
    _part attachTo [_truck, _pos];
    private _v = [_rot] call AP_fnc_rigRotToVec;
    _part setVectorDirAndUp [_v select 0, _v select 1];
};

private _makePart = {
    params ["_truck", "_file", "_pos", "_rot"];
    private _part = createSimpleObject [getMissionPath format ["custom_p3ds\%1", _file], getPosASL _truck, true];
    if (isNull _part) exitWith { objNull };
    [_part, _truck, _pos, _rot] call _applyPart;
    _part
};

params [["_mode", "", [""]], ["_truck", objNull, [objNull]]];
if (isNull _truck && {_mode isNotEqualTo ""}) exitWith {};

switch (toLower _mode) do {

case "cleanup": {
    { detach _x; deleteVehicle _x; } forEach (_truck getVariable ["AP_rigParts", []]);
    _truck setVariable ["AP_rigParts", []];
    _truck setVariable ["AP_rigAnimUp", false];
};

case "init": {
    if (hasInterface isEqualTo false) exitWith {};   // HC/server draw nothing
    // idempotent: a second init (JIP replay, rebuild) deletes before creating
    ["cleanup", _truck] call AP_fnc_rigClient;
    private _kind = _truck getVariable ["AP_rigKind", ""];
    if (_kind isEqualTo "processor") exitWith {
        private _p = [_truck, "ap_rig_processor.p3d", AP_rigProcessorPos, AP_rigProcessorRot] call _makePart;
        _truck setVariable ["AP_rigParts", [_p]];
    };
    if (_kind isNotEqualTo "extractor") exitWith {};
    private _pivot = [_truck, "ap_rig_pivot.p3d", AP_rigPivotPosF, AP_rigPivotRot] call _makePart;
    private _arm   = [_truck, "ap_rig_arm.p3d",   AP_rigArmCompactPosF, AP_rigArmCompactRot] call _makePart;
    private _bit   = [_truck, "ap_rig_bit.p3d",   AP_rigBitCompactPosF, AP_rigBitCompactRot] call _makePart;
    _truck setVariable ["AP_rigParts", [_pivot, _arm, _bit]];

    // one animation driver per client per truck, alive while the truck is
    if (_truck getVariable ["AP_rigAnimUp", false]) exitWith {};
    _truck setVariable ["AP_rigAnimUp", true];
    [_truck, _applyPart] spawn {
        params ["_truck", "_applyPart"];
        private _lerpV = {
            params ["_a", "_b", "_t"];
            [(_a select 0) + (((_b select 0) - (_a select 0)) * _t),
             (_a select 1) + (((_b select 1) - (_a select 1)) * _t),
             (_a select 2) + (((_b select 2) - (_a select 2)) * _t)]
        };
        private _layout = {
            // stable-state layout: [armPos, armRot, bitPos, bitRot]
            params ["_state", "_spin"];
            switch (_state) do {
                case "deployed": { [AP_rigArmDeployedPos, AP_rigArmDeployedRot, AP_rigBitDeployedPos, AP_rigBitDeployedRot] };
                case "mining":   { [AP_rigArmDeployedPos, AP_rigArmDeployedRot, AP_rigBitMiningPos,
                                    [AP_rigBitDeployedRot select 0, AP_rigBitDeployedRot select 1, _spin]] };
                default          { [AP_rigArmCompactPosF, AP_rigArmCompactRot, AP_rigBitCompactPosF, AP_rigBitCompactRot] };
            }
        };
        private _spin = 0;
        // SOUND is state-driven and client-local like everything else here: the
        // deploy sweep fires once per transition START (tracked by t0 so a JIP
        // mid-transition does not replay it from the beginning of time), and the
        // 1.75s drill segment re-triggers on its own duration while mining.
        private _sndT0 = -1;
        private _nextDrill = 0;
        while { !isNull _truck && { count (_truck getVariable ["AP_rigParts", []]) isEqualTo 3 } } do {
            (_truck getVariable ["AP_rigParts", []]) params [["_pivot", objNull], ["_arm", objNull], ["_bit", objNull]];
            private _state = _truck getVariable ["AP_rigState", "compact"];
            private _far = (player distance _truck) > AP_rigAnimDistance;

            if (!_far) then {
                if (_state in ["deploying", "folding"]) then {
                    private _t0s = (_truck getVariable ["AP_rigTransition", [0,0,0,0]]) param [2, 0];
                    if (_t0s isNotEqualTo _sndT0 && {(serverTime - _t0s) < 1}) then {
                        _sndT0 = _t0s;
                        _truck say3D ["ap_rig_deploy", 120];
                    };
                };
                if (_state isEqualTo "mining" && {serverTime >= _nextDrill}) then {
                    _truck say3D ["ap_rig_drill", 140];
                    _nextDrill = serverTime + 1.7;   // hair under the segment: no gap, no stack
                };
            };
            if (_state in ["deploying", "folding", "startingMining", "stoppingMining"] && {!_far}) then {
                (_truck getVariable ["AP_rigTransition", ["compact", "compact", serverTime, 1]])
                    params ["_from", "_to", "_t0", "_dur"];
                private _raw = ((serverTime - _t0) / _dur) max 0 min 1;
                private _t = _raw * _raw * (3 - 2 * _raw);   // smoothstep
                private _A = [[_from] call { params ["_s"]; if (_s isEqualTo "mining") then {"mining"} else { if (_s in ["deployed"]) then {"deployed"} else {"compact"} } }, _spin] call _layout;
                private _B = [[_to]   call { params ["_s"]; if (_s isEqualTo "mining") then {"mining"} else { if (_s in ["deployed"]) then {"deployed"} else {"compact"} } }, _spin] call _layout;
                private _armPos = [_A select 0, _B select 0, _t] call _lerpV;
                private _bitPos = [_A select 2, _B select 2, _t] call _lerpV;
                private _armRot = [_A select 1, _B select 1, _t] call _lerpV;
                private _bitRot = [_A select 3, _B select 3, _t] call _lerpV;
                [_arm, _truck, _armPos, _armRot] call _applyPart;
                [_bit, _truck, _bitPos, _bitRot] call _applyPart;
                uiSleep AP_rigBitSpinTick;
            } else {
                // stable state, or too far: snap. Mining adds the spin locally.
                if (_state isEqualTo "mining" && {!_far}) then {
                    _spin = (_spin + AP_rigBitSpinDps * AP_rigBitSpinTick) mod 360;
                };
                private _L = [_state, _spin] call _layout;
                [_arm, _truck, _L select 0, _L select 1] call _applyPart;
                [_bit, _truck, _L select 2, _L select 3] call _applyPart;
                uiSleep ([0.5, AP_rigBitSpinTick] select (_state isEqualTo "mining" && {!_far}));
            };
        };
        _truck setVariable ["AP_rigAnimUp", false];
    };
};

};
