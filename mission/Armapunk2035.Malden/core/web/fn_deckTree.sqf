/*
    fn_deckTree.sqf — the payload behind every point-spend app on the deck.

    Six phone apps (Talents, Perks, Infamy, Prestige, TT Prestige, Honor) are
    ONE screen taking a category string. That collapse is real -- it is the whole
    point of the design brief's "pattern C" -- but the shape underneath is not
    the uniform pool-of-ranked-nodes the brief assumed:

      * Nodes are BINARY. Learned or not. There are no ranks anywhere in either
        catalogue, so there is nothing for rank pips to read.
      * Gating is PER NODE. Every row names its own prerequisite id in field 2.
        It is NOT "any node in the tier above has a rank" -- Porch Pirate
        Protection needs Delivery Expert specifically. A branch is therefore one
        root (prerequisite -1) plus its descendants, and a civ has 21 of them,
        which is why the left column switches BRANCH and not app.
      * There are TWO economies. Talents and Perks spend a POINT POOL against a
        cap; Honor / Infamy / Prestige / TT Prestige spend an XP CURRENCY at a
        per-node price carried in field 6 of the prestige rows.
      * Unlearn is four different rules, not one. See UNLEARN below.

    Usage:  private _payload = ["bh"] call AP_fnc_deckTree;
*/

params [["_cat", "standard", [""]]];

// ---------------------------------------------------------------- catalogue --
// Talent rows are [id, side, req, depth, name, desc]; prestige rows carry a
// seventh field, the XP price. Everything downstream reads the same six indices
// and treats the price as 0 when it is absent, so one builder covers both.
private _rows = switch (_cat) do {
    case "standard": { ["getTalents"] call AP_fnc_talentCfg };
    default { ["getSpecialitys", _cat] call AP_fnc_prestigeCfg };
};
if (_rows isEqualTo []) exitWith { createHashMap };

// ------------------------------------------------------------------ economy --
// UNLEARN, per category, straight out of fn_learnTalent / fn_learnPrestige:
//   standard  AP_respec_fee from the bank, blocked by a learned child
//   gang      free, blocked by a learned child
//   bh/rebel  $5,000 from the bank AND the node's XP is refunded
//   cop/medic impossible -- fn_learnPrestige has literally empty cases for both
//
// AP_respec_fee is read live rather than baked: it is currently compiled to 0
// (__SETCONST__ in configuration.sqf), so unlearning a talent is free today and
// the page must not promise a price the game will not charge.
//
// THERE IS NO RESPEC-ALL and this payload deliberately offers none. The design
// brief drew a "RESPEC TREE $250,000" button, but fn_respec was taken off the
// DMV by the owner on 2026-06-12 -- "the talent system was stripped, so a respec
// could corrupt player state" -- and is reachable from nothing. Wiring it to the
// deck would quietly undo that call.
private _meta = switch (_cat) do {
    case "standard": { ["TALENTS",     "STANDARD",   "points", "TALENT POINTS", true,  (call AP_respec_fee)] };
    case "gang":     { ["PERKS",       "GANG",       "points", "GANG POINTS",   true,  0] };
    case "bh":       { ["HONOR",       "SKIPTRACER", "xp",     "HONOR",         true,  5000] };
    case "rebel":    { ["INFAMY",      "REBEL",      "xp",     "INFAMY",        true,  5000] };
    case "cop":      { ["PRESTIGE",    "MaxSec",        "xp",     "PRESTIGE",      false, 0] };
    case "medic":    { ["TT PRESTIGE", "TT",         "xp",     "PRESTIGE",      false, 0] };
    default          { ["TREE",        "",           "points", "POINTS",        false, 0] };
};
_meta params ["_appName", "_crumb", "_economy", "_poolLabel", "_canUnlearn", "_unlearnCash"];

private _have = switch (_cat) do {
    case "standard": { +AP_side_talents };
    case "gang":     { +AP_gang_talents };
    case "bh":       { +AP_honor_talents };
    case "rebel":    { +AP_infamy_talents };
    case "cop":      { +AP_cop_talents };
    case "medic":    { +AP_medic_talents };
    default          { [] };
};

// Point trees spend against a cap; XP trees spend a balance and cap the COUNT of
// specialities instead (15 honor, 21 infamy -- cop and medic are uncapped).
private _spent = count _have;
private _pool  = switch (_cat) do {
    case "standard": { AP_currentTalents - _spent };
    case "gang":     { AP_currentGangTalents - _spent };
    case "bh":       { AP_honor_exp };
    case "rebel":    { AP_infamy_exp };
    case "cop":      { AP_prestige };
    case "medic":    { AP_medic_exp };
    default          { 0 };
};
private _cap = switch (_cat) do {
    case "standard": { AP_currentTalents };
    case "gang":     { AP_currentGangTalents };
    case "bh":       { 15 };
    case "rebel":    { 21 };
    default          { -1 };            // -1 = uncapped, the page hides the figure
};
private _full = (_cap > -1) && { _economy isEqualTo "xp" } && { _spent >= _cap };

// A rebel licence gates the whole infamy tree, and blocks exactly one talent.
private _rebelLic = missionNamespace getVariable ["license_civ_rebel", false];
// AP_medicLevel is CODE and only exists for the medic side, so it cannot be
// called unconditionally -- a civ opening TT Prestige would take an undefined
// variable error instead of seeing a locked tree.
private _medicLvl = if (isNil "AP_medicLevel") then { 0 } else { call AP_medicLevel };

// ------------------------------------------------------------------- nodes ---
private _childLearned = {
    params ["_id"];
    (_rows findIf { ((_x select 2) isEqualTo _id) && { (_x select 0) in _have } }) > -1
};

