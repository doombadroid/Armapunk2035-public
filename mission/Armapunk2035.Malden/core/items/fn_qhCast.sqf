// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhCast.sqf  (AP_fnc_qhCast)
    LooneyBin 2026-07-21: fire a quickhack. The client validates for instant feedback, then hands off --
    the SERVER owns the upload clock and re-validates on completion, so the channel can't be skipped.
*/
params [["_id", "", [""]]];
private _cfg = ([(if (AP_effSide isEqualTo west) then {"cop"} else {"civ"})] call AP_fnc_qhCfg) select { (_x select 0) isEqualTo _id };
if (_cfg isEqualTo []) exitWith {};
private _e = _cfg select 0;
_e params ["", "_name", "", "", "", "_upload", "_cd", "_range", "_los", "_auth", "_kind", "", ["_reqMod", -1]];
if (_reqMod > -1 && {!(_reqMod in (player getVariable ["AP_cdMods", []]))}) exitWith {
    [format ["%1 -- chip not installed.", toUpper _name], "basic"] spawn AP_fnc_handleMessage;};

private _cdKey = "AP_qhCd_" + _id;
if (diag_tickTime < (missionNamespace getVariable [_cdKey, 0])) exitWith {
    [format ["%1 -- recharging (%2s).", toUpper _name, ceil ((missionNamespace getVariable [_cdKey, 0]) - diag_tickTime)], "basic"] spawn AP_fnc_handleMessage;
};

private _t = missionNamespace getVariable ["AP_cdTarget", objNull];
// NB: collect the failure reason and exit at FILE scope. An exitWith inside the kind branch only left
// that branch -- the cast still fired and burned the cooldown after showing "no target".
private _why = "";
if (_kind isEqualTo "player") then {
    if (isNull _t || {!(_t isKindOf "CAManBase")} || {!(isPlayer _t)} || {_t isEqualTo player}) then { _why = "no target"; }
    else {if ((player distance _t) > _range) then { _why = "out of range"; }
        else {if (_los && {!([objNull, "VIEW"] checkVisibility [eyePos player, eyePos _t] > 0.3)}) then { _why = "no line of sight"; };};};
};
if (_kind isEqualTo "vehicle") then {
    if (isNull _t || {!((_t isKindOf "Car") || (_t isKindOf "Air") || (_t isKindOf "Ship") || (_t isKindOf "Tank"))}) then { _why = "no vehicle"; }
    else {if !(_t in AP_vehicles) then { _why = "not your ride"; }
        else {if ((player distance _t) > _range) then { _why = "out of range"; };};};};
// ANYVEH kind (Leech): aim at any car -- yours or not, empty or occupied, no autopilot needed. Just a car in range.
if (_kind isEqualTo "anyveh") then {private _tv = if (!isNull _t && {_t isKindOf "CAManBase"}) then { vehicle _t } else { _t };
    if (isNull _tv || {!((_tv isKindOf "Car") || (_tv isKindOf "Air") || (_tv isKindOf "Ship") || (_tv isKindOf "Tank"))}) then { _why = "no vehicle"; }
    else {if ((player distance _tv) > _range) then { _why = "out of range"; }
        else { _t = _tv; };};};
// DRIVABLE kind (Puppet Strings): aim at any car that isn't the seat you're in. Empty or occupied both work --
// you deck-dive and drive it yourself. Autopilot-present / not-analog re-checked server-side.
if (_kind isEqualTo "drivable") then {private _tv = if (!isNull _t && {_t isKindOf "CAManBase"}) then { vehicle _t } else { _t };
    if (isNull _tv || {!((_tv isKindOf "Car") || (_tv isKindOf "Ship") || (_tv isKindOf "Tank"))}) then { _why = "no vehicle"; }
    else {if (_tv isEqualTo (vehicle player)) then { _why = "you're sitting in it"; }
        else {if ((player distance _tv) > _range) then { _why = "out of range"; }
            else { _t = _tv; };};};};
