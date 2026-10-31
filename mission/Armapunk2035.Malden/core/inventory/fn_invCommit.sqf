/*
    fn_invCommit.sqf -- what the native inventory did for free, done explicitly.
    INVENTORY_SPEC.md Appendix A hazard 1 / §9.4.

        [_took, _put] call AP_fnc_invCommit
        _took : [[container, cls] ...] items that ENTERED the player's gear
        _put  : [[container, cls] ...] items that LEFT it (container = where they went)

    The native display 602 fired the "Take" / "Put" event handlers on every drag, and the mission
    hung its logging (-TOOKITEM- / -STOREDITEM-), the shared-container dupe check, the role-item
    force-drops (governor uniform, medic vest, low-rank MaxSec SMGs, civ UAV terminals), the ground
    holder clean time and the gear save on them. Scripted moves fire none of that, so every verb the
    I-screen performs ends here, with the same handlers called with the same [unit, container,
    item] the engine would have passed. Both are spawned: fn_onTakeItem uiSleeps inside its dupe
    branch, and fn_onPutItem is spawned by the EH wiring itself.

    Then one more save after the handlers' own (they debounce theirs), and the screen re-pushes.
*/
params [["_took", [], [[]]], ["_put", [], [[]]]];
{
    _x params [["_c", objNull, [objNull]], ["_cls", "", [""]]];
    if (_cls != "" && {_cls != "spill"}) then { [player, _c, _cls] spawn AP_fnc_onTakeItem; };
} forEach _took;
{
    _x params [["_c", objNull, [objNull]], ["_cls", "", [""]]];
    if (_cls != "" && {_cls != "spill"}) then { [player, _c, _cls] spawn AP_fnc_onPutItem; };
} forEach _put;
[] spawn {
    uiSleep 0.2;
    [false] call AP_fnc_saveGear;
    [3] call AP_fnc_ClupdatePartial;
    [] call AP_fnc_calWeight;
    if (!isNil "AP_fnc_invPush") then { [] call AP_fnc_invPush; };
};
true
