disableSerialization;
private _unit = cursorTarget;
if (isNull _unit || !isPlayer _unit) exitWith {};
if (player distance _unit > 8) exitWith {};
// DECK ROUTE: tickets are the intake terminal's other commit.
if ((missionNamespace getVariable ["AP_deckApps", true]) && {AP_effSide isEqualTo west}) exitWith {
    ["Intake", _unit] call AP_fnc_deckOpenApp;
};
["AP_ticket_give"] call AP_fnc_createDialog;
ctrlSetText[2651, format["Ticketing %1", [name _unit] call AP_fnc_cleanName]];
AP_ticket_unit = _unit;