if (AP_action_in_use) exitWith {["An action is already being processed...", "basic"] spawn AP_fnc_handleMessage};
if (player getVariable["AP_restrained", false]) exitWith {};
if (player getVariable["AP_surrendered", false]) exitWith {};
disableSerialization;
AP_chopShop = _this select 3;
private _nearVehicles = nearestObjects[getMarkerPos(_this select 3), ["Car", "Truck", "Air", "Ship"], 25];
if (_nearVehicles isEqualTo[]) exitWith {titleText["There are no vehicles near to sell.", "PLAIN"];};
// DECK ROUTE (UI overhaul 2026-08-26): the chop list opens as a deck app.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["ChopShop"] call AP_fnc_deckOpenApp;
};
["Chop_Shop"] call AP_fnc_createDialog;
private _display = findDisplay 39400;
private _list = _display displayCtrl 39402; {if (alive _x && crew _x isEqualTo[]) then {private _className = typeOf _x;
        private _displayName = getText(configFile >> "CfgVehicles" >> _className >> "displayName");
        private _picture = getText(configFile >> "CfgVehicles" >> _className >> "picture");
        private _vehRow = ["getVehicleRow", "", _className] call AP_fnc_vehicleConfig;
        private _side =
        switch (_x getVariable["AP_side", -1]) do {case -1: {0};
            case "civ": {0};
            case "cop": {1};
            case "med": {2};}; private _price =
        if (_vehRow select 8 isEqualType[]) then {(_vehRow select 8) select _side} else {_vehRow select 8};
        private _index = _list lbAdd _displayName;
        _list lbSetPicture[_index, _picture];
        _list lbSetData[_index, (netId _x)];
        _list lbSetValue[_index, _price];};}
forEach _nearVehicles;