/*
    APS_fnc_easterSeasonalEvent  (LooneyBin -- implemented from stub 2026-06-09)
    Easter-egg hunt (season-gated via SRV_enabledSeasonalEvents). Client
    (core/seasonalEvents/fn_easterSeasonalEventCL.sqf) sends ["pickupEasterBunny", _bunnyObject, player].
    Server removes the bunny globally (so only ONE player can claim it) + pays a small prize.
*/
params [["_caseType", "", [""]], ["_bunny", objNull, [objNull]], ["_unit", objNull, [objNull]]];
switch (_caseType) do {case "pickupEasterBunny": {if (isNull _bunny || {isNull _unit}) exitWith {};
        if (_bunny getVariable ["AP_bunnyClaimed", false]) exitWith {};   // race guard: first claimer wins
        _bunny setVariable ["AP_bunnyClaimed", true, true];
        deleteVehicle _bunny;
        private _prize = 5000 + (floor random 6) * 1000;
        [["cash", "add", _prize], "AP_fnc_uC", _unit, false, false] spawn AP_fnc_MP;
        [[format ["You found an Easter bunny! $%1!", [_prize] call AP_fnc_numberText], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        diag_log format ["[LooneyBin][easter] bunny claimed by %1 ($%2)", getPlayerUID _unit, _prize];};
    default { diag_log format ["[LooneyBin][easter] unhandled case: %1", _this]; };};
