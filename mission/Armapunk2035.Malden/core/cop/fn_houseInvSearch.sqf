#include "..\..\macro.h"
params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle || !(alive _vehicle) || !(typeOf _vehicle in AP_houseTypes)) exitWith {};
["Searching...", "basic"] spawn AP_fnc_handleMessage;
uiSleep 2;
private _ownerUID = _vehicle getVariable["AP_homeOwner", ""];
private _keyHolders = [_vehicle, "", "getKeyHolders"] call AP_fnc_keyHolderStatus;
private _allCivilianPids = (allPlayers select {side _x isEqualTo civilian}) apply {getPlayerUID _x};
private _onlineOwner = _ownerUID in _allCivilianPids;
private _onlineKeys = _keyHolders arrayIntersect _allCivilianPids;
private _onlineFolk = ""; {private _onlineUID = _x;
    private _playerObject = allPlayers param[allPlayers findIf {getPlayerUID _x isEqualTo _onlineUID}, objNull];
    _onlineFolk = _onlineFolk + format["%1 <br/>", name _playerObject];}
forEach _onlineKeys;
if (!(_onlineOwner) && _onlineKeys isEqualTo[]) exitWith {
    ["You cannot search the contents of this house right now. Try again later.", "basic"] spawn AP_fnc_handleMessage};
// owner 2026-06-23 (B): house storage is server-local/gated now -> request a hydrate (cop is authorized server-side
// in APS_fnc_initHouseInventory) + wait, snapshot the contents, then dehydrate so it stops being broadcast.
[[_vehicle, _vehicle getVariable ["AP_houseID", -1], "hydrate"], "APS_fnc_initHouseInventory", 2] spawn AP_fnc_MP;
private _hydrTimeout = time + 5;
waitUntil { uiSleep 0.1; (time > _hydrTimeout) || !(isNil { _vehicle getVariable "AP_vinv" }) };
private _houseVInv = _vehicle getVariable["AP_vinv", [[], 0]];
private _housePInv = _vehicle getVariable["AP_pinv", [[], 0]];
[[_vehicle, _vehicle getVariable ["AP_houseID", -1], "dehydrate"], "APS_fnc_initHouseInventory", 2] spawn AP_fnc_MP;
if (_houseVInv isEqualTo[[], 0] && _housePInv isEqualTo[[], 0]) exitWith {
    ["There is nothing in this house.", "basic"] spawn AP_fnc_handleMessage};
private _index = -1;
private _value = 0;
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _inv = "";
private _displayName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
private _owner = objNull;
private _ownerName = "";
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]}; {_x params["_var", "_val"];
    _index = [_var, _illegalItems] call AP_fnc_index;
    if (!(_index isEqualTo - 1) && !(_var in _illegalExempt)) then {
        _inv = _inv + format["%1 %2<br/>", _x select 1, ["getName", (_x select 0)] call AP_fnc_virtItemCfg];
        _value = _value + (_val * ((_illegalItems select _index) select 1));};}
forEach(_houseVInv select 0);
private _weapons = [];
private _weaponString = "";
private _magazines = [];
private _magazineString = "";
private _clothes = [];
private _clothingString = "";
private _name = "";
private _clothingParentConfigs = ["Uni_", "Bpack_", "Vest_", "Glass_"]; {_x params["_var", "_val"];
    private _parentConfig = configName(inheritsFrom(missionConfigFile >> "CfgWeights" >> _var));
    private _isClothing = (_clothingParentConfigs findIf {_parentConfig in _x}
    isNotEqualTo - 1) || (getNumber(configFile >> "CfgWeapons" >> _var >> "type") isEqualTo 131072);
    private _isWeapon = "Gun_" in _parentConfig;
    private _isMagazine = _var isKindOf["CA_Magazine", configFile >> "CfgMagazines"];
    private _isIllegal = getNumber(missionConfigFile >> "CfgWeights" >> _var >> "illegal") isEqualTo 1;
    if (_isWeapon) then {_weapons pushBack[_var, _val];};
    if (_isMagazine) then {_magazines pushBack[_var, _val];};
    if (_isClothing && _isIllegal) then {_clothes pushBack[_var, _val];};}
forEach(_housePInv select 0);
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
                                "Police Uniform"}; case ("U_B_GEN_Soldier_F"): {"Police Uniform"}; case ("U_Rangemaster"): {
                                        "U_Rangemaster"}; default {getText(configFile >> "CfgWeapons" >> _var >> "displayName")};
        }; _clothingString = _clothingString + format["%1x %2<br/>", _val, _name];}
    forEach _clothes;};
if (_vehicle isKindOf "House_F") then {_ownerUID = _vehicle getVariable["AP_homeOwner", ""];
    _owner = allPlayers param[allPlayers findIf {getPlayerUID _x isEqualTo _ownerUID}, objNull];
    if !(isNull _owner) then {_ownerName = name _owner;} else {_ownerName = "(Offline) " + _ownerUID;};} else {
    _ownerName = ((_vehicle getVariable["AP_vehOwners", ""]) select 0) select 1;};
[format["<t align='center'><t color='#FF0000' size='1.5'>%1</t><br/><t color='#FFD700' size='0.8'>Owned by: %2</t><br/><t color='#FFD700' size='0.8'>Additional Key Holders:</t><br/>%8<br/><t color='#FFD700' size='1.15'>Illegal items:</t><br/>%3<t color='#FFD700' size='1.15'>Weapons:</t><br/>%4<t color='#FFD700' size='1.15'>Magazines:</t><br/>%5<t color='#FFD700' size='1.15'>Clothing:</t><br/>%6<br/><t color='#FFD700' size='1.15'>Value of Illegal Items:</t><br/>$%7</t></t>", _displayName, _ownerName, _inv, _weaponString, _magazineString, _clothingString, ([_value] call AP_fnc_numberText), _onlineFolk], "basic"] spawn AP_fnc_handleMessage;