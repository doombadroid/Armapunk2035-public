/*
    AP_fnc_deckMedic -- the TT RESPONSE BOARD (approved mock deck-medic).

    Rows come off AP_medicRequestedCorpses exactly as the native board read
    them; ACCEPT is the same [idx] spawn AP_fnc_acceptMedicalRequest. All the
    dispatch detail the native computed per selection -- bearing, distance,
    revivable, defib cooldown, current responder -- rides the payload so the
    board answers "who do I go to first" at a glance.

    ["data"] / ["accept", idx]
*/
params [["_verb", "", [""]], ["_a", -1, [0]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

switch (toLower _verb) do {

case "data": {
    private _rows = [];
    {
        _x params [["_caller", objNull, [objNull]], ["_corpse", objNull, [objNull]], ["_uid", "", [""]], ["_cname", "", [""]], ["_reqTime", 0, [0]]];
        if (!isNull _corpse) then {
            private _heading = player getDir _corpse;
            private _dir = switch (true) do {
                case (_heading >= 338 || _heading <= 23): {"N"};
                case (_heading <= 68): {"NE"}; case (_heading <= 113): {"E"};
                case (_heading <= 158): {"SE"}; case (_heading <= 203): {"S"};
                case (_heading <= 248): {"SW"}; case (_heading <= 293): {"W"};
                default {"NW"} };
            private _grp = switch (true) do {
                case (side _caller isEqualTo west): {"MaxSec"};
                case (side _caller isEqualTo independent): {"TT"};
                default {(group _caller) getVariable ["AP_grpTag", ""]} };
            private _resp = (_corpse getVariable ["AP_requestAcceptor", [objNull, ""]]) param [1, ""];
            private _defib = time < (_corpse getVariable ["AP_next_revive", -1000])
                && !(call AP_medicLevel >= 5 || (call AP_copLevel >= 6 && AP_copRole in ["all", "medic"] && 22 in AP_cop_talents));
            _rows pushBack (createHashMapFromArray [
                ["idx", _forEachIndex],
                ["name", [_cname] call AP_fnc_cleanName],
                ["grp", _grp],
                ["dist", round (_corpse distance2D player)],
                ["dir", _dir],
                ["revivable", _corpse getVariable ["AP_revivable", false]],
                ["defib", _defib],
                ["responder", if (_resp isEqualTo "") then {"NONE"} else {_resp}],
                ["reviving", !isNull (_corpse getVariable ["AP_reviving", objNull])],
                ["age", round ((time - _reqTime) / 60)]
            ]);
        };
    } forEach AP_medicRequestedCorpses;
    createHashMapFromArray [["rows", _rows]]
};

case "accept": {
    private _row = AP_medicRequestedCorpses param [_a, []];
    if (_row isEqualTo [] || {isNull (_row param [1, objNull])}) exitWith { ["That request is gone."] call _no };
    [_a] spawn AP_fnc_acceptMedicalRequest;
    ["Accepted -- waypoint set."] call _yes
};

default { ["unknown medic verb"] call _no };
};
