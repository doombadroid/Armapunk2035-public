if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks the caller is staff
params[["_admin", objNull, [objNull]]];
if (isNull _admin) exitWith {};
private _player = player;
AP_action_in_use = true;
if (dialog) then {closeDialog 0;};
openMap false;
[format["You have been restrained by LoonyBin Administrator: %1", name _admin], "warning"] spawn AP_fnc_handleMessage;
private _continue = true;
while {_continue}
do {1 fadeSound 0.18;
    if (isNull objectParent player) then {_player playMove "AmovPercMstpSnonWnonDnon_Ease"};
    if (dialog) then {closeDialog 0;};
    if !(AP_action_in_use) then {AP_action_in_use = true;};
    waitUntil {if (!(_player getVariable["AP_adminRestrain", false]) || !alive _player) then {_continue = false;};
        if !(isNull objectParent player) then {if (driver(vehicle player) isEqualTo player) then {player action["Eject", vehicle player];};
        };
        if (dialog) then {closeDialog 0;};
        if !(AP_action_in_use) then {AP_action_in_use = true;};
        !_continue || animationState _player != "AmovPercMstpSnonWnonDnon_Ease";};}; 1 fadeSound 1;
AP_action_in_use = false;
if (alive player) then {player switchMove "AmovPercMstpSlowWrflDnon_SaluteIn";
    player setVariable["AP_escorting", false, true];
    player setVariable["AP_transporting", false, true];
    player setVariable["AP_restrained", false, true];
    detach player;};