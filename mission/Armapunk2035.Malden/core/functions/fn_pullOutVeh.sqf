if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_unit", objNull, [objNull]]];
if ((AP_effSide isEqualTo west && !((player getVariable["AP_restrained", false]) || (player getVariable["AP_downed", false]))) || (isNull objectParent player)) exitWith {};
if (player getVariable["AP_downed", false]) then {player setUnconscious false;};
if (player getVariable["AP_restrained", false]) then {detach player;
    player setVariable["AP_escorting", nil, true];
    player setVariable["AP_transporting", nil, true];};
player action["Eject", vehicle player];
player action["GetOut", vehicle player];
waitUntil {isNull objectParent player};
if (player getVariable["AP_downed", false]) then {player setUnconscious true;
    player setVelocity[0, 0, 0];};
titleText["You have been pulled out of the vehicle", "PLAIN"];
titleFadeOut 4;