/*
    fn_keyGive.sqf — hand a vehicle/house key to another player.

    TWO ENTRY POINTS, ONE SET OF RULES
      The keychain dialog (2700) fires this from a ButtonClick, so _this is
      [control, ...] and both the vehicle and the recipient come from its
      listboxes — unchanged.
      The web deck passes them directly: [controlNull, _vehicle, _unit].

    Type-checked params are what makes that safe: a Control is not an Object, so
    the dialog's [control] argument can never be mistaken for a vehicle.

    Usage:  _this spawn AP_fnc_keyGive;                      // from the dialog
            [controlNull, _veh, _target] spawn AP_fnc_keyGive;   // from a page
*/
params [["_control", controlNull, [controlNull]], ["_vehicle", objNull, [objNull]], ["_unit", objNull, [objNull]]];
disableSerialization;

private _fromDialog = isNull _vehicle && { isNull _unit };
if (_fromDialog) then {
    private _display = findDisplay 2700;
    if (!isNull _display) then {
        private _vehicleList = _display displayCtrl 2702;
        if ((lbCurSel _vehicleList) >= 0 && { (lbCurSel _vehicleList) < count AP_vehicles }) then {
            _vehicle = AP_vehicles select (lbCurSel _vehicleList);
        };
        _unit = allPlayers param [allPlayers findIf {
            (lbData [2703, lbCurSel 2703]) isEqualTo (_x getVariable ["AP_steamid", getPlayerUID _x])
        }, objNull];
    };
};

if (isNull _vehicle) exitWith { false };
if (isNull _unit) exitWith {
    ["The player selected doesn't seem to exist?", "basic"] spawn AP_fnc_handleMessage;
    false
};
if (_unit isEqualTo player) exitWith { false };
if (_vehicle isKindOf "House_F" && {(_vehicle getVariable ["AP_homeOwner", "Error UID"]) != getPlayerUID player}) exitWith {
    ["You cannot give house keys from a house you do not own!", "basic"] spawn AP_fnc_handleMessage;
    false
};

private _vehicleOwners = _vehicle getVariable ["AP_vehOwners", []];
// You can only pass on a key you hold yourself. Applied to the NON-dialog path
// only: the keychain dialog lists nothing but your own AP_vehicles, so this
// was implicit there, and enforcing it on that path too would newly reject any
// vehicle whose AP_vehOwners happens to be unpopulated — a regression risk for
// zero gain. A caller that supplies its own vehicle has no such guarantee.
if (!_fromDialog && { (_vehicleOwners findIf {(getPlayerUID player) isEqualTo (_x param [0, ""])}) isEqualTo -1 }) exitWith {
    ["You do not have keys to that.", "basic"] spawn AP_fnc_handleMessage;
    false
};
if !((_vehicleOwners findIf {getPlayerUID _unit isEqualTo (_x param [0, "Error UID"])}) isEqualTo -1) exitWith {
    ["This player already has keys", "basic"] spawn AP_fnc_handleMessage;
    false
};

_vehicleOwners pushBackUnique [getPlayerUID _unit, [name _unit] call AP_fnc_cleanName];
_vehicle setVariable ["AP_vehOwners", _vehicleOwners, true];
[format ["You have given %1 keys to your %2", [name _unit] call AP_fnc_cleanName,
    getText (configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
[[_vehicle, player], "AP_fnc_addVehicle2Chain", _unit, false, false] spawn AP_fnc_MP;
true
