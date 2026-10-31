/*
    APS_fnc_keyManagement  (LooneyBin -- implemented from stub 2026-06-09)
    Server-side vehicle key registry = the vehicle's `AP_vehOwners` variable ([[uid, name], ...]),
    read by Check-Registration and chop-shop claim. Client callers:
      [player, _vehicle, 1]   core/vehicle/fn_prepareVehicle.sqf  -- garage pull: register the puller
      [_toSend, _vehicle, 3]  core/shops/fn_chopShopClaim.sqf     -- claim: strip the OLD holders
                                (_toSend = array of player objects whose client keys were just removed)
*/
params [["_a", objNull, [objNull, []]], ["_vehicle", objNull, [objNull]], ["_mode", -1, [0]]];
if (isNull _vehicle || {_mode < 0}) exitWith {};
private _owners = _vehicle getVariable ["AP_vehOwners", []];

// owner 2026-06-23 SECURITY (security.md §2.2 HIGH): CfgRE-whitelisted -> a client could remoteExec
// [player, ANY_veh, 1] to grant ITSELF a working key to any vehicle. Derive the caller from the
// non-spoofable remoteExecutedOwner (model fn_seizeLock:22); server-internal (0) stays trusted.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;

switch (_mode) do {case 1: {   // register a key holder (garage pull)
        // owner 2026-06-23 SECURITY (security.md §2.2): for a CLIENT call, register the CALLER themselves
        // (never an arbitrary passed object) AND only if they're actually entitled to this vehicle's key --
        // i.e. they're the registered owner (AP_dbInfo[0]) or already in AP_vehOwners. The legit pull
        // (client fn_prepareVehicle) sets AP_vehOwners to the owner + gang members IMMEDIATELY before this
        // call, so a real puller always passes; a forged [me, someoneElsesVeh, 1] is rejected.
        private _regUnit = if (_src isEqualTo 0) then { _a } else { _caller };
        if (_regUnit isEqualType objNull && {!isNull _regUnit}) then {private _uid = getPlayerUID _regUnit;
            private _ownerUID = format ["%1", (_vehicle getVariable ["AP_dbInfo", ["", 0, false]]) param [0, ""]];
            private _entitled = (_src isEqualTo 0)
                || {(_owners findIf { (format ["%1", _x param [0, ""]]) isEqualTo _uid }) > -1}
                || {_uid isEqualTo _ownerUID};
            if (!_entitled) exitWith { ["-SEC-", _caller, format ["BLOCKED keyManagement mode1 (not entitled to veh key) by %1", _callerUID]] call APS_fnc_logIt; };
            if ((_owners findIf { (_x param [0, ""]) isEqualTo _uid }) isEqualTo -1) then {_owners pushBack [_uid, name _regUnit];
                _vehicle setVariable ["AP_vehOwners", _owners, true];};};};
    case 3: {   // chop-shop claim -> strip the previous holders' keys server-side
        // owner 2026-06-23 SECURITY (security.md §2.2): require a real caller on a client invocation (a null
        // caller = a forged server-targeted call with no originating client). This only mutates the in-memory
        // AP_vehOwners (key revocation) -- grief-only, no ownership/money transfer (that's gated in
        // fn_vehOwnerSwap) -- so the deeper "is this a legitimate claim" check is NEEDS OWNER REVIEW.
        if (_src isNotEqualTo 0 && {isNull _caller}) exitWith { ["-SEC-", objNull, format ["BLOCKED keyManagement mode3 (no real caller, src %1)", _src]] call APS_fnc_logIt; };
        private _strip = if (_a isEqualType []) then { _a } else { [_a] };
        private _uids = (_strip select { _x isEqualType objNull && {!isNull _x} }) apply { getPlayerUID _x };
        _owners = _owners select { !((_x param [0, ""]) in _uids) };
        _vehicle setVariable ["AP_vehOwners", _owners, true];};
    default {diag_log format ["[LooneyBin][keyManagement] unhandled mode %1: %2", _mode, _this];};};
