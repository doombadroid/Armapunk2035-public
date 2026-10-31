/*
    fn_calculateWarRating.sqf  (AP_fnc_calculateWarRating)

    ECONOMY 2026-09-05: the top band was $20,000, set when a rebel rifle cost $5,000. Under the
    derived gun curve a bare 6.5 mm rifle is $7,500 and a 7.62 kit is $29,800, so the band no longer
    separated a serious loadout from an ordinary one -- worse, AP_fnc_getLoadoutPrice counts
    ATTACHMENTS, and a $20,000 suppressor alone pushed any rifle over the line. War rating was
    measuring whether the killer brought a can. Top band raised to $35,000, which is a full 7.62 kit
    plus glass; the $5,000 floor still separates a sidearm-only loadout and did not need to move.

    These are absolute cash thresholds and they will drift again if the gun curve moves. If this
    needs touching a third time, make them ratios of the two loadout prices instead.
*/
params[["_deadLoadoutPrice", -1, [0]], ["_killerLoadoutPrice", -1, [0]]];
if ((_deadLoadoutPrice >= 35000) && (_killerLoadoutPrice >= 35000)) exitWith {10};
if ((_deadLoadoutPrice >= 35000) && (_killerLoadoutPrice <= 5000)) exitWith {15};
if ((_deadLoadoutPrice <= 35000) && (_deadLoadoutPrice >= 5000) && (_killerLoadoutPrice <= 35000) && (_killerLoadoutPrice >= 5000)) exitWith {
    7};
if ((_deadLoadoutPrice <= 5000) && (_killerLoadoutPrice >= 35000)) exitWith {5};
if ((_deadLoadoutPrice <= 5000) && (_killerLoadoutPrice <= 5000)) exitWith {5};
if (true) exitWith {5};