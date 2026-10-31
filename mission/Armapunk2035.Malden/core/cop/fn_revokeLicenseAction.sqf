if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_cop", objNull, [objNull]], ["_type", "", [""]], ["_bool", false, [true]]];
if (isNull _cop) exitWith {};
switch (_type) do {case "driver": {license_civ_driver = false;
            [format["Your Drivers License was revoked by %1.", [name _cop] call AP_fnc_cleanName], "basic"] spawn AP_fnc_handleMessage;
            systemChat format["Your Drivers License was revoked by %1.", name _cop];}; case "bounty": {license_civ_bounty = false;
                if (_bool) then {
                    [format["Your Bounty Hunter License was revoked for the remaining duration of the server cycle by %1.", [name _cop] call AP_fnc_cleanName], "basic"] spawn AP_fnc_handleMessage;
                    systemChat format["Your Bounty Hunter License was revoked for the remaining duration of the server cycle by %1.", name _cop];
                } else {
                    [format["Your Bounty Hunter License was revoked by %1.", [name _cop] call AP_fnc_cleanName], "basic"] spawn AP_fnc_handleMessage;
                    systemChat format["Your Bounty Hunter License was revoked by %1.", name _cop];};
                player setVariable["AP_isBountyHunter", false, true];};};
[ 2 ] call AP_fnc_ClupdatePartial;