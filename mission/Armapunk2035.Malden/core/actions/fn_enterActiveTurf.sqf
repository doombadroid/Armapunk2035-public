if (!canSuspend) exitWith {_this spawn AP_fnc_enterActiveTurf;};
params["_thisList", "_thisTrigger"];
if !(player in _thisList || (vehicle player) in _thisList) exitWith {};
private _plb_obj = vehicle player;
private _zoneRadius = (triggerArea _thisTrigger) param[0, 750];
private _activeTurf = [rodo_flag, zaros_flag, panagia_flag] param[([rodo_flag, zaros_flag, panagia_flag] findIf {
    (_x getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] param[2, false])}), objNull];
if (isNull _activeTurf) exitWith {};
private _inTurf = (player inArea(format["turf_area_%1", _activeTurf]));
if !(_inTurf) exitWith {};
(_activeTurf getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]]) params[["_gangID", -1, [0]], ["_gangName", "Unknown", [""]], ["_active", false, [false]], ["_playerCapturer", "Unknown", [""]]];
if !(_active) exitWith {};
["<t color='#FF0000'>YOU'VE ENTERED A GANG TURF WAR REGION!</t> This is a temporary illegal area during an active turf battle. When the circle on the map turns yellow, it's safe to enter. <t color='#FF0000'>RDM rules do NOT APPLY.</t>", "turf"] spawn AP_fnc_handleMessage;
[[0, 2], "YOU'VE ENTERED A GANG TURF WAR REGION! RDM rules do NOT APPLY while the circle is red."] spawn AP_fnc_broadcast;