#include "..\..\macro.h"
AP_action_in_use = false;
params[["_civ", objNull, [objNull]], ["_invs", [], [[]]], ["_clothes", [], [[]]
], ["_illegalActivity", "", [""]], ["_licenses", "", [""]], ["_seizableMoney", 0, [0]], ["_alcoholLevel", 0, [0]], ["_drugLevel", 0, [0]], ["_newPlayer", "", [""]]];   // owner 2026-09-05: the 10th param (_firmware) is GONE -- see fn_searchClient.
if (isNull _civ) exitWith {};
if (_licenses isEqualTo "") then {_licenses = "No licenses<br/>";};
private _illegal = 0;
private _inv = "";
private _index = -1;
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]}; if !(_invs isEqualTo[]) then {{
        _x params["_item", "_val"];
        _inv = _inv + format["%1 %2<br/>", _val, ["getName", _item] call AP_fnc_virtItemCfg];
        _index = [_item, _illegalItems] call AP_fnc_index;
        if (!(_item in _illegalExempt) && !(_index isEqualTo - 1)) then {
            _illegal = _illegal + (_val * ((_illegalItems select _index) select 1));};}
    forEach _invs; [
        [0, format["%1 has $%2 worth of contraband on them.", name _civ, [_illegal] call AP_fnc_numberText]], "AP_fnc_broadcast", west, false, false] spawn AP_fnc_MP;
} else {_inv = "No illegal items";};
if (player distance _civ > 5 || !(alive _civ)) exitWith {[format["Couldn't search %1", name _civ], "basic"] spawn AP_fnc_handleMessage;};
private _weapons = ""; {_weapons = _weapons + format["%1<br/>", getText(configFile >> "CfgWeapons" >> _x >> "displayName")];}
forEach(weapons _civ);
if (_weapons isEqualTo "") then {_weapons = "No weapons<br/>";};
private _class = [];
private _qty = [];
private _magazines = "";
private _className = ""; {if !(_x in _class) then {_class pushBack _x;
        _qty pushBack 0;};
    _index = -1;
    _className = _x; {if (_x == _className) then {_index = _forEachIndex};}
    forEach _class;
    _qty set[_index, (_qty select _index) + 1];}
forEach(magazines _civ);
if (_class isEqualTo[]) then {_magazines = "No magazines or grenades<br/>";} else {{
        _magazines = _magazines + format["%2x %1<br/>", getText(configFile >> "CfgMagazines" >> _x >> "displayName"), _qty select _forEachIndex];
    }
    forEach _class;};
private _clothingString = "";
if (_clothes isEqualTo[]) then {_clothingString = "No illegal clothing <br/>";} else {{_x params["_var", "_val"];
        private _name =
        switch (_var) do {case ("V_HarnessOGL_brn"): {"Suicide Vest"};
                case ("U_B_CombatUniform_mcam_worn"): {"Police Uniform (SGT+)"}; case ("U_I_CombatUniform_shortsleeve"): {
                            "Medic Uniform"}; case ("U_BG_Guerrilla_6_1"): {"Police Uniform"}; case ("U_Rangemaster"): {
                                    "U_Rangemaster"}; default {getText(configFile >> "CfgWeapons" >> _var >> "displayName")};
        }; _clothingString = _clothingString + format["%1x %2<br/>", _val, _name];}
    forEach _clothes;};
private _extra = "";
_extra =
switch (_illegalActivity) do {case ("drugRunner"): {"Cash on hand has traces of narcotics"}; case ("bankRobber"): {
                "Cash on hand matches with the stolen money"}; case ("vehicleChop"): {
                    "Cash on hand has stains of grease on it"}; case ("gasStationRobber"): {
                        "This guy matches with the description of the robbery suspect"}; default {
                        ""};}; if (_extra != "") then {[[player, _seizableMoney], "APS_fnc_copSplit", 2] spawn AP_fnc_MP;
    [floor(_seizableMoney / 50)] spawn AP_fnc_earnPrestige;};
switch (true) do {case (_drugLevel > 0.9): {_extra = _extra + "Seems to be tripping massive balls<br/>"};
    case (_drugLevel > 0.6): {_extra = _extra + "Appears stoned out of his mind.<br/>"};
    case (_drugLevel > 0.4): {_extra = _extra + "Clearly very paranoid and jittery<br/>"};
    case (_drugLevel > 0.2): {_extra = _extra + "Seems moderately intoxicated.<br/>"};
    case (_drugLevel > 0.05): {_extra = _extra + "Seems to have a buzz.<br/>"};}; switch (true) do {case (_alcoholLevel > 0.9): {
            _extra = _extra + "BAC > 0.25; Blacked Out intoxicated."};
    case (_alcoholLevel > 0.6): {_extra = _extra + "BAC > 0.2; Extremely intoxicated."};
    case (_alcoholLevel > 0.4): {_extra = _extra + "BAC > 0.1; Slurred speech and motor control."};
    case (_alcoholLevel > 0.2): {_extra = _extra + "BAC > 0.06; Impaired reasoning and vision."};
    case (_alcoholLevel > 0.05): {_extra = _extra + "BAC > 0.03; Unable to concentrate."};};
// owner 2026-09-05: the ILLEGAL FIRMWARE DETECTED line is DELETED. Firmware is no longer a thing a player
// can lack, so it read on every civilian and was probable cause for nothing. AP_lastFirmwareSuspect went with
// it -- it armed the Factory Reset action, which is also gone, and nothing else ever read that variable.
[ format ["<t align='center'><t color='#FF000' size='1.5'>%1</t><br/><t color='#2aff00' size='0.8'>%9</t><br/><t color='#FFD700' size='1.1'>Cash on hand:</t><br/>$%7<br/><t color='#FFD700' size='1.1'>Weapons:</t><br/>%2<t color='#FFD700' size='1.1'>Magazines:</t><br/>%3<t color='#FFD700' size='1.1'>Clothing:</t><br/>%8<t color='#FFD700' size='1.1'>Licenses:</t><br/>%4<t color='#FFD700' size='1.1'>Illegal items:</t><br/>%5</t><br/><t color='#FF0000' align='center'>%6</t></t>", name _civ, _weapons, _magazines, _licenses, _inv, _extra, [_seizableMoney] call AP_fnc_numberText, _clothingString, _newPlayer], "basic"] spawn AP_fnc_handleMessage;