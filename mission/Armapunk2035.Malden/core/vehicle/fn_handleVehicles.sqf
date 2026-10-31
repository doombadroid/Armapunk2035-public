#include "..\..\macro.h"
params["_type", "_spawn", ["_isGangGarage", false, [false]]];
if (scriptAvailable(3)) exitWith {if (_isGangGarage) then {
        ["Please do not spam your gang's garage. It may take a bit to show vehicles if the server is under heavy load.", "basic"] spawn AP_fnc_handleMessage;
    } else {
        ["Please do not spam your garage. It may take a bit to show your vehicles if the server is under heavy load.", "basic"] spawn AP_fnc_handleMessage;
    };};
if (AP_inEvent) exitWith {["You cannot use the garage during an admin event.", "basic"] spawn AP_fnc_handleMessage;};
AP_garageData = [];
if (_isGangGarage) then {[
        [(AP_gang_data param[0, -1]), player, getPlayerUID player, _type], "APS_fnc_gangGarageGetVehicles", 2] spawn AP_fnc_MP;
    ["gangGarage"] call AP_fnc_createDialog;} else {[[player, _type], "APS_fnc_getVehicles", 2] spawn AP_fnc_MP;
    // DECK ROUTE (UI overhaul 2026-08-26): the personal garage opens as a deck
    // app; the server's reply lands in fn_vehicleGarageMenu, which pushes the
    // deck channel instead of filling dialog 100150. Gang garage stays native
    // this wave. AP_deckApps=false falls back.
    if (missionNamespace getVariable ["AP_deckApps", true]) then {
        ["Garage"] call AP_fnc_deckOpenApp;
    } else {
        ["AP_vehicleGarage"] call AP_fnc_createDialog;
    };};
disableSerialization;
AP_garage_sp = _spawn;
AP_garage_type = _type;