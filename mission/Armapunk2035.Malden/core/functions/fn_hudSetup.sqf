disableSerialization;
// PR14: the native HUD is retired while the web STATUS HUD is the HUD, so its layer is not even
// cut -- AP_playerHUD's class defaults are visible (ui.hpp parks every bar at 0.8/0.85 and only
// AP_fnc_hudUpdate moves them), so cutting a layer nothing draws into paints placeholder bars.
// AP_webHudEnabled false restores the old behaviour exactly, and mid-session it does not need
// this line at all: AP_fnc_hudUpdate's own isNull self-heal cuts the layer the next time it
// runs, and the web keeper calls it within a second of the flip. The hudUpdate call below stays
// UNCONDITIONAL -- it is what runs the first web push and the first profileNamespace writes.
if !(missionNamespace getVariable ["AP_webHudEnabled", true]) then {2 cutRsc["AP_playerHUD", "PLAIN"];};
[] call AP_fnc_hudUpdate;
[] spawn {private _damage = 0;
    private _wanted = 0;
    for "_i"
    from 0 to 1 step 0 do {_damage = damage player;
        _wanted = A_stats_crimes select 0;
        waitUntil {uiSleep 1;
            !(_wanted isEqualTo((A_stats_crimes) select 0)) || !(_damage isEqualTo(damage player))};
        [] call AP_fnc_hudUpdate;};};