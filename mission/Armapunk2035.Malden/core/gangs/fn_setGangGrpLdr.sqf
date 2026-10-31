params["_unit", "_group"];
if (isNil "_unit" || isNil "_group") exitWith {};
if (player isEqualTo _unit && (group player) isEqualTo _group) then {player setRank "COLONEL";
    _group selectLeader _unit;};