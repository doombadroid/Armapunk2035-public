/*
    AP_fnc_dutyCfg -- the duty-faction data table. Pure data, no side effects, safe to call anywhere.

        ["maxsec"] call AP_fnc_dutyCfg   -> that faction's row, or [] for an unknown id
        []         call AP_fnc_dutyCfg   -> the list of known faction ids

    Row layout (index: meaning)
        0 id                 wire id -- what the terminal, the roster and the DB all carry
        1 side               the engine side the duty group lives on; also what AP_effSide becomes
        2 groupVarName       SERVER-side variable holding the persistent shared group (APS_fnc_dutySRV "init")
        3 paycheck           per-side paycheck from core\configuration.sqf's side switch
        4 maxWeight          the old cop / medic lobby inits' AP_maxWeight (both 90)
        5 talentCapCode      CODE -- their AP_maxTalents. `call` it; reads the consts.
        6 spawnMarkers       dialog\function\fn_spawnPointCfg.sqf's marker list for this side
        7 roles              [[roleId, gateCode], ...] in OFFER order
        8 defaultLoadoutCode applied when the player has no saved duty gear for this faction

    Every number here is copied from the code that owns it today, not from the design sketch: trauma's
    paycheck is 10000 (configuration.sqf `case independent`), NOT the 8500 the spec guessed, because the
    old TT slot pays 10000 and standing up duty must not quietly change anyone's income.

    The role gateCodes are OFFER filters, not power gates. They only ever run inside AP_fnc_dutyTerminal --
    which is itself behind AP_dutyEnabled, the faction whitelist and a server re-check of every one of
    these same conditions from the server's own DB read. Nothing downstream may treat "AP_copLevel >= 3"
    as authority; the authority is the roster entry APS_fnc_dutySRV writes.

    med_spawn_1..4 are IN mission.sqm as of PR6 and slot 6 lists exactly those four -- it used to carry
    the six Altis names, and a marker that does not exist resolves to [0,0,0], i.e. the sea. Nothing
    here dereferences a marker even so; the list is data for later callers, and today it has none
    (dialog\function\fn_spawnPointCfg.sqf keeps its own copy, which this must be kept in step with).
*/
params [["_id", "", [""]]];

private _rows = [
    ["maxsec", west, "AP_dutyGroupCop", 10000, 90,
        {20 + (2 * (((call AP_copLevel) - 2) max 0))},
        ["cop_spawn_1", "cop_spawn_2", "cop_spawn_3", "cop_spawn_4", "cop_spawn_5"],
        [["patrol", {true}],
            ["warrant", {(call AP_copLevel) >= 3}],
            ["medic", {(call AP_copLevel) >= 3}],
            ["scd", {AP_isSCD}],
            ["all", {(call AP_copLevel) >= 6 || (call AP_adminLevel) >= 3}]],
        {[] call AP_fnc_copLoadout}],

    ["trauma", independent, "AP_dutyGroupMed", 10000, 90,
        {16},
        ["med_spawn_1", "med_spawn_2", "med_spawn_3", "med_spawn_4"],
        [["ttmedic", {true}]],
        {[] call AP_fnc_medicLoadout}]
];

if (_id isEqualTo "") exitWith { _rows apply {_x select 0} };
_rows param [_rows findIf {(_x select 0) isEqualTo _id}, []]
