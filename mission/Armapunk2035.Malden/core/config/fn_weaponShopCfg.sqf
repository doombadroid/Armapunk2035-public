// ---------------------------------------------------------------------------------------------
// ECONOMY 2026-09-05: ONE derived price for every firearm in the game.
//
// Two catalogues used to price the same guns and disagreed by a median factor of 2.5: a curated
// table of hand-typed rows loaded first, and this file's runtime CfgWeapons sweep, which only ever
// got to price a gun whose display name nobody had already typed into the array. That produced 79
// pairs where a gun strictly worse in damage, penetration AND magazine size cost MORE than its
// better at the same counter, and a 33.9x spread in dollars-per-lethality inside one shop.
//
// The curve is the old one generalised. It was `hit^2 * 150`, which ignores penetration entirely --
// so a 7.62x54 DMR (caliber 1.8, the best armour penetration a rebel can buy) priced identically to
// a 7.62x51 (caliber 1.6), and 5.7x28 (caliber 0.56, stopped by a plate carrier) priced like 5.45.
// Now:
//
//     L     = hit * (0.5 + 0.5 * caliber)        damage, weighted by what it defeats
//     S     = clamp(1 + 0.35 * log2(cap / 30), 0.9, 2.0)   sustain; 30 rounds is neutral
//     price = K * L^2 * S                        K = 75 primary, 40 handgun
//
// K is set from the KIT, not from any single gun: a 7.62x51 rifle plus the best buyable vest and
// helmet has to come to about $30,000, which puts the rifle at $15,300 and a 6.5 mm rifle at $7,500.
// That lands between the two old catalogues rather than on either -- roughly 1.5x the hand table and
// half what this file's old formula charged.
//
// Returns -1 for anything the curve must NOT price:
//   * submunition rounds (shotgun pellets). The carrier's `hit` of 20 is not per-pellet damage --
//     the pellets themselves hit for 2 -- and feeding it to a squared curve prices a sawn-off above
//     a DMR. Shotguns keep a hand band by role.
//   * launchers and flare guns (type 4, and any type outside 1/2). Explosive damage is a different
//     scale; those stay hand-priced as deliberate gates.
// A -1 leaves the curated row's own price untouched.
if !(isFinal "AP_fnc_gunPrice") then {AP_fnc_gunPrice = compileFinal {
    params ["_cls"];
    private _cfg = configFile >> "CfgWeapons" >> _cls;
    private _type = getNumber (_cfg >> "type");
    if !(_type in [1, 2]) exitWith { -1 };
    private _mags = getArray (_cfg >> "magazines");
    if (_mags isEqualTo []) exitWith { -1 };
    // Walk the list for the first magazine that actually RESOLVES. The lush and arid AK-12 variants
    // list magazine classnames (30Rnd_762x39_AK12_Lush_Mag_F and friends) that are defined nowhere in
    // the shipped configs, so taking magazines[0] blindly returned an empty ammo path -> no price ->
    // the old curated number stood, and two rifles firing the identical round ended up $6,000 apart.
    private _mc = configNull;
    private _ac = configNull;
    {
        private _m = configFile >> "CfgMagazines" >> _x;
        if (isClass _m) then {
            private _a = configFile >> "CfgAmmo" >> (getText (_m >> "ammo"));
            if (isClass _a) exitWith { _mc = _m; _ac = _a; };
        };
    } forEach _mags;
    if (isNull _ac) exitWith { -1 };
    if ((getText (_ac >> "submunitionAmmo")) isNotEqualTo "") exitWith { -1 };
    // read the RAW hit first: a flare gun's signal round hits for 0, and clamping before the test
    // would price it as a $1,100 sidearm. Signal equipment is not a weapon; leave it hand-priced.
    private _hit = getNumber (_ac >> "hit");
    if (_hit <= 0) exitWith { -1 };
    _hit = _hit max 5;
    private _cal = (getNumber (_ac >> "caliber")) max 0.1;
    private _cap = (getNumber (_mc >> "count")) max 1;
    private _l = _hit * (0.5 + 0.5 * _cal);
    // log is base 10 in SQF; log2(x) = log x / log 2
    private _s = (((1 + 0.35 * ((log (_cap / 30)) / (log 2))) max 0.9) min 2);
    private _k = if (_type isEqualTo 1) then { 75 } else { 40 };
    (round ((_k * _l * _l * _s) / 100)) * 100
}};
// Faction multiplier, applied to the derived price. This replaces 234 implicit discounts: MaxSec
// paid a median 0.60x the rebel price today but individual guns ranged 0.36x to 0.90x, and the
// medic shop ranged 0.47x to 2.00x with a median of exactly 1.00. Nobody chose those spreads.
// Rank and talent gates are untouched -- this changes what a gun costs, never who may buy it.
if !(isFinal "AP_fnc_gunFactionMult") then {AP_fnc_gunFactionMult = compileFinal {
    params ["_shopType"];
    switch (_shopType) do {
        case "police_weapons";
        case "maxtac_weapons";
        case "srt_weapons";
        case "police_equipment": { 0.55 };   // department issue, and cops respawn into it repeatedly
        case "med_basic":        { 0.75 };   // licensed but not subsidised
        case "bounty";
        case "skiptracer":       { 1.15 };   // grey-market premium on a catalogue nobody else reaches
        default                  { 1 };      // rebel / turf / gun store is the baseline
    };
}};
// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};
params[["_shop","",[""]]];if(_shop isEqualTo"") exitWith{closeDialog 0};
private _shopName=switch(_shop) do{case"police_equipment":{"Police General Equipment"};case"med_basic":{"TT Equipment Shop"};case"police_weapons":{switch(call AP_copLevel) do{case 1:{"Cadet Armory"};case 2:{"Patrol Officer Armory"};case 3:{"Corporal Armory"};case 4:{"Sergeant Armory"};case 5:{"Lieutenant Armory"};case 6:{"Captain Armory"};case 7:{"Chief of Police Armory"};default{"Police Armory"};};};case"srt_weapons":{"SRT Armory"};case"maxtac_weapons":{"MaxTac Armory"};case"bounty":{"Bounty Hunter Shop"};case"skiptracer":{"Bounty Hunter Shop"};case"ndheavy":{"ND Heavy Weapons"};case"rebelwep":{"Your Jihadi Shop"};case"turf":{"Gang Gats"};case"gun":{"Billy Joe's Firearms"};case"huntingwep":{"Hunting Ground Supplies"};case"genstore":{format["%1 General Store",worldName]};case"gas":{format["%1 Gas Station",worldName]};case"delivery":{format["%1 DP Supplies",worldName]};default{"No Shop Name"};};private _isMaxTac=false;private _isSRT=false;if(_shop isEqualTo"police_weapons"&&AP_isMaxTac&&AP_activeMAXTAC) then{_shopName="MaxTac Armory";_isMaxTac=true;};if(_shop isEqualTo"maxtac_weapons"&&AP_isMaxTac) then{_isMaxTac=true;};;;private _exit=false;switch(_shop) do{case"police_equipment":{_exit=if!(AP_effSide isEqualTo west) then{true}else{false};};case"med_basic":{_exit=if!(AP_effSide isEqualTo independent) then{true}else{false};};case"police_weapons":{_exit=if!(AP_effSide isEqualTo west) then{true}else{false};};case"maxtac_weapons":{_exit=if!(AP_effSide isEqualTo west&&AP_isMaxTac) then{true}else{false};if(_exit)then{["You are not MaxTac whitelisted!","basic"]spawn AP_fnc_handleMessage;};};case"bounty":{if!(license_civ_bounty) then{_exit=true;["You don't have a bounty hunter license!","basic"]spawn AP_fnc_handleMessage;};};case"skiptracer":{if!(license_civ_bounty) then{_exit=true;["You don't have a bounty hunter license!","basic"]spawn AP_fnc_handleMessage;};if!(8 in AP_side_talents) then{_exit=true;["You don't have the talent required of a Master Bounty Hunter!","basic"]spawn AP_fnc_handleMessage;};};case"ndheavy":{_exit=if!(AP_effSide isEqualTo civilian) then{true}else{false};if!(license_civ_rebel) then{_exit=true;["You don't have a Rebel Training!","basic"]spawn AP_fnc_handleMessage;};};case"rebelwep":{_exit=if!(AP_effSide isEqualTo civilian) then{true}else{false};if!(license_civ_rebel) then{_exit=true;["You don't have a Rebel Training!","basic"]spawn AP_fnc_handleMessage;};};case"turf":{};case"gun":{_exit=if!(AP_effSide isEqualTo civilian) then{true}else{false};if!(license_civ_gun) then{_exit=true;["You don't have a Firearms License!","basic"]spawn AP_fnc_handleMessage;};};case"genstore":{};case"gas":{};case"delivery":{};default{};};if(_exit) exitWith{};private _copLevel=call AP_copLevel;private _medLevel=call AP_medicLevel;private _ttRank=if(_medLevel isEqualTo 99) then{0}else{_medLevel};if(AP_effSide isEqualTo west&&AP_isMaxTac&&AP_activeMAXTAC) then{_copLevel=5;};private _smokeNades=if((AP_effSide isEqualTo west&&_shop=="police_weapons"&&_copLevel>=4)||AP_effSide isEqualTo civilian) then{true}else{false};private _medSmokes=if(AP_effSide isEqualTo independent&&_medLevel<=2) then{false}else{true};private _srtKills=0;private _weaponList=[["ToolKit",nil,50,["police_equipment","med_basic","bounty","skiptracer","turf","genstore","gas","delivery","rebelwep","huntingwep","srt_weapons"],true],["FirstAidKit",nil,75,["police_equipment","med_basic","bounty","skiptracer","turf","genstore","gas","delivery","rebelwep","huntingwep","srt_weapons"],true],["ItemGPS",nil,10,["police_equipment","med_basic","bounty","skiptracer","turf","genstore","gas","delivery","rebelwep","huntingwep","srt_weapons"],true],["ItemMap",nil,10,["police_equipment","med_basic","bounty","skiptracer","turf","genstore","gas","delivery","rebelwep","huntingwep","srt_weapons"],true],["ItemCompass",nil,10,["police_equipment","med_basic","bounty","skiptracer","turf","genstore","gas","delivery","rebelwep","huntingwep","srt_weapons"],true],["ItemWatch",nil,10,["police_equipment","med_basic","bounty","skiptracer","turf","genstore","gas","delivery","rebelwep","huntingwep","srt_weapons"],true],["Binocular",nil,100,["police_equipment","med_basic","bounty","skiptracer","turf","genstore","gas","delivery","rebelwep","huntingwep","srt_weapons"],true],["Rangefinder",nil,1000,["police_equipment","med_basic","skiptracer","rebelwep","srt_weapons"],true],["B_UavTerminal",nil,1000,["police_equipment"],_copLevel>=4],["I_UavTerminal","UAV Terminal",1000,["med_basic"],_ttRank>=5],["NVGoggles_OPFOR",nil,300,["police_equipment","srt_weapons"],_copLevel>=1],["Integrated_NVG_F","NV Goggles (Fullscreen)",300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["NVGoggles",nil,300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["NVGoggles_INDEP",nil,300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["O_NVGoggles_grn_F",nil,300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["O_NVGoggles_urb_F",nil,300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["O_NVGoggles_ghex_F",nil,300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["O_NVGoggles_hex_F",nil,300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["NVGoggles_tna_F",nil,300,["police_equipment","rebelwep","turf","genstore","med_basic","bounty","skiptracer","huntingwep","srt_weapons"],true],["Chemlight_green",nil,50,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],true],["Chemlight_red",nil,50,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],true],["Chemlight_yellow",nil,50,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],true],["Chemlight_blue",nil,50,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],true],["SmokeShell",nil,100,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],_medSmokes],["SmokeShellRed",nil,100,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],_medSmokes],["SmokeShellGreen",nil,100,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],_medSmokes],["SmokeShellYellow",nil,100,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],_medSmokes],["SmokeShellPurple",nil,100,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],_medSmokes],["SmokeShellBlue",nil,100,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],_medSmokes],["SmokeShellOrange",nil,100,["police_weapons","med_basic","skiptracer","turf","rebelwep","srt_weapons"],_medSmokes],["1Rnd_Smoke_Grenade_shell",nil,250,["police_weapons","turf","rebelwep"],_smokeNades],["1Rnd_SmokeRed_Grenade_shell",nil,250,["police_weapons","turf","rebelwep"],_smokeNades],["1Rnd_SmokeGreen_Grenade_shell",nil,250,["police_weapons","turf","rebelwep"],_smokeNades],["1Rnd_SmokeYellow_Grenade_shell",nil,250,["police_weapons","turf","rebelwep"],_smokeNades],["1Rnd_SmokePurple_Grenade_shell",nil,250,["police_weapons","turf","rebelwep"],_smokeNades],["1Rnd_SmokeBlue_Grenade_shell",nil,250,["police_weapons","turf","rebelwep"],_smokeNades],["1Rnd_SmokeOrange_Grenade_shell",nil,250,["police_weapons","turf","rebelwep"],_smokeNades],["3Rnd_Smoke_Grenade_shell",nil,500,["police_weapons"],_smokeNades],["3Rnd_SmokeRed_Grenade_shell",nil,500,["police_weapons"],_smokeNades],["3Rnd_SmokeGreen_Grenade_shell",nil,500,["police_weapons"],_smokeNades],["3Rnd_SmokeYellow_Grenade_shell",nil,500,["police_weapons"],_smokeNades],["3Rnd_SmokePurple_Grenade_shell",nil,500,["police_weapons"],_smokeNades],["3Rnd_SmokeBlue_Grenade_shell",nil,500,["police_weapons"],_smokeNades],["3Rnd_SmokeOrange_Grenade_shell",nil,500,["police_weapons"],_smokeNades],["MiniGrenade","Flashbang",1000,["police_weapons"],_copLevel>=2&&(86 in AP_side_talents)],["HandGrenade",nil,5000,["rebelwep"],true],["hgun_Pistol_Signal_F","Flare Gun",500,["gun","rebelwep","skiptracer","turf","bounty","huntingwep"],true],["hgun_Pistol_01_F",nil,1250,["gun","rebelwep","turf","huntingwep"],true],["hgun_Rook40_F",nil,1500,["gun","rebelwep","turf","huntingwep"],true],["hgun_ACPC2_F",nil,2500,["gun","rebelwep","turf","huntingwep"],true],["hgun_Pistol_heavy_02_F",nil,2500,["rebelwep","turf"],true],["hgun_P07_F",nil,1000,["skiptracer","bounty"],true],["hgun_P07_khk_F",nil,1000,["skiptracer","bounty","police_weapons"],true],["hgun_P07_blk_F",nil,1000,["skiptracer","bounty","police_weapons"],true],["hgun_Pistol_Signal_F","Flare Gun",1000,["med_basic"],_medLevel>=4],["hgun_P07_khk_F","Medic P07 (Heal/Taser)",20000,["med_basic"],15 in AP_medic_talents],["muzzle_snds_L","P07 Suppressor",2000,["med_basic"],16 in AP_medic_talents],["SMG_05_F",nil,3500,["med_basic"],_ttRank>=1],["hgun_P07_F",nil,1000,["med_basic"],_ttRank>=1],["hgun_PDW2000_F",nil,3000,["med_basic"],_ttRank>=1],["SMG_02_F",nil,4000,["med_basic"],_ttRank>=1],["SMG_01_F",nil,4000,["med_basic"],_ttRank>=1],["arifle_MX_Black_F",nil,3500,["med_basic"],_ttRank>=2],["arifle_MXC_Black_F",nil,3000,["med_basic"],_ttRank>=2],["arifle_MSBS65_black_F",nil,3500,["med_basic"],_ttRank>=2],["arifle_MSBS65_Mark_black_F",nil,4000,["med_basic"],_ttRank>=2],["arifle_Katiba_F",nil,4000,["med_basic"],_ttRank>=2],["arifle_Katiba_C_F",nil,3500,["med_basic"],_ttRank>=2],["arifle_sdar_F",nil,1500,["med_basic"],_ttRank>=2],["SMG_03_F",nil,4000,["med_basic"],_ttRank>=2],["arifle_CTAR_blk_F",nil,4500,["med_basic"],_ttRank>=2],["hgun_Rook40_F",nil,1500,["med_basic"],_ttRank>=2],["srifle_DMR_07_blk_F",nil,4250,["med_basic"],_ttRank>=2],["srifle_DMR_06_F",nil,4250,["med_basic"],_ttRank>=3],["arifle_SPAR_03_blk_F",nil,4500,["med_basic"],_ttRank>=3],["arifle_SPAR_02_blk_F",nil,5000,["med_basic"],_ttRank>=3],["arifle_MXM_Black_F",nil,4500,["med_basic"],_ttRank>=3],["arifle_MX_GL_Black_F",nil,5000,["med_basic"],_ttRank>=3],["arifle_MSBS65_GL_black_F",nil,5000,["med_basic"],_ttRank>=3],["sgun_HunterShotgun_01_F",nil,6000,["med_basic"],_ttRank>=3],["hgun_Pistol_heavy_01_F",nil,2500,["med_basic"],_ttRank>=3],["srifle_DMR_06_hunter_F",nil,5000,["med_basic"],_ttRank>=3],["arifle_ARX_blk_F",nil,4500,["med_basic"],_ttRank>=3],["srifle_DMR_01_F",nil,3250,["med_basic"],_ttRank>=5],["srifle_DMR_03_F",nil,4250,["med_basic"],_ttRank>=5],["srifle_EBR_F",nil,5200,["med_basic"],_ttRank>=5],["arifle_MX_SW_Black_F",nil,5000,["med_basic"],_ttRank>=5],["hgun_ACPC2_F",nil,2500,["med_basic"],_ttRank>=5],["arifle_AK12_F",nil,4500,["med_basic"],_ttRank>=6],["LMG_Mk200_F",nil,9000,["med_basic"],_ttRank>=6],["LMG_03_F",nil,30000,["med_basic"],_ttRank>=6],["hgun_Pistol_heavy_02_F",nil,2500,["med_basic"],_ttRank>=6],["LMG_Zafir_F",nil,50000,["med_basic"],_ttRank>=7],["arifle_AK12_lush_F",nil,5000,["med_basic"],_ttRank>=7],["arifle_RPK12_lush_F",nil,20000,["med_basic"],_ttRank>=7],["srifle_DMR_04_F",nil,6000,["med_basic"],_ttRank>=7],["SMG_05_F",nil,3500,["rebelwep","turf"],true],["hgun_PDW2000_F",nil,3500,["gun","rebelwep","turf"],true],["SMG_02_F",nil,4000,["skiptracer","bounty"],true],["SMG_01_F",nil,4000,["skiptracer","bounty","rebelwep","turf"],true],["sgun_HunterShotgun_01_sawedoff_F","12Ga Sawed Off (Illegal)",4500,["rebelwep","turf"],true],["sgun_HunterShotgun_01_F","12Ga Shotgun (Illegal)",6000,["rebelwep","turf","huntingwep"],true],["SMG_03C_TR_khaki","P90 SMG Khaki",6000,["rebelwep","turf"],true],["SMG_03C_TR_camo","P90 SMG Camo",6000,["rebelwep","turf"],true],["SMG_03C_TR_hex","P90 SMG Hex",6000,["rebelwep","turf"],true],["SMG_03C_TR_black","P90 SMG Black",6000,["rebelwep","turf"],true],["SMG_03_TR_khaki","P90 SMG Khaki",7000,["rebelwep","turf"],true],["SMG_03_TR_camo","P90 SMG Camo",7000,["rebelwep","turf"],true],["SMG_03_TR_hex","P90 SMG Hex",7000,["rebelwep","turf"],true],["SMG_03_TR_black","P90 SMG Black",7000,["rebelwep","turf"],true],["hgun_P07_F",nil,500,["police_weapons"],_copLevel>=1],["SMG_05_F",nil,1250,["police_weapons"],_copLevel>=1],["arifle_sdar_F",nil,1500,["police_weapons"],_copLevel>=2&&82 in AP_side_talents],["arifle_Mk20_F",nil,1250,["police_weapons"],81 in AP_side_talents],["arifle_SPAR_01_blk_F",nil,2000,["police_weapons"],_copLevel>=1&&81 in AP_side_talents],["arifle_MXC_Black_F",nil,2000,["police_weapons"],_copLevel>=2&&81 in AP_side_talents],["arifle_MX_Black_F",nil,2500,["police_weapons"],_copLevel>=2&&84 in AP_side_talents],["arifle_MSBS65_black_F",nil,2500,["police_weapons"],_copLevel>=2&&84 in AP_side_talents],["arifle_ARX_blk_F",nil,3000,["police_weapons"],_copLevel>=3&&85 in AP_side_talents],["arifle_MXM_Black_F",nil,3000,["police_weapons"],_copLevel>=3&&85 in AP_side_talents],["SMG_03C_TR_black",nil,3000,["police_weapons"],_copLevel>=3&&85 in AP_side_talents],["SMG_03_TR_black",nil,3000,["police_weapons"],_copLevel>=3&&85 in AP_side_talents],["arifle_MSBS65_Mark_black_F",nil,3000,["police_weapons"],_copLevel>=3&&85 in AP_side_talents],["arifle_SPAR_02_blk_F",nil,5000,["police_weapons"],_copLevel>=4&&85 in AP_side_talents],["arifle_MX_GL_Black_F","MX Smoke Launcher",3000,["police_weapons"],_copLevel>=4&&85 in AP_side_talents],["arifle_MSBS65_GL_black_F","Promet Smoke Launcher",3000,["police_weapons","maxtac_weapons"],_copLevel>=4&&85 in AP_side_talents],["arifle_MSBS65_UBS_F","Promet UBS Shotgun",3000,["maxtac_weapons"],true],["hgun_Pistol_heavy_01_green_F",nil,750,["police_weapons"],_copLevel>=5],["hgun_Pistol_heavy_01_F",nil,750,["police_weapons"],_copLevel>=5],["arifle_SPAR_03_blk_F",nil,4500,["police_weapons"],_copLevel>=5&&85 in AP_side_talents],["srifle_DMR_03_F",nil,5000,["police_weapons"],_copLevel>=5&&85 in AP_side_talents],["arifle_MX_SW_Black_F",nil,5000,["police_weapons"],_copLevel>=6&&85 in AP_side_talents],["hgun_Pistol_Signal_F","Flare Gun",250,["police_weapons"],AP_copRole in["scd","all"]],["hgun_Rook40_F",nil,750,["police_weapons"],AP_copRole in["scd","all"]],["hgun_Pistol_01_F",nil,500,["police_weapons"],AP_copRole in["scd","all"]],["SMG_02_F",nil,2000,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["SMG_01_F",nil,2000,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["hgun_PDW2000_F",nil,2000,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_Mk20_plain_F",nil,1750,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_Mk20C_plain_F",nil,1750,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_TRG20_F",nil,1750,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_TRG21_F",nil,1750,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_AKS_F",nil,2250,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_SPAR_01_khk_F",nil,2500,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_SPAR_01_snd_F",nil,2500,["police_weapons"],81 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_MXC_F",nil,2500,["police_weapons"],84 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_MX_F",nil,3000,["police_weapons"],84 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_MX_khk_F",nil,3000,["police_weapons"],84 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_MSBS65_F",nil,3000,["police_weapons"],84 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_ARX_hex_F",nil,3000,["police_weapons"],85 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_MXM_khk_F",nil,3500,["police_weapons"],85 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_MXM_F",nil,3500,["police_weapons"],85 in AP_side_talents&&AP_copRole in["scd","all"]],["hgun_Pistol_heavy_02_F",nil,1500,["police_weapons"],_copLevel>=4&&AP_copRole in["scd","all"]],["arifle_Katiba_F",nil,3250,["police_weapons"],_copLevel>=4&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_Katiba_C_F",nil,3250,["police_weapons"],_copLevel>=4&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_MSBS65_Mark_F",nil,3500,["police_weapons"],_copLevel>=5&&84 in AP_side_talents&&AP_copRole in["scd","all"]],["arifle_AK12_F",nil,4500,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_CTAR_blk_F",nil,3000,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_03_khaki_F",nil,5750,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_03_multicam_F",nil,5750,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_03_tan_F",nil,5750,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_03_woodland_F",nil,5750,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_SPAR_03_khk_F",nil,4500,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_SPAR_03_snd_F",nil,4500,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_01_F",nil,3250,["police_weapons"],_copLevel>=5&&85 in AP_side_talents],["srifle_EBR_F",nil,5200,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_06_olive_F",nil,4250,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_06_F",nil,4250,["police_weapons"],_copLevel>=5&&85 in AP_side_talents],["srifle_DMR_06_camo_F",nil,4250,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["srifle_DMR_06_hunter_F",nil,4000,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_AK12_lush_f",nil,4500,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_AK12U_lush_f",nil,4250,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_AKM_F",nil,4000,["police_weapons"],_copLevel>=5&&{85 in AP_side_talents&&AP_copRole in["scd","all"]}],["arifle_SPAR_01_khk_F","Spar 16",5000,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_SPAR_01_snd_F","Spar 16",5000,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_MXC_F","MXC (Illegal)",6000,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_MX_F","MX (Illegal)",6500,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_MX_khk_F","MX (Illegal)",6500,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_MX_Black_F","MX (Illegal)",6500,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_MXM_F","MXM (Illegal)",8000,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_MX_SW_F","MX SW (Illegal)",13000,["skiptracer"],8 in AP_side_talents&&{7 in AP_side_talents&&count AP_honor_talents>0}],["arifle_TRG20_F",nil,4000,["skiptracer","bounty"],true],["arifle_sdar_F","SDAR (Illegal)",3500,["rebelwep","gun","turf"],true],["arifle_Mk20_plain_F",nil,3500,["rebelwep","turf"],true],["arifle_Mk20C_plain_F",nil,3500,["rebelwep","turf"],true],["arifle_ARX_hex_F",nil,6000,["rebelwep","turf"],true],["srifle_DMR_03_F",nil,9000,["rebelwep"],true],["arifle_MSBS65_F",nil,5000,["rebelwep"],true],["arifle_MSBS65_Mark_F",nil,6000,["rebelwep"],true],["arifle_AK12_F",nil,5000,["rebelwep"],true],["arifle_AK12_lush_F",nil,5000,["rebelwep"],true],["arifle_AK12_arid_F",nil,5000,["rebelwep"],true],["arifle_AKS_F",nil,3500,["rebelwep","turf"],true],["arifle_CTAR_blk_F",nil,4500,["rebelwep","turf"],true],["arifle_CTAR_hex_F",nil,4500,["rebelwep","turf"],true],["arifle_CTAR_ghex_F",nil,4500,["rebelwep","turf"],true],["arifle_CTAR_GL_blk_F",nil,5500,["rebelwep","turf"],true],["arifle_CTAR_GL_hex_F",nil,5500,["rebelwep","turf"],true],["arifle_CTAR_GL_ghex_F",nil,5500,["rebelwep","turf"],true],["arifle_Katiba_F",nil,5000,["rebelwep","turf"],true],["arifle_Katiba_C_F",nil,5000,["rebelwep","turf"],true],["arifle_Katiba_GL_F","Katiba Smoke Launcher",6000,["rebelwep","turf"],true],["srifle_DMR_03_khaki_F",nil,9000,["rebelwep"],true],["srifle_DMR_03_multicam_F",nil,9000,["rebelwep"],true],["srifle_DMR_03_tan_F",nil,9000,["rebelwep"],true],["srifle_DMR_03_woodland_F",nil,9000,["rebelwep"],true],["arifle_SPAR_03_khk_F",nil,7000,["rebelwep"],true],["arifle_SPAR_03_snd_F",nil,7000,["rebelwep"],true],["srifle_DMR_01_F",nil,5000,["rebelwep"],true],["srifle_EBR_F",nil,8000,["rebelwep"],true],["srifle_DMR_06_olive_F",nil,6500,["rebelwep"],true],["srifle_DMR_06_camo_F",nil,6500,["rebelwep"],true],["srifle_DMR_06_hunter_F","7.62 Hunting Rifle (Illegal)",5000,["rebelwep","huntingwep"],true],["arifle_AK12_lush_f",nil,5000,["rebelwep"],true],["arifle_AK12U_lush_f",nil,6500,["rebelwep"],true],["arifle_AKM_F",nil,6000,["rebelwep"],true],["arifle_TRG21_F",nil,4000,["rebelwep","turf"],true],["arifle_SPAR_01_khk_F",nil,5000,["rebelwep","turf"],true],["arifle_SPAR_01_snd_F",nil,5000,["rebelwep","turf"],true],["LMG_Mk200_F",nil,9000,["rebelwep"],true],["LMG_Mk200_black_F",nil,9000,["rebelwep"],true],["LMG_03_F",nil,30000,["rebelwep"],true],["LMG_Zafir_F",nil,50000,["rebelwep"],true],["arifle_RPK12_lush_F",nil,20000,["rebelwep"],true],["arifle_RPK12_arid_F",nil,20000,["rebelwep"],true],["launch_RPG7_F",nil,30000,["rebelwep"],!AP_ndShop],["launch_RPG7_F",nil,30000,["rebelwep"],AP_ndShop],["arifle_SPAR_01_blk_F",format["SPAR-16 Black%1",([""," (ILLEGAL)"] select (!(SRV_governorData param[4,false])))],7500,["gun"],true],["launch_B_Titan_F","Titan AA Launcher",1000,["police_weapons","maxtac_weapons"],false],["srifle_GM6_F",nil,75000,["ndheavy"],true],["srifle_DMR_02_F",nil,61500,["ndheavy"],true],["MMG_02_camo_F",nil,90000,["ndheavy"],true],["srifle_DMR_06_F",nil,78000,["ndheavy"],true],["arifle_ARX_hex_F",nil,6000,["ndheavy"],true]];
private _matchShop=if(_shop isEqualTo"maxtac_weapons") then{"police_weapons"}else{_shop};private _list=[];{if(_isMaxTac) then{if(_matchShop in(_x select 3)) then{_list pushBack[_x select 0,_x select 1,_x select 2];};}else{if(_matchShop in(_x select 3)&&(_x select 4)) then{_list pushBack[_x select 0,_x select 1,_x select 2];};}}forEach _weaponList;
// LooneyBin 2026-06-10 (owner): REBEL + MaxSec armory carry the FULL gun catalog. Built once from
// CfgWeapons: every scope-2 rifle/MG/sniper/SMG + handgun, ONE entry per unique display name (kills
// camo-variant duplicates), and Titan-family + RPG-7 launchers ($150k) for REBEL ONLY. Prices scale
// with caliber damage (#82): 5.56 ~$9.6k, 6.5 ~$15k, 7.62 ~$18k, .338/9.3 MGs ~$40-65k, .50 ~$110k.
// Ammo for these guns is served by the side panel from fn_weaponAddons (AP_dynShopMags), not here.
if (_shop in ["rebelwep", "police_weapons", "maxtac_weapons"]) then {if (isNil "AP_dynGuns") then {AP_dynGuns = [];
        private _seenDN = [];
        private _cfgW = configFile >> "CfgWeapons";
        // owner 2026-06-11: top-tier exclusions -- Cyrus, GM6 Lynx, M320 LRR, Navid stay OUT of the
        // dyn rebel/MaxSec catalogs (event/crate loot only)
        private _plbExcluded = ["srifle_DMR_05_", "srifle_GM6_", "srifle_LRR_", "MMG_01_"];
        for "_i" from 0 to ((count _cfgW) - 1) do {private _c = _cfgW select _i;
            if (isClass _c && {(getNumber (_c >> "scope")) isEqualTo 2}) then {private _cn = configName _c;
                if ((_plbExcluded findIf { (_cn find _x) isEqualTo 0 }) isNotEqualTo -1) then { continue };
                private _type = getNumber (_c >> "type");
                private _dn = getText (_c >> "displayName");
                private _price = -1; private _isL = false;
                // BUGS.md #82: flat tiers priced a Navid like an MXM. Scale by the round's damage
                // (CfgAmmo hit: 5.56~8, 6.5~10, 7.62~11, .338/9.3~16-17, .50~27) on a hit-squared curve,
                // +50% on belt/drum feeds (>=100rnd mag) so MGs land above same-caliber rifles.
                private _hitCap = [8, 30];
                private _mags = getArray (_c >> "magazines");
                if (_mags isNotEqualTo []) then {private _mc = configFile >> "CfgMagazines" >> (_mags select 0);
                    private _ac = configFile >> "CfgAmmo" >> (getText (_mc >> "ammo"));
                    _hitCap = [(getNumber (_ac >> "hit")) max 5, getNumber (_mc >> "count")];};
                _hitCap params ["_hit", "_cap"];
                switch (_type) do {
                    // ECONOMY 2026-09-05: both cases now defer to AP_fnc_gunPrice so the dynamic
                    // catalogue and the curated rows are priced by ONE curve. The old flat-tier
                    // maths (hit^2 * 150, a step at 100 rounds, no caliber term) lived here.
                    case 1;
                    case 2: { _price = [_cn] call AP_fnc_gunPrice; };
                    // owner 2026-06-13: full Titan AA (launch_*_Titan_F) DROPPED from rebel; only the
                    // compact (launch_*_Titan_short_F) sells, @70k. RPG7 stays (deduped by curated 30k).
                    case 4: { if ((_cn find "Titan_short") > -1) then { _price = 70000; _isL = true; } else { if ((_cn find "RPG7") > -1) then { _price = 150000; _isL = true; }; }; };
                };
                if (_price > 0 && {_dn isNotEqualTo ""} && {!(_dn in _seenDN)} && {(getArray (_c >> "magazines")) isNotEqualTo []}) then {
                    _seenDN pushBack _dn;
                    AP_dynGuns pushBack [_cn, _price, _isL, _dn];};};};};
    private _haveDN = [];   // display names already in the curated list -> never double-list a gun name
    { _haveDN pushBackUnique (getText (configFile >> "CfgWeapons" >> (_x select 0) >> "displayName")); } forEach _list; {
        _x params ["_gCls", "_gPrice", "_gL", "_gDN"];
        if (_gL && {_shop in ["police_weapons", "maxtac_weapons"]}) then {} else {if !(_gDN in _haveDN) then {
                _list pushBack [_gCls, nil, _gPrice];
                _haveDN pushBack _gDN;};};} forEach AP_dynGuns;};
// LoonyBin (owner 2026-06-13): Mar-10 + SPMG pulled from the REBEL catalog until 3D printing ships
// (see 3dprint.md). Rebel-only -- MaxSec keeps Mar-10 (rank 5) via its own dynamic add. Classname prefix.
if (_shop isEqualTo "rebelwep") then {
    // owner 2026-06-13: Mar-10 + SPMG pulled from rebel until 3D printing ships.
    // owner 2026-06-24 (#530): the MX family (MX / MXC / MXM / MX-SW / MX-GL) is BOUNTY-HUNTER-EXCLUSIVE -- it's
    // curated into the skiptracer shop behind the Master-BH talent gate. But the rebel DYNAMIC full-gun catalog
    // (built above from every scope-2 CfgWeapons class) auto-included it, so rebels bought freely what BHs must earn.
    // Exclude the whole arifle_MX* family from the rebel catalog (prefix match on configName). Police/MaxTac keep MX
    // via their own curated/dynamic entries; the BH shop is unaffected (it doesn't use this dynamic catalog).
    private _plb3dPrint = ["srifle_DMR_02_", "MMG_02_", "arifle_MX"];
    _list = _list select { private _c = _x select 0; (_plb3dPrint findIf { (_c find _x) isEqualTo 0 }) isEqualTo -1 };};
// ECONOMY 2026-09-05: every firearm in the finished list takes its price from the curve, then the
// counter's faction multiplier. Runs AFTER the curated rows and the dynamic sweep have been merged,
// so it catches both, and BEFORE the owner override pass below, so a deliberate override still wins.
// A -1 back from AP_fnc_gunPrice means "the curve must not price this" (shotgun, launcher, flare
// gun) and leaves the curated number alone.
private _facMult = [_shop] call AP_fnc_gunFactionMult;
{
    private _derived = [_x select 0] call AP_fnc_gunPrice;
    if (_derived > 0) then { _x set [2, (round ((_derived * _facMult) / 100)) * 100]; };
} forEach _list;
// LooneyBin Economy: apply owner weapon-price overrides (weap p0 = price) to the final list
{private _ov = ["weap", _x select 0] call AP_fnc_priceOv;
    if (_ov isNotEqualTo [] && {(_ov select 2) >= 0}) then { _x set [2, _ov select 2]; };} forEach _list;
// LoonyBin (owner gear table 2026-06-12): MaxSec firearms are RANK-gated (cumulative), replacing the old
// talent gates. Filter the police armory to the rank-allowed gun set; non-guns (items/NVG/smokes) pass
// untouched, and the MaxTac shop (maxtac_weapons) is intentionally unaffected (full unlock).
if (_shop isEqualTo "police_weapons") then {private _maxsecGuns = [
        // ---- Cadet (1) ----
        ["hgun_p07_f",1],["hgun_p07_khk_f",1],["hgun_p07_blk_f",1],["smg_02_f",1],["smg_05_f",1],["smg_01_f",1],
        // ADR-97 family (SMG_03 / SMG_03C, all body styles + colours) -- server's "P90" is this same gun
        ["smg_03_black",1],["smg_03_camo",1],["smg_03_hex",1],["smg_03_khaki",1],["smg_03_tan",1],
        ["smg_03_tr_black",1],["smg_03_tr_camo",1],["smg_03_tr_hex",1],["smg_03_tr_khaki",1],["smg_03_tr_tan",1],
        ["smg_03c_black",1],["smg_03c_camo",1],["smg_03c_hex",1],["smg_03c_khaki",1],["smg_03c_tan",1],
        ["smg_03c_tr_black",1],["smg_03c_tr_camo",1],["smg_03c_tr_hex",1],["smg_03c_tr_khaki",1],["smg_03c_tr_tan",1],
        ["arifle_mk20c_f",1],["arifle_mk20c_plain_f",1],["arifle_mk20_f",1],["arifle_mk20_plain_f",1],
        ["arifle_spar_01_blk_f",1],["arifle_spar_01_khk_f",1],["arifle_spar_01_snd_f",1],["arifle_trg21_f",1],["arifle_trg20_f",1],
        // ---- Patrol Officer (2) ----
        ["arifle_mxc_f",2],["arifle_mxc_black_f",2],["arifle_mx_f",2],["arifle_mx_black_f",2],["arifle_mx_khk_f",2],
        ["arifle_sdar_f",2],["arifle_ctar_blk_f",2],["arifle_ctar_hex_f",2],["arifle_msbs65_f",2],["arifle_msbs65_black_f",2],
        // ---- Corporal (3) ----
        ["hgun_rook40_f",3],["arifle_katiba_f",3],["arifle_katiba_c_f",3],["arifle_msbs65_mark_f",3],["arifle_msbs65_mark_black_f",3],
        ["arifle_arx_blk_f",3],["arifle_arx_hex_f",3],["arifle_mxm_f",3],["arifle_mxm_black_f",3],["arifle_mxm_khk_f",3],
        ["srifle_dmr_07_blk_f",3],["srifle_dmr_07_hex_f",3],["srifle_dmr_07_ghex_f",3],
        // ---- Sergeant (4) ----
        ["hgun_acpc2_f",4],["srifle_ebr_f",4],["arifle_spar_02_blk_f",4],["arifle_mx_gl_f",4],["arifle_mx_gl_black_f",4],
        ["sgun_huntershotgun_01_f",4],["sgun_huntershotgun_01_sawedoff_f",4],["hgun_pistol_signal_f",4],
        ["arifle_msbs65_gl_f",4],["arifle_msbs65_gl_black_f",4],["lmg_03_f",4],["srifle_dmr_06_hunter_f",4],
        // ---- Lieutenant (5) ----
        ["hgun_pistol_heavy_01_f",5],["hgun_pistol_heavy_01_green_f",5],["hgun_pistol_heavy_02_f",5],["srifle_dmr_02_f",5],
        ["srifle_dmr_06_camo_f",5],["srifle_dmr_06_olive_f",5],["srifle_dmr_06_f",5],["arifle_spar_03_blk_f",5],["lmg_mk200_f",5],["lmg_mk200_black_f",5],
        ["arifle_mx_sw_f",5],["arifle_mx_sw_black_f",5],["arifle_msbs65_ubs_f",5],["arifle_ak12_f",5],["srifle_dmr_01_f",5],
        // ---- Captain / Chief of Police (6) ----
        ["lmg_zafir_f",6],["arifle_rpk12_arid_f",6],["arifle_rpk12_lush_f",6],["srifle_dmr_04_f",6],
        ["srifle_dmr_03_f",5],["srifle_dmr_03_khaki_f",5],["srifle_dmr_03_multicam_f",5],["srifle_dmr_03_tan_f",5],["srifle_dmr_03_woodland_f",5]
    ];
    _list = _list select {
        // NO exitWith in a select-filter block (it escapes the parent scope -> _list became a Bool ->
        // "forEach: Type Bool" -> empty shop; BUGS #151). Pure boolean expression instead.
        private _c = toLower (_x select 0);
        private _cw = configFile >> "CfgWeapons" >> (_x select 0);
        private _isGun = isClass _cw && {getNumber (_cw >> "type") in [1, 2, 4]} && {count getArray (_cw >> "magazines") > 0};
        (!_isGun) || {    // non-firearms (items/NVG/smokes/optics) always pass
            private _gi = _maxsecGuns findIf { (_x select 0) isEqualTo _c };
            (_gi > -1) && { _copLevel >= ((_maxsecGuns select _gi) select 1) }}};
    // LoonyBin (owner): MaxSec pays 25% of the CIVILIAN price for the same weapon. Tracks whatever the civ
    // price is set to (curated rebel/turf/gun entry, dynamic gun-catalog price, or owner price override).
    private _civPrices = []; {if ((_x select 0) isEqualType "" && {(_x select 3) isEqualType []} && {
            ("rebelwep" in (_x select 3)) || ("turf" in (_x select 3)) || ("gun" in (_x select 3)) || ("huntingwep" in (_x select 3))
        }) then { _civPrices pushBack [toLower (_x select 0), _x select 2]; };} forEach _weaponList;
    if (!isNil "AP_dynGuns") then {{ _civPrices pushBack [toLower (_x select 0), _x select 1]; } forEach AP_dynGuns;}; {
        private _c = toLower (_x select 0);
        private _cp = -1;
        private _ov = ["weap", _x select 0] call AP_fnc_priceOv;   // owner override = the civ price too
        if (_ov isNotEqualTo [] && {(_ov select 2) >= 0}) then {_cp = _ov select 2;} else {
            private _ci = _civPrices findIf { (_x select 0) isEqualTo _c };
            if (_ci > -1) then { _cp = (_civPrices select _ci) select 1; };};
        if (_cp > 0) then { _x set [2, (round (_cp * 0.25)) max 1]; };} forEach _list;};
[_shopName,_list]
