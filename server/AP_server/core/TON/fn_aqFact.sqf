/*
    File: fn_aqFact.sqf  (APS_fnc_aqFact)

    Report one ArmaQuest action verb that the SERVER witnessed:

        [_unit, "qhcast"] call APS_fnc_aqFact;

    Verbs listed in aq_content.hpp AQ_Settings >> serverFacts[] are refused when a
    client reports them (aq_fnc_srvFact, local patch in ArmaQuest/VENDORED.txt) and
    count only when they arrive through here. srvFact tells the two apart by the
    local _aqServerFact on its call stack, which no client can put there. That is
    also why this is NOT in CfgRE: a client that could call it would be a client
    reporting its own verbs again.
*/
params [["_unit", objNull, [objNull]], ["_verb", "", [""]]];
if (!isServer || {isNull _unit} || {_verb isEqualTo ""} || {isNil "aq_fnc_srvFact"}) exitWith { false };
// A completing fact pays out, and the payout's DB read refuses an unscheduled context.
if (!canSuspend) exitWith { _this spawn APS_fnc_aqFact; true };
private _aqServerFact = true;
[_unit, _verb, [1]] call aq_fnc_srvFact
