/*
    AP_fnc_warmCatalogue -- hand the connect-time cache worker the weapon shop's thumbnails.

        [_ctrl] call AP_fnc_warmCatalogue;      // from fn_warmBridge's "warmReady" handler

    Returns the number of picture paths pushed. Pushes them to ui\html\warm.html on the
    "warmGuns" channel, in chunks, as [[path, ...], isLastChunk].

    WHY IT EXISTS. Task 6 taught warm.html to warm 592 things: the three map text assets,
    the satellite tiles and every icons\*.paa in the mission. Not one weapon thumbnail was
    among them. The ARMORY (ui\html\armory.html, AP_fnc_armoryOpen) draws its grid from
    GAME CONTENT pictures -- A3\Weapons_F\...\gear_*_CA.paa, resolved per row out of
    CfgWeapons at open time -- so every one of them was still converting on first sight,
    which is the "second or two" the owner reported on the rebel weapon shop.

    128 ONLY, NOT 512. armory.html asks for 128 for the grid thumbs and 512 for the hero
    preview. The 283-odd grid thumbs all appear at once and are the reported stall; the
    preview is ONE image, on demand, on a row the player clicked. Warming the 512s would
    roughly quadruple the texture memory this costs for something a player may never open.

    THE LEADING BACKSLASH IS THE TRAP. A config picture path leads with a "\" and
    RequestTexture wants it WITHOUT one -- fn_armoryOpen.sqf:61-65 records the rule and the
    consequence: with it, every texture 404s SILENTLY and the thumbs render broken. A warm
    queue full of leading-backslash paths would look exactly like the bug it was written to
    fix, so the strip happens here and again in the page (belt and braces, both cheap).

    WHERE THE CLASSNAMES COME FROM, AND WHY IT IS TWO HALVES.

      1. THE CURATED CATALOGUE, generated below out of fn_weaponShopCfg.sqf's own
         _weaponList by tools/gen_warm_catalogue.py, with tools/run_checks.sh failing the
         moment the two drift. That array cannot be read at runtime: it is a `private`
         local, it is built after the gating prologue, and calling AP_fnc_weaponShopCfg
         once per shop id to get at it pops "You don't have a Rebel Training!" toasts at
         connect and returns only the shops this player happens to qualify for right now.
         The generator + the gate buy the same guarantee the runtime read would have.

      2. THE DYNAMIC HALF. The rebel and MaxSec counters merge a runtime CfgWeapons sweep
         (AP_dynGuns, fn_weaponShopCfg.sqf) that NO static list can contain -- and the
         rebel shop is precisely the one the owner reported. So the sweep's predicate is
         re-walked here in its widest form: scope 2, a weapon type, at least one magazine.
         It is deliberately a SUPERSET of the shop's (no price curve, no owner exclusions,
         no display-name dedupe), because over-warming costs a texture nobody looks at
         while under-warming costs the stall. It cannot silently miss a gun the shop adds.

    DEDUPED BY PATH, NOT BY CLASSNAME. Weapon variants share renders constantly, and the
    page has no dedupe of its own, so this is where a path is spent once.

    NO SERVER, NO CfgRE. Every value here is read out of configFile on this client and
    warmed into this client's own texture cache.
*/
params [["_ctrl", controlNull, [controlNull]]];
if (isNull _ctrl) then { _ctrl = uiNamespace getVariable ["AP_warmCtrl", controlNull] };
if (isNull _ctrl) exitWith { diag_log "[WARM] catalogue: no control to push to"; 0 };

private _t0 = diag_tickTime;