// OCCUPIED kind (Chauffeur Override): aim at someone else's OCCUPIED car. Aiming at the driver resolves to
// their vehicle. Autopilot-present / not-analog is re-checked server-side; here we only need a live target.
if (_kind isEqualTo "occupied") then {private _tv = if (!isNull _t && {_t isKindOf "CAManBase"}) then { vehicle _t } else { _t };
    if (isNull _tv || {!((_tv isKindOf "Car") || (_tv isKindOf "Ship") || (_tv isKindOf "Tank"))}) then { _why = "no vehicle"; }
    else {if ((driver _tv) isEqualTo player) then { _why = "you can't hijack your own seat"; }
        else {if (isNull (driver _tv) || {!(isPlayer (driver _tv))}) then { _why = "nobody's driving it"; }
            else {if ((player distance _tv) > _range) then { _why = "out of range"; }
                else { _t = _tv; };   // hand the VEHICLE to the server as the target
            };};};};
if (_why isNotEqualTo "") exitWith {[format ["%1 -- %2.", toUpper _name, _why], "basic"] spawn AP_fnc_handleMessage;};

// AIM POINT: the two "place a thing over there" hacks (Crybaby's fake 911, Decoy Unit's fake patrol blip)
// need a world position, not an object. Only the caster's machine can know where they are looking, so it is
// computed here and range-clamped SERVER-SIDE on arrival -- a spoofed position can therefore only ever be a
// legal one. Every other hack passes an empty aim point and ignores it.
private _aim = [];
if (_id in ["crybaby", "decoy"]) then {_aim = screenToWorld [0.5, 0.5];
    if ((player distance2D _aim) > _range) exitWith { _why = "too far -- look closer to a spot you can reach"; };};
// Chauffeur Override: the victim's car is driven to the hacker's PLOTTED GPS DESTINATION. Require one -- the old
// "else drive to my position" fallback produced a ~0-length route when the hacker stood next to the victim, so
// the autopilot refused to engage and the whole hack silently did nothing (the #1 "Chauffeur doesn't work"
// cause in testing). Match the robotaxi: no destination set -> tell them, don't cast, don't burn the cooldown.
// owner 2026-07-24 BUGFIX: this guard used `exitWith` INSIDE the `then {}` block, so it exited only that
// block and not the function -- the cast proceeded, burned the 18-minute cooldown and remoteExec'd anyway,
// which is the exact failure the comment above says it prevents. Restructured to a flag checked at function
// scope. _aim must stay untouched on the abort path.
private _noDest = false;
if (_id isEqualTo "chauffeur") then {private _rp = missionNamespace getVariable ["AP_gpsRoutePts", []];
    if (_rp isEqualTo [] || {count _rp < 4}) then {
        ["<t color='#ff3b1e'>SET A DESTINATION</t> -- open your GPS and plot where you want their car driven, then cast.", "basic"] spawn AP_fnc_handleMessage;
        _noDest = true;} else {_aim = _rp select ((count _rp) - 1);};};
if (_noDest) exitWith {};
if (_why isNotEqualTo "") exitWith {[format ["%1 -- %2.", toUpper _name, _why], "basic"] spawn AP_fnc_handleMessage;};

missionNamespace setVariable [_cdKey, diag_tickTime + _cd];
[[_id, _t, player, _aim], "APS_fnc_qhSRV", 2] spawn AP_fnc_MP;
// Quest hook (owner 2026-08-12). fn_handleQuest had 99 call sites and not one
// of them was a quickhack -- the signature system of the mod was invisible to
// the quest system. Fired on HANDOFF, not on the server's result: the player
// cast it, and whether it landed is the server's business.
["action", "qhcast", 1] spawn AP_fnc_handleQuest;
["action", "qh_" + _id, 1] spawn AP_fnc_handleQuest;   // per-hack, for "cast Whiteout 10 times"
// ArmaQuest's "qhcast" is reported by the SERVER when the upload lands (APS_fnc_qhSRV -> APS_fnc_aqFact);
// it is in AQ_Settings serverFacts[], so a client report of it is refused.

// hacker-side upload bar (the server runs the authoritative clock of the same length)
[_name, _upload] spawn {params ["_name", "_upload"];
    disableSerialization;
    5 cutRsc ["AP_progress", "PLAIN"];
    private _d = uiNameSpace getVariable ["AP_progress", displayNull];
    private _bar = _d displayCtrl 38201;
    private _txt = _d displayCtrl 38202;
    private _t0 = diag_tickTime;
    while { diag_tickTime - _t0 < _upload && {!isNull _bar} } do {private _p = (diag_tickTime - _t0) / _upload;
        _bar progressSetPosition _p;
        _txt ctrlSetText format ["UPLOADING %1 (%2%3)", toUpper _name, round (_p * 100), "%"];
        uiSleep 0.05;};
    5 cutText ["", "PLAIN"];};
