/*
    APS_fnc_chopTreeSRV  (LooneyBin: SERVER-AUTHORITATIVE tree chop) -- owner 2026-06-24.
    Closes the TIMBER-MINT exploit (76561190000000040 / player093). fn_chopTree used to spawn the timber pile CLIENT-side
    via the generic APS_fnc_createItem, so a cheat client could just remoteExec createItem [["timberh",16]] directly --
    no tree, no woodaxe, no 2.2s, no city-limit -- and pick up free timber, indistinguishable from chopping in the
    logs. NOW: the SERVER validates a real, live, in-range tree (not already chopped), computes the pile (species +
    height, capped 16) ITSELF, and spawns it directly. fn_createItem additionally STRIPS timber from client calls, so
    the ONLY legit source of fresh timber is this fn. A bypass attempt = stripped + logged -SEC-.

    Client args: [_tree]   (caller derived from the non-spoofable remoteExecutedOwner; the passed tree is re-validated)
*/
params [["_tree", objNull, [objNull]], ["_treePos", [], [[]]]];
private _src = remoteExecutedOwner;
if (_src isEqualTo 0) exitWith {};                       // server-internal -> no client to chop for
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};
// owner 2026-06-25 (#536): a TERRAIN tree object does NOT survive a client->server remoteExec by reference -> _tree
// arrived objNull, so this fn early-exited (no timber, no -CHOPTREE- log) for EVERY chop. Re-acquire the live tree by
// the client-sent position; the distance-to-caller check below keeps the anti-mint (a real tree must be next to you).
if (isNull _tree && {(_treePos isEqualType []) && {count _treePos >= 2}}) then {
    _tree = (nearestTerrainObjects [_treePos, [], 4, true]) select { alive _x && { private _m = toLower ((getModelInfo _x) param [0, ""]); (_m find "t_") == 0 || {_m find "palm_" >= 0} } } param [0, objNull];
};
if (isNull _tree) exitWith {};
if !(alive _tree) exitWith {};
// re-validate it's actually a TREE model + the caller is genuinely next to it (the client can pass any object/netId).
private _mdl = toLower ((getModelInfo _tree) param [0, ""]);
if !((_mdl find "t_") == 0 || {_mdl find "palm_" >= 0}) exitWith {};
if ((_caller distance _tree) > 6) exitWith {};
if (_tree getVariable ["AP_chopped", false]) exitWith {};          // one pile per tree
// anti-spam: ~1.8s server cooldown per caller (the client action is 2.2s) -> blocks faster-than-legit chopping.
private _now = diag_tickTime;
if ((_now - (_caller getVariable ["AP_lastChop", -999])) < 1.8) exitWith {};
_caller setVariable ["AP_lastChop", _now];

// compute the pile SERVER-SIDE (mirror fn_chopTree): height -> size (cap 16), species -> item.
private _p3 = getPos _tree;
private _height = ([_p3 select 0, _p3 select 1, 0] distance _p3);
private _amount = (round (_height / 3)) min 4;
private _pileSize = _amount * 4;
if (_pileSize <= 0) exitWith {};
private _pile = switch (_mdl) do {
    case "t_pinusp3s_f.p3d"; case "t_fraxinusav2s_f.p3d"; case "t_phoenixc1s_f.p3d"; case "t_phoenixc3s_f.p3d";
    case "t_quercusir2s_f.p3d"; case "t_populusn3s_f.p3d"; case "t_poplar2f_dead_f.p3d": { "timberh" };
    case "t_oleae1s_f.p3d"; case "t_oleae2s_f.p3d": { "timberl" };
    default { "timber" };};
_tree setVariable ["AP_chopped", true, true];
_tree setDamage 1;
[_tree, 180] call APS_fnc_setCleanTime;

// spawn the pile DIRECTLY (server-authoritative; bypasses the client-facing createItem, which now strips timber).
// Mirror fn_createItem's holder logic: merge into a nearby same-class pile, else a new inert (sim-disabled) suitcase.
private _dropPos = getPosASL _caller;
private _existing = objNull;
{ if (!((_x getVariable ["AP_droppedItems", []]) isEqualTo []) && {isNull (_x getVariable ["AP_inUse", objNull])}) exitWith { _existing = _x; }; } forEach (nearestObjects [ASLToAGL _dropPos, ["Land_Suitcase_F"], 6]);
if (!isNull _existing) then {private _cur = +(_existing getVariable ["AP_droppedItems", []]);
    private _i = _cur findIf { (_x select 0) isEqualTo _pile };
    if (_i >= 0) then { (_cur select _i) set [1, ((_cur select _i) select 1) + _pileSize]; } else { _cur pushBack [_pile, _pileSize]; };
    _existing setVariable ["AP_droppedItems", _cur, true];} else {
    private _holder = createVehicle ["Land_Suitcase_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _holder setPosASL _dropPos;
    _holder enableSimulationGlobal false;
    _holder allowDamage false;
    _holder setVariable ["AP_droppedItems", [[_pile, _pileSize]], true];
    _holder setVariable ["AP_inUse", nil, true];
    [_holder] spawn {params ["_h"]; private _s = time; private _end = time + 1800;
        waitUntil { uiSleep 30; isNull _h || time > _end || ((time - _s >= 1200) && ((_h getVariable ["AP_droppedItems", []]) isEqualTo []) && isNull (_h getVariable ["AP_inUse", objNull])) };
        if (!isNull _h) then { deleteVehicle _h; };};};
["-CHOPTREE-", _caller, format ["chopped %1 -> %2 x%3 (%4m)", _mdl, _pile, _pileSize, round _height]] call APS_fnc_logIt;
