#include "..\..\macro.h"
/*
    AP_fnc_ownerMode  (owner 2026-07-06) -- OWNER-ONLY self toggle. Disclosed feature (patch-noted). ON =
      - ESP: floating name/health/distance label + bounding box over every player (Draw3D, LOCAL to this client)
      - near-zero weapon sway (setCustomAimCoef) + zero recoil (setUnitRecoilCoefficient), re-applied on a 0.5s
        loop so fn_survival's periodic setCustomAimCoef 0.25 can't override it -- for building/testing VR missions
      - a "Super Spangle" scroll on your cursor target = NON-LETHAL ragdoll-launch (routes through the owner-
        validated APS_fnc_ownerSpangle) to punish safezone/town vehicle abusers
    ESP + sway/recoil are client-LOCAL and touch nothing else. Super Spangle is the only cross-client effect and it
    is server-validated. Hard-gated to the owner UID as defence in depth (the phone-app condition also gates it).
    Repurposed from the old "Owner" phone app (was the whole-server newbie-role grant); wired at core\init.sqf.
    setCustomAimCoef/setUnitRecoilCoefficient are NOT BattlEye-watched, and the recoil anti-cheat only trips on -1.
*/
if ((getPlayerUID player) isNotEqualTo "76561190000000001") exitWith {};
private _on = !(missionNamespace getVariable ["AP_ownerMode", false]);
missionNamespace setVariable ["AP_ownerMode", _on];

if (_on) then {
    // -- weapon handling: near-zero sway + zero recoil, re-applied so fn_survival's 0.25 re-apply can't win
    [] spawn {while { missionNamespace getVariable ["AP_ownerMode", false] } do {player setCustomAimCoef 0.01;
            player setUnitRecoilCoefficient 0;
            uiSleep 0.5;};
        player setCustomAimCoef 0.25;          // fn_survival baseline
        player setUnitRecoilCoefficient 1;     // vanilla
    };

    // -- ESP overlay (Draw3D): label + bounding box over every player, self excluded (adapted from fn_adminMode)
    private _old = missionNamespace getVariable ["AP_ownerESPh", -1];
    if (_old isEqualType 0 && {_old >= 0}) then { removeMissionEventHandler ["Draw3D", _old]; };
    private _h = addMissionEventHandler ["Draw3D", {if !(missionNamespace getVariable ["AP_ownerMode", false]) exitWith {}; {
            if (isPlayer _x && {name _x isNotEqualTo profileName} && {alive _x}) then {private _c = switch (side _x) do {
                    case civilian: { [0.467, 0, 1] };
                    case west: { [0, 0.5, 1] };
                    case independent: { [0, 0.65, 0] };
                    default { [1, 1, 1] };};
                private _a = switch (true) do {case (player distance _x < 100): { 1 };
                    case (player distance _x < 250): { 0.9 };
                    case (player distance _x < 500): { 0.8 };
                    case (player distance _x < 1250): { 0.6 };
                    default { 0 };};
                if (_a > 0) then {private _color = _c + [_a];
                    private _pos = visiblePosition _x; _pos set [2, (getPosATL _x select 2) + 2];
                    private _lbl = format ["%1 (%2%3) - %4m", name _x, 100 - ceil ((damage _x) * 100), "%", round (player distance _x)];
                    drawIcon3D ["", _color, _pos, 0, -1, 0, _lbl, 1.5, 0.03, "PuristaMedium", "center", false];
                    private _u = _x;
                    (boundingBoxReal _u) params ["_bbMin", "_bbMax"];
                    _bbMin params ["_x0", "_y0", "_z0"];
                    _bbMax params ["_x1", "_y1", "_z1"];
                    private _cn = [[_x0,_y0,_z0],[_x1,_y0,_z0],[_x1,_y1,_z0],[_x0,_y1,_z0],[_x0,_y0,_z1],[_x1,_y0,_z1],[_x1,_y1,_z1],[_x0,_y1,_z1]] apply { _u modelToWorldVisual _x };
                    { _x params ["_i", "_j"]; drawLine3D [_cn select _i, _cn select _j, _color]; } forEach [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
                };};} forEach playableUnits;}];
    missionNamespace setVariable ["AP_ownerESPh", _h];

    // -- Super Spangle scroll (non-lethal launch of the player you're looking at)
    private _act = player addAction ["<t color='#ff44ff'>Super Spangle</t>",
        { private _t = cursorTarget; if (!isNull _t && {_t isKindOf "Man"} && {isPlayer _t} && {alive _t} && {_t isNotEqualTo player}) then { [[_t, player], "APS_fnc_ownerSpangle", 2] spawn AP_fnc_MP; } else { ["Look directly at a player to Super Spangle them.", "basic"] spawn AP_fnc_handleMessage; }; },
        nil, 6, false, true, "",
        "!isNull cursorTarget && {cursorTarget isKindOf 'Man'} && {isPlayer cursorTarget} && {alive cursorTarget} && {cursorTarget isNotEqualTo player}"
    ];
    missionNamespace setVariable ["AP_spangleAction", _act];

    ["Owner Mode ON -- ESP + no sway/recoil. Super Spangle scroll active (look at a player).", "info"] spawn AP_fnc_handleMessage;
} else {private _h = missionNamespace getVariable ["AP_ownerESPh", -1];
    if (_h isEqualType 0 && {_h >= 0}) then { removeMissionEventHandler ["Draw3D", _h]; };
    missionNamespace setVariable ["AP_ownerESPh", nil];

    private _act = missionNamespace getVariable ["AP_spangleAction", -1];
    if (_act isEqualType 0 && {_act >= 0}) then { player removeAction _act; };
    missionNamespace setVariable ["AP_spangleAction", nil];

    ["Owner Mode OFF.", "info"] spawn AP_fnc_handleMessage;};
