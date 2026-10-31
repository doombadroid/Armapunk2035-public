if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_typeItems", "ALL", [""]]];
if (AP_effSide isEqualTo west) exitWith {};
private _exempt = ["Binocular", "Rangefinder", "ItemWatch", "ItemCompass", "ItemGPS", "ItemMap", "NVGoggles", "FirstAidKit", "ToolKit", "Integrated_NVG_F"];
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]};
private _seizedWeps = [];
private _seizedVirt = [];
if (_typeItems isEqualTo "ALL") then {{if !(_x in _exempt) then {_seizedWeps pushBack _x;
            player removeWeapon _x;};}
    forEach weapons player; {if !(_x in _exempt) then {player removeItemFromUniform _x;};}
    forEach uniformItems player; {if !(_x in _exempt) then {player removeItemFromVest _x;};}
    forEach vestItems player; {if !(_x in _exempt) then {player removeItemFromBackpack _x;};}
    forEach backpackItems player; {player removeMagazine _x}
    forEach magazines player;
    if (getNumber(missionConfigFile >> "CfgWeights" >> uniform player >> "illegal") isEqualTo 1) then {removeUniform player};
    if (vest player in ["V_HarnessOGL_brn", "V_TacVest_blk_POLICE", "V_TacVest_gen_F"]) then {removeVest player;};
    if (headgear player in ["H_CrewHelmetHeli_B", "H_Cap_police"]) then {removeHeadgear player;};
    if (hmd player isEqualTo "NVGoggles_OPFOR") then {player unassignItem "NVGoggles_OPFOR";
        player removeItem "NVGoggles_OPFOR";};
    license_civ_gun = false;};
private "_num"; {_x params["_item"];
    _num = missionNamespace getVariable [format["AP_inv_%1", _item], 0];
    if (!(_item in _illegalExempt) && (_num > 0)) then {_seizedVirt pushBack[_item, _num];
        [false, _item, _num] call AP_fnc_handleInv;};}
forEach(["getIllegalItems"] call AP_fnc_virtItemCfg);
private _dice = random 100;
if (_dice > 75) then {[[_seizedVirt, 2], "APS_fnc_evidenceAppend", 2] spawn AP_fnc_MP;} else {[
        [_seizedWeps, 1], "APS_fnc_evidenceAppend", 2] spawn AP_fnc_MP;};
[3] call AP_fnc_ClupdatePartial;
private _message =
if (_typeItems isEqualTo "ALL") then {"Your weapons and illegal items have been seized into evidence."} else {
    "Your illegal items have been seized into evidence."};
titleText[_message, "PLAIN"];