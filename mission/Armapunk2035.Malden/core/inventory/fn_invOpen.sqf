/*
    fn_invOpen.sqf -- open the I-screen (dialog 938500). INVENTORY_SPEC.md §9.2.

        [_container] spawn AP_fnc_invOpen;     // objNull = self + ground only

    Called from evh/fn_inventoryOpened.sqf AFTER its guard chain has passed (firefighter, admin
    mode, bag stealing, bodies, seizing, cooldown, event crates, locked vehicles, the AP_veh_in_use
    single-user lock) -- that file returns true to the engine so display 602 never opens, and this
    one puts the web dialog up in its place. Nothing here re-decides access; it only reserves and
    opens. The reservation is released by fn_invBridge.sqf's Unload handler, the one releaser.

    A ground WeaponHolder handed over as the container is folded into the merged ground pile the
    snapshot already reads (every holder within 5 m), so the reach panel is for vehicles and crates.
*/
params [["_container", objNull, [objNull]]];
if (!isNull (findDisplay 938500)) exitWith {};
if (dialog) exitWith {};
if (!alive player) exitWith {};
if (player getVariable ["AP_restrained", false]) exitWith {
    ["You cannot access your inventory while you're restrained!", "basic"] spawn AP_fnc_handleMessage;
};
if (AP_action_in_use) exitWith { ["You're currently doing a different action..", "basic"] spawn AP_fnc_handleMessage; };
if (_container isKindOf "WeaponHolder" || {_container isKindOf "WeaponHolderSimulated"}) then {
    // fn_inventoryOpened reserved it like a vehicle; a pile is shared through the snapshot instead
    if ((_container getVariable ["AP_veh_in_use", objNull]) isEqualTo player) then { _container setVariable ["AP_veh_in_use", nil, true]; };
    _container = objNull;
};

if (!isNull _container) then { _container setVariable ["AP_veh_in_use", player, true]; };
uiNamespace setVariable ["AP_invContainer", _container];
uiNamespace setVariable ["AP_invGsOpen", ""];
// the figure's exposure lock (fn_invFigure.sqf) starts here, before the page is even up, so the
// eye adaptation has the extra half second; fn_invFigure sets it again and releases it on close
if (isPiPEnabled && {!isNil "AP_fnc_invFigTune"}) then { setAperture ((call AP_fnc_invFigTune) select 0); };
createDialog "AP_web_inventory";
if (isNull (findDisplay 938500)) then {
    diag_log "[INV] createDialog AP_web_inventory failed";
    if (!isNull _container && {(_container getVariable ["AP_veh_in_use", objNull]) isEqualTo player}) then {
        _container setVariable ["AP_veh_in_use", nil, true];
    };
};
