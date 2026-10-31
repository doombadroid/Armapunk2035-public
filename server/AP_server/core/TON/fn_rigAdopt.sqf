/*
    APS_fnc_rigAdopt -- stamp RESOURCE RIG identity onto an EXISTING truck (moved out of APS_fnc_rigSRV "adopt",
    audit 2026-09-26, mints).

        [_truck, "extractor"|"processor"] call APS_fnc_rigAdopt;

    Callers (all server code): APS_fnc_rigSRV "spawn"/"craft" on the truck they just made, APS_fnc_vehicleSetActive
    on a garage pull and DB_fnc_restoreVehicles at boot, both from the truck's own DB row (rig_kind). One copy of the
    identity, whatever door the truck came through. Never touches AP_vinv: a garage pull restores the stored trunk
    and clobbering it here would eat the hopper.

    DELIBERATELY ABSENT FROM CfgRE.hpp -- that absence is the whole gate. As a verb of the whitelisted rigSRV, any
    client could turn any truck it held keys to into a working extractor without crafting one.
*/
if (!isServer) exitWith {};
params [["_truck", objNull, [objNull]], ["_kind", "", [""]]];
if (isNull _truck || {!(_kind in ["extractor", "processor"])}) exitWith {};
{
    _truck setObjectTextureGlobal _x;
} forEach [
    [0, "images\rig\rig_hemtt1.jpg"],
    [1, "images\rig\rig_hemtt2.jpg"],
    [2, "images\rig\rig_hemtt3.jpg"]
];
_truck setVariable ["AP_rigKind", _kind, true];
// The SERVER's copy. AP_rigKind above is for the clients' UI, and any client can setVariable a public object var,
// so a keyed plain flatbed stamped "extractor" would pass every rigSRV gate that read it. Not an object var at all
// (audit 2026-09-26, mints2): a client's public setVariable overwrites an UNpublished one of the same name on the
// server too. localNamespace, keyed by netId, is out of the network's reach. rigSRV's gates and
// APS_fnc_vehicleCreate's rig_kind column read only this one.
localNamespace setVariable ["APS_rigKind_" + netId _truck, _kind];
_truck setVariable ["AP_vcap", [300, 220] select (_kind isEqualTo "extractor"), true];
if (_kind isEqualTo "extractor") then {
    _truck setVariable ["AP_rigState", "compact", true];
    _truck setVariable ["AP_rigTarget", "", true];
    _truck setVariable ["AP_rigLinkedTo", "", true];
} else {
    _truck setVariable ["AP_rigState", "idle", true];
    _truck setVariable ["AP_rigLinks", [], true];
};
[["init", _truck], "AP_fnc_rigClient", 0, format ["AP_rig_%1", netId _truck]] spawn AP_fnc_MP;
// the server copy goes with the truck (r2rig): a garage store deletes it, a pull adopts a new object
_truck addEventHandler ["Deleted", { localNamespace setVariable ["APS_rigKind_" + netId (_this select 0), nil]; }];
_truck addEventHandler ["Killed", {
    params ["_t"];
    private _k = localNamespace getVariable ["APS_rigKind_" + netId _t, ""];   // the server copy, not the public AP_rigKind
    localNamespace setVariable ["APS_rigKind_" + netId _t, nil];              // a wreck is no rig
    // donor contract 13.6: death clears processor links on BOTH sides
    if (_k isEqualTo "extractor") then {
        private _pid = _t getVariable ["AP_rigLinkedTo", ""];
        if (_pid isNotEqualTo "") then {
            private _proc = objectFromNetId _pid;
            if (!isNull _proc) then {
                _proc setVariable ["AP_rigLinks", (_proc getVariable ["AP_rigLinks", []]) - [netId _t], true]; };
        };
        _t setVariable ["AP_rigState", "compact", true];
    } else {
        {
            private _e = objectFromNetId _x;
            if (!isNull _e) then { _e setVariable ["AP_rigLinkedTo", "", true]; };
        } forEach (_t getVariable ["AP_rigLinks", []]);
        _t setVariable ["AP_rigState", "idle", true];
    };
    [["cleanup", _t], "AP_fnc_rigClient", 0, format ["AP_rig_%1", netId _t]] spawn AP_fnc_MP;
}];
