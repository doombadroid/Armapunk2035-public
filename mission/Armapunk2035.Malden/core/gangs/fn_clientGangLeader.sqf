params[["_unit", objNull, [objNull]], ["_group", grpNull, [grpNull]]];
if (isNull _unit || isNull _group) exitWith {};
if (player isEqualTo _unit && (group player) isEqualTo _group) then {player setRank "COLONEL";
    _group selectLeader _unit;};