if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_robber", objNull, [objNull]], ["_virtItems", false, [false]], ["_pistol", false, [false]]];
if (isNull _robber) exitWith {};
if (AP_gfunds_active) exitWith {[
        ["You can't rob this person at this time. Try again in a couple seconds", "basic"], "AP_fnc_handleMessage", _robber] spawn AP_fnc_MP;
};
private _cashAmt = AP_cash;
private _isBH = false;
[format["%1 has just robbed you of %2.", name _robber, [_cashAmt] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
if (_cashAmt > 0) then {AP_cash = 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    [0] call AP_fnc_ClupdatePartial;};
if (_virtItems && AP_effSide isEqualTo civilian) then {private _items = [];
    private["_item", "_value", "_shortName"]; {_item = _x;
        _value = missionNamespace getVariable _item;
        if (_value > 0) then {_shortName = ["getShortName", _item] call AP_fnc_virtItemCfg;
            _items pushBackUnique[_shortName, _value];};}
    forEach([1] call AP_fnc_virtItemCfg);
    if !(_items isEqualTo[]) then {_isBH = true;};
    [player] call AP_fnc_dropItems;};
if (_pistol) then {private _items = [handgunWeapon player];
    player removeWeapon handgunWeapon player; {if ("grenade" in (toLower(_x)) || "smokeshell" in (toLower(_x))) then {_items pushBack _x;
            player removeMagazine _x;};}
    forEach magazines player;
    private _weaponHolder = createVehicle["WeaponHolderSimulated", getPosATL player, [], 0, "CAN_COLLIDE"]; {
        _weaponHolder addItemCargoGlobal[_x, 1]}
    forEach _items;
    if !(_items isEqualTo[""]) then {_isBH = true;};};
if ((_cashAmt > 0) || _isBH) then {[[_cashAmt, player, _isBH], "AP_fnc_robReceive", _robber, false, false] spawn AP_fnc_MP; [
        ["-ROBBED-", player, (profileName), format["was robbed by %1 (%2) for $%3.", name _robber, getPlayerUID _robber, [_cashAmt] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
} else {[["They had nothing to steal...", "basic"], "AP_fnc_handleMessage", _robber, false, false] spawn AP_fnc_MP;};