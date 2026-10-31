#include "..\..\macro.h"
if (scriptAvailable(0.75)) exitWith {["Please don't spam charges!", "basic"] spawn AP_fnc_handleMessage;};
params[["_unitUID", ""]];
if (_unitUID isEqualTo "") exitWith {closeDialog 0;};
disableSerialization;
if (isNull(findDisplay 5520)) exitWith {};
if ((lbCurSel 5522) isEqualTo - 1) exitWith {["No charge selected", "basic"] spawn AP_fnc_handleMessage;};
private _display = findDisplay 5520;
waitUntil {!isNull _display};
private _title = _display displayCtrl 5521;
private _list = _display displayCtrl 5522;
private _input = _display displayCtrl 5523;
private _button = _display displayCtrl 5524;
private _players = allPlayers;
private _unit = _players param[_players findIf {((getPlayerUID _x) isEqualTo _unitUID) && !((side _x) isEqualTo west)}, objNull];
if (isNull _unit) exitWith {closeDialog 0};
private _inputAmount = parseNumber(ctrlText _input);
private _max = 5;
if (_inputAmount > _max) then {systemChat format["You cannot charge someone with more than %1 crimes at once!", _max];
    _inputAmount = 0;
    ctrlSetText[5523, format["%1", _max]];};
if (_inputAmount <= 0) exitWith {};
if ((isNull _unit) || (!isPlayer _unit) || (!alive _unit)) exitWith {closeDialog 0};
private _label = lbText[5522, lbCurSel 5522];
private _charge = (parseSimpleArray(lbData[5522, lbCurSel 5522])) select 0; [
    [_charge, _unit, _inputAmount], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP; [
    [1, format["%4 has charged %1 with %2 count(s) of %3", [name _unit] call AP_fnc_cleanName, _inputAmount, _label, [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", west];
systemChat format["You have charged %1 with %2 count(s) of %3", [name _unit] call AP_fnc_cleanName, _inputAmount, _label]; [
    ["-ADDCHARGE-", player, (profileName), format["charged %1 (%2) with %3 count(s) of %4.", (name _unit), (getPlayerUID _unit), _inputAmount, _label]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
// owner 2026-06-21: the "Rape" charge (id 110, fn_wantedChargesConfig) is a first-line-moderator CONTAINMENT tool,
// not a routine citation. Cops have no server power, so applying it fires a DEDICATED high-priority audit row that
// CLANKR keys on to ping an admin the INSTANT it's used (kept out of the routine -ADDCHARGE- citation stream). The
// suspect is max-jailed + re-chargeable while staff review the footage. Keep id 110 in sync with the charges config.
if (_charge isEqualTo 110) then {
    [["-MODFLAG-RAPE-", player, (profileName), format["FLAGGED %1 (%2) with the Rape containment charge (x%3) -- needs admin review of footage.", (name _unit), (getPlayerUID _unit), _inputAmount]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};