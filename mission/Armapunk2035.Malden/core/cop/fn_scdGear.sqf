private _magazine = "30Rnd_556x45_Stanag_Sand";
private _uniforms = ["U_B_CombatUniform_vest_mcam_wdl_f", "U_I_CombatUniform", "U_B_CTRG_Soldier_2_Arid_F", "U_B_CTRG_Soldier_Arid_F", "U_B_CTRG_Soldier_urb_2_F", "U_I_E_Uniform_01_sweater_F"];
private _backpacks = ["B_AssaultPack_blk", "B_AssaultPack_rgr", "B_AssaultPack_dgtl"];
private _vests = ["V_TacVest_camo", "V_TacVest_oli", "V_TacVest_khk", "V_TacVest_blk"];
private _primaryWeapon =
if (395180 in (getDLCs 1)) then {selectRandom["arifle_SPAR_01_khk_F", "arifle_SPAR_01_snd_F"]} else {
    selectRandom["arifle_TRG21_F", "arifle_Mk20_plain_F", "arifle_Mk20C_plain_F", "arifle_TRG20_F"]};
player forceAddUniform(selectRandom _uniforms);
player addBackpack(selectRandom _backpacks);
player addVest(selectRandom _vests);
player addHeadgear "H_Watchcap_blk";
player addGoggles "G_Bandanna_aviator";
player addWeapon "Binocular"; {player linkItem _x}
forEach["ItemMap", "ItemGPS", "ItemCompass", "Integrated_NVG_F"]; {(unitBackpack player) addItemCargoGlobal _x}
forEach[["optic_MRCO", 1], ["V_tacVest_blk_police", 1], ["H_Cap_police", 1]];
switch (true) do {case (43 in AP_cop_talents && (call AP_copLevel) >= 5): {_primaryWeapon = "arifle_MXM_F";
            _magazine = "30Rnd_65x39_caseless_mag";};
    case (41 in AP_cop_talents && (call AP_copLevel) >= 4): {_primaryWeapon = "arifle_MX_F";
            _magazine = "30Rnd_65x39_caseless_mag";};}; { player addMagazines _x}
forEach[[_magazine, 8]];
player addWeapon _primaryWeapon;
player addWeaponItem[_primaryWeapon, "acc_flashlight"];
player addWeaponItem[_primaryWeapon, "optic_Arco_lush_F"];
player addMagazines["30Rnd_9x21_Mag", 2];
player addWeapon "hgun_P07_F";
player addHandgunItem "muzzle_snds_L";
if (86 in AP_side_talents) then {player addMagazines["MiniGrenade", 1]};
player addMagazines["SmokeShellBlue", 4];
[] call AP_fnc_giveMedkits;
[false] call AP_fnc_saveGear;
[] spawn {uiSleep 0.5;
    [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;};