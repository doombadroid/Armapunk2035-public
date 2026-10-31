params[["_target", objNull, [objNull]], ["_progress", false, [false]], ["_deadBody", objNull, [objNull]]];
if (isNull _target) exitWith {};
if !(AP_effSide isEqualTo civilian) exitWith {};
if !(AP_inEvent) exitWith {};
if (_progress) then {AP_gunGameKills = (AP_gunGameKills + 1) min 15;} else {cutText["", "BLACK FADED"];
    0 cutFadeOut 7.5;
    AP_isDead = false; localNamespace setVariable ["AP_isDead", false];
    AP_corpse = _deadBody;
    if !(isNull AP_corpse) then {private _containers = nearestObjects[AP_corpse, ["WeaponHolderSimulated"], 5]; {deleteVehicle _x}
        forEach _containers;
        hideBody AP_corpse;};
    if !(AP_effSide isEqualTo west) then {AP_cash = 0;
        AP_cashCacheB = ((AP_cash / 4) + 9);}; {_x setVariable["AP_aggressive", nil];}
    forEach allPlayers;
    waitUntil {alive player};
    private _plb_pos = ((["getLocationByID", (AP_adminEvent select 3)] call AP_fnc_eventCfg) select 2);
    if (!isNil "_plb_pos") then {while {
            _plb_pos isEqualTo((["getLocationByID", (AP_adminEvent select 3)] call AP_fnc_eventCfg) select 2)}
        do {
            _plb_pos = [((["getLocationByID", (AP_adminEvent select 3)] call AP_fnc_eventCfg) select 2), 1, 250, 1, 0, 0, 0, [], ((["getLocationByID", (AP_adminEvent select 3)] call AP_fnc_eventCfg) select 2)] call BIS_fnc_findSafePos;
        }; uiSleep ((random 3) + 2);
        player setPos _plb_pos;};
    AP_deathCamera cameraEffect["TERMINATE", "BACK"];
    camDestroy AP_deathCamera;
    player switchMove "amovpercmstpsnonwnondnon";};
private _defaultGear = [[], [], [], ["U_B_Wetsuit", []], ["V_TacVest_oli", []], ["B_Carryall_cbr", []], "H_HelmetB_light", "", [],
    ["ItemMap", "", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]];
private _nextGun =
switch (AP_gunGameKills) do {case 0: {_defaultGear set[0, ["LMG_Zafir_F", "", "", "", ["150Rnd_762x54_Box", 150], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["150Rnd_762x54_Box", 2, 150]]]];
            _defaultGear;};
    case 1: {_defaultGear set[0, ["LMG_Mk200_F", "", "", "optic_Arco", ["200Rnd_65x39_cased_Box", 200], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["200Rnd_65x39_cased_Box", 2, 200]]]];
            _defaultGear;};
    case 2: {_defaultGear set[0, ["LMG_03_F", "", "", "optic_Arco", ["200Rnd_556x45_Box_F", 200], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["200Rnd_556x45_Box_F", 2, 200]]]];
            _defaultGear;};
    case 3: {_defaultGear set[0, ["srifle_EBR_F", "", "", "optic_Arco", ["20Rnd_762x51_Mag", 20], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["20Rnd_762x51_Mag", 10, 20]]]];
            _defaultGear;};
    case 4: {_defaultGear set[0, ["arifle_MXM_F", "", "", "optic_Arco", ["30Rnd_65x39_caseless_mag", 30], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["30Rnd_65x39_caseless_mag", 10, 30]]]];
            _defaultGear;};
    case 5: {_defaultGear set[0, ["arifle_MX_Black_F", "", "", "optic_Arco", ["30Rnd_65x39_caseless_mag", 30], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["30Rnd_65x39_caseless_mag", 10, 30]]]];
            _defaultGear;};
    case 6: {_defaultGear set[0, ["arifle_MXC_Black_F", "", "", "optic_Arco", ["30Rnd_65x39_caseless_mag", 30], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["30Rnd_65x39_caseless_mag", 10, 30]]]];
            _defaultGear;};
    case 7: {_defaultGear set[0, ["arifle_Katiba_F", "", "", "optic_Arco", ["30Rnd_65x39_caseless_green", 30], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["30Rnd_65x39_caseless_green", 10, 30]]]];
            _defaultGear;};
    case 8: {_defaultGear set[0, ["SMG_03C_TR_khaki", "", "", "", ["50Rnd_570x28_SMG_03", 50], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["50Rnd_570x28_SMG_03", 10, 50]]]];
            _defaultGear;};
    case 9: {_defaultGear set[0, ["srifle_DMR_06_hunter_F", "", "", "optic_Arco", ["10Rnd_Mk14_762x51_Mag", 10], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["10Rnd_Mk14_762x51_Mag", 10, 10]]]];
            _defaultGear;};
    case 10: {_defaultGear set[0, ["srifle_DMR_01_F", "", "", "optic_Arco", ["10Rnd_762x54_Mag", 10], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["10Rnd_762x54_Mag", 10, 10]]]];
            _defaultGear;};
    case 11: {_defaultGear set[0, ["hgun_PDW2000_F", "", "", "", ["30Rnd_9x21_Mag", 30], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["30Rnd_9x21_Mag", 10, 30]]]];
            _defaultGear;};
    case 12: {_defaultGear set[0, ["arifle_sdar_F", "", "", "", ["20Rnd_556x45_UW_mag", 20], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["20Rnd_556x45_UW_mag", 10, 20]]]];
            _defaultGear;};
    case 13: {_defaultGear set[2, ["hgun_Rook40_F", "", "", "", ["30Rnd_9x21_Mag", 20], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["30Rnd_9x21_Mag", 10, 20]]]];
            _defaultGear;};
    case 14: {_defaultGear set[2, ["hgun_Pistol_heavy_02_F", "", "", "", ["6Rnd_45ACP_Cylinder", 6], [], ""]];
            _defaultGear set[5, ["B_AssaultPack_khk", [["6Rnd_45ACP_Cylinder", 10, 6]]]];
            _defaultGear;};
    default {_defaultGear;};}; if (AP_gunGameKills <= 14) then {if !(AP_adminEvent select 0) exitWith {};
    player setUnitLoadout _nextGun;
    if (sunOrMoon < 0.5) then {player action["nvGoggles", player];};
    if (_progress) then {[["Player Killed", 0.25, 0.25], [format["Advanced to the next tier! %1/15", AP_gunGameKills], 0.25, 0.25],
            [format["%1", getText(configFile >> "CfgWeapons" >> currentWeapon player >> "DisplayName")], 0.25, 0.25, 7]
        ] spawn BIS_fnc_EXP_camp_SITREP;} else {};} else {if !(AP_adminEvent select 0) exitWith {}; [
        [2, player], "APS_fnc_eventGunGameSRV", 2] spawn AP_fnc_MP;};