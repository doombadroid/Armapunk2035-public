#include "..\..\macro.h"
/*
    fn_gangKick.sqf — remove a member from the gang.

    TWO ENTRY POINTS, ONE SET OF RULES
      dialog/gangMenu.hpp calls it with no arguments and the target is read out
      of listbox 9621, exactly as before.
      The web deck passes the member directly: [uid, name, rank].

    The permission checks below are shared by both on purpose. A second copy for
    the web path would be a second thing to get wrong, and the whole point of
    routing through this function is that the deck cannot reach a weaker one.
    APS_fnc_updateGangMem re-validates server-side regardless.

    Usage:  [] spawn AP_fnc_gangKick;                       // from the dialog
            [["76561198...", "Sable", 5]] spawn AP_fnc_gangKick;   // from a page
*/
params [["_unit", [], [[]]]];
disableSerialization;

// Reading the listbox is what tells us we were opened from the dialog, which is
// also the only case where the dialog should be refreshed afterwards.
private _fromDialog = _unit isEqualTo [];
if (_fromDialog && { (lbCurSel 9621) isNotEqualTo -1 }) then {
    _unit = parseSimpleArray (lbData [9621, lbCurSel 9621]);
};

if (!(_unit isEqualType []) || { count _unit < 3 }) exitWith {
    ["You need to select a person to kick!", "basic"] spawn AP_fnc_handleMessage;
    false
};
if ((_unit select 0) isEqualTo getPlayerUID player) exitWith {
    ["You cannot kick yourself from the gang... Sorry. Try using the leave button instead!", "basic"] spawn AP_fnc_handleMessage;
    false
};
if ((_unit select 2) <= (AP_gang_data select 2)) exitWith {
    ["Insufficient permissions.", "shortwarning"] spawn AP_fnc_handleMessage;
    false
};
if ((AP_gang_data select 2) isEqualTo 3 && (_unit select 2) != 5) exitWith {
    ["Insufficient permissions.", "shortwarning"] spawn AP_fnc_handleMessage;
    false
};
if ((_unit select 0) isEqualTo "") exitWith { false };

private _member = playableUnits param [playableUnits findIf {getPlayerUID _x isEqualTo (_unit select 0)}, objNull];
if (isNull _member) then {
    [[player, 1, AP_gang_data select 0, AP_gang_data select 1, _unit select 0, -1], "APS_fnc_updateGangMem", 2] spawn AP_fnc_MP;
} else {
    [[player, 2, AP_gang_data select 0, AP_gang_data select 1, _member, -1], "APS_fnc_updateGangMem", 2] spawn AP_fnc_MP;
};
["Kicking player from gang and updating the database...", "basic"] spawn AP_fnc_handleMessage;

// Only re-open the native menu if that is where we came from — the deck must
// not have a gang dialog thrown over the top of it.
if (_fromDialog) then {  };
true
