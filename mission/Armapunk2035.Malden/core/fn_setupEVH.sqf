player addEventHandler["HandleDamage", {_this call AP_fnc_handleDamage;}];
player addEventHandler["Respawn", {_this call AP_fnc_onPlayerRespawn}];
player addEventHandler["Take", {_this call AP_fnc_onTakeItem}];
player addEventHandler["FiredMan", {_this call AP_fnc_onFired}];
player addEventHandler["Put", {_this spawn AP_fnc_onPutItem;}];
player addEventHandler["InventoryClosed", {_this call AP_fnc_inventoryClosed}];
player addEventHandler["InventoryOpened", {_this call AP_fnc_inventoryOpened}];
player addEventHandler["GetInMan", {_this call AP_fnc_getInMan}];
player addEventHandler["GetOutMan", {_this call AP_fnc_getOutMan}];
// LUXE AV: a second pair of handlers on purpose (GetIn/GetOut return values are ignored, unlike HandleDamage)
player addEventHandler["GetInMan", {params ["", "", "_veh"]; if (_veh isKindOf "ap_av_lux") then {["in", _veh] call AP_fnc_avClient;};}];
player addEventHandler["GetOutMan", {params ["", "", "_veh"]; if (_veh isKindOf "ap_av_lux") then {["out", _veh] call AP_fnc_avClient;};}];
player addEventHandler["HandleRating", {0}];
player addEventHandler["FiredNear", {if ((call AP_adminLevel) <= 1) then {AP_inCombat = true;
        AP_inCombatTime = diag_tickTime;};}];
addMissionEventHandler["EachFrame", {call AP_fnc_onEachFrame}];
// Streamer Mode: censor profanity in player names on the MP score table (IDD 175) while it is open. The engine
// repopulates the rows each frame, so we re-apply every frame; gated to streamers and only when the board is up.
// Matches by text content (handles plain text controls and listbox rows) so it is independent of the engine IDCs.
addMissionEventHandler["EachFrame", {if (isNil "AP_streamerMode" || {!AP_streamerMode}) exitWith {};
    private _d = findDisplay 175;
    if (isNull _d) exitWith {}; {if ((ctrlType _x) isEqualTo 5) then {for "_i" from 0 to ((lbSize _x) - 1) do {private _t = _x lbText _i;
                if (_t isNotEqualTo "") then {private _f = [_t] call AP_fnc_profanityFilter;
                    if (_f isNotEqualTo _t) then { _x lbSetText [_i, _f]; };};};} else {private _t = ctrlText _x;
            if (_t isNotEqualTo "") then {private _f = [_t] call AP_fnc_profanityFilter;
                if (_f isNotEqualTo _t) then { _x ctrlSetText _f; };};};} forEach (allControls _d);}];
addMissionEventHandler["HandleChatMessage", {call AP_fnc_handleChatMessage}];
addMissionEventHandler["ProjectileCreated", {params["_projectile"];
    if ((netId _projectile) isEqualTo "0:0") then {private _projectileClass = typeOf _projectile;
        if (getNumber(configFile >> "CfgAmmo" >> _projectileClass >> "explosive") isEqualTo 1 && {
            (_projectileClass find "Smoke") isEqualTo - 1}) then {private _distanceToExplosion = player distance2D _projectile; [
                [player, [69, _projectileClass, str(getPosATL _projectile), str(getPosATL player), _distanceToExplosion]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
            deleteVehicle _projectile;};};}];
if (AP_effSide isEqualTo civilian) then {player addEventHandler["SeatSwitchedMan", {_this call AP_fnc_seatSwitchedMan}];};
player addEventHandler["Killed", {_this spawn AP_fnc_onPlayerKilled}];
(findDisplay 46) displayAddEventHandler["MouseButtonDown", "_this call AP_fnc_mouseDownHandler"];
(findDisplay 46) displayAddEventHandler["MouseButtonUp", "_this call AP_fnc_mouseUpHandler"];
(findDisplay 46) displayAddEventHandler["KeyDown", "_this call AP_fnc_keyDownHandler"];
(findDisplay 46) displayAddEventHandler["KeyUp", "_this call AP_fnc_keyUpHandler"];
(findDisplay 46) displayAddEventHandler["MouseZchanged", "_this spawn AP_fnc_enableActions"];
if (hasInterface) then {(findDisplay 46) displayAddEventHandler["KeyDown", {_this call RWT_fnc_chatcomVerify}];}; [{
    if (cameraView isEqualTo "GROUP") then {player switchCamera "EXTERNAL";};}, [], 0.5] call AP_fnc_addPerFrameHandler;
"AP_allPointsBulletin"
addPublicVariableEventHandler {if (AP_allPointsBulletin isEqualTo[] && AP_effSide isEqualTo west) exitWith {
        ["The current APB has been lifted!", "copalert"] spawn AP_fnc_handleMessage;
        [] call AP_fnc_hudUpdate;};
    if (AP_allPointsBulletin isEqualTo[]) exitWith {};
    if (getPlayerUID player isEqualTo(AP_allPointsBulletin select 1)) exitWith {
        ["AllPointsBulletin", ["An APB has been issued for your arrest!"]] call BIS_fnc_showNotification;
        ["An APB has been issued for your arrest!", "basic"] spawn AP_fnc_handleMessage;
        [] call AP_fnc_hudUpdate;};
    if !(AP_effSide isEqualTo west) exitWith {};
    ["AllPointsBulletin", [format["APB issued for the arrest of %1!", AP_allPointsBulletin select 0]]] call BIS_fnc_showNotification;
    [format["APB issued for the arrest of %1, their last known location has been marked on your map!", AP_allPointsBulletin select 0], "copalert"] spawn AP_fnc_handleMessage;
    [] call AP_fnc_hudUpdate;
    [] call AP_fnc_trackAPB;};