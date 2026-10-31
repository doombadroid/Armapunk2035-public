#include "..\..\macro.h"
/*
    AP_fnc_furnitureAction -- LooneyBin (2026-06-11): scroll-wheel options on placed house furniture.
    Modes: "lay" / "getup" (Land_WoodenBed_01_F), "move" (pick up -> re-place), "delete" (confirm -> Y inv).
    Furniture place/persist/pickup + the 20-per-house cap live in fn_placeObject / fn_pickupObject /
    APS_fnc_houseFurnitureSRV. This only adds the on-object interactions.
*/
params [["_mode", "", [""]], ["_obj", objNull, [objNull]]];
if (_mode isEqualTo "") exitWith {};

// Return a placed piece to the player's Y inventory + drop its persisted DB row + delete it. Returns item key ("" = fail).
private _fnc_return = {params ["_o"];
    if (isNull _o) exitWith { "" };
    private _idx = [typeOf _o, AP_placeable] call AP_fnc_index;
    if (_idx isEqualTo -1) exitWith { "" };
    private _key = (AP_placeable select _idx) select 0;
    if !([true, _key, 1] call AP_fnc_handleInv) exitWith {["No room in your Y inventory.", "basic"] spawn AP_fnc_handleMessage;""};
    [["remove", getPosATL _o], "APS_fnc_houseFurnitureSRV", 2] spawn AP_fnc_MP;
    deleteVehicle _o;
    _key};

switch (_mode) do {case "lay": {if (isNull _obj || {player distance _obj > 3}) exitWith {};
        if !(vehicle player isEqualTo player) exitWith {};
        if (player getVariable ["AP_layingBed", false]) exitWith {};
        if (AP_isDowned || (player getVariable ["AP_restrained", false])) exitWith {};
        player setVariable ["AP_layingBed", true, true];
        private _p = _obj modelToWorldVisual [0, 0, 0.5];
        player setPosATL [_p select 0, _p select 1, (getPosATL _obj select 2) + 0.5];
        player setDir (getDir _obj);
        player playMoveNow "AmovPpneMstpSnonWnonDnon";
        ["You lie down on the bed. Use the scroll menu -> Get Up when finished.", "basic"] spawn AP_fnc_handleMessage;};
    case "getup": {player setVariable ["AP_layingBed", nil, true];
        player switchMove "";
        ["You get up.", "basic"] spawn AP_fnc_handleMessage;};
    case "delete": {if (isNull _obj) exitWith {};
        // owner 2026-07-10: COMPOSITION members (helipad lamps etc.) have no AP_placeable/Y-item mapping,
        // so they can't be "returned" -- offer a straight scrap instead (persisted row removed, no refund).
        if (([typeOf _obj, AP_placeable] call AP_fnc_index) isEqualTo -1) exitWith {
            if !(_obj getVariable ["AP_furniture", false]) exitWith {};
            if (["Scrap this piece? (Composition parts can't be returned to inventory.)", "Scrap Furniture", "Yes", "No"] call BIS_fnc_guiMessage) then {
                [["remove", getPosATL _obj], "APS_fnc_houseFurnitureSRV", 2] spawn AP_fnc_MP;
                deleteVehicle _obj;
                ["Piece scrapped.", "basic"] spawn AP_fnc_handleMessage;};};
        if (["Delete this furniture? It will be returned to your Y inventory.", "Delete Furniture", "Yes", "No"] call BIS_fnc_guiMessage) then {
            private _k = [_obj] call _fnc_return;
            if (_k isNotEqualTo "") then { ["Furniture returned to your Y inventory.", "basic"] spawn AP_fnc_handleMessage; };};};
    case "move": {if (isNull _obj) exitWith {};
        private _k = [_obj] call _fnc_return;
        if (_k isNotEqualTo "") then {uiSleep 0.2;
            ["Re-position the piece, then place it again.", "basic"] spawn AP_fnc_handleMessage;
            [_k] spawn AP_fnc_holdObject;};};};
