/*
    Re-plumbed 2026-08-12 for the web deck: the item used to come only from dialog
    361000's listbox.

        [] spawn AP_fnc_useItem;                   // native, unchanged
        [controlNull, "proxychain"] spawn AP_fnc_useItem;   // deck

    The button comes first because the native handler is wired as
    `_this spawn AP_fnc_useItem` and ButtonClick passes [control, ...]. Taking
    the item first would hand a Control to a String param and log a type error on
    every native click.
*/
params [["_btn", controlNull], ["_itemIn", "", [""]]];
disableSerialization;
if (player getVariable["AP_restrained", false]) exitWith {};
private _item = if (_itemIn isNotEqualTo "") then { _itemIn } else {
    if ((lbCurSel 361001) isEqualTo -1) then { "" } else { lbData[361001, lbCurSel 361001] }
};
if (_item isEqualTo "") exitWith {["You need to select an item first!", "basic"] spawn AP_fnc_handleMessage};
switch (true) do {
    // owner 2026-07-20: cyberdeck consumables -- USE to ARM a one-shot effect on your next hack.
    case (_item isEqualTo "proxychain"): {
            if (player getVariable ["AP_proxyActive", false]) exitWith { ["Proxy Chain already active -- your next hack won't ping MaxSec.", "basic"] spawn AP_fnc_handleMessage; };
            if ([false, "proxychain", 1] call AP_fnc_handleInv) then {
                player setVariable ["AP_proxyActive", true, true];   // synced -> server-side hack alerts honour it
                ["action", "proxyarm", 1] spawn AP_fnc_handleQuest;   // quest hook: paying to be quiet
                ["proxyarm", [1]] call aq_fnc_event;   // ArmaQuest hook (Task 10): aq_fx2_breach
                ["<t color='#33ffbb'>PROXY CHAIN ACTIVE</t> -- your next hack leaves no trace for MaxSec.", "basic"] spawn AP_fnc_handleMessage;
            };};
    case (_item isEqualTo "breachkit"): {
            if (AP_breachKitArmed) exitWith { ["Breach Kit already armed -- your next breach auto-completes.", "basic"] spawn AP_fnc_handleMessage; };
            if ([false, "breachkit", 1] call AP_fnc_handleInv) then {AP_breachKitArmed = true;
                ["<t color='#c9e21a'>BREACH KIT ARMED</t> -- your next Sequence or Terminal breach auto-completes.", "basic"] spawn AP_fnc_handleMessage;
            };};
    // NEW DRACHMA: legacy loonycoin -> USE converts the WHOLE held stack straight to the wallet at
    // 1 coin = 1 ND (the intuitive path for coins pulled out of a house/trunk after the switch, which
    // the login sweep never saw). Server-authoritative credit; the item is consumed client-side first.
    case (_item isEqualTo "loonycoin"): {private _n = missionNamespace getVariable ["AP_inv_loonycoin", 0];
            if (_n < 1) exitWith { ["You have no New Drachma coins to convert.", "basic"] spawn AP_fnc_handleMessage; };
            if ([false, "loonycoin", _n] call AP_fnc_handleInv) then {[format ["%1", _n], "coinsell"] call AP_fnc_ndRequest;
                [format ["Converted %1 mined coin%2 to <t color='#5be39c'>%1 New Drachma</t>.", _n, ["s", ""] select (_n == 1)], "basic"] spawn AP_fnc_handleMessage;
            };};
    // drop-only chip: USE installs the Plate Ghost quickhack permanently (id 201 in AP_cdMods)
    case (_item isEqualTo "ghostplatechip"): {
            if (201 in (player getVariable ["AP_cdMods", []])) exitWith { ["Ghost Plate Chip already installed -- Plate Ghost is on your deck.", "basic"] spawn AP_fnc_handleMessage; };
            if !(call AP_fnc_hasDeck) exitWith { ["Chips only seat on ICEBREAKER, and ICEBREAKER is civilian-only.", "basic"] spawn AP_fnc_handleMessage; };
            if ([false, "ghostplatechip", 1] call AP_fnc_handleInv) then {
                ["action", "chipinstall", 1] spawn AP_fnc_handleQuest;   // quest hook: the firmware economy
                // ArmaQuest "chipinstall" is reported by the server once it seats the chip (serverFacts[]).
                [["installHack", 201, player], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;};};
    // drop-only Tier 4 chips + the ICE Firewall. Same shape as the Ghost Plate Chip: consume the item client
    // side, then the SERVER validates and writes the id into AP_cdMods (persisted). One table, one path.
    // Membership comes from AP_chipItemMap itself, NOT a second literal list (owner 2026-08-03). It used to
    // be a hardcoded array here while the body below read the map -- two lists that had to agree, and the
    // comment underneath already claimed the map was "the single source". They diverged the first time a chip
    // was added: detonatechip was registered in the map, the item config, the catalogue, the ring pool and the
    // loot table, but not here, so USE fell through to the default and reported "This item is not usable"
    // with nothing in any log. Deriving the gate from the map makes that failure impossible to repeat.
    // ghostplatechip is unaffected -- its dedicated case above matches first and still wins.
    case (_item in keys AP_chipItemMap): {
            // owner 2026-07-23: the chip->[id,label] map is now AP_chipItemMap (configuration.sqf), the single
            // source shared with the AP_itemDesc hover-text seed. Was an inline literal rebuilt on every USE.
            (AP_chipItemMap get _item) params ["_hackId", "_label"];
            // owner 2026-09-16: BIOWARE (AP_biowareIds) is a body implant, not deck software, so it skips the
            // civilian-only deck gate. Everything after this line -- duplicate refusal, consume, server install --
            // is the same path every other chip takes.
            if (!(_hackId in (missionNamespace getVariable ["AP_biowareIds", []])) && {!(call AP_fnc_hasDeck)}) exitWith { ["Chips only seat on ICEBREAKER, and ICEBREAKER is civilian-only.", "basic"] spawn AP_fnc_handleMessage; };
            // ICE Firewall re-arm cooldown (owner 2026-07-23): after one shatters, its firmware needs ~5 min
            // before it will seat another (AP_iceRearm set server-side on shatter). Blocks chain-replacing a
            // cheap consumable that hard-counters Tier-4-rarity hacks. Item stays in inventory to retry later.
            if (_hackId isEqualTo 108 && {serverTime < (player getVariable ["AP_iceRearm", 0])}) exitWith {
                private _secs = ceil ((player getVariable ["AP_iceRearm", 0]) - serverTime);
                [format ["ICE firmware still cooling down -- %1s before it can seat another firewall.", _secs], "basic"] spawn AP_fnc_handleMessage;
            };
            // ALL of these are permanent installs (owner 2026-07-22 -- Flatline/Puppet no longer burn per
            // cast), so a duplicate chip is refused and the item stays in inventory (trade it away).
            // (108 ICE Firewall is the exception -- a consumable that re-installs after it shatters.)
            if (_hackId isNotEqualTo 108 && {_hackId in (player getVariable ["AP_cdMods", []])}) exitWith {
                [format ["%1 is already installed on your deck.", _label], "basic"] spawn AP_fnc_handleMessage;};
            if ([false, _item, 1] call AP_fnc_handleInv) then {
                ["action", "chipinstall", 1] spawn AP_fnc_handleQuest;   // quest hook: the firmware economy
                // ArmaQuest "chipinstall" is reported by the server once it seats the chip (serverFacts[]).
                [["installHack", _hackId, player], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;};};
    case (_item isEqualTo ""): {
            ["Loot crate keys are used to open loot crates, which can get you awesome and rare rewards. You can find loot crates while exploring the world, but they can also be purchased from the market.", "basic"] spawn AP_fnc_handleMessage;
        };
    case ((_item isEqualTo "water") || (_item isEqualTo "coffee") || (_item isEqualTo "soda")): {
            if ([false, _item, 1] call AP_fnc_handleInv) then {APV_thirst = 100;
                if (AP_revive_fatigue isEqualTo 0) then {player setFatigue 0};
                [] call AP_fnc_hudUpdate;
                [_item, 1] call AP_fnc_statArrUpdate;};};
    case (_item in ["beer", "moonshine", "scotch_1", "scotch_2", "scotch_3", "rum_0", "rum_1", "rum_2", "rum_3"]): {
            [_item] spawn AP_fnc_drinkAlcohol;};
    case (_item in ["canna_bong", "canna_rig", "canna_joint", "canna_vape", "canna_papers"]): {[_item] spawn AP_fnc_cannabisItems;};
    case (_item in ["spraycan"]): {
        // DECK ROUTE: the stencil picker is a deck app (memo-utilities)
        if (missionNamespace getVariable ["AP_deckApps", true]) then {
            ["Sprays"] call AP_fnc_deckOpenApp;
        } else { ['sprayMenu'] call AP_fnc_createDialog; };
    };
    case (_item in ["marijuanam", "marijuana"]): {
            ["You must roll this into a joint or pack a bowl for a bong to smoke it!", "basic"] spawn AP_fnc_handleMessage;};
    case (_item isEqualTo "ducttape"): {
            ["You could craft a shank with this if you had something hard and sharp.", "basic"] spawn AP_fnc_handleMessage;};
    case (_item isEqualTo "campfire"): {[] spawn AP_fnc_campFire;};
    // phone-redux: removed the self-use "blindfold" case -- it called the undefined AP_fnc_blindfold (LB only has
    // AP_fnc_blindfoldClient, applied via the action menu on a RESTRAINED target, never self-used) and wrongly
    // consumed a blindfold first. The item now falls through to the default "not usable" path.
    // DEAD CASES, guarded rather than deleted (2026-08-24). The lootcrate items are not in
    // fn_virtItemCfg any more, so AP_inv_lootcrate<N> is never initialised, so every one of these
    // conditions raised "Undefined variable in expression: ap_inv_lootcrate1" -- on EVERY item Use,
    // because a switch evaluates conditions in order until one matches. AP_fnc_inspectLootCrate
    // does not exist anywhere in the tree either, so none of them could do anything if it did
    // match. Guarded reads make them harmlessly false instead of noisy, and leave the cases intact
    // in case the crates come back; whoever restores them owes the handler and the item rows.
    case ((_item in ["", "lootcrate1"]) && ((missionNamespace getVariable ["AP_inv_lootcrate1", 0]) > 0)): {[1] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate2"]) && ((missionNamespace getVariable ["AP_inv_lootcrate2", 0]) > 0)): {[2] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate3"]) && ((missionNamespace getVariable ["AP_inv_lootcrate3", 0]) > 0)): {[3] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate4"]) && ((missionNamespace getVariable ["AP_inv_lootcrate4", 0]) > 0)): {[4] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate5"]) && ((missionNamespace getVariable ["AP_inv_lootcrate5", 0]) > 0)): {[5] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate6"]) && ((missionNamespace getVariable ["AP_inv_lootcrate6", 0]) > 0)): {[6] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate7"]) && ((missionNamespace getVariable ["AP_inv_lootcrate7", 0]) > 0)): {[7] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate8"]) && ((missionNamespace getVariable ["AP_inv_lootcrate8", 0]) > 0)): {[8] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate9"]) && ((missionNamespace getVariable ["AP_inv_lootcrate9", 0]) > 0)): {[9] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate10"]) && ((missionNamespace getVariable ["AP_inv_lootcrate10", 0]) > 0)): {[10] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate11"]) && ((missionNamespace getVariable ["AP_inv_lootcrate11", 0]) > 0)): {[11] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate12"]) && ((missionNamespace getVariable ["AP_inv_lootcrate12", 0]) > 0)): {[12] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate13"]) && ((missionNamespace getVariable ["AP_inv_lootcrate13", 0]) > 0)): {[13] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate14"]) && ((missionNamespace getVariable ["AP_inv_lootcrate14", 0]) > 0)): {[14] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate15"]) && ((missionNamespace getVariable ["AP_inv_lootcrate15", 0]) > 0)): {[15] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate16"]) && ((missionNamespace getVariable ["AP_inv_lootcrate16", 0]) > 0)): {[16] call AP_fnc_inspectLootCrate};
    case ((_item in ["", "lootcrate17"]) && ((missionNamespace getVariable ["AP_inv_lootcrate17", 0]) > 0)): {[17] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_0" && {AP_lootKeys select 0 > 0}): {[1] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_1" && {AP_lootKeys select 1 > 0}): {[2] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_2" && {AP_lootKeys select 2 > 0}): {[3] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_3" && {AP_lootKeys select 3 > 0}): {[4] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_4" && {AP_lootKeys select 4 > 0}): {[5] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_5" && {AP_lootKeys select 5 > 0}): {[6] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_6" && {AP_lootKeys select 6 > 0}): {[7] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_7" && {AP_lootKeys select 7 > 0}): {[8] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_8" && {AP_lootKeys select 8 > 0}): {[9] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_9" && {AP_lootKeys select 9 > 0}): {[10] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_10" && {AP_lootKeys select 10 > 0}): {[11] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_11" && {AP_lootKeys select 11 > 0}): {[12] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_12" && {AP_lootKeys select 12 > 0}): {[13] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_13" && {AP_lootKeys select 13 > 0}): {[14] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_14" && {AP_lootKeys select 14 > 0}): {[15] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_15" && {AP_lootKeys select 15 > 0}): {[16] call AP_fnc_inspectLootCrate};
    case (_item isEqualTo "cratekey_16" && {AP_lootKeys select 16 > 0}): {[17] call AP_fnc_inspectLootCrate};
    case (_item in ["giftAdmin", "giftHallo", "giftXmas"]): {[_item] call AP_fnc_openGift;};
    case (_item in ["defib", "bloodbag"]): {
            titleText["This item is used via the action menu while looking at an injured person.", "PLAIN DOWN"]};
    case (_item isEqualTo "redgull"): {while {dialog}
            do {closeDialog 0};
            [] spawn AP_fnc_redgull;};
    case (_item isEqualTo "supermale"): {while {dialog} do {closeDialog 0};
            [] spawn AP_fnc_supermale;};
    case (_item isEqualTo "pparachute"): {[] spawn AP_fnc_pocketparachute;};
    case (_item isEqualTo "vammo"): {[] spawn AP_fnc_vehAmmo};
    case (_item isEqualTo "protest"): {[] spawn AP_fnc_protest};
    // owner 2026-07-10: RESTORED -- the phone-redux import (54a4411) overwrote this file and dropped the
    // furniture routing, so every furn_* item fell through to the default "This item is not usable".
    // Verbatim from the pre-redux file: civilian-only here; the owned-house/20m gates live in
    // fn_holdObject / fn_placeObject, and persistence in APS_fnc_houseFurnitureSRV.
    // 2026-08-22: schematic shards. The client asks; the SERVER picks which schematic, because a
    // schematic is a permanent unlock and letting the client choose is the exploit this whole feature
    // was designed away from. 2026-09-26: the shard is no longer consumed here -- APS_fnc_fabGrantSRV
    // removes it only once the decrypt succeeds, so a refusal leaves it where it is (no refund to farm).
    case (_item in ["shard", "shard_rare", "shard_epic"]): {
        if !(AP_effSide isEqualTo civilian) exitWith {
            ["Only civilians can decrypt data shards.", "basic"] spawn AP_fnc_handleMessage};
        if ((missionNamespace getVariable [format ["AP_inv_%1", _item], 0]) < 1) exitWith {};
        [["shard", [player, _item]], "APS_fnc_fabGrantSRV", 2] spawn AP_fnc_MP;
    };
    case (_item in AP_furnitureItems): {if !(AP_effSide isEqualTo civilian) exitWith {
                ["Only civilians can place house furniture.", "basic"] spawn AP_fnc_handleMessage};
            [_item] spawn AP_fnc_holdObject;};
    case (_item in ["roadBarrierSmall", "roadConelight", "roadCone", "roadBarrier", "cncBarrier", "cncBarrierL", "barGate", "bagwallshort", "bagwalllong", "bagwallround", "razorwire", "ied"]):
        {
            if ((AP_effSide isEqualTo independent) && (_item in ["roadBarrier", "roadBarrierSmall", "roadConelight", "roadCone"]) && !((call AP_medicLevel) >= 1)) exitWith {
                ["You must be AEMT+ to use this item!", "basic"] spawn AP_fnc_handleMessage;};
            [_item] spawn AP_fnc_holdObject;};
    case (_item isEqualTo "spikeStrip"): {if (([false, _item, 1] call AP_fnc_handleInv)) then {[] spawn AP_fnc_spikeStrip};};
    case (_item isEqualTo "excavator"): {[] spawn AP_fnc_searchWreck};
    case (_item isEqualTo "nitro"): {[cursorObject] spawn AP_fnc_nitro};
    case (_item isEqualTo "speedbomb"): {[] spawn AP_fnc_speedBomb;};
    case (_item isEqualTo "ignitionbomb"): {if (isNull objectParent player) then {
                ["You must be in the driver seat of a vehicle to use this."] spawn AP_fnc_handleMessage;} else {closeDialog 0;
                [vehicle player] spawn AP_fnc_ignitionBomb;};};
    case (_item in ["caralarm", "airalarm"]): {[cursorObject, _item] spawn AP_fnc_alarm};
    case (_item isEqualTo "manflesh"): {
            ["Human organs can't be eaten. Maybe if they were cooked on a fire?", "basic"] spawn AP_fnc_handleMessage};
    case (_item isEqualTo "fuelF"): {if !((vehicle player) isEqualTo player) exitWith {
                ["You can't refuel the vehicle while in it!", "basic"] spawn AP_fnc_handleMessage};
            [] spawn AP_fnc_jerryRefuel;};
    case (_item isEqualTo "adrenalineShot"): {[nil, nil, nil, player] spawn AP_fnc_adrenalineShot;};
    case (_item isEqualTo "boltCutter"): {if (cursorObject isKindOf "CAManBase") then {[cursorObject, true] spawn AP_fnc_lockpick;};};
    case (_item in ["manfleshp", "berry", "apple", "salema", "ornate", "mackerel", "tuna", "mullet", "catshark", "turtle", "turtlesoup", "donuts", "tbacon", "peach", "redburger", "chickenp", "dogp", "sheepp", "goatp", "rabbitp", "snakep", "kebab", "donerkebab", "pizza_cheese", "pizza_pepperoni", "pizza_hawaiian", "pizza_supreme"]):
        {[_item] call AP_fnc_eatFood};
    case (_item isEqualTo "tracker"): {[cursorObject] spawn AP_fnc_tracker};
    case (_item in ["smash", "smashbrick"]): {[] spawn AP_fnc_smash};
    case (_item in ["blacklace", "blacklaceprime"]): {[] spawn AP_fnc_blackLace};
    case (_item isEqualTo "glitter"): {[] spawn AP_fnc_glitter};
    case (_item in ["tent1", "tent2"]): {[_item] spawn AP_fnc_tent};
    case (_item isEqualTo "bank_money"): {if (AP_effSide isEqualTo west) then {
                ["This item must be seized via HQ/Vehicle", "basic"] spawn AP_fnc_handleMessage;} else {
                if ((serverTime - (AP_bank_robbed select 1)) < 400) exitWith {
                    ["The dye packs are still active, so you can't break the money bands yet.", "basic"] spawn AP_fnc_handleMessage;};
                AP_cash = AP_cash + AP_inv_bank_money;
                AP_ucashCacheC = ((AP_cash / 2) + 5);
                [format["You have broken down %1 banded bank money into cash.", [AP_inv_bank_money] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                ["bankmoneyconv", AP_inv_bank_money] call AP_fnc_statArrUpdate;
                AP_inv_bank_money = 0;};};
    case (_item isEqualTo "treasuremap"): {[] spawn AP_fnc_treasureMapOpen;};
    case (_item isEqualTo "medDrop"): {if !(AP_effSide isEqualTo independent) exitWith {
                ["This signal flare is for medics only!", "basic"] spawn AP_fnc_handleMessage;};
            if !((call AP_medicLevel) >= 3) exitWith {
                ["Your medic rank does not permit using this!", "basic"] spawn AP_fnc_handleMessage;};
            private _nearCrates = vehicles select {((typeOf _x) isEqualTo "C_IDAP_supplyCrate_F") && ((((_x getVariable["AP_vehOwners", [
                    ["", ""]]]) select 0) select 0) isEqualTo(getPlayerUID player))};
            if (count _nearCrates >= 1) exitWith {["You can only have one active supply crate!", "basic"] spawn AP_fnc_handleMessage;};
            if (SRV_lastMedSupply > serverTime - 900) exitWith {
                ["You can only call a supply crate every 15 minutes.", "basic"] spawn AP_fnc_handleMessage;};
            if !([false, "medDrop", 1] call AP_fnc_handleInv) exitWith {}; [[player], "APS_fnc_medSupplySpawn", 2] call AP_fnc_MP;};
    case (_item isEqualTo "painkillers"): {if ([false, _item, 1] call AP_fnc_handleInv) then { [player] spawn AP_fnc_painkillers; }};
    case (_item in ["ifrit", "ammo", "orca", "weapDrop", "hummingbird", "boxtruck", "qilin"]): {
            if !(AP_effSide isEqualTo civilian) exitWith {
                ["This care package can only be called in by civilians!", "basic"] spawn AP_fnc_handleMessage;};
            if ([800] call AP_fnc_nearTown) exitWith {
                ["You're too close to a town. The aircraft cannot be called here.", "basic"] spawn AP_fnc_handleMessage;};
            if !(isNull objectParent player) exitWith {
                ["You cannot request a care package while inside another vehicle.", "basic"] spawn AP_fnc_handleMessage;};
            if (player distance(getMarkerPos "casino_marker") < 350) exitWith {
                ["You're too close to the casino's restricted airspace.", "basic"] spawn AP_fnc_handleMessage;};
            if (surfaceIsWater(getPosATL player)) exitWith {
                ["You cannot request a care package in water.", "basic"] spawn AP_fnc_handleMessage;};
            if (player distance(getMarkerPos "courtroom") < 300) exitWith {["Really???", "basic"] spawn AP_fnc_handleMessage;};
            if (player distance(getMarkerPos "Respawn_west") < 1000) exitWith {["Really???", "basic"] spawn AP_fnc_handleMessage;};
            if ((count(nearestTerrainObjects[(getPosATL player), ["House"], 4, true, true])) > 0) exitWith {
                ["You're too close to a house. It could end up on the roof.", "basic"] spawn AP_fnc_handleMessage;};
            private _carePackageTalents = [["ifrit", 50], ["hummingbird", 48], ["orca", 49], ["boxtruck", 46], ["qilin", 47],
                ["weapDrop", -1], ["ammo", -1]];
            private _talentID = (_carePackageTalents select {_x select 0 isEqualTo _item}) param[0, [-1, -1]] select 1;
            if (_talentID > -1 && !((_talentID in AP_infamy_talents) || (_talentID in AP_honor_talents))) exitWith {
                ["You do not have the required prestige talent to call this care package.", "basic"] spawn AP_fnc_handleMessage;};
            if !([false, _item, 1] call AP_fnc_handleInv) exitWith {}; [
                [player, _item], "APS_fnc_rebelCarePackages", 2] call AP_fnc_MP;};
    case (_item in ["quad", "hatchback", "offroad", "hatchback2"]): {[_item] spawn AP_fnc_pocketCars};
    case (_item isEqualTo "distressBeacon"): {[] spawn AP_fnc_distressBeacon;};
    case (_item isEqualTo "cyberdeck"): {[cursorObject] spawn AP_fnc_cyberdeck};
    default {["This item is not usable", "basic"] spawn AP_fnc_handleMessage;};};

[] call AP_fnc_hudUpdate;
