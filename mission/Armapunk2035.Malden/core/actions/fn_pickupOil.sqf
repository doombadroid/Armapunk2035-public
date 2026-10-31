private _barrel = cursorObject;
if (isNull _barrel) exitWith {};
if ((typeOf _barrel) in IL_Supported_Vehicles_BOAT && !isNull(_barrel getVariable["AP_oil_barrel", objNull])) then {
    _barrel = _barrel getVariable["AP_oil_barrel", objNull];
    private _vehicle = attachedTo _barrel;
    detach _barrel;
    _vehicle setVariable["AP_oil_barrel", nil, true];};
if (typeOf _barrel != "Land_MetalBarrel_F") exitWith {};
if !(isNull(player getVariable["AP_escortObj", objNull])) exitWith {
    ["You can't hold more than one thing at a time, silly!", "basic"] spawn AP_fnc_handleMessage};
if !(isNull objectParent player) exitWith {["You cannot pick up oil while in a vehicle.", "basic"] spawn AP_fnc_handleMessage};
if !(currentWeapon player isEqualTo "") exitWith {
    ["You must holster your weapon before picking this up.", "basic"] spawn AP_fnc_handleMessage};
_barrel attachTo[player, [0, 1, 1]];
player forceWalk true;
AP_holding_barrel = _barrel;
[_barrel] spawn {params["_barrel"];
    while {uiSleep 0.2;
        true}
    do {if !(alive player) exitWith {};
        if !(currentWeapon player isEqualTo "") exitWith {};
        if !(isNull objectParent player) then {player action["Eject", vehicle player]};
        if (isNull AP_holding_barrel) exitWith {};
        if !(isNull((player getVariable["AP_escortee", [objNull, false]]) select 0)) exitWith {};
    }; if !(isNull AP_holding_barrel) exitWith {[] call AP_fnc_dropOil};};