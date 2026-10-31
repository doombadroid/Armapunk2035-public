/*
    File: fn_suitePresence.sqf  (AP_fnc_suitePresence)
    Luxe Suites 2026-08-07 -- ask the server to put this tenant's furniture out.

        [] spawn AP_fnc_suitePresence      (once, from core\init.sqf)

    Suite furniture is PRESENCE-SPAWNED (suites.md §8): the pieces exist only
    while the tenant is around, so they cost nothing for the 29 floors nobody is
    standing on. Somebody has to say "I am here" -- that is this.

    It asks when the player is inside a suite they hold and has not asked for
    that oid yet this session; APS_fnc_suiteFurnitureSRV ignores a second "load"
    for a suite already spawned, so a duplicate request cannot double the room up.
    Removal is not done here: APS_fnc_suiteRentSweep already runs every 300 s and
    prunes suites whose owner has gone, which avoids hanging another hook off the
    disconnect path (already the busiest and most incident-scarred path we have).

    Ownership is judged the same way the door and the placement gate judge it --
    the stamp AP_fnc_suiteDoorSync puts on the leaf, not the AP_suiteRows
    cache, which is only filled by opening the kiosk.
*/
if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["AP_suitePresenceMon", false]) exitWith {};
AP_suitePresenceMon = true;
AP_suiteAsked = [];

[] spawn {
    while { true } do {
        sleep 8;
        if (alive player) then {
            private _s = [player] call AP_fnc_suiteAt;
            if (_s isNotEqualTo []) then {
                private _oid = _s param [2, ""];
                if !(_oid in AP_suiteAsked) then {
                    if ([_s param [0, objNull], _s param [1, -1]] call AP_fnc_suiteMine) then {
                        AP_suiteAsked pushBack _oid;
                        [["load", _oid, []], "APS_fnc_suiteFurnitureSRV", 2] spawn AP_fnc_MP;
                    };
                };
            };
        };
    };
};
