/*
    AP_fnc_fedRadarCharge -- plant one demo charge on a footing of the island's radar tower.

    Four footings, any order (owner 2026-07-27). The fourth one placed arms a three-minute fuse that
    nobody can stop, so this deliberately says so before it is too late to walk away.

    Same shape as the evidence-vault breach in fn_evidenceSystems.sqf: progress bar, planting
    animation, and the run is void if you move, board a vehicle or die. The charge itself, the fuse,
    the tower and the map are all the server's business -- this only reports which footing was used
    (APS_fnc_fedRadarSRV re-checks the caller and his distance, since the whitelist means any client
    can call it with any argument).
*/
if (AP_action_in_use) exitWith {};
if !(AP_effSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {};
if (AP_inv_demoCharge < 1) exitWith {["You need a demo charge for each footing.", "basic"] spawn AP_fnc_handleMessage;};

private _pts = missionNamespace getVariable ["AP_fedRadarPoints", []];
if (_pts isEqualTo []) exitWith {["The tower's footings are not marked yet -- tell an admin.", "basic"] spawn AP_fnc_handleMessage;};
private _state = (missionNamespace getVariable ["SRV_fedRadar", [[false, false, false, false], false, -1]]) param [0, [false, false, false, false]];
if ((missionNamespace getVariable ["SRV_fedRadar", []]) param [1, false]) exitWith {
    ["All four charges are already set -- the fuse is running.", "basic"] spawn AP_fnc_handleMessage;
};

// nearest footing that has nothing on it yet
private _idx = -1;
private _best = 3;                                   // the server tolerates 8 m; ask for 3 so it never rejects
{
    if (!(_state param [_forEachIndex, false]) && {(player distance2D _x) < _best}) then {
        _best = player distance2D _x;
        _idx = _forEachIndex;
    };
} forEach _pts;
if (_idx isEqualTo -1) exitWith {["Stand at one of the four tower footings that is still empty.", "basic"] spawn AP_fnc_handleMessage;};

private _startPos = getPosATL player;
disableSerialization;
5 cutRsc ["AP_progress", "PLAIN"];
private _display = uiNameSpace getVariable ["AP_progress", displayNull];
private _bar = _display displayCtrl 38201;
private _txt = _display displayCtrl 38202;
AP_action_in_use = true;
private _total = 20;
private _step = 1;
private _delay = _total / floor (100 / _step);
_bar progressSetPosition 0;
_txt ctrlSetText format ["Placing Charge %1 of 4 (0%2)", ({_x} count _state) + 1, "%"];
["AinvPknlMstpSnonWnonDnon_medic_1", 20] spawn AP_fnc_handleAnim;

private _ok = for "_i" from 0 to 1 step 0 do {
    uiSleep _delay;
    if (isNull _bar) exitWith {false};
    private _p = (progressPosition _bar) + (_step / 100);
    _bar progressSetPosition _p;
    _txt ctrlSetText format ["Placing Charge %1 of 4 (%2%3)", ({_x} count _state) + 1, round (_p * 100), "%"];
    if (_p >= 1) exitWith {true};
    if ((speed player) >= 2) exitWith {false};
    if ((player distance _startPos) > 4) exitWith {false};
    if !(isNull objectParent player) exitWith {false};
    if (!AP_action_in_use || !alive player) exitWith {false};
    false;
};
AP_action_in_use = false;
[] spawn AP_fnc_handleAnim;
5 cutText ["", "PLAIN"];

if (!_ok) exitWith {["You stopped placing the charge.", "basic"] spawn AP_fnc_handleMessage;};
if !([false, "demoCharge", 1] call AP_fnc_handleInv) exitWith {
    ["You no longer have a demo charge.", "basic"] spawn AP_fnc_handleMessage;
};
[[_idx], "APS_fnc_fedRadarSRV", 2, false] spawn AP_fnc_MP;
[format ["Charge set on footing %1. Four of them arms a three-minute fuse -- and once it is armed nothing stops it.", _idx + 1], "basic"] spawn AP_fnc_handleMessage;