private _nameOf = {
    params ["_id"];
    private _i = _rows findIf { (_x select 0) isEqualTo _id };
    if (_i isEqualTo -1) then { "" } else { (_rows select _i) select 4 }
};

private _node = {
    params ["_row"];
    _row params ["_id", "", "_req", "_depth", "_title", "_desc"];
    private _cost  = if (_economy isEqualTo "xp") then { _row param [6, 0] } else { 1 };
    private _owned = _id in _have;
    private _why   = "";

    // Reason strings are built here rather than in the page because every one of
    // them mirrors a specific exitWith in the native learn function -- keeping
    // them next to that list is what stops the two drifting apart.
    private _state = "open";
    if (_owned) then { _state = "owned" } else {
        if (_req > 0 && { !(_req in _have) }) then {
            _state = "locked";
            _why   = format ["REQUIRES %1", toUpper ([_req] call _nameOf)];
        } else {
            if (_cat isEqualTo "rebel" && { AP_effSide isEqualTo civilian } && { !_rebelLic }) then {
                _state = "locked"; _why = "NEEDS A REBEL LICENCE";
            };
            // TT specialities are gated on medic rank, not on the tree at all
            if (_cat isEqualTo "medic" && { _medicLvl < 3 }) then {
                _state = "locked"; _why = "REQUIRES AEMT OR HIGHER";
            };
            // Master Bounty Hunter and Rebel Training are mutually exclusive
            if (_cat isEqualTo "standard" && { _id isEqualTo 8 } && { _rebelLic }) then {
                _state = "locked"; _why = "DROP REBEL TRAINING FIRST";
            };
            // honor 11 and 22 demand the whole tier below them
            if (_cat isEqualTo "bh" && { _id in [11, 22] }) then {
                private _need = if (_id isEqualTo 11) then { [10, 7, 4] } else { [21, 18, 15] };
                if (({ _x in _have } count _need) < count _need) then {
                    _state = "locked"; _why = "MASTER -- REQUIRES ALL PRIOR";
                };
            };
            if (_state isEqualTo "open") then {
                if (_full) then { _why = format ["TREE FULL -- MAX %1", _cap] }
                else {
                    if (_cost > _pool) then {
                        _why = if (_economy isEqualTo "xp") then {
                            format ["NEEDS %1 %2", _cost, _poolLabel]
                        } else { "NO POINTS" };
                    };
                };
            };
        };
    };

    createHashMapFromArray [
        ["id",      _id],
        ["name",    _title],
        ["effect",  _desc],
        ["depth",   _depth],
        ["req",     _req],
        ["cost",    _cost],
        ["state",   _state],
        // affordable is deliberately separate from state: "you have not unlocked
        // it" and "you cannot pay for it" want different button copy
        ["can",     (_state isEqualTo "open") && { _why isEqualTo "" }],
        ["blocked", _owned && { [_id] call _childLearned }],
        ["why",     _why]
    ]
};

// ---------------------------------------------------------------- branches ---
// Descendants are collected by walking the parent chain, not by depth, so each
// branch keeps its own shape. The hop guard is insurance against a catalogue row
// that ever points at its own ancestor -- cheap, and a cycle here would hang the
// client rather than fail visibly.
private _trees = [];
{
    private _rootRow = _x;
    _rootRow params ["_rootId", "", "", "", "_rootName"];
    private _members  = [_rootRow];
    private _frontier = [_rootId];
    private _hops     = 0;
    while { (count _frontier > 0) && { _hops < 12 } } do {
        private _next = [];
        {
            private _pid = _x;
            {
                if ((_x select 2) isEqualTo _pid) then { _members pushBack _x; _next pushBack (_x select 0); };
            } forEach _rows;
        } forEach _frontier;
        _frontier = _next;
        _hops = _hops + 1;
    };

    private _depths = _members apply { _x select 3 };
    _depths = _depths arrayIntersect _depths;          // unique
    _depths sort true;

    private _tiers = [];
    {
        private _d = _x;
        _tiers pushBack (createHashMapFromArray [
            ["n",     _d],
            ["nodes", (_members select { (_x select 3) isEqualTo _d }) apply { [_x] call _node }]
        ]);
    } forEach _depths;

    _trees pushBack (createHashMapFromArray [
        ["id",    _rootId],
        ["name",  _rootName],
        ["owned", count (_members select { (_x select 0) in _have })],
        ["total", count _members],
        ["tiers", _tiers]
    ]);
} forEach (_rows select { (_x select 2) isEqualTo -1 });

// Extra talent points are buyable past the free cap, on a ladder that starts at
// $1m and climbs $500k a time (fn_buyTalentPoint). The sale is blocked once the
// cap already covers the whole tree, so the page can grey the button instead of
// letting the player click into a refusal. Standard talents only -- the other
// five trees have no equivalent.
private _buyPrice = -1;
private _canBuy   = false;
if (_cat isEqualTo "standard") then {
    _buyPrice = 1000000 + (500000 * (missionNamespace getVariable ["AP_boughtTalents", 0]));
    _canBuy   = (count _rows > 0) && { AP_currentTalents < count _rows };
};

createHashMapFromArray [
    ["cat",         _cat],
    ["buyPrice",    _buyPrice],
    ["canBuy",      _canBuy],
    ["bank",        AP_atmcash],
    ["name",        _appName],
    ["crumb",       _crumb],
    ["economy",     _economy],
    ["pool",        _pool],
    ["poolLabel",   _poolLabel],
    ["spent",       _spent],
    ["cap",         _cap],
    ["full",        _full],
    ["canUnlearn",  _canUnlearn],
    ["unlearnCash", _unlearnCash],
    ["trees",       _trees]
]
