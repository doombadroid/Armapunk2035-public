params[["_houseObj", objNull, [objNull]]];
if (isNull _houseObj || !(alive _houseObj) || !(typeOf _houseObj in AP_houseTypes)) exitWith {};
private _action = [format["WARNING: This will immediatly seize all contents from the house into a nearby cop vehicle <br/> Are you sure you want to seize the contents from this house?"], "Seize house content", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
private _ownerUID = _houseObj getVariable["AP_homeOwner", ""];
private _keyHolders = [_houseObj, "", "getKeyHolders"] call AP_fnc_keyHolderStatus;
private _allCivilianPids = (allPlayers select {side _x isEqualTo civilian}) apply {getPlayerUID _x};
private _onlineOwner = _ownerUID in _allCivilianPids;
private _onlineKeys = _keyHolders arrayIntersect _allCivilianPids;
if (!(_onlineOwner) && _onlineKeys isEqualTo[]) exitWith {
    ["You cannot seize the contents of this house right now. Try again later.", "basic"] spawn AP_fnc_handleMessage};
// owner 2026-06-23 (B): house storage is server-local/gated now -> hydrate (cop authorized server-side) + wait
// before reading. The seizure is persisted + dehydrated below via APS_fnc_updateHouseTrunk.
[[_houseObj, _houseObj getVariable ["AP_houseID", -1], "hydrate"], "APS_fnc_initHouseInventory", 2] spawn AP_fnc_MP;
private _hydrTimeout = time + 5;
waitUntil { uiSleep 0.1; (time > _hydrTimeout) || !(isNil { _houseObj getVariable "AP_vinv" }) };
private _houseVInv = _houseObj getVariable["AP_vinv", [[], 0]];
private _housePInv = _houseObj getVariable["AP_pinv", [[], 0]];
if (_houseVInv isEqualTo[[], 0] && _housePInv isEqualTo[[], 0]) exitWith {
    [[_houseObj, _houseObj getVariable ["AP_houseID", -1], "dehydrate"], "APS_fnc_initHouseInventory", 2] spawn AP_fnc_MP;
    ["There is nothing in this house.", "basic"] spawn AP_fnc_handleMessage};
_houseVInv params["_Vitems", "_Vweight"];
_housePInv params["_Pitems", "_Pweight"];
private _nearestVehicles = nearestObjects[_houseObj, ["Car", "Air", "Ship"], 30];
private _nearestVehicle = _nearestVehicles param[_nearestVehicles findIf {_x getVariable["AP_side", ""] isEqualTo "cop"}, objNull];
if (isNull _nearestVehicle) exitWith {
    ["There aren't any nearby Police vehicles to seize this house's illegal items into!", "basic"] spawn AP_fnc_handleMessage;};
if !(alive _nearestVehicle) exitWith {
    ["You cannot seize items into a vehicle which has been destroyed!", "basic"] spawn AP_fnc_handleMessage;};
(_nearestVehicle getVariable["AP_vinv", [[], 0]]) params["_nearVitems", "_nearVweight"];
private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
private _illegalValue = 0;
private _index = -1;
private _itemWeight = 0;
private _preWeight = _Pweight;
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]}; {_x params["_var", "_val"];
    _index = _illegalItems findIf {_var in _x};
    if (!(_index isEqualTo - 1) && !(_var in _illegalExempt)) then {_itemWeight = ["getItemWeight", _var] call AP_fnc_virtItemCfg;
        _Vweight = _Vweight - (_val * _itemWeight);
        _Vitems = _Vitems - [_x];
        _nearVweight = _nearVweight + (_val * _itemWeight);
        private _idx = _nearVitems findIf {(_x select 0) isEqualTo _var};
        if (_idx isEqualTo - 1) then {_nearVitems pushBack[_var, _val];} else {private _oldVal = (_nearVitems select _idx) select 1;
            (_nearVitems select _idx) set[1, _oldVal + _val];};
        _illegalValue = _illegalValue + (_val * ((_illegalItems select _index) select 1));};}
forEach(_houseVInv select 0);
private _illegalVirtualSeized = +_nearVitems;
private _illegalPhysicalSeized = []; {_x params["_var", "_val"];
    if ((getNumber(missionConfigFile >> "CfgWeights" >> _var >> "illegal")) isEqualTo 1) then {
        _Pweight = _Pweight - getNumber(missionConfigFile >> "CfgWeights" >> _var >> "weight");
        _index = _Pitems findIf {(_x select 0) isEqualTo _var};
        if !(_index isEqualTo - 1) then {_Pitems = _Pitems - [_x]};
        _nearestVehicle addItemCargoGlobal[_var, _val];
        _illegalPhysicalSeized pushBack[_var, _val];};}
forEach(_housePInv select 0);
if (_illegalValue > 0 || _preWeight != _Pweight) then {
    // owner 2026-06-23 (B): persist the post-seizure stash to the DB + DEHYDRATE through APS_fnc_updateHouseTrunk
    // (cops pass its gate). Replaces the old "set AP_vinv GLOBAL" -- that both LEFT the stash broadcast (the leak)
    // and only updated the live cache (the DB persisted lazily on the owner's next close). The cop vehicle (a
    // VEHICLE, not a house) keeps its global set below -- vehicle trunks are out of scope for B.
    [[player, _houseObj, [_Vitems, _Vweight], [_Pitems, _Pweight]], "APS_fnc_updateHouseTrunk", 2] spawn AP_fnc_MP;
    _nearestVehicle setVariable["AP_vinv", [_nearVitems, _nearVweight], true];
    private _rank = [west, player] call AP_fnc_getRankString; [
        [0, format["A house was searched by %1%2 and $%3 worth of drugs / contraband were taken into police custody.", _rank, profileName, [_illegalValue] call AP_fnc_numberText]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    titleText["The illegal items from this house have been seized into the nearest police vehicle. The items can be placed into evidence from any Police HQ.", "PLAIN"];
    [
        ["-HOUSEINVSEIZE-", player, (profileName), format["seized house contents (ID: %1 | Owner: %2 | Position: %3), House Virtual Seized: %4, House Physical Seized: %5, Total Illegal Value: $%6, Online key holders: %7", _houseObj getVariable["AP_houseID", -1], _houseObj getVariable["AP_homeOwner", "NoPidVar"], getPosATL _houseObj, _illegalVirtualSeized, _illegalPhysicalSeized, _illegalValue, _onlineKeys]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
} else {[[_houseObj, _houseObj getVariable ["AP_houseID", -1], "dehydrate"], "APS_fnc_initHouseInventory", 2] spawn AP_fnc_MP;
    ["Nothing illegal to seize in this house.", "basic"] spawn AP_fnc_handleMessage;};