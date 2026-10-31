/*
    AP_fnc_vaultClassLabel  (LooneyBin, owner 2026-07-11)
    Friendly display name for a house/shed classname in the Storage Worker UI. Falls back to a cleaned
    classname (strip Land_ prefix / _F suffix, underscores -> spaces) for anything unmapped.
*/
params [["_cls", "", [""]]];
private _map = createHashMapFromArray [["Land_i_Shed_Ind_F",   "Industrial Shed"], ["Land_u_Shed_Ind_F",   "Industrial Shed"],
    ["Land_i_Garage_V1_F",  "Garage"], ["Land_i_Garage_V2_F",  "Garage"], ["Land_i_House_Big_01_V1_F", "Large House"],
    ["Land_i_House_Big_02_V1_F", "Large House"], ["Land_i_House_Small_01_V1_F", "Small House"],
    ["Land_i_House_Small_02_V1_F", "Small House"], ["Land_i_House_Small_03_V1_F", "Small House"],
    ["Land_i_Stone_HouseBig_V1_F", "Stone House"], ["Land_i_Stone_Shed_V1_F", "Stone Shed"]];
private _r = _map getOrDefault [_cls, ""];
if (_r isNotEqualTo "") exitWith { _r };
if (_cls isEqualTo "" || {_cls isEqualTo "NULL"}) exitWith { "Property" };
// cleaned fallback
private _s = _cls;
{ if ((_s select [0, count _x]) isEqualTo _x) then { _s = _s select [count _x]; }; } forEach ["Land_i_", "Land_u_", "Land_"];
if ((_s select [(count _s) - 2]) isEqualTo "_F") then { _s = _s select [0, (count _s) - 2]; };
(_s splitString "_") joinString " "
