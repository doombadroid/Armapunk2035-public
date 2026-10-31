/*
    File: fn_factionHostile.sqf  (AP_fnc_factionHostile)

        [_unit] call AP_fnc_factionHostile   -> BOOL

    True when this unit and I are on opposite sides of THIS WEEK'S war, and I am
    standing on ground belonging to one of the two belligerents.

    WHAT IT MEANS, AND WHAT IT DOES NOT. This is the engagement-rules layer and
    nothing else: it turns a name tag red and it makes the kill legal by server
    rule. It does not touch damage, sides, or group relations -- there is no engine
    relations layer in this mission to conflict with (setFriend, getFriend and
    BIS_fnc_sideIsFriendly have zero call sites anywhere in the tree), and adding
    one for this would make a cosmetic rule into a mechanical one nobody asked for.
    The precedent is fn_enterActiveTurf, which warns that RDM rules do not apply
    and enforces nothing.

    THE HOT PATH IS THE WHOLE DESIGN. fn_playerTags calls this for every rendered
    unit, every frame. So almost all of the work is done ONCE per 3s tick by
    AP_fnc_factionBanner and left in three variables:

        AP_myFaction    my gang's faction, "" if none
        AP_myTerritory  the faction owning the ground I am on, "" if neutral
        AP_warHere      am I, an aligned player, standing in a belligerent's
                        territory during a week my own faction is fighting

    When AP_warHere is false -- which is true for most players, most of the time,
    everywhere on the map except two towns -- this exits on one boolean read and
    the tag ladder falls through to its existing rules.

    THE ONE THING IT CANNOT TRUST. The observed unit's faction is resolved through
    its public `gang_data`, which that player's own client writes. A modified client
    could therefore make its own tag render friendly to an enemy. That is a
    pre-existing property of every tag rule in this mission (AP_aggressive, the
    existing gang-war red and the group check are all read the same way) and it is
    accepted for the same reason: this decides what a name looks like, not who is
    allowed to do what. Nothing that pays, punishes or gates reads this function --
    the aligned-only contract board goes through APS_gangOfUid on the server
    precisely because that one had to be trustworthy.
*/
params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith { false };
if !(missionNamespace getVariable ["AP_warHere", false]) exitWith { false };

private _mine = missionNamespace getVariable ["AP_myFaction", ""];
if (_mine isEqualTo "") exitWith { false };

// The other belligerent. AP_warHere already established that mine is one of the
// two, so the enemy is simply whichever of the pair is not me.
private _w = missionNamespace getVariable ["AP_factionWar", []];
if (!(_w isEqualType []) || {count _w < 2}) exitWith { false };
private _foe = if ((_w select 0) isEqualTo _mine) then { _w select 1 } else { _w select 0 };
if (_foe isEqualTo "") exitWith { false };

private _gd = _unit getVariable ["gang_data", []];
if (!(_gd isEqualType []) || {_gd isEqualTo []}) exitWith { false };
private _gid = _gd param [0, -1];
if (_gid isEqualTo -1) exitWith { false };
// My own gang is never hostile to me, whatever the war says.
if (_gid isEqualTo (AP_gang_data param [0, -2])) exitWith { false };

private _map = missionNamespace getVariable ["AP_gangFactions", []];
if !(_map isEqualType []) exitWith { false };
private _i = _map findIf { (_x param [0, -1]) isEqualTo _gid };
if (_i isEqualTo -1) exitWith { false };   // unaligned gang -- never a target

(format ["%1", (_map select _i) param [1, ""]]) isEqualTo _foe
