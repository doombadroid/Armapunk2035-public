#include "..\..\macro.h"
params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if !(alive _vehicle) exitWith {};
if !(_vehicle isKindOf "Air" || _vehicle isKindOf "Ship" || _vehicle isKindOf "LandVehicle" || typeOf _vehicle in ["Land_TentA_F", "Land_TentDome_F", "B_CargoNet_01_ammo_F", "B_CargoNet_01_ammo_F"]) exitWith {};
["Searching...", "basic"] spawn AP_fnc_handleMessage;
uiSleep 2;
private _virtInv = _vehicle getVariable["AP_vinv", [[], 0]];
private _index = -1;
private _value = 0;
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _inv = "";
private _displayName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
private _ownerName = "";
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]}; {_x params["_var", "_val"];
    _index = [_var, _illegalItems] call AP_fnc_index;
    if (!(_var in _illegalExempt) && !(_index isEqualTo - 1)) then {
        _inv = _inv + format["%1 %2<br/>", _x select 1, ["getName", (_x select 0)] call AP_fnc_virtItemCfg];
        _value = _value + (_val * ((_illegalItems select _index) select 1));};}
forEach(_virtInv select 0);
private _weapons = [];
private _weaponString = "";
private _magazines = [];
private _magazineString = "";
private _clothes = [];
private _clothingString = "";
private _name = "";
private _oldVal = 0; {private _wepAmounts = (getWeaponCargo _vehicle) select 1;
    _weapons pushBack[_x, _wepAmounts select _forEachIndex];}
forEach((getWeaponCargo _vehicle) select 0); {private _magAmounts = (getMagazineCargo _vehicle) select 1;
    _magazines pushBack[_x, _magAmounts select _forEachIndex];}
forEach((getMagazineCargo _vehicle) select 0); {_x params["_classname", "_container"];
    if (getNumber(missionConfigFile >> "CfgWeights" >> _classname >> "illegal") isEqualTo 1) then {private _idx = _clothes findIf {
            (_x select 0) isEqualTo _classname};
        if (_idx isEqualTo - 1) then {_clothes pushBack[_classname, 1];} else {_oldVal = (_clothes select _idx) select 1;
            (_clothes select _idx) set[1, _oldVal + 1];};};
    private _cargoArrays = [[magazineCargo _container, _magazines], [weaponCargo _container, _weapons]]; {
        _x params["_cargo", "_itemsSearched"]; {private _classname = _x;
            private _idx = _itemsSearched findIf {(_x select 0) isEqualTo _classname};
            if (_idx isEqualTo - 1) then {_itemsSearched pushBack[_classname, 1];} else {_oldVal = (_itemsSearched select _idx) select 1;
                (_itemsSearched select _idx) set[1, _oldVal + 1];};}
        forEach _cargo;}
    forEach _cargoArrays;}
forEach(everyContainer _vehicle);
if (_inv isEqualTo "") then {_inv = "No illegal items.<br/>";};
if (_weapons isEqualTo[]) then {_weaponString = "No weapons.<br/>";} else {{_x params["_var", "_val"];
        _weaponString = _weaponString + format["%1x %2<br/>", _val, getText(configFile >> "CfgWeapons" >> _var >> "displayName")];}
    forEach _weapons;};
if (_magazines isEqualTo[]) then {_magazineString = "No magazines or grenades.<br/>";} else {{_x params["_var", "_val"];
        _magazineString = _magazineString + format["%1x %2<br/>", _val, getText(configFile >> "CfgMagazines" >> _var >> "displayName")];}
    forEach _magazines;};
if (_clothes isEqualTo[]) then {_clothingString = "No illegal clothing.";} else {{_x params["_var", "_val"];
        _name =
        switch (_var) do {case ("V_HarnessOGL_brn"): {"Suicide Vest"}; case ("U_B_CombatUniform_mcam_worn"): {
                        "Police Uniform (SGT+)"}; case ("U_I_CombatUniform_shortsleeve"): {"Medic Uniform"}; case ("U_BG_Guerrilla_6_1"): {
                                "Police Uniform"}; case ("U_Rangemaster"): {
                                    "U_Rangemaster"}; default {getText(configFile >> "CfgWeapons" >> _var >> "displayName")};
        }; _clothingString = _clothingString + format["%1x %2<br/>", _val, _name];}
    forEach _clothes;};
if (_vehicle getVariable["AP_drugrunning", false]) then {_displayName =
    if (_vehicle isKindOf "Air") then {"Drugrunner's Plane"} else {"Drugrunner's Boat"};
    _value = _value + 10000;
    _inv = "Assorted Contraband<br/>";
    if (random(100) > 95) then {_inv = _inv + " (and a very large bag full of snakes)"};};
if (_vehicle getVariable["AP_supplyPlane", false]) then {_displayName = "Cargo Supply Plane";
    _value = _value + 10000;};
private _ownerName = ((_vehicle getVariable["AP_vehOwners", ""]) select 0) select 1;
[format["<t align='center'><t color='#FF0000' size='1.5'>%1</t><br/><t color='#FFD700' size='0.8'>Owned by: %2</t><br/><br/><t color='#FFD700' size='1.15'>Illegal items:</t><br/>%3<t color='#FFD700' size='1.15'>Weapons:</t><br/>%4<t color='#FFD700' size='1.15'>Magazines:</t><br/>%5<t color='#FFD700' size='1.15'>Clothing:</t><br/>%6<br/><t color='#FFD700' size='1.15'>Value of Illegal Items:</t><br/>$%7</t></t>", _displayName, _ownerName, _inv, _weaponString, _magazineString, _clothingString, [_value] call AP_fnc_numberText], "vehiclesearch"] spawn AP_fnc_handleMessage;