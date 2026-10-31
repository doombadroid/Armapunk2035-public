/*
    APS_fnc_evidenceTruck  (LooneyBin -- implemented from stub 2026-06-09)
    Client (core/actions/fn_evidenceVaultOpen.sqf) calls [_groupMems] ([[uid,name],..]) after the vault
    demo pops. Spawns the evidence loot TRUCK near the vault with the seized pool in its trunk
    (AP_Trunk = [[items], weight]) -- the robbers' getaway prize. Keys to the breaching group.
*/
params [["_groupMems", [], [[]]]];
// owner 2026-06-23 SECURITY (security.md §2.2): caller = fn_evidenceVaultOpen (the civ crew that just breached
// the lockup). Ungated, ANY client could remoteExec [[[myUID,myName]]] at any time to dump the entire seized
// SRV_evidencePool into a getaway truck for themselves -- instant theft of all contraband cops ever seized,
// no breach required. Gate server-side on the SAME breach state the client checks (defenses DOWN + evidence on
// site) AND require the real caller (remoteExecutedOwner, non-spoofable) to be one of the breaching _groupMems.
// Server-internal passes.
// 2026-09-26: that refusal was an exitWith INSIDE the then-block, which only left the block -- every
// blocked call still fell through to the spawn and the pool wipe. The verdict is now _ok, raised by a
// flat exitWith. The crew is rebuilt from the caller's own group (the payload named it, so "caller is in
// the crew" was self-satisfying), and the caller must be at the dome after the server's own fuse opened
// it (AP_evidenceOpen, set by APS_fnc_handleTimer case 2) -- not merely past the fence hack.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _ok = true;
if (_src isNotEqualTo 0) then {
    _groupMems = (units group _caller) apply { [getPlayerUID _x, name _x] };   // same shape fn_evidenceVaultOpen sends
    private _evi = missionNamespace getVariable ["SRV_evidence_status", [false, true]];
    private _breachLive = (_evi param [0, false]) && {!(_evi param [1, true])};   // hasEvidence && defensesDown
    private _dome = nearestObject [[20898.6, 19221.7, 0], "Land_Dome_Big_F"];
    private _domeOpen = _dome getVariable ["AP_evidenceOpen", false];
    private _near = !isNull _caller && {!isNull _dome} && {(_caller distance _dome) < 100};   // the breach action needs < 12 m
    _ok = _near && _breachLive && _domeOpen;
    if (!_ok) then { ["-SEC-", _caller, format ["BLOCKED evidenceTruck by %1 (breachLive=%2 domeOpen=%3 near=%4)", getPlayerUID _caller, _breachLive, _domeOpen, _near]] call APS_fnc_logIt; };
};
if (!_ok) exitWith {};
if (isNil "SRV_evidencePool") then { SRV_evidencePool = []; };
if (isNil "SRV_evidenceWeps") then { SRV_evidenceWeps = []; };

private _pos = getMarkerPos "armory_vault";
if (_pos isEqualTo [0,0,0]) then { _pos = [20898.6, 19221.7, 0]; };
private _spawnPos = [_pos, 12, 30, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
private _truck = "I_Truck_02_transport_F" createVehicle _spawnPos;
_truck setDir (random 360);
_truck setVariable ["AP_side", "civ", true];
_truck setVariable ["AP_vehOwners", _groupMems, true];
_truck setVariable ["owner", (_groupMems param [0, ["",""]]) select 0, true];   // cleanup-sweep spare

// trunk: the seized virtual pool (+ a floor reward so an empty pool still pays something)
private _items = +SRV_evidencePool;
if (_items isEqualTo []) then { _items = [["goldbar", 3]]; };
private _weight = 0;
{ _weight = _weight + (_x select 1); } forEach _items;
_truck setVariable ["AP_Trunk", [_items, _weight], true];
// physical weapons land in the truck's real cargo
clearWeaponCargoGlobal _truck; clearItemCargoGlobal _truck; clearMagazineCargoGlobal _truck;
{ _truck addWeaponCargoGlobal [_x, 1]; } forEach SRV_evidenceWeps;

// pool is paid out -> empty it + disarm the event until cops seize more
SRV_evidencePool = [];
SRV_evidenceWeps = [];
if (!isNil "SRV_evidence_status") then { SRV_evidence_status set [0, false]; publicVariable "SRV_evidence_status"; };
diag_log format ["[LooneyBin][evidence] truck spawned at %1 for %2 (loot %3)", _spawnPos, _groupMems, _items];
