/*
    APS_fnc_eventParticipants  (LooneyBin rename layer)  ->  APS_fnc_addToEvent [2017]
    2020 client args : [true, player]
    2017 fn params   : _unit(@0), _add(@1)
    ADAPT (known behaviour drift — passthrough is a stub)
*/
// LooneyBin 2026-06-09: 2020 client sends [add(BOOL), unit]; the 2017 fn wants [unit, add] -- the
// passthrough fed a BOOL into the unit slot so the event queue NEVER populated (Battle Royale's
// last-alive winner check reads that queue). Swap the args.
params [["_add", true, [true]], ["_unit", objNull, [objNull]]];
// 2026-09-26 SECURITY (audit admin-0-0): the unit came from the payload, so one client could queue a second
// unit for Battle Royale, pull it back out after the join lock and be "last alive" for the $250k alone (or
// pull real fighters out). Every client caller passes `player`, so a client only ever (un)registers ITSELF.
private _src = remoteExecutedOwner;
if (isRemoteExecuted && {_src != 2}) then {
    _unit = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
};
[_unit, _add] call APS_fnc_addToEvent;
