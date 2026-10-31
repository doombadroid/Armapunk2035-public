/*
    AP_fnc_deckBoot -- FIRST BOOT / daily bonus (approved mock deck-firstboot,
    reduced to what exists).

    The mock folded welcome + tutorial + login bonus into one flow. Two of the
    three are already covered: the HTML landing page IS the welcome, and the
    tutorial keeps its own native flow (a redesign of its content is design
    work, not a port). What this app carries is the piece with real state --
    the DAILY BONUS: streak, the three-tier preview the crate ceremony showed,
    and CLAIM through the same AP_fnc_loginBonusGive grant with every native
    guard (civ only, on foot, not jailed, tier row must exist).

    ["data"] / ["claim"]
*/
params [["_verb", "", [""]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

private _tierName = {
    params ["_tier"];
    if (_tier isEqualTo []) exitWith { "" };
    private _isPhys = !(_tier param [2, false]);
    private _class = (_tier param [1, []]) param [0, ""];
    if (_isPhys) then { ([_class] call AP_fnc_fetchCfgDetails) param [1, _class] }
    else { ["getName", _class] call AP_fnc_virtItemCfg }
};

switch (toLower _verb) do {

case "data": {
    AP_loginBonusData params [["_uid", "", [""]], ["_days", -1, [0]], ["_needsGift", false, [false]]];
    private _tierTable = ["getCfg"] call AP_fnc_loginBonusCfg;
    private _idx = _tierTable findIf { (_x param [0, 0]) isEqualTo _days };
    private _prev = ""; private _cur = ""; private _next = "";
    if (_idx isNotEqualTo -1) then {
        (["get3Tiers", _idx] call AP_fnc_loginBonusCfg) params ["_p", "_c", "_n"];
        switch (_idx) do {
            case 0:  { _n = _c; _c = _p; _p = []; };
            case 50: { _n = []; };
        };
        _prev = [_p] call _tierName; _cur = [_c] call _tierName; _next = [_n] call _tierName;
    };
    createHashMapFromArray [
        ["streak", _days max 0],
        ["claimable", _needsGift && {_days < 101} && {_idx isNotEqualTo -1}],
        ["prev", _prev], ["cur", _cur], ["next", _next],
        ["civ", AP_effSide isEqualTo civilian],
        ["tutorialOpen", missionNamespace getVariable ["AP_activeTutorial", -1] isNotEqualTo -1]
    ]
};

case "claim": {
    AP_loginBonusData params [["_uid", "", [""]], ["_days", -1, [0]], ["_needsGift", false, [false]]];
    if (_days >= 101) exitWith { ["Streak complete -- nothing left on the ladder."] call _no };
    if (!_needsGift) exitWith {
        [format ["Nothing to claim -- %1 day streak and today's crate is already open.", _days max 0]] call _no };
    if (AP_effSide isNotEqualTo civilian) exitWith { ["Civilian side only."] call _no };
    if !(isNull objectParent player) exitWith { ["Step out of the vehicle first."] call _no };
    if ((AP_is_arrested param [0, 0]) isEqualTo 1) exitWith { ["Not from prison."] call _no };
    private _tierTable = ["getCfg"] call AP_fnc_loginBonusCfg;
    private _idx = _tierTable findIf { (_x param [0, 0]) isEqualTo _days };
    if (_idx isEqualTo -1) exitWith { ["No reward row for this streak day -- report this."] call _no };
    [_idx] spawn AP_fnc_loginBonusGive;
    ["Claimed -- check your inventory."] call _yes
};

default { ["unknown boot verb"] call _no };
};
