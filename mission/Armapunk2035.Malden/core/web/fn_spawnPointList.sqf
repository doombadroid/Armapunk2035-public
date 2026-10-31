/*
    AP_fnc_spawnPointList -- ONE payload for the web spawn screen's "spawn" channel.

        private _rows = [_isRedeploy] call AP_fnc_spawnPointList;

    Shape, exactly what ui\html\spawn.html's header declares:

        [{ id, label, kind, x, y, near, reason }]      reason "" = the point is usable

    WHY THIS EXISTS AND WHAT IT IS NOT. The native menu needs a label and an id; a 3D map needs a
    POSITION for every row, and the only place that knew how to turn a spawn id into a position was
    fn_spawnConfirm -- inline, in the middle of the teleport, per side, per id shape. Copying that
    resolution into a page payload would be the drift every comment in that file warns about, so the
    rules are reproduced here ONCE, side by side with a note saying which branch of fn_spawnConfirm
    each one mirrors, and nothing else in the tree resolves a spawn position.

    IT RESOLVES WHAT fn_spawnConfirm RESOLVES, NOT WHAT IS KNOWABLE. Three id shapes reach
    fn_spawnConfirm's `default` branch and resolve to [0,0,0] because the marker they name does not
    exist on Malden -- turf_label_<obj>, "gov", "armory_marker" (the same dead-Altis-marker trap
    fn_spawnPointCfg's own header documents for the cop and medic lists). Today those rows are
    offered, clicked, and answered with "Error. Please wait a bit or try a different spawn point."
    This function could find a turf flag's position by hand and pin it correctly -- and that would be
    a LIE, because the teleport still cannot use it. So a row that fn_spawnConfirm cannot resolve
    gets reason "POSITION UNRESOLVED" and the screen greys it out. That is the honest rendering of
    today's behaviour, and it is the whole reason this reads like the teleport rather than like a map.

    THE PIN IS THE STABLE POINT, NOT THE ARRIVAL POINT. A town row arrives at one of five
    designer-placed scatter markers picked at random AT CONFIRM, and a house row at a random building
    position, so there is no single arrival point to draw. The pin is the town marker / the house, and
    the camera flies there; where inside it you wake up is the teleport's business.

    near IS THE NATIVE MENU'S COUNT, unchanged: players within 500 m, and not computed for a house row,
    because the native list skips it for "phouse_" too. It is a count, not a position, so it leaks
    nothing the native menu has not shown for years (see fn_mapOpen's ESP guard for the rule).
*/
params [["_isRedeploy", false, [false]]];

private _radius = 500;
private _cfg = [AP_effSide, _isRedeploy, true] call AP_fnc_spawnPointCfg;

// fn_spawnConfirm:"house" -- marker first, then the owned object itself when login raced the marker.
private _fnc_housePos = {
    params ["_marker"];
    private _p = getMarkerPos _marker;
    if (_p isEqualTo [0,0,0]) then {
        private _suffix = _marker select [7];                 // strip "phouse_"
        private _own = (AP_vehicles select {
            format ["%1", _x getVariable ["AP_houseID", ""]] isEqualTo _suffix
        }) param [0, objNull];
        if (!isNull _own) then { _p = getPosATL _own; };
    };
    _p
};

private _out = [];
{
    _x params [["_id", ""], ["_label", ""], ["_reason", ""]];
    private _pos = [0,0,0];

    // A position-typed id is the Mobile HQ row: fn_spawnPointCfg pushes getPos of the HQ truck as
    // element 0, and fn_spawnConfirm reads it straight back out. Test the TYPE, not the label, so a
    // renamed Mobile HQ cannot silently fall through to getMarkerPos on an array.
    if (_id isEqualType []) then {
        _pos = _id;
    } else {
        switch (true) do {
            case (_id isEqualTo "gangbldg"): {
                _pos = AP_gang_data param [3, [0,0,0]];       // fn_spawnConfirm:"gangbldg"
            };
            case (_id isEqualTo "gangboat_label"): {
                if (!isNil "SRV_gangBoatShops") then { _pos = SRV_gangBoatShops select 3; };
            };
            case ("phouse_" in _id): {
                _pos = [_id] call _fnc_housePos;
            };
            default {
                // fn_spawnConfirm's own `default`: a missionNamespace array of buildings wins over a
                // marker of the same name (that is what civ_spawn_1 is after fn_initCiv builds it),
                // otherwise the marker. Anything neither answers stays [0,0,0] and is labelled below.
                //
                // THE TWO-ARGUMENT FORM IS LOAD-BEARING, and the one-argument form cost a live build.
                // `missionNamespace getVariable _id` answers nil for a name that does not exist, and
                // `private _x = nil` does not DEFINE _x -- so the next line threw "Undefined variable
                // in expression: _arr", which aborted this forEach, which truncated the whole payload
                // at the first such row. civ_spawn_1 IS a missionNamespace array (fn_initCiv builds
                // it) so it passed; civ_spawn_2 is only a marker, so every spawn list on the server
                // was exactly one row long and nothing said why. fn_spawnConfirm's twin branch reads
                // the same value and guards it with isNil "_houses" -- a STRING test, which is
                // nil-safe; this reads it with a default instead, which is the same guarantee and the
                // idiom the rest of this tree uses.
                private _arr = missionNamespace getVariable [_id, []];
                if (_arr isEqualType [] && {count _arr > 0}) then {
                    _pos = getPosATL (_arr select 0);
                } else {
                    _pos = getMarkerPos _id;
                };
            };
        };
    };

    if (_reason isEqualTo "" && {(_pos select 0) isEqualTo 0 && {(_pos select 1) isEqualTo 0}}) then {
        _reason = "POSITION UNRESOLVED";
    };

    // Structural, not a status: the page colours a row by kind and greys it by reason, so a contested
    // house still reads as YOUR house. "duty" covers every faction point (cop, medic, Mobile HQ,
    // evidence lockup) because the two duty lists never appear in the same menu as each other.
    private _kind = switch (true) do {
        case (_id isEqualType []):                            { "duty" };
        case ("phouse_" in _id):                              { "home" };
        case (_id isEqualTo "gangbldg");
        case (_id isEqualTo "gangboat_label");
        case ("turf_label_" in _id):                          { "gang" };
        case ("cop_spawn" in _id);
        case ("med_spawn" in _id);
        case (_id isEqualTo "armory_marker");
        case (_id isEqualTo "gov"):                           { "duty" };
        default                                               { "city" };
    };

    private _near = -1;
    if (!("phouse_" in (str _id)) && {!(_pos isEqualTo [0,0,0])}) then {
        _near = count (allPlayers select {
            !(_x isKindOf "HeadlessClient_F") && {(_x distance2D _pos) < _radius}
        });
    };

    _out pushBack (createHashMapFromArray [
        // The page addresses a row by INDEX, not by id: a Mobile HQ id is an array and a house id can
        // repeat nothing but still be long, and the deploy verb re-derives the row from this same
        // builder anyway. Index is the only id shape that is always a string and always unique.
        ["id",     _forEachIndex],
        ["label",  _label],
        ["kind",   _kind],
        ["x",      _pos select 0],
        ["y",      _pos select 1],
        ["near",   _near],
        ["reason", _reason]
    ]);
} forEach _cfg;

_out
