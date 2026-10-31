/*
    AP_fnc_adminGearReceive (LooneyBin, NC_PHONE branch) -- runs ON THE TARGET client: receives an admin
    give from the staff menu (weapon / mag / item / clothing) and applies it locally with plain engine
    commands. Exists because CfgRemoteExec mode=1 (rightly) drops raw remoteExec of engine commands --
    grants must travel as a whitelisted function (CfgRE.hpp entry) via AP_fnc_MP.
    Sender identity is resolved from remoteExecutedOwner and LOGGED with every receipt (fn_MP call-audit +
    -ADMINSPAWN- server log carry the rest). Deep sender-privilege validation is part of the deferred
    public-launch CfgRE hardening pass (security.md).
    _this = [_kind, _class, _count]
      _kind: "weapon" | "mag" | "item" | "uniform" | "vest" | "headgear" | "goggles" | "backpack"
*/
params [["_kind", "", [""]], ["_class", "", [""]], ["_count", 1, [0]]];
if (!hasInterface || _class isEqualTo "" || _kind isEqualTo "") exitWith {};
// the class must actually exist in the matching config -- refuse junk
private _root = switch (_kind) do {case "mag": { "CfgMagazines" };
    case "goggles": { "CfgGlasses" };
    case "backpack": { "CfgVehicles" };
    default { "CfgWeapons" };};
if (!isClass (configFile >> _root >> _class)) exitWith {};
private _sender = objNull;
if (isRemoteExecuted) then {_sender = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];};
diag_log format ["[LooneyBin][adminGear] %1 received %2x %3 (%4) from %5", profileName, _count, _class, _kind, if (isNull _sender) then { "local/self" } else { name _sender }];

switch (_kind) do {case "weapon":   { player addWeapon _class; };
    case "mag":      { for "_i" from 1 to (_count max 1) do { player addMagazine _class; }; };
    case "item":     { for "_i" from 1 to (_count max 1) do { player addItem _class; }; };
    case "uniform":  { player forceAddUniform _class; };
    case "vest":     { player addVest _class; };
    case "headgear": { player addHeadgear _class; };
    case "goggles":  { player addGoggles _class; };
    case "backpack": { player addBackpack _class; };};
