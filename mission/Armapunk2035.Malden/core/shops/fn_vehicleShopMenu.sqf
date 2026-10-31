(_this select 3) params[["_shop", "", [""]], ["_sideCheck", sideUnknown, [civilian]], ["_spawnPoints", "", ["", [], objNull]], ["_shopFlag", "", [""]], ["_shopTitle", "", [""]], ["_disableBuy", false, [true]]];
if (dialog || _shop isEqualTo "" || _sideCheck isEqualTo sideUnknown || player getVariable["AP_restrained", false] || player getVariable["AP_surrendered", false]) exitWith {};
if !(_sideCheck isEqualTo AP_effSide) exitWith {["This shop is not allowed for your faction!", "basic"] spawn AP_fnc_handleMessage;};
private _shop =
_shop;
disableSerialization;
if (_shop isEqualTo "nd_car") then {AP_ndShop = true;};
// DECK ROUTE (UI overhaul 2026-08-26): the dealership opens as a deck app. The
// garage-count fetch below still matters -- fn_vehicleShopBuy's cap guard reads
// it -- so the deck branch fires it and skips only the dialog work.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    if !(_shop in ["maxtac_car", "firefighter_car", "srt_car"]) then {
        AP_garageCount = -1;
        [[getPlayerUID player, AP_effSide, player], "APS_fnc_garageCount", 2] spawn AP_fnc_MP;
    } else { AP_garageCount = 0; };
    AP_veh_shop = [_shop, _spawnPoints, _shopFlag, _disableBuy];
    ["VehicleShop"] call AP_fnc_deckOpenApp;
};
["AP_vehicleShop"] call AP_fnc_createDialog;
if !(_shop in ["maxtac_car", "firefighter_car", "srt_car"]) then {AP_garageCount = -1; [
        [getPlayerUID player, AP_effSide, player], "APS_fnc_garageCount", 2] spawn AP_fnc_MP;} else {AP_garageCount = 0;};
AP_veh_shop = [_shop, _spawnPoints, _shopFlag, _disableBuy];
if (AP_ndShop) then {ctrlSetText[100101, _shopTitle + (format[" - %1 ND", [AP_ndStr] call AP_fnc_ndText])];} else {
    ctrlSetText[100101, _shopTitle];};
if (_disableBuy) then {ctrlEnable[100107, false];};
private _vehicleList = ["shopVehicles", _shop] call AP_fnc_vehicleConfig;
// owner 2026-06-24 DIAG (MaxTac garage empty): client RPT is unreadable on Linux, so mirror what shopVehicles returned
// for the duty shops to the SERVER RPT (-VEHSHOP-). Shows live whether the list is genuinely empty or it's a render issue.
if (_shop in ["maxtac_car", "srt_car", "firefighter_car"]) then {
    [["-VEHSHOP-", player, profileName, format ["%1 -> %2 veh: %3 | copLvl %4 isMaxTac %5", _shop, count _vehicleList, _vehicleList apply { _x select 0 }, call AP_copLevel, missionNamespace getVariable ["AP_isMaxTac", false]]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
private _diagControl = ((findDisplay 100100) displayCtrl 100102);
private _diagVehInfo = ((findDisplay 100100) displayCtrl 100104);
private _index = -1;
private _index = _vehicleList findIf {(_x select 0) isEqualTo "I_Plane_Fighter_04_F"};
if (_shop isEqualTo "srt_car") then {private _index = _vehicleList findIf {(_x select 0) isEqualTo "B_G_Offroad_01_armed_F"};
    if ((_index isNotEqualTo - 1) && (AP_effSide isEqualTo west)) then {_vehicleList deleteAt _index};
    private _index = _vehicleList findIf {(_x select 0) isEqualTo "O_MRAP_02_F"};
    if ((_index isNotEqualTo - 1) && (AP_effSide isEqualTo west)) then {_vehicleList deleteAt _index};};
lbClear _diagControl;
_diagVehInfo ctrlSetStructuredText parseText "<t size='0.40'>&#160;</t><br/><t align='center'>Select a vehicle to purchase</t>";
private["_className", "_vehInfo"]; {_className = _x select 0;
    _vehInfo = [_className] call AP_fnc_fetchVehInfo;
    if ((_x select 1) isEqualTo "") then {_diagControl lbAdd(_vehInfo select 3);} else {_diagControl lbAdd(_x select 1);};
    _diagControl lbSetPicture[(lbSize _diagControl) - 1, (_vehInfo select 2)];
    _diagControl lbSetData[(lbSize _diagControl) - 1, _className];
    _diagControl lbSetValue[(lbSize _diagControl) - 1, _forEachIndex];}
forEach _vehicleList;
waitUntil {isNull(findDisplay 100100)};
if (AP_ndShop) then {AP_ndShop = false;};