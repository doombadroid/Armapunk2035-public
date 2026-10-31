removeAllWeapons player; {player removeMagazine _x;}
forEach(magazines player);
removeUniform player;
removeVest player;
removeBackpack player;
removeGoggles player;
removeHeadGear player; {player unassignItem _x;
    player removeItem _x;}
forEach(assignedItems player);
private _uniforms = ["U_C_Poloshirt_blue", "U_C_Poloshirt_burgundy", "U_C_Poloshirt_stripped", "U_C_Poloshirt_tricolour", "U_C_Poloshirt_salmon", "U_C_Poloshirt_redwhite", "U_C_Poor_1", "U_I_G_Story_Protagonist_F", "U_I_G_resistanceLeader_F", "U_NikosBody", "U_OrestesBody", "U_C_HunterBody_grn", "U_OG_Guerilla3_1", "U_OG_Guerilla3_2", "U_IG_Guerilla2_1", "U_IG_Guerilla2_2", "U_IG_Guerilla2_3", "U_I_C_Soldier_Bandit_1_F", "U_I_C_Soldier_Bandit_2_F", "U_I_C_Soldier_Bandit_3_F", "U_I_C_Soldier_Bandit_4_F", "U_I_C_Soldier_Bandit_5_F", "U_C_Man_casual_1_F", "U_C_Man_casual_2_F", "U_C_Man_casual_3_F", "U_C_Man_casual_4_F", "U_C_Man_casual_5_F", "U_C_Man_casual_6_F"];
if (getPlayerUID player isEqualTo(SRV_governorData param[0, "GovUID"])) then {player forceAddUniform "U_NikosAgedBody";} else {
    player forceAddUniform(selectRandom _uniforms);};
player linkItem "ItemMap";
player linkItem "ItemWatch";
player linkItem "ItemCompass";
AP_carryWeight = 0; {missionNamespace setVariable[_x, 0];}
forEach([1] call AP_fnc_virtItemCfg);
// owner 2026-07-13: Red Burger Regular (62) pruned -- trivial spawn freebie, removed.
if (128 in AP_side_talents) then {player addWeapon "Integrated_NVG_F";
    player addWeapon "Binocular";
    // GPS dropped: it's core now (all factions auto-spawn with a GPS). Hawk Eyes keeps NVGs + Binos.
};
// owner 2026-07-20: Hackerman talent (250) removed with the Hacker tree -- the Cyberdeck is bought at the Rebel market ($10k).
[true] call AP_fnc_saveGear;
[uniform player, "setUniform", ""] call AP_fnc_clothingTextures;