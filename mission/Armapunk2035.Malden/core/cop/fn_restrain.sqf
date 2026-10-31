params[["_unit", objNull, [objNull]]];
if (isNull _unit || player isEqualTo _unit || !(isNull objectParent player) || !(_unit isKindOf "CAManBase")) exitWith {};
if (player distance(getMarkerPos "courtroom") < 50) exitWith {};
if ((AP_effSide isEqualTo west) && (side _unit isEqualTo west)) exitWith {};
if (_unit getVariable["AP_restrained", false] || _unit getVariable["AP_escorting", false]) exitWith {};
if ((player getVariable["AP_surrendered", false]) || (player getVariable["AP_restrained", false])) exitWith {
    ["How could you possibly restrain someone right now?", "basic"] spawn AP_fnc_handleMessage;};
if (player distance _unit > 8 && (call AP_adminLevel <= 1)) exitWith {};
private _exit = false;
if !(AP_effSide isEqualTo west) then {if (_unit getVariable["AP_unitPassiveMode", false]) exitWith {
        ["This player is in passive mode and cannot be restrained.", "basic"] spawn AP_fnc_handleMessage;
        _exit = true};
    if (AP_inv_ziptie < 1) exitWith {["You need a zip tie to restrain someone.", "basic"] spawn AP_fnc_handleMessage;
        _exit = true};
    if !([false, "ziptie", 1] call AP_fnc_handleInv) exitWith {_exit = true};
    ["ziptied", 1] call AP_fnc_statArrUpdate;
    private _groupMembersBounties = units player apply {(_x getVariable["AP_myBounties", []]) apply {_x select 0}};
    private _lawfulRestraint = (8 in AP_side_talents && !(_groupMembersBounties findIf {getPlayerUID _unit in _x}
    isEqualTo - 1)) || !(AP_bounty_list findIf {getPlayerUID _unit in _x}
    isEqualTo - 1) || group _unit isEqualTo group player;
    if !(_lawfulRestraint) then {[[20, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;};};
if (_exit) exitWith {};
private _toSend = (allPlayers - [allDeadMen]) select {(_x distance player) <= 10};
private _restrainSound =
if (AP_effSide isEqualTo west) then {"handcuffs"} else {
    "ziptie"}; [[_unit, _restrainSound], "AP_fnc_playSound", _toSend] spawn AP_fnc_MP; [
    ["restrain", _unit], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP; [   // server re-checks, forwards AP_fnc_restrainAction
    ["-RESTRAIN-", player, (profileName), format["(%1) restrained %2 (%3) (%4) at %5", AP_effSide, name _unit, getPlayerUID _unit, side _unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;