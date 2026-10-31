params[["_inJail", false]];
waitUntil {!(isNull(findDisplay 46))};
private _itemArray = AP_gear;
private _handle = [] spawn AP_fnc_stripDownPlayer;
waitUntil {scriptDone _handle};
if (_itemArray isEqualTo[]) exitWith {switch (AP_effSide) do {case west: {[] call AP_fnc_copLoadout;};
        case civilian: {[] call AP_fnc_civLoadout;};
        case independent: {[] call AP_fnc_medicLoadout;};};};
_itemArray params[["_armaItems", []], ["_virtualInv", [], [[]]], ["_textures", [-1, -1]]];
player setUnitLoadout _armaItems;
if !((_virtualInv isEqualTo[]) && _inJail) then {if ((_virtualInv select 0) isEqualType[] && {!((_virtualInv select 0) isEqualTo[])
    }) then {
        // owner 2026-06-20 (#435 -- relog Y-inventory DUPE, COMPOUNDING): this restore is ADDITIVE (handleInv `true`
        // = add _amount). loadGear runs TWICE on a relog that lands on the spawn menu -- once in fn_requestReceived
        // (connect) and again in fn_spawnConfirm -- and fn_stripDownPlayer clears only PHYSICAL gear, never the
        // virtual AP_inv_* vars. So the 2nd pass added the saved Y-inv ON TOP of the 1st (FAK 7->14); saveGear then
        // baked it, so the next relog went 14->28... exponential. Zero the virtual inventory + carryWeight first (the
        // exact wipe fn_civLoadout uses) so the add-loop below always SETS the saved counts -> loadGear is idempotent
        // no matter how many times it runs in a session. Nothing legit is lost: the player is at the spawn-select menu
        // between connect and spawn-confirm (and through the redeploy countdown), so no items can be acquired in that
        // window, and AP_gear is the authoritative saved kit either way.
        AP_carryWeight = 0;
        { missionNamespace setVariable[_x, 0]; } forEach ([1] call AP_fnc_virtItemCfg); {_x params["_item", "_amount"];
            [true, _item, _amount] call AP_fnc_handleInv;}
        forEach(_virtualInv select 0);};};
AP_uniformBackpack_skins = _textures;
[_textures] spawn {params["_textures"];
    uiSleep 0.5;
    if !((_textures select 0) isEqualTo - 1) then {[uniform player, "setIdx", _textures select 0] call AP_fnc_clothingTextures;};
    if !((_textures select 1) isEqualTo - 1) then {[backpack player, "setIdx", _textures select 1] call AP_fnc_clothingTextures;};
    // owner 2026-06-25 (Northhhhh): invisible backpack reverted to VISIBLE after a soft log. loadGear's
    // setUnitLoadout rebuilds the pack as a fresh VISIBLE object; the setIdx re-skin above is skipped for the
    // invis bag (its skin index is -1). Re-hide here so EVERY rebuild (connect AND spawn-menu/soft-log) re-hides
    // it -- AP_invisBag is cleared in fn_buyClothes when a normal pack is bought, so normal packs stay visible.
    if ((profileNamespace getVariable ["AP_invisBag", false]) && {(backpack player) isNotEqualTo ""}) then {[true] call AP_fnc_invisBag;
    };};
if (_inJail) then {if !(weapons player isEqualTo []) then {removeAllWeapons player;};
    // owner 2026-06-19 (#401): the suicide vest is contraband -- confiscate it on jail release. jailMe strips it
    // on ENTRY, but setUnitLoadout above re-applied the full saved loadout (incl. V_HarnessOGL_brn), so players
    // "kept their sui vest after being sent to jail". Weapons were already stripped here; the vest was not.
    if ((vest player) isEqualTo "V_HarnessOGL_brn") then {removeVest player;};};