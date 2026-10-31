private _handle = [] spawn AP_fnc_stripDownPlayer;
waitUntil {scriptDone _handle};
// owner 2026-06-18: undercover/SCD gear leaked to CADETS on respawn. Role "all" is granted for
// adminLevel>=3 OR copLevel>=6, so an ADMIN signing on at a low cop rank (e.g. cadet) holds "all"
// -> scdGear here = "cadets on death get undercover loadout". Gate the "all" clause on ACTUALLY being a
// high-rank cop (copLevel>=6 = a real Captain), so admins below that rank get their RANK loadout. Real captains
// still spawn undercover (owner's call).
// PR7: the second clause listed the four undercover SLOT NAMES. The slots are gone and the role now comes
// from the duty terminal's picker, which offers it on the AP_isSCD whitelist alone at any rank -- exactly
// the population the slots were whitelisted to. So this is the same test, spelled as the role. The rank
// half is deliberately NOT folded into a flat `AP_copRole in ["scd","all"]`: that would drop the copLevel
// guard and hand undercover kit back to the admin cadet the owner's fix took it from.
if ((AP_copRole isEqualTo "scd") || {(AP_copRole isEqualTo "all") && ((call AP_copLevel) >= 6)}) exitWith {
    [] call AP_fnc_scdGear;};
// owner 2026-08-13: MaxSec spawns in the stock U_Rangemaster. The per-rank retexture skins were retired
// with the rest of the custom police art, so there is no texture override here any more.
player forceAddUniform "U_Rangemaster";
if (83 in AP_side_talents) then {player addVest "V_tacVest_blk_police"} else {player addVest "V_Rangemaster_belt"};
if (129 in AP_side_talents) then {player addWeapon "Integrated_NVG_F";
    player linkItem "ItemGPS"};
player addHeadgear "H_Cap_police";
player linkItem "ItemMap";
player linkItem "ItemCompass";
player addWeapon "Binocular";
player linkItem "ItemGPS";
[] call AP_fnc_giveMedkits;
player addMagazines["30Rnd_9x21_Mag", 3];
player addMagazines["SmokeShell", 2];
player addWeapon "hgun_P07_F";
player addHandgunItem "muzzle_snds_L";
switch (true) do {case (43 in AP_cop_talents && (call AP_copLevel) >= 5): {
            [player, "arifle_MXM_Black_F", 6, "30Rnd_65x39_caseless_black_mag"] call BIS_fnc_addWeapon;
            player addMagazines["30Rnd_65x39_caseless_black_mag", 2];};
    case (41 in AP_cop_talents && (call AP_copLevel) >= 4): {
            [player, "arifle_MX_Black_F", 6, "30Rnd_65x39_caseless_black_mag"] call BIS_fnc_addWeapon;
            player addMagazines["30Rnd_65x39_caseless_black_mag", 2];};
    case (81 in AP_side_talents && (call AP_copLevel) >= 2): {
            [player, "arifle_SPAR_01_blk_F", 6, "30Rnd_556x45_Stanag"] call BIS_fnc_addWeapon;
            player addMagazines["30Rnd_556x45_Stanag", 2];};
    default {[player, "SMG_05_F", 7, "30Rnd_9x21_Mag_SMG_02_Tracer_Yellow"] call BIS_fnc_addWeapon;};
}; player addPrimaryWeaponItem "optic_ACO_grn_smg";
// owner 2026-06-16 (#257/#263): this hard-set the BACKPACK skin index to -1 on every cop gear-up. The login
// path (fn_requestReceived) had just restored the player's saved backpack skin (AP_clothingSkinsCop), so the
// re-gear wiped it -> "invisible backpack reverts after restart" (#263); and a revive re-gears, so it also
// reverted "after being revived" (#257). PRESERVE the saved backpack skin index and re-apply it (the skin
// only paints if its class matches the equipped pack, so a mismatch is a harmless no-op).
private _savedBackpackSkin = (profileNamespace getVariable ["AP_clothingSkinsCop", [-1, -1]]) param [1, -1];
// owner 2026-08-13: -1 = "no uniform skin" (same sentinel fn_buyClothes uses on the no-texture path).
// The police rows this used to index (63 for cadet, else copLevel) were deleted with the custom skins.
AP_uniformBackpack_skins = [-1, _savedBackpackSkin];
if (_savedBackpackSkin != -1 && {!(backpack player isEqualTo "")}) then {
    [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;};
[false] call AP_fnc_saveGear;