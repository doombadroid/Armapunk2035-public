if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_mode", -1, [0]], ["_building", objNull, [objNull]], ["_pid", "", [""]], "_marketPrice", "_gangid"];
if (isNull _building || _mode isEqualTo - 1) exitWith {};
if !(_pid isEqualTo(getPlayerUID player)) exitWith {};
AP_houseTxn = false;
AP_action_in_use = false;
private _position = (getPosATL _building);
if ((count(nearestObjects[_position, ["House_F"], 10])) > 0) then {
    if ((typeof((nearestObjects[_position, ["House_F"], 10]) select 0)) == (typeof _building)) then {
        _building = ((nearestObjects[_position, ["House_F"], 10]) select 0);};};
private _houseCfg = [(typeOf _building)] call AP_fnc_houseConfig;
if (count _houseCfg isEqualTo 0) exitWith {};
_houseCfg params["_buyPrice", "_sellPrice", "_pStorage", "_vStorage"];
// owner 2026-06-18 (#357): drop a house from AP_houses by NEAREST stored position, NOT an exact
// str(getPosATL) match. AP_houses entries reload from the DB on login (a saved worldspace string,
// fn_requestReceived:206) which won't character-match the live str(getPosATL _building) -> after a relog the
// sold house lingered in AP_houses -> the buy-limit check (`count AP_houses >= AP_houseLimit`,
// fn_buyHouse:130) stayed maxed = "sold a house but still own 5, can't buy" (#357). Closest entry (you're
// standing at the house you're selling) within 10m; exact-string match kept as the same-session fallback.
private _fnc_dropHouse = {params ["_b"];
    private _bp = getPosATL _b;
    private _best = -1; private _bd = 1e9; {private _hp = parseSimpleArray (_x param [0, "[0,0,0]"]);
        if ((_hp isEqualType []) && {count _hp >= 2}) then {private _d = _bp distance2D [_hp select 0, _hp select 1, 0];
            if (_d < _bd) then { _bd = _d; _best = _forEachIndex; };};} forEach AP_houses;
    private _i = if (_bd < 10) then { _best } else { [str _bp, AP_houses] call AP_fnc_index };
    if (_i != -1) then { AP_houses deleteAt _i; };};
