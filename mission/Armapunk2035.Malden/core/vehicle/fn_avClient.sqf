/*
    AP_fnc_avClient  (Armapunk 2035, 2026-09-22) -- LUXE AV passenger controls (client side of APS_fnc_avSRV).

    Called from the player's GetInMan / GetOutMan handlers (core/fn_setupEVH.sqf):
        ["in",  _veh]   adds a "Fly to <pad>" action per AP_avDest entry + Open / Close door (landed only)
        ["out", _veh]   removes them
    The actions live on the PLAYER while seated in an ap_av_lux; every one of them only sends a request --
    the server (APS_fnc_avSRV) checks the seat, the state and the destination and does the flying.
*/
params [["_mode", "", [""]], ["_veh", objNull, [objNull]]];
if (!hasInterface) exitWith {};
private _clear = {
    { player removeAction _x; } forEach (player getVariable ["AP_avActions", []]);
    player setVariable ["AP_avActions", []];
};
switch (_mode) do {
    case "in": {
        call _clear;
        if (isNull _veh || {!(_veh isKindOf "ap_av_lux")}) exitWith {};
        if !(missionNamespace getVariable ["SRV_avEnabled", true]) exitWith {};
        private _ids = [];
        {
            _x params ["_name", "_pos"];
            _ids pushBack (player addAction [
                format ["<t color='#e8c170'>AV: fly to %1</t>", _name],
                { params ["_t", "_c", "_id", "_a"]; _a params ["_veh", "_i"];
                  [["go", _veh, _i], "APS_fnc_avSRV", false, false] spawn AP_fnc_MP; },
                [_veh, _forEachIndex], 6, false, true, "",
                "vehicle _this isKindOf 'ap_av_lux' && {!((vehicle _this) getVariable ['AP_avBusy', false])} && {(vehicle _this) distance2D " + str _pos + " > 150}"
            ]);
        } forEach (missionNamespace getVariable ["AP_avDest", []]);
        _ids pushBack (player addAction ["AV: open door",
            { [["door", vehicle player, true], "APS_fnc_avSRV", false, false] spawn AP_fnc_MP; },
            nil, 5, false, true, "",
            "vehicle _this isKindOf 'ap_av_lux' && {!((vehicle _this) getVariable ['AP_avBusy', false])} && {(vehicle _this) animationSourcePhase 'doors_open' < 0.5}"]);
        _ids pushBack (player addAction ["AV: close door",
            { [["door", vehicle player, false], "APS_fnc_avSRV", false, false] spawn AP_fnc_MP; },
            nil, 5, false, true, "",
            "vehicle _this isKindOf 'ap_av_lux' && {!((vehicle _this) getVariable ['AP_avBusy', false])} && {(vehicle _this) animationSourcePhase 'doors_open' >= 0.5}"]);
        player setVariable ["AP_avActions", _ids];
    };
    case "out": { call _clear; };
};
