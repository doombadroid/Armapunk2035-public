params[["_loadout", [], [[]]]];
_loadout params["_primary", "_launcher", "_handgun", "_magazines", "_uniform", "_vest", "_backpack", "_items", "_primitems", "_secitems", "_handgunitems", "_uitems", "_vitems", "_bitems", "_headgear", "_goggles"];
RemoveAllWeapons player; {player removeMagazine _x;}
forEach(magazines player);
removeUniform player;
removeVest player;
removeBackpack player;
removeGoggles player;
removeHeadGear player; {player unassignItem _x;
    player removeItem _x;}
forEach(assignedItems player);
private "_handle";
if (_uniform != "") then {_handle = [_uniform, true, false, false, false] spawn AP_fnc_handleItem;
    waitUntil {scriptDone _handle};};
if (_vest != "") then {_handle = [_vest, true, false, false, false] spawn AP_fnc_handleItem;
    waitUntil {scriptDone _handle};};
if (_backpack != "") then {
    // LooneyBin 2026-06-11: the backpack disappeared on revive -- routing the CONTAINER through
    // handleItem relied on fetchCfgDetails returning "CfgVehicles" and silently no-op'd when it
    // didn't. Add the backpack directly (bulletproof); _bitems below refill it.
    removeBackpack player;
    player addBackpack _backpack;
    clearAllItemsFromBackpack player;}; {_handle = [_x, true, false, false, false] spawn AP_fnc_handleItem;
    waitUntil {scriptDone _handle};}
forEach _items;
if (_headgear != "") then {player addHeadGear _headgear};
if (_goggles != "") then {player addGoggles _goggles};
// LooneyBin 2026-06-10: the weapon adds were SPAWNED without waiting, then the attachment loops ran
// immediately -> addWeaponItem on a not-yet-added weapon silently drops the attachment = suppressors/
// optics vanished on death->revive. Await each weapon before its attachments apply.
if (_primary != "") then {_handle = [_primary, true, false, false, false] spawn AP_fnc_handleItem;
    waitUntil { scriptDone _handle };};
if (_launcher != "") then {_handle = [_launcher, true, false, false, false] spawn AP_fnc_handleItem;
    waitUntil { scriptDone _handle };};
if (_handgun != "") then {_handle = [_handgun, true, false, false, false] spawn AP_fnc_handleItem;
    waitUntil { scriptDone _handle };}; {_handle = [_x, true, false, true, false] spawn AP_fnc_handleItem;
    waitUntil {scriptDone _handle};}
forEach _primitems; {_handle = [_x, true, false, true, false] spawn AP_fnc_handleItem;
    waitUntil {scriptDone _handle};}
forEach _secitems; {_handle = [_x, true, false, true, false] spawn AP_fnc_handleItem;
    waitUntil {scriptDone _handle};}
forEach _handgunitems; {_handle = [_x, true, false, false, false] spawn AP_fnc_handleItem;
    waitUntil {scriptDone _handle};}
forEach _magazines; {[_x, true, false, false, true] call AP_fnc_handleItem;}
forEach(_uitems); {[_x, true, false, false, true] call AP_fnc_handleItem;}
forEach(_vitems); {[_x, true, true, false, false] call AP_fnc_handleItem;}
forEach(_bitems);
private _TracerMag = {if (("tracer"find _x) != -1) exitWith {_x};""}
forEach magazines player;
if (!isNil "_TracerMag" && {_TracerMag != ""} && {(("tracer"find currentMagazine player) isEqualTo - 1)}) then {
    player removeMagazine _TracerMag;
    player addMagazine currentMagazine player;
    player addPrimaryWeaponItem _TracerMag;};
// owner 2026-06-19 (#382): the weapons are added ABOVE before the magazines, so each gun got NO magazine
// auto-loaded -> the player revived with EMPTY guns (mags sat loose in inventory). Load one compatible
// inventory mag into any still-empty weapon; removeMagazine first so the mag MOVES into the gun (no dupe).
{_x params ["_wpn", "_loadedMag"];
    if (_wpn != "" && {_loadedMag isEqualTo []}) then {private _compat = getArray (configFile >> "CfgWeapons" >> _wpn >> "magazines");
        private _mag = (magazines player) param [(magazines player) findIf { _x in _compat }, ""];
        if (_mag != "") then {if (_wpn isEqualTo (secondaryWeapon player)) then {
                // owner 2026-06-25 (Northhhhh: revive loses a loaded rocket): a LAUNCHER won't chamber via addWeaponItem.
                // Load with the launcher idiom FIRST, then pull the now-duplicate mag from inventory ONLY if it loaded --
                // so a failed load leaves the rocket in inventory instead of deleting it (the old removeMagazine-then-fail path).
                player addSecondaryWeaponItem _mag;
                if ((secondaryWeaponMagazine player) isNotEqualTo []) then { player removeMagazine _mag; };} else {
                player removeMagazine _mag;
                player addWeaponItem [_wpn, _mag, true];};};};} forEach [[primaryWeapon player, primaryWeaponMagazine player],
    [handgunWeapon player, handgunMagazine player], [secondaryWeapon player, secondaryWeaponMagazine player]];
[] spawn {uiSleep 0.5;
    if !(backpack player isEqualTo "") then {[backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;};
    if !(uniform player isEqualTo "") then {[uniform player, "setUniform", ""] call AP_fnc_clothingTextures;};};
[false] call AP_fnc_saveGear;