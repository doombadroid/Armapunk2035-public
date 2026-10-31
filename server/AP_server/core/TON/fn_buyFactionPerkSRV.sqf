/*
    File: fn_buyFactionPerkSRV.sqf  (APS_fnc_buyFactionPerkSRV)

        [_player, 9001] remoteExec ["APS_fnc_buyFactionPerkSRV", 2];

    Spends a faction perk point. See FACTION_REP_SPEC.md section 5.

    SERVER-AUTHORITATIVE, and it re-derives every input. The client sends a perk
    id and nothing else -- standing, primary faction, points available, points
    already spent and the perk's prerequisites are all recomputed here from the
    database. A client that lies can ask for a perk it has not earned and be
    refused; it cannot grant itself one.

    That matters more here than for most purchases, because the whole faction
    system is new and its curve is untuned: the cheapest exploit in an unbalanced
    progression system is buying past it.

    WHY POINTS ARE NOT STORED. Available points are a pure function of standing
    (AP_fnc_calFactionTalents' thresholds), and spent points are a function of
    what is owned. Storing a third number would let the three disagree, and the
    disagreement would be invisible until someone audited it. Both sides are
    derived here instead, every time.
*/
params [["_player", objNull, [objNull]], ["_perkId", -1, [0]]];
if (!isServer) exitWith { false };
if (isNull _player || {_perkId < 0}) exitWith { false };

private _uid = getPlayerUID _player;
if !(_uid regexMatch "\d{17}") exitWith { false };

private _say = { [[_this, "basic"], "AP_fnc_handleMessage", _player, false] spawn AP_fnc_MP; false };

private _row = ["byId", _perkId] call AP_fnc_factionPerkCfg;
if (_row isEqualTo []) exitWith { "That perk does not exist." call _say };
_row params ["", "_faction", "_parent", "_cost", "_name", ""];

// ---- standing, and whether this faction is the player's primary ------------
// Recomputed server-side rather than trusting AP_primaryFaction, which lives on
// the client and is exactly what an attacker would set.
private _rp = [format ["SELECT faction_rep FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
if !(_rp isEqualType []) exitWith { false };
private _rep = [_rp param [0, ""]] call AP_fnc_aqRepDecode;

private _standing = [_rep, _faction] call AP_fnc_aqRepFind;
private _best = 0;
private _tied = false;
{
    private _v = _x param [1, 0];
    if (_v > _best) then { _best = _v; _tied = false; }
    else { if (_v isEqualTo _best && {!((_x param [0,""]) isEqualTo _faction)}) then { _tied = true; }; };
} forEach _rep;

if (_standing <= 0 || {_standing < _best} || {_tied}) exitWith {
    // A tie is not a primary. The player has not chosen, and choosing for them is
    // how a perk appears to flicker on and off as standing drifts.
    "You do not stand highest with that faction." call _say
};

// ---- points available, from the same thresholds the client shows -----------
private _avail = switch (true) do {
    case (_standing >= 6000): {12}; case (_standing >= 4800): {11};
    case (_standing >= 3800): {10}; case (_standing >= 3000): {9};
    case (_standing >= 2400): {8};  case (_standing >= 1900): {7};
    case (_standing >= 1450): {6};  case (_standing >= 1050): {5};
    case (_standing >= 750):  {4};  case (_standing >= 500):  {3};
    case (_standing >= 300):  {2};  case (_standing >= 150):  {1};
    default {0};
};

// ---- what is already owned, and what it cost -------------------------------
private _tp = [format ["SELECT faction_talents FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
if !(_tp isEqualType []) exitWith { false };
private _owned = [_tp param [0, ""]] call AP_fnc_aqRepDecode;   // same mres decode
if !(_owned isEqualType []) then { _owned = []; };

if (_perkId in _owned) exitWith { "You already have that perk." call _say };

private _spent = 0;
{
    private _r = ["byId", _x] call AP_fnc_factionPerkCfg;
    if !(_r isEqualTo []) then { _spent = _spent + (_r select 3); };
} forEach _owned;

if ((_spent + _cost) > _avail) exitWith {
    format ["Not enough perk points: %1 costs %2, you have %3 of %4 unspent.", _name, _cost, _avail - _spent, _avail] call _say
};

// ---- prerequisite ----------------------------------------------------------
if (_parent >= 0 && {!(_parent in _owned)}) exitWith {
    format ["%1 requires the perk before it.", _name] call _say
};

_owned pushBack _perkId;
[format ["UPDATE players SET faction_talents='%1' WHERE playerid='%2'", ([_owned] call DB_fnc_mresArray), _uid], 1] call DB_fnc_asyncQuery;
_player setVariable ["AP_faction_talents", _owned, true];

diag_log format ["[AP][faction] %1 bought perk %2 (%3), faction %4, standing %5", _uid, _perkId, _name, _faction, _standing];
[[format ["Perk unlocked: %1.", _name], "info"], "AP_fnc_handleMessage", _player, false] spawn AP_fnc_MP;
true