// --- BEGIN GENERATED (tools/gen_warm_catalogue.py -- do not hand-edit) ---
// 143 distinct classnames, lifted from the 234 rows of fn_weaponShopCfg.sqf's _weaponList.
private _curated = [
    "ToolKit", "FirstAidKit", "ItemGPS", "ItemMap", "ItemCompass", "ItemWatch", "Binocular",
    "Rangefinder", "B_UavTerminal", "I_UavTerminal", "NVGoggles_OPFOR", "Integrated_NVG_F", "NVGoggles",
    "NVGoggles_INDEP", "O_NVGoggles_grn_F", "O_NVGoggles_urb_F", "O_NVGoggles_ghex_F",
    "O_NVGoggles_hex_F", "NVGoggles_tna_F", "Chemlight_green", "Chemlight_red", "Chemlight_yellow",
    "Chemlight_blue", "SmokeShell", "SmokeShellRed", "SmokeShellGreen", "SmokeShellYellow",
    "SmokeShellPurple", "SmokeShellBlue", "SmokeShellOrange", "1Rnd_Smoke_Grenade_shell",
    "1Rnd_SmokeRed_Grenade_shell", "1Rnd_SmokeGreen_Grenade_shell", "1Rnd_SmokeYellow_Grenade_shell",
    "1Rnd_SmokePurple_Grenade_shell", "1Rnd_SmokeBlue_Grenade_shell", "1Rnd_SmokeOrange_Grenade_shell",
    "3Rnd_Smoke_Grenade_shell", "3Rnd_SmokeRed_Grenade_shell", "3Rnd_SmokeGreen_Grenade_shell",
    "3Rnd_SmokeYellow_Grenade_shell", "3Rnd_SmokePurple_Grenade_shell", "3Rnd_SmokeBlue_Grenade_shell",
    "3Rnd_SmokeOrange_Grenade_shell", "MiniGrenade", "HandGrenade", "hgun_Pistol_Signal_F",
    "hgun_Pistol_01_F", "hgun_Rook40_F", "hgun_ACPC2_F", "hgun_Pistol_heavy_02_F", "hgun_P07_F",
    "hgun_P07_khk_F", "hgun_P07_blk_F", "muzzle_snds_L", "SMG_05_F", "hgun_PDW2000_F", "SMG_02_F",
    "SMG_01_F", "arifle_MX_Black_F", "arifle_MXC_Black_F", "arifle_MSBS65_black_F",
    "arifle_MSBS65_Mark_black_F", "arifle_Katiba_F", "arifle_Katiba_C_F", "arifle_sdar_F", "SMG_03_F",
    "arifle_CTAR_blk_F", "srifle_DMR_07_blk_F", "srifle_DMR_06_F", "arifle_SPAR_03_blk_F",
    "arifle_SPAR_02_blk_F", "arifle_MXM_Black_F", "arifle_MX_GL_Black_F", "arifle_MSBS65_GL_black_F",
    "sgun_HunterShotgun_01_F", "hgun_Pistol_heavy_01_F", "srifle_DMR_06_hunter_F", "arifle_ARX_blk_F",
    "srifle_DMR_01_F", "srifle_DMR_03_F", "srifle_EBR_F", "arifle_MX_SW_Black_F", "arifle_AK12_F",
    "LMG_Mk200_F", "LMG_03_F", "LMG_Zafir_F", "arifle_AK12_lush_F", "arifle_RPK12_lush_F",
    "srifle_DMR_04_F", "sgun_HunterShotgun_01_sawedoff_F", "SMG_03C_TR_khaki", "SMG_03C_TR_camo",
    "SMG_03C_TR_hex", "SMG_03C_TR_black", "SMG_03_TR_khaki", "SMG_03_TR_camo", "SMG_03_TR_hex",
    "SMG_03_TR_black", "arifle_Mk20_F", "arifle_SPAR_01_blk_F", "arifle_MSBS65_UBS_F",
    "hgun_Pistol_heavy_01_green_F", "arifle_Mk20_plain_F", "arifle_Mk20C_plain_F", "arifle_TRG20_F",
    "arifle_TRG21_F", "arifle_AKS_F", "arifle_SPAR_01_khk_F", "arifle_SPAR_01_snd_F", "arifle_MXC_F",
    "arifle_MX_F", "arifle_MX_khk_F", "arifle_MSBS65_F", "arifle_ARX_hex_F", "arifle_MXM_khk_F",
    "arifle_MXM_F", "arifle_MSBS65_Mark_F", "srifle_DMR_03_khaki_F", "srifle_DMR_03_multicam_F",
    "srifle_DMR_03_tan_F", "srifle_DMR_03_woodland_F", "arifle_SPAR_03_khk_F", "arifle_SPAR_03_snd_F",
    "srifle_DMR_06_olive_F", "srifle_DMR_06_camo_F", "arifle_AK12U_lush_f", "arifle_AKM_F",
    "arifle_MX_SW_F", "arifle_AK12_arid_F", "arifle_CTAR_hex_F", "arifle_CTAR_ghex_F",
    "arifle_CTAR_GL_blk_F", "arifle_CTAR_GL_hex_F", "arifle_CTAR_GL_ghex_F", "arifle_Katiba_GL_F",
    "LMG_Mk200_black_F", "arifle_RPK12_arid_F", "launch_RPG7_F", "launch_B_Titan_F", "srifle_GM6_F",
    "srifle_DMR_02_F", "MMG_02_camo_F"
];
// --- END GENERATED ---

