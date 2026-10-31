/*
    File: fn_hasFactionPerk.sqf  (AP_fnc_hasFactionPerk)

    The single gate gameplay code uses for a faction perk:

        if ([9101] call AP_fnc_hasFactionPerk) then { ... };

    Deliberately a function rather than the bare `id in AP_faction_talents` idiom
    the side talents use, because a faction perk has TWO conditions and only one of
    them is in that array:

        1. the player has bought the perk                (id in AP_faction_talents)
        2. its faction is STILL their primary            (evaluated live, here)

    Condition 2 is the whole design. A perk is not owned outright, it is owned
    while you stand with the faction that grants it -- so realigning costs you the
    perks of the faction you left, without anything having to hunt down and revoke
    them. Baking the check in at purchase time would silently keep them.

    THAT COST MUST BE STATED IN THE UI BEFORE A PLAYER REALIGNS. A perk that stops
    working with no explanation reads as a bug, and a player who loses one they
    paid for without being warned is right to be annoyed. The mechanism is correct;
    the communication is what makes it fair.

    Returns false rather than erroring for an unknown id: an unrecognised gate is
    a closed gate, matching how the quest system treats an unrecognised
    prerequisite.
*/
params [["_perkId", -1, [0]]];

if (_perkId < 0) exitWith { false };
if !((missionNamespace getVariable ["AP_faction_talents", []]) isEqualType []) exitWith { false };
if !(_perkId in (missionNamespace getVariable ["AP_faction_talents", []])) exitWith { false };

private _row = ["byId", _perkId] call AP_fnc_factionPerkCfg;
if (_row isEqualTo []) exitWith {
    // Bought a perk that no longer exists in the catalogue -- a content removal,
    // not a player fault. Closed, and said once so it can be found.
    diag_log format ["[AP][faction] hasFactionPerk: %1 is owned but not in the catalogue; treating as unowned.", _perkId];
    false
};

// Live primacy check. This is the condition that makes realignment cost something.
[_row select 1] call AP_fnc_isPrimaryFaction
