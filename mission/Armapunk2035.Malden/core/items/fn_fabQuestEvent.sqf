if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_key", "", [""]], ["_qty", 1, [0]]];
/*
    AP_fnc_fabQuestEvent -- tell the quest systems that a print was collected.

    aq_fnc_event is client-side, so the server pushes here once per collect. ONE emission per
    collect, from the server's collect arm rather than from the two grant branches (virtual item vs
    physical gear), because emitting from both would count a print twice for anything that happens
    to be craftable in either form.

    ArmaQuest's "craft" objective type (ArmaQuest/types/fn_typeCraft.sqf) has been implemented and
    unfed since before this feature existed -- it takes [item, qty, stationId] and nothing in the
    mission emitted it. The Fabricator is its first producer.

    Nothing here grants anything, so a client that drops this loses only its own quest progress.
*/
if (!hasInterface || {_key isEqualTo ""}) exitWith {};
_qty = (round _qty) max 1;

if (!isNil "aq_fnc_event") then {
    ["aq_crafted", [_key, _qty, "fabricator"]] call aq_fnc_event;
};
// the native quest system's own generic hook, alongside the Factory's existing "craft" tags
["craft", "fabricator", _qty] call AP_fnc_handleQuest;