switch (_mode) do {case 1: {_building setVariable["AP_homeOwner", (getPlayerUID player), true];
            _building setVariable["AP_buildingLocked", true, true];
            _building setVariable["AP_vinv", [[], 0], true];
            _building setVariable["AP_pinv", [[], 0], true];
            // LooneyBin: seed BASE storage caps + keycap from houseConfig on buy. Without these, AP_vcap/
            // AP_phys_cap stay nil and fn_upgradeProperty defaults them to the MAX -> every upgrade reports
            // "you already have the max amount of upgrades" and exits. Also makes the storage UI show the
            // correct base capacity instead of the fallback 100.
            _building setVariable["AP_phys_cap", ((_pStorage select 0) select 0), true];
            _building setVariable["AP_vcap", ((_vStorage select 0) select 0), true];
            _building setVariable["AP_keycap", 0, true];
            _building setVariable["AP_activeTrunk", nil, true];
            AP_vehicles pushBack _building;
            AP_houses pushBack[(str(getPosATL _building)), []];
            private _marker = createMarkerLocal[format["phouse_%1", (_building getVariable "AP_houseID")], getPosATL _building];
            _marker setMarkerTextLocal getText(configFile >> "CfgVehicles" >> (typeOf _building) >> "displayName");
            _marker setMarkerShapeLocal "ICON";
            _marker setMarkerColorLocal "ColorBlue";
            _marker setMarkerTypeLocal "mil_end";
            private _tax = round(_buyPrice * (call AP_fnc_getGovTax));
            [format["Your purchase offer for the home has been accepted! The keys have been added to your keychain. You paid a total of $%1, including a tax of $%2", [_buyPrice + _tax] call AP_fnc_numberText, [_tax] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
            ["payGovernor", [_tax]] spawn AP_fnc_govSystem;
            _building setVariable["AP_activeTrunk", nil, true];};
    case 2: {private _gangbldg = _building getVariable["AP_house_gang", -1];
            if !(_gangbldg isEqualTo - 1) then {private _onlineMembers = [(AP_gang_data select 0)] call AP_fnc_getOnlineMembers;
                deleteMarkerLocal AP_gangBldgMark;
                AP_gangBldgMark = ""; [
                    [_building, (AP_gang_data select 0), _building getVariable "AP_homeOwner"], "AP_fnc_removeGangHouse", _onlineMembers] call AP_fnc_MP;
            } else {deleteMarkerLocal format["phouse_%1", _building getVariable "AP_houseID"];};
            _building setVariable["AP_houseID", nil, true];
            _building setVariable["AP_homeOwner", nil, true];
            AP_atmcash = AP_atmcash + _sellPrice;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [6] call AP_fnc_ClupdatePartial;
            private _index = AP_vehicles find _building;
            if !(_index isEqualTo - 1) then {AP_vehicles set[_index, -1];
                AP_vehicles = AP_vehicles - [-1];};
            [_building] call _fnc_dropHouse;   // #357: robust nearest-position removal (str match failed after relog)
            [format["The bank has purchased your house for $%1. The money has been added to your bank account.", [_sellPrice] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        };
    case 3: {
            // owner 2026-06-19 (#392): a denied purchase refunded the house CONFIG base price (+tax) -- _buyPrice
            // here comes from houseConfig (line 15), NOT what the buyer actually paid. On a P2P RESALE the buyer paid
            // the seller's ASKING price (transferHouse/addHouse pass it back as _marketPrice) but only got the 200k
            // base back = lost the difference. Refund what the server says was charged (_marketPrice) when present;
            // fall back to config base+tax for any denial that doesn't pass an amount.
            private _tax = round(_buyPrice * (call AP_fnc_getGovTax));
            private _refund = if ((_marketPrice isEqualType 0) && {_marketPrice > 0}) then { _marketPrice } else { _buyPrice + _tax };
            [format["The realtor group has denied your purchase as this home is already owned. The $%1 used to purchase the home has been added back to your bank balance.", [_refund] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
            AP_atmcash = AP_atmcash + _refund;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [6] call AP_fnc_ClupdatePartial;};
    case 4: {
            [format["Your house on the market has sold to another player for $%1. Ownership is now transfering and the money has been deposited in to your account.", [_marketPrice] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
            AP_atmcash = AP_atmcash + _marketPrice;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [6] call AP_fnc_ClupdatePartial;
            if !(_gangid isEqualTo - 1) then {deleteMarkerLocal AP_gangBldgMark;
                AP_gangBldgMark = "";} else {deleteMarkerLocal format["phouse_%1", _building getVariable "AP_houseID"];};
            private _index = AP_vehicles find _building;
            if !(_index isEqualTo - 1) then {AP_vehicles set[_index, -1];
                AP_vehicles = AP_vehicles - [-1];};
            [_building] call _fnc_dropHouse;   // #357: robust nearest-position removal (str match failed after relog)
        };
    case 5: {AP_vehicles pushBack _building;
            AP_houses pushBack[(str(getPosATL _building)), []];
            private _marker = createMarkerLocal[format["phouse_%1", (_building getVariable "AP_houseID")], getPosATL _building];
            _marker setMarkerTextLocal getText(configFile >> "CfgVehicles" >> (typeOf _building) >> "displayName");
            _marker setMarkerShapeLocal "ICON";
            _marker setMarkerColorLocal "ColorBlue";
            _marker setMarkerTypeLocal "mil_end";
            [format["Your house purchase has finished! The keys have been added to your keychain. You paid a total of $%1.", [_marketPrice] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        };};