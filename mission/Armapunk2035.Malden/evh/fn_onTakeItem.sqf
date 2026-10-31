params[["_unit", objNull, [objNull]], ["_container", objNull, [objNull]], ["_item", "", [""]]];
if (isNull _unit || _item isEqualTo "") exitWith {};
// owner 2026-06-30: TT can now pick up weapons -- dropped the `playerSide isEqualTo independent` term from this gate.
// (That quotes the code as it stood in June, before the playerSide -> AP_effSide sweep; the sweep rewrote the
// quotation along with the live reads, which made the note describe a line that never existed.)
// Passive-mode JIP players are still force-dropped weapons. (Restores the if-head that was removed, which had left a
// dangling `}) exitWith {` -- a syntax error that broke the whole take-item handler.)
if (AP_passiveModeJIP && {isClass(configFile >> "CfgWeapons" >> _item)}) exitWith {
    private _type = getNumber(configFile >> "CfgWeapons" >> _item >> "type");
    switch (_type) do {case 1: {[6, _item] call AP_fnc_forceDropItem};
        case 2: {[8, _item] call AP_fnc_forceDropItem};
        case 4: {[7, _item] call AP_fnc_forceDropItem};}; if (AP_passiveModeJIP) then {
        ["You cannot pick up a gun while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;};
};
if (_container isKindOf "CAManBase" && !(alive _container)) exitWith {[_item, false, false, false, false] call AP_fnc_handleItem;};
if ((local _container) && (netid _container == "0:0") && !(_container getVariable["AP_questloot", false])) exitWith {
    ["You can't pickup decorations... sorry.", "basic"] spawn AP_fnc_handleMessage;}; [
    ["-TOOKITEM-", player, profileName, format["Took %1 from %2 :: %3. Position: %4", _item, typeOf _container, [getWeaponCargo _container, getItemCargo _container, getBackpackCargo _container, getMagazineCargo _container] select {
        _x isNotEqualTo[[], []]}, getPosATL player]], "APS_fnc_logIt", false] call AP_fnc_MP;
switch (_item) do {
    // LooneyBin (owner, 2026-06-10): pilot coveralls / heli-helmet wear restrictions removed --
    // any clothing combination is allowed. (Gov uniform + medic-side vest gates kept: role items.)
        case "V_PlateCarrierGL_blk": {
                // LooneyBin: was a blanket medic-rank gate that stripped this vest off ANY side --
                // now sold to Captain+ cops (Level V) and combos are owner-allowed; gate medics only.
                if (AP_effSide isEqualTo independent && {call AP_medicLevel < 6}) then {[1, _item] call AP_fnc_forceDropItem;};};

        case "U_NikosAgedBody": {if !((getPlayerUID player) isEqualTo(SRV_governorData param[0, "GovUID"])) then {
                    [3, _item] call AP_fnc_forceDropItem;};};

        case "SMG_03C_TR_black": {if (call AP_copLevel <= 2 && AP_effSide isEqualTo west) then {[6, _item] call AP_fnc_forceDropItem;};
            };
        case "SMG_03_TR_black": {if (call AP_copLevel <= 2 && AP_effSide isEqualTo west) then {[6, _item] call AP_fnc_forceDropItem;};
            };}; if (("UAV" in _item) && !(AP_effSide in [west, independent])) then {[2, _item] call AP_fnc_forceDropItem;};
private _isPack = getNumber(configFile >> "CfgVehicles" >> _item >> "isBackpack");
private _itemType = getNumber(configFile >> "CfgWeapons" >> _item >> "ItemInfo" >> "type");
if (_isPack isEqualTo 1) exitWith {[] spawn {AP_action_in_use = true;
        uiSleep 1.5; {
            if (isPlayer _x && _x != player && (backpack player != "") && ((backpackContainer _x) == (backpackContainer player))) exitWith {
                uiSleep 0.5;
                removeBackpack player;
                ["The item you just picked up appears to have been duped. We've removed it and logged it. If you feel you have gotten this in error please make a compensation ticket on our forums with evidence.", "basic"] spawn AP_fnc_handleMessage;
                [
                    ["-GEAREXPLOIT-", player, profileName, format["-- CAUGHT EXPLOITING (backpacks) -- Exploited with (%1) %2, tried to dupe backpacks", getPlayerUID _x, name _x]], "APS_fnc_logIt", false] call AP_fnc_MP;
            };}
        forEach(player nearEntities["Man", 15]);
        if !(backpack player isEqualTo "") then {[backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;};
        [false] call AP_fnc_saveGear;
        [3] call AP_fnc_ClupdatePartial;
        AP_action_in_use = false;};};
if (_itemType isEqualTo 701) exitWith {[] spawn {AP_action_in_use = true;
        uiSleep 1.5; {if (isPlayer _x && _x != player && (vest player != "") && ((vestContainer _x) == (vestContainer player))) exitWith {
                uiSleep 0.5;
                removeVest player;
                ["The item you just picked up appears to have been duped. We've removed it and logged it. If you feel you have gotten this in error please make a compensation ticket on our forums with evidence.", "basic"] spawn AP_fnc_handleMessage;
                [
                    ["-GEAREXPLOIT-", player, profileName, format["-- CAUGHT EXPLOITING (vests) -- Exploited with (%1) %2, tried to dupe vests", getPlayerUID _x, name _x]], "APS_fnc_logIt", false] call AP_fnc_MP;
            };}
        forEach(player nearEntities["Man", 15]);
        [false] call AP_fnc_saveGear;
        [3] call AP_fnc_ClupdatePartial;
        AP_action_in_use = false;};};
if (_itemType isEqualTo 801) exitWith {[] spawn {AP_action_in_use = true;
        uiSleep 1.5; {
            if (isPlayer _x && _x != player && (uniform player != "") && ((uniformContainer _x) == (uniformContainer player))) exitWith {
                uiSleep 0.5;
                removeUniform player;
                ["The item you just picked up appears to have been duped. We've removed it and logged it. If you feel you have gotten this in error please make a compensation ticket on our forums with evidence.", "basic"] spawn AP_fnc_handleMessage;
                [
                    ["-GEAREXPLOIT-", player, profileName, format["-- CAUGHT EXPLOITING (uniforms) -- Exploited with (%1) %2, tried to dupe uniforms", getPlayerUID _x, name _x]], "APS_fnc_logIt", false] call AP_fnc_MP;
            };}
        forEach(player nearEntities["Man", 15]);
        if !(uniform player isEqualTo "") then {[uniform player, "setUniform", ""] call AP_fnc_clothingTextures;};
        [false] call AP_fnc_saveGear;
        [3] call AP_fnc_ClupdatePartial;
        AP_action_in_use = false;};};
[false] call AP_fnc_saveGear;
[] spawn {uiSleep 5;
    [3] call AP_fnc_ClupdatePartial;};
