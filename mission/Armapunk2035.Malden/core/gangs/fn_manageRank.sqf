#include "..\..\macro.h"
/*
    fn_manageRank.sqf — promote (_mode 1) or demote (_mode 2) a gang member.

    Ranks are INVERTED: a LOWER number is more authority (1 = leader). So a
    promotion subtracts one and a demotion adds one, which reads backwards and
    is easy to "fix" into a bug.

    TWO ENTRY POINTS, ONE SET OF RULES
      dialog/gangMenu.hpp calls [1] / [2] and the target comes from listbox 9621.
      The web deck passes the member too: [1, [uid, name, rank]].

    The permission checks are shared deliberately — see fn_gangKick for why.
    APS_fnc_updateGangMem re-validates server-side either way.

    Usage:  [1] spawn AP_fnc_manageRank;
            [1, ["76561198...", "Sable", 5]] spawn AP_fnc_manageRank;
*/
params [["_mode", 0, [0]], ["_unit", [], [[]]]];
disableSerialization;

private _gangID   = AP_gang_data select 0;
private _gangName = AP_gang_data select 1;

private _fromDialog = _unit isEqualTo [];
if (_fromDialog && { (lbCurSel 9621) isNotEqualTo -1 }) then {
    _unit = parseSimpleArray (getSelData(9621));
};

if (!(_unit isEqualType []) || { count _unit < 3 }) exitWith {
    ["You must select a player first.", "basic"] spawn AP_fnc_handleMessage;
    false
};
if ((_unit select 0) isEqualTo (getPlayerUID player)) exitWith {
    ["You cannot modify your own rank.", "basic"] spawn AP_fnc_handleMessage;
    false
};
if ((_unit select 0) isEqualTo "") exitWith { false };

private _onlineMembers = [_gangID] call AP_fnc_getOnlineMembers;
private _member = _onlineMembers param [_onlineMembers findIf {getPlayerUID _x isEqualTo (_unit select 0)}, objNull];

private _ok = false;
switch (_mode) do {
    case 1: {
        if (((_unit select 2) - 1) <= (AP_gang_data select 2)) exitWith {
            ["Insufficient permissions.", "basic"] spawn AP_fnc_handleMessage;
        };
        if (isNull _member) then {
            [[player, 1, _gangID, _gangName, (_unit select 0), ((_unit select 2) - 1)], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;
        } else {
            [[player, 2, _gangID, _gangName, _member, ((_unit select 2) - 1)], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;
        };
        ["Promoting member and updating rank in database...", "basic"] spawn AP_fnc_handleMessage;
        _ok = true;
    };
    case 2: {
        if ((((_unit select 2)) <= (AP_gang_data select 2)) || ((_unit select 2) + 1) < 0) exitWith {
            ["Insufficient permissions.", "basic"] spawn AP_fnc_handleMessage;
        };
        if (isNull _member) then {
            [[player, 1, _gangID, _gangName, (_unit select 0), ((_unit select 2) + 1)], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;
        } else {
            [[player, 2, _gangID, _gangName, _member, ((_unit select 2) + 1)], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;
        };
        ["Demoting member and updating rank in database...", "basic"] spawn AP_fnc_handleMessage;
        _ok = true;
    };
};

if (_ok && _fromDialog) then {  };
_ok
