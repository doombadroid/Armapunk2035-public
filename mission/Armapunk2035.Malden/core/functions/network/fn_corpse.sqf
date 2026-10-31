params[["_corpse", objNull, [objNull]]];
if (isNull _corpse) exitWith {};
if (alive _corpse) exitWith {};
if (isPlayer _corpse) exitWith {};
_corpse hideObject true;
_corpse enableSimulation false;
if (local _corpse) then {hideBody _corpse;
    deleteVehicle _corpse;};