private _seen = createHashMap;
private _out = [];

// The one place a path is normalised, deduped and admitted. See the header on the
// leading backslash: this is the strip fn_armoryOpen.sqf performs on the same values.
private _add = {
    params ["_p"];
    if (!(_p isEqualType "")) exitWith {};
    if ((_p select [0, 1]) isEqualTo "\") then { _p = _p select [1] };
    if (_p isEqualTo "") exitWith {};
    private _k = toLower _p;
    if (_seen getOrDefault [_k, false]) exitWith {};
    _seen set [_k, true];
    _out pushBack _p;
};

// The catalogue holds weapons, magazines (chemlights, smokes, launcher rounds) and the
// odd item, so the lookup order is AP_fnc_fetchCfgDetails's own -- the function the shop
// itself resolves these rows through. A different order would pick a different config
// class for any id that exists in two of them, and warm a picture the shop never shows.
private _pic = {
    params ["_cls"];
    private _c = configFile >> "CfgMagazines" >> _cls;
    if (!isClass _c) then { _c = configFile >> "CfgWeapons" >> _cls };
    if (!isClass _c) then { _c = configFile >> "CfgVehicles" >> _cls };
    if (!isClass _c) then { _c = configFile >> "CfgGlasses" >> _cls };
    if (isClass _c) then { getText (_c >> "picture") } else { "" }
};

{ [[_x] call _pic] call _add } forEach _curated;
private _nCurated = count _out;

// The dynamic half -- see header point 2. One pass over CfgWeapons, the same walk the
// shop makes on its first open; doing it here also means the shop's own sweep is not the
// first thing to touch these classes.
private _cfgW = configFile >> "CfgWeapons";
for "_i" from 0 to ((count _cfgW) - 1) do {
    private _c = _cfgW select _i;
    if (!isClass _c) then { continue };
    if (!((getNumber (_c >> "scope")) isEqualTo 2)) then { continue };
    if (!((getNumber (_c >> "type")) in [1, 2, 4])) then { continue };
    if ((getArray (_c >> "magazines")) isEqualTo []) then { continue };
    [getText (_c >> "picture")] call _add;
};

// A CEILING, because the sweep's size is a property of whatever content is loaded and not
// of this repository -- a mod that ships a thousand rifles must not turn the connect-time
// warmer into a minute of texture conversion. The curated half is added first, so a trim
// only ever takes from the speculative end. It is logged, loudly, because a cap that bites
// in silence is indistinguishable from a queue that was always this short.
private _cap = 900;
if ((count _out) > _cap) then {
    diag_log format ["[WARM] catalogue: %1 pictures exceeds the %2 cap -- warming the first %2 (curated first)",
        count _out, _cap];
    _out resize _cap;
};

// CHUNKED, and the handshake is why it is safe to chunk. webui_fnc_push replays only the
// LAST value on a channel to a late subscriber, so chunks sent before the page subscribed
// would be lost with no error. This function only ever runs in answer to the page's own
// "warmReady" call, i.e. after WEBUI.on("warmGuns") is installed, so every chunk lands.
// 100 paths is ~6 KB of JSON per ExecJS statement rather than one 50 KB statement.
private _n = count _out;
private _i = 0;
if (_n isEqualTo 0) then {
    [_ctrl, "warmGuns", [[], true]] call webui_fnc_push;
} else {
    while { _i < _n } do {
        private _slice = _out select [_i, 100];
        _i = _i + 100;
        [_ctrl, "warmGuns", [_slice, _i >= _n]] call webui_fnc_push;
    };
};

diag_log format ["[WARM] catalogue: %1 weapon pictures at 128 (%2 curated, %3 swept), %4 classnames, %5 ms",
    _n, _nCurated, _n - _nCurated, count _curated, ((diag_tickTime - _t0) * 1000) toFixed 0];
_n
