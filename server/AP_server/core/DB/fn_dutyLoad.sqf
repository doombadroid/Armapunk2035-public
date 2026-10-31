/*
    DB_fnc_dutyLoad -- read the saved duty character for one player + faction.

        [uid, factionId] call DB_fnc_dutyLoad   ->   [gear, talents, exp, prestigeTalents, prestige,
                                                     licenses]

    The return is an ARRAY, not a bare gear value, because later PRs add to it (rep) and every caller
    already unpacks positionally. Slot 0 is the gear packet as fn_saveGear.sqf:45 built it:
    [loadout, [virtualInventory, weight], uniform/backpack skins] -- or [] when the column has never been
    written, which is what makes AP_fnc_dutyClient fall through to the faction's default loadout.

    THE OTHER FIVE SLOTS ARE THE DUTY CHARACTER'S OWN STATE -- four of progression and one of licences --
    and they are here because a shift without them is a broken character rather than a fresh one. AP_fnc_dutyContext derives AP_track_radius straight
    off AP_cop_talents (the old cop init's switch verbatim), so an officer signing on with an empty prestige
    tree gets the 1400 m default no matter what they have unlocked; every standard-tree talent gate reads
    AP_side_talents, so those all read closed too. Both globals belong to whichever character is live, and
    until this the duty character inherited the CIVILIAN's -- i.e. the wrong tree entirely.
        slot 1  talents           cop_talents / med_talents  -> AP_side_talents  (STANDARD tree)
        slot 2  exp               cop_exp     / med_exp      -> AP_side_exp
        slot 3  prestigeTalents   pre_talents / medic_talents-> AP_cop_talents / AP_medic_talents
        slot 4  prestige          prestige    / medic_prestige-> AP_prestige   / AP_medic_exp
        slot 5  licenses          cop_licenses/ med_licenses  -> the license_<side>_* globals
    SLOT 5 IS THE SLOT THIS HEADER RESERVED, now filled. The licenses column is per-side and so are the
    globals it feeds -- fn_licenseCfg.sqf's third column is the side, and every name it defines is built
    as `license_<civ|cop|med>_<id>`, so a duty load writes license_cop_cg / license_cop_pilot (or
    license_med_boat / license_med_pilot) and CANNOT collide with the license_civ_* set login populated.
    That is why there is no restore on the way out: clocking off leaves the cop names set, and every
    reader of them is co-gated on AP_effSide (fn_copVehicles.sqf:59-79, fn_copShops.sqf:40), so they go
    inert the moment AP_fnc_dutyContext puts AP_effSide back to civilian. The save side is the mirror
    image -- fn_ClupdatePartial's case 2 filters AP_licenses by the same side flag before writing.
    The pre_talents-vs-cop_talents split is not cosmetic: fn_updatePartial case 16's comment records that
    they were once the same column and the periodic save clobbered the prestige unlocks every sync. Loading
    them into the same two globals fn_requestReceived seeds at login (fn_requestReceived.sqf:43-45) keeps the
    duty character on the same side of that split as the civilian it was loaded over.

    THE ARRAY COLUMNS ARE SELECTED UNQUOTED. fn_queryRequest.sqf:89 does the same and says why: they are
    str2-encoded and already carry their own outer double quotes, which are what asyncQuery's compile uses
    as the string delimiters. QUOTE()-ing one double-wraps it and the decode fails -- the repo's standing
    "never QUOTE() an mres column on read" rule. The decoder below is fn_queryRequest.sqf:29-43's `_dec`,
    copied rather than referenced, including its parseSimpleArray step: a poisoned free-text column must
    never be handed to compile (the Lystic compile-RCE class). The two numeric columns go through the same
    file's `_num`.
*/
params [["_uid", "", [""]], ["_faction", "", [""]]];
private _empty = [[], [], 0, [], 0, []];
if (_uid isEqualTo "") exitWith { _empty };
if ((toArray _uid) findIf {_x < 48 || _x > 57} isNotEqualTo -1) exitWith { _empty };

// [gearCol, talentsCol, expCol, prestigeTalentsCol, prestigeCol, licensesCol]
private _cols = switch (_faction) do {
    case "maxsec": { ["cop_gear", "cop_talents", "cop_exp", "pre_talents", "prestige", "cop_licenses"] };
    case "trauma": { ["med_gear", "med_talents", "med_exp", "medic_talents", "medic_prestige", "med_licenses"] };
    default { [] };
};
if (_cols isEqualTo []) exitWith { _empty };

private _dec = {   // fn_queryRequest.sqf:29-43 verbatim -- NULL-safe, and parses rather than compiles
    params [["_v", ""]];
    if (isNil "_v") exitWith {[]};
    if (_v isEqualType []) exitWith {_v};
    if (_v isEqualTo "" || {_v isEqualTo "NULL"}) exitWith {[]};
    private _a = [_v] call DB_fnc_mresToArray;
    if (typeName _a isEqualTo "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };
    if (isNil "_a") then { _a = []; };
    _a};
private _num = { parseNumber (format ["%1", _this]) };

// %8 (the licenses column) is UNQUOTED for the same reason as the three array columns above -- see the
// header. fn_queryRequest.sqf:89 selects the civilian one exactly this way.
private _r = [format ["SELECT %3,%4,%5,%6,%7,%8 FROM %2 WHERE playerid='%1'",
    _uid, "players", _cols select 0, _cols select 1, _cols select 2, _cols select 3, _cols select 4,
    _cols select 5], 2] call DB_fnc_asyncQuery;
if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { _empty };

private _gear = [_r param [0, ""]] call _dec;
private _tal  = [_r param [1, ""]] call _dec;
private _pTal = [_r param [3, ""]] call _dec;
private _lic  = [_r param [5, ""]] call _dec;
if !(_gear isEqualType []) then { _gear = []; };
if !(_tal isEqualType [])  then { _tal  = []; };
if !(_pTal isEqualType []) then { _pTal = []; };
if !(_lic isEqualType [])  then { _lic  = []; };

[_gear, _tal, (_r param [2, 0]) call _num, _pTal, (_r param [4, 0]) call _num, _lic]
