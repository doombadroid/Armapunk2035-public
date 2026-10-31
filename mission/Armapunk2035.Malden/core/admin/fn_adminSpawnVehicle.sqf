#include "..\..\macro.h"
params[["_mode", 0, [0]]];
if ((call AP_adminLevel) <= 2) exitWith {closeDialog 0;};
disableSerialization;
switch (_mode) do {case 1: {private _vehicleData = parseSimpleArray(lbData[12943, lbCurSel 12943]);
            private _vehicle = _vehicleData select 0;
            private _vehicleWeapons = _vehicleData select 1;
            if (isNil "_vehicle" || _vehicle isEqualTo "") exitWith {};
            if !(scriptAvailable(7)) then {["Sending request to server to create vehicle...", "basic"] spawn AP_fnc_handleMessage;};
            [_mode, player, _vehicle, position player, _vehicleWeapons] remoteExec["APS_fnc_createAdminVeh", 2];
            private _extra =
            if (_vehicleWeapons isEqualTo[]) then {""} else {format[" with weapons: %1", _vehicleWeapons joinString ", "]}; [
                ["-ADMINACTION-", player, profileName, format["Spawned vehicle %1%2", _vehicle, _extra]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        };
    case 2: {if !(scriptAvailable(7)) then {
                ["Sending request to server to delete all admin vehicles...", "basic"] spawn AP_fnc_handleMessage;};
            [_mode, player] remoteExec["APS_fnc_createAdminVeh", 2]; [
                ["-ADMINACTION-", player, profileName, format["deleted all admin vehicles."]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        };
    default {};};