params[["_target", objNull, [objNull]]];
if (isNull _target) exitWith {};
if !(isPlayer _target) exitWith {};
if (_target getVariable["AP_unitPassiveMode", false]) exitWith {
    ["This player is in passive mode and cannot be robbed.", "basic"] spawn AP_fnc_handleMessage;};
private _BH = 8 in AP_side_talents;
private _idx = AP_bounty_list findIf {(getPlayerUID _target) in _x};
private _bhTarget =
if (_idx isEqualTo - 1) then {false} else {true}; [   // via the server: APS_fnc_victimSRV re-checks range/surrender, forwards to AP_fnc_robPerson
    ["rob", _target, [_BH && 17 in AP_honor_talents && (_bhTarget || 22 in AP_honor_talents), _BH && 18 in AP_honor_talents && (_bhTarget || 22 in AP_honor_talents)]], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;