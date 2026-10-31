if !(remoteExecutedOwner in [0, 2]) exitWith {};   // server hop only (APS_fnc_victimSRV checks actor/range/state); 0 = a local call or spawn, which remoteExecutedOwner does not survive
params[["_enforcer", objNull, [objNull]], ["_target", objNull, [objNull]], ["_isTrial", false, [false]]];
if ((_enforcer isEqualTo _target) && !(_isTrial)) exitWith {};
if ((_target getVariable["AP_arrested", false]) && !(_isTrial)) exitWith {};
if (_target getVariable["AP_surrendered", false]) then {_target setVariable["AP_surrendered", nil, true];};
detach _target;
private _copEnforcer = (side _enforcer) isEqualTo west;
if (isNull _enforcer || isNull _target) exitWith {};
if (_copEnforcer && side _target isEqualTo west) exitWith {}; [
    ["action", "restrain", 1], "AP_fnc_handleQuest", _enforcer] spawn AP_fnc_MP;
_target setVariable["AP_restrained", true, true];
closeDialog 0;
private _enforcerString =
if (_isTrial) then {"the Judge"} else {_enforcer getVariable["AP_name", [name _enforcer] call AP_fnc_cleanName]};
[format["You've been restrained by %1", _enforcerString], "basic"] spawn AP_fnc_handleMessage;
if (side player isEqualTo west) then {[["civ_cops_restrained", 1], "AP_fnc_statArrUpdate", _enforcer] spawn AP_fnc_MP;};
if (_copEnforcer) then {AP_old_group = group player;
    if !((units group player) isEqualTo[]) then {[player] join grpNull;
        if ("ItemGPS" in (assignedItems player)) then {[
                [false, player], "AP_fnc_setGroupRestrainMarker", units AP_old_group] spawn AP_fnc_MP;};};} else {
    _target setVariable["AP_civRestrained", true, true]; ["Civilian restraints break after 10 minutes.", "civ_restraints", {
        player getVariable["AP_civRestrained", false];}] spawn AP_fnc_handleMessage;};
if (_target getVariable["AP_downed", false] && !(_copEnforcer)) then {waitUntil {uiSleep 0.25;
        !(_target getVariable["AP_downed", false])}};
_target playMoveNow "AmovPercMstpSnonWnonDnon";
disableUserInput false;
private _startTime = time;
private _maxRestrainTime = 10 * 60;
private _timeUp = false;
private _continue = true;
while {_continue}
do {if (isNull objectParent player) then {_target playMove "AmovPercMstpSnonWnonDnon_Ease"};
    waitUntil {_noNearbyCops = ({side _x isEqualTo west && player distance _x < 500}
        count allPlayers isEqualTo 0);
        _timeUp = (!_copEnforcer || (isNull objectParent player && _copEnforcer && _noNearbyCops)) && time - _startTime > _maxRestrainTime && !(_target getVariable["AP_escorting", false]) && !(_target getVariable["AP_transporting", false]);
        if (_timeUp || !(_target getVariable["AP_restrained", false]) || !alive _target) then {_continue = false;};
        if !(isNull objectParent player) then {if (driver(vehicle player) isEqualTo player) then {player action["Eject", vehicle player];};
        };
        !_continue || animationState _target != "AmovPercMstpSnonWnonDnon_Ease";};}; _target playMoveNow "AmovPercMstpSnonWnonDnon";
if (_copEnforcer && AP_old_group != group player) then {[player] joinSilent AP_old_group;
    AP_old_group = grpNull;};
_target allowDamage true;
_target setVariable["AP_restrained", nil, true];
_target setVariable["AP_civRestrained", nil, true];
if (AP_isDowned) then {player setUnconscious true};