if !(isNil "AP_treasureSpot") exitWith {};
AP_treasureSpot = [nil, nil];
private _treasureLocation = [[worldSize / 2, worldSize / 2, 0], 1, (worldSize / 2), 1, 0, 0, 1, [[[8466, 25101], 1000]], [[0, 0, 0],
        [0, 0, 0]]] call BIS_fnc_findSafePos;
private _treasureSpotRandom = [((_treasureLocation select 0) + random[-100, 0, 100]), ((_treasureLocation select 1) + random[-100, 0, 100])];
AP_treasureSpot = [_treasureLocation, _treasureSpotRandom];
private _plb_pos = [((AP_treasureSpot select 0) select 0), ((AP_treasureSpot select 0) select 1), 0];
private _treasureChest = "Box_Syndicate_WpsLaunch_F"
createVehicleLocal _plb_pos;
_treasureChest allowDamage false;
_treasureChest setPos _plb_pos;
_treasureChest setVariable["AP_owner", player];
private _virutalInventory = [["treasure", 1]];
_treasureChest setVariable["AP_droppedItems", _virutalInventory];
clearWeaponCargo _treasureChest;
clearMagazineCargo _treasureChest;
clearBackpackCargo _treasureChest;
clearItemCargo _treasureChest;
_treasureChest spawn {waitUntil {uiSleep 0.5;
        ((_this getVariable["AP_droppedItems", []]) isEqualTo[]);};
    deleteVehicle _this;
    AP_treasureSpot = nil;};