/*
    File: fn_nearTown.sqf  (AP_fnc_nearTown)
    True when a position is within _radius metres of any of the island's five town centres.

        if ([500] call AP_fnc_nearTown) exitWith { ... };        // the player
        if ([200, _pos] call AP_fnc_nearTown) then { ... };      // any position

    ONE list of towns, because six copies of it had already rotted. "No chopping trees / no campfire
    / no tent / no execution / no care package in town" were each written as their own OR chain of
    getMarkerPos calls, carried over from Altis, and every chain named markers that do not exist on
    Malden ("city", "donor_town") next to markers that do. A missing marker answers [0,0,0], which is
    kilometres from anywhere a player stands, so each dead name silently removed one town from the
    rule: the chains covered Larche and nothing else until La Port, Chapoi and La Pessagne got their
    spawn markers on 2026-09-11, and La Trinite -- the capital -- was never in any of them.

    A town whose marker is missing is skipped rather than treated as [0,0,0], so a renamed marker
    loses that town from the rule instead of banning the whole map corner around the sea origin.
    AP_fnc_spawnScatterCheck calls this at boot, once per town, and logs how many it can actually
    see -- so a marker renamed in Eden shows up as "4 of 5" in the log instead of as a rule that
    quietly stopped applying somewhere. The list lives here and nowhere else; pass a position and
    the function never touches `player`, which is why the server-side boot check can use it.
*/
params [["_radius", 500, [0]], ["_pos", [], [[], objNull]]];
private _p = switch (true) do {
    case (_pos isEqualType objNull): { getPosATL _pos };
    case (_pos isEqualTo []): { getPosATL player };
    default { _pos };
};
private _towns = ["civ_spawn_1", "civ_spawn_2", "civ_spawn_3", "civ_spawn_4", "civ_spawn_5"];
(_towns findIf {
    private _m = getMarkerPos _x;
    !(_m isEqualTo [0,0,0]) && {(_p distance2D _m) < _radius}
}) > -1
