if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_vehicle", objNull, [objNull]], ["_typeItems", "ALL", [""]]];
if (isNull _vehicle) exitWith {};
private _exempt = ["Binocular", "Rangefinder", "ItemWatch", "ItemCompass", "ItemGPS", "ItemMap", "NVGoggles", "FirstAidKit", "ToolKit", "Integrated_NVG_F"];
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]}; if (_typeItems isEqualTo "ALL") then {{
        if !(_x in _exempt) then {_vehicle addItemCargoGlobal[_x, 1];};}
    forEach(primaryWeaponItems player + [primaryWeapon player] + handgunItems player + [handgunWeapon player] + uniformItems player + vestItems player + backPackitems player); {
        if !(_x in _exempt) then {player removeWeapon _x;};}
    forEach weapons player; {if !(_x in _exempt) then {player removeItemFromUniform _x;};}
    forEach uniformItems player; {if !(_x in _exempt) then {player removeItemFromVest _x;};}
    forEach vestItems player; {if !(_x in _exempt) then {player removeItemFromBackpack _x;};}
    forEach backpackItems player; {player removeMagazine _x}
    forEach magazines player;
    if (getNumber(missionConfigFile >> "CfgWeights" >> uniform player >> "illegal") isEqualTo 1) then {
        _vehicle addItemCargoGlobal[uniform player, 1];
        removeUniform player};
    if (vest player in ["V_HarnessOGL_brn", "V_TacVest_blk_POLICE", "V_TacVest_gen_F"]) then {_vehicle addItemCargoGlobal[vest player, 1];
        removeVest player;};
    if (headgear player in ["H_CrewHelmetHeli_B", "H_Cap_police"]) then {_vehicle addItemCargoGlobal[headgear player, 1];
        removeHeadgear player;};
    if (hmd player == "NVGoggles_OPFOR") then {player unassignItem "NVGoggles_OPFOR";
        player removeItem "NVGoggles_OPFOR";
        _vehicle addItemCargoGlobal["NVGoggles_OPFOR", 1];};
    license_civ_gun = false;};
private _vehData = _vehicle getVariable["AP_vinv", [[], 0]];
_vehData params["_vehInv", "_vehWeight"]; {_x params["_item"];
    private _val = missionNamespace getVariable [format["AP_inv_%1", _item], 0];
    if (!(_item in _illegalExempt) && (_val > 0)) then {private _itemWeight = (["getItemWeight", _item] call AP_fnc_virtItemCfg) * _val;
        _vehWeight = _vehWeight + _itemWeight;
        private _idx = _vehInv findIf {(_x select 0) isEqualTo _item};
        if (_idx isEqualTo - 1) then {_vehInv pushBack[_item, _val];} else {private _oldVal = (_vehInv select _idx) select 1;
            (_vehInv select _idx) set[1, _oldVal + _val];};
        [false, _item, _val] call AP_fnc_handleInv;};}
forEach(["getIllegalItems"] call AP_fnc_virtItemCfg);
_vehicle setVariable["AP_vinv", [_vehInv, _vehWeight], true];
[3] call AP_fnc_ClupdatePartial;
private _message =
if (_typeItems isEqualTo "ALL") then {"Your weapons and illegal items have been seized into the nearest police vehicle."} else {
    "Your illegal items have been seized into the nearest police vehicle."};
titleText[_message, "PLAIN"];