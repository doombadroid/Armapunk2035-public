/*
    File: fn_factionBanner.sqf  (AP_fnc_factionBanner)

    Tells the player whose ground they are standing on, and maintains the three
    variables the hostility predicate reads. Spawned once per client from
    initPlayerLocal.sqf.

        AP_myFaction    my gang's faction, "" if none
        AP_myTerritory  the faction owning the ground I am on, "" if neutral
        AP_warHere      I am aligned, I am inside a belligerent's territory, and my
                        own faction is one of the two fighting this week

    WHY A LOOP AND NOT AN EVENT. There is no "entered a polygon" event, and the two
    other things that could drive it are worse: a trigger per territory cannot
    express a polygon, and testing inside the tag renderer would run three polygon
    tests per rendered unit per frame instead of three per player per 3s.

    3s MATCHES fn_eventPurgeClient, which is the closest existing thing -- a client
    loop that tells you the ground you are on has changed rules. Territories are
    hundreds of metres across, so the worst case is a few seconds of driving before
    the banner catches up, and paying frame time to shorten that buys nothing a
    player would notice.

    FIRES ON CHANGE ONLY. The banner is a full-width interruption; showing it every
    3s while a gang holds a street corner would make players learn to ignore the one
    piece of text that says they can be shot legally.
*/
if (!hasInterface) exitWith {};

AP_myFaction   = "";
AP_myTerritory = "";
AP_warHere     = false;

[] spawn {
    private _last = "@";   // never a faction id, so the first pass always resolves
    while { true } do {
        uiSleep 3;

        // My own allegiance, from the PUBLISHED mirror rather than anything local:
        // a member who was not online when their leader swore has no client-side
        // record of it, and would otherwise render as unaligned to themselves.
        private _mine = "";
        private _gid = AP_gang_data param [0, -1];
        if (_gid isNotEqualTo -1) then {
            private _map = missionNamespace getVariable ["AP_gangFactions", []];
            if (_map isEqualType []) then {
                private _i = _map findIf { (_x param [0, -1]) isEqualTo _gid };
                if !(_i isEqualTo -1) then { _mine = format ["%1", (_map select _i) param [1, ""]]; };
            };
        };
        AP_myFaction = _mine;

        private _here = [] call AP_fnc_factionTerritory;
        AP_myTerritory = _here;

        // Hostility needs BOTH belligerents involved: I am aligned to one of them,
        // and I am standing on ground belonging to one of them. Standing in the
        // neutral fixer's town during a war I am part of is not a war zone, and
        // being an uninvolved gang in a contested town does not make me a target.
        private _w = missionNamespace getVariable ["AP_factionWar", []];
        private _pair = if (_w isEqualType [] && {count _w >= 2}) then { [_w select 0, _w select 1] } else { ["", ""] };
        AP_warHere = (_mine isNotEqualTo "") && {_mine in _pair} && {_here isNotEqualTo ""} && {_here in _pair};

        // Announce on a CHANGE of (territory, war state). Keyed on both, so a war
        // starting or ending while the player stands still is announced too --
        // which is the moment a street they were safe on stops being safe, and the
        // one they would most resent finding out about by being shot.
        private _key = format ["%1|%2", _here, AP_warHere];
        if (_key isNotEqualTo _last) then {
            _last = _key;
            if (_here isEqualTo "") then {
                // Leaving territory is worth one quiet line, not a banner.
                ["<t size='0.8'>NEUTRAL GROUND</t>", 0, 0, 3, 0.5] spawn BIS_fnc_dynamicText;
            } else {
                private _row  = ["byId", _here] call AP_fnc_factionCfg;
                private _name = toUpper (_row param [1, _here]);
                private _town = _row param [6, ""];
                // BIS_fnc_typeText takes [stringLines, posX, posY, rootFormat]: the LINES are one
                // argument, so they need their own array around them (fn_intake.sqf has it right).
                // Passing the lines bare made the first line the argument list -- two engine errors
                // and no banner, the first time anyone stood on fixer ground (owner, 2026-09-04).
                if (AP_warHere) then {
                    [[[format ["%1 TERRITORY", _name], "<t align='center' size='2' font='PuristaBold' color='#ff3b30'>%1</t>", 4],
                      ["AT WAR - YOU CAN BE ENGAGED HERE", "<t align='center' size='1' color='#ff8c8c'>%1</t>", 4]]]
                     spawn BIS_fnc_typeText;
                } else {
                    [[[format ["%1 TERRITORY", _name], "<t align='center' size='1.6' font='PuristaBold'>%1</t>", 3],
                      [_town, "<t align='center' size='0.9' color='#9a9a9a'>%1</t>", 3]]]
                     spawn BIS_fnc_typeText;
                };
            };
        };
    };
};
