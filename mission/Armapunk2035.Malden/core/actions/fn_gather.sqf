if !(isNull objectParent player) exitWith {};
if (isNil "AP_action_gathering") then {AP_action_gathering = false;};
if (AP_action_gathering) exitWith {};
// 2026-07-26: opium, cannabis, oysters and prison metal were cut from the game entirely, so their
// zones are gone from this list rather than merely unplaced -- there is nothing left for them to give.
private _resourceZones = ["apple_1", "apple_2", "apple_4", "apple_5", "peaches_2", "peaches_3", "peaches_4", "illegal_marker_2_0", "illegal_marker_3_0", "illegal_marker_8_0", "rock_1", "rock_2", "rock_3", "oil_1", "oil_2", "oil_3", "mine_1", "mine_2", "mine_3", "mine_4", "mine_5", "mine_6", "salt_1", "tobacco_1", "fentanyl_1", "vineyard_1"];
// The list is a SUPERSET on purpose -- it names every field the code can gather, on any map, and the
// markers decide which of them this map actually has (Malden's are created in initServer.sqf). A name
// with no marker reads as [0,0,0], so without the markerType test every unplaced field stacked up in
// the map's SW corner and could be harvested there, all of them, from one spot.
private _nearbyZones = _resourceZones select {markerType _x isNotEqualTo "" && {player distance2D(getMarkerPos _x) <= 150}};
private _zone = _nearbyZones param[(_nearbyZones apply {player distance2D(getMarkerPos _x)}) findIf {
    _x isEqualTo(selectMin(_nearbyZones apply {player distance2D(getMarkerPos _x)}))}, ""];
if (_zone isEqualTo "") exitWith {};
(switch (true) do {
    case (_zone isEqualTo "illegal_marker_2_0"): {["smashpowder", 150];};
    case (_zone isEqualTo "illegal_marker_3_0"): {["sparkdust", 150];};
    // Malden fields the designer marked (initServer.sqf pins the markers). Raw ends only for now --
    // what they turn INTO arrives with the processor pass.
    case (_zone isEqualTo "tobacco_1"): {["tobaccou", 150];};
    case (_zone isEqualTo "fentanyl_1"): {["boost", 150];};
    case (_zone isEqualTo "vineyard_1"): {["grapes", 100];};
    case (_zone find "mine" != -1): {[["diamondf", "diamond", "ironore", "copperore", "sand"], 70];};
    case (_zone find "rock" != -1): {["redshift", 150];};
    case (_zone find "oil" != -1 && AP_inv_pickaxe >= 1 && !((player nearEntities["Car", 15] select {
        typeOf _x in ["B_Truck_01_fuel_F", "C_Truck_02_fuel_F", "C_Van_01_fuel_F"]}) isEqualTo[])): {["oilu", 150];};
    case (_zone find "oil" != -1): {["toxicslurry", 150];};
    case (_zone find "salt" != -1): {["salt", 150];};
    case (_zone find "apple" != -1): {["apple", 50];};
    case (_zone find "peaches" != -1): {["peach", 50];};
    default {""};}) params["_item", "_distance"];
if (player distance2D(getMarkerPos _zone) > _distance) exitWith {};
if ("mine" in _zone) exitWith {[_zone, _distance] call AP_fnc_mine;};
titleText["Gathering...", "PLAIN"];
AP_action_gathering = true;
AP_action_in_use = true;
private _startPos = getPos player;
private _nBuilding = nearestBuilding player;
// 2026-07-26: opium and the cannabis field are gone. Boost takes opium's place in both bonus lists
// -- it is the hard drug the turf and the gang perk were written for, and it is the one being gathered.
private _rodoDrugs = ["smashpowder", "boost"];
private _gangDrugs = ["smashpowder", "boost"];
private _giveExtraGangTalent8 = (_item in _gangDrugs && 8 in AP_gang_talents);
private _giveExtraGangTalent9 = (_item in ["sparkdust"] && 9 in AP_gang_talents);
private _totalGathered = 0;
private _exit = false;
private _delay = 4;
// infamy 20 was the opium speed perk; it now buys the same 0.4 s on boost. Infamy 19 (cannabis)
// has nothing left to speed up -- the perk still exists, it simply has no field to apply to.
if (_item isEqualTo "boost" && {20 in AP_infamy_talents && license_civ_rebel}) then {_delay = _delay - 0.4;};
if (_item isEqualTo "smashpowder" && {21 in AP_infamy_talents && license_civ_rebel}) then {_delay = _delay - 0.4;};
if (_item in ["sparkdust"] && {22 in AP_infamy_talents && license_civ_rebel}) then {_delay = _delay - 0.04;};
for "_i"
from 0 to 1 step 0 do {
    if (_exit || (player distance2D _startPos) > 2 || (player distance2D(getMarkerPos _zone) > _distance) || !(isNull objectParent player)) exitWith {};
    if (player distance2D _nBuilding <= 10) exitWith {   // the plateMetal exemption died with prison metal
        ["You can't gather items so close to a building.", "basic"] spawn AP_fnc_handleMessage;};
    if !(AP_action_in_use) exitWith {};
    uiSleep _delay;
    private _count =
    switch (true) do {
        case (_item in _rodoDrugs && (AP_gang_data param[0, -1337] isEqualTo(rodo_flag getVariable["AP_turf_data", []] select 0))): {
                selectRandom[1, 2]};
        default {1};}; private _amount =
    if (random 4 < 1 && (_giveExtraGangTalent8 || _giveExtraGangTalent9)) then {_count + 1} else {_count};
    // BUMPER CROP (222): +1 unit on every field harvest.
    if (222 in AP_side_talents) then { _amount = _amount + 1; };
    // 2026-07-26: the oyster beds carried the rare treasure-map and pearl rolls. Oysters and pearls are
    // gone; treasure maps still drop from wrecks, quarries and the metal detector, so that hunt survives.
    if ([true, _item, _amount] call AP_fnc_handleInv) then {
        titleText[format["Gathered %1 %2. %3/%4", _amount, ["getName", _item] call AP_fnc_virtItemCfg, AP_carryWeight, AP_maxWeight], "PLAIN"];
        AP_side_exp = AP_side_exp + 1;
        _totalGathered = _totalGathered + _amount;
        [_item, _amount] call AP_fnc_statArrUpdate;
        // 3D printer schematic drop. The client only REPORTS that a gather completed -- which
        // schematic (if any) comes out is rolled server-side, because a schematic is a permanent
        // unlock and a client-side roll is a mint. APS_fnc_fabGrantSRV throttles per UID.
        [["roll", [player, "gather", ""]], "APS_fnc_fabGrantSRV", 2] spawn AP_fnc_MP;
        ["collect", _item, _amount] call AP_fnc_handleQuest;   // owner 2026-07-11: generic gather event (Parole Papers + future collect quests)
    } else {_exit = true;};}; if (_exit) then {
    titleText[format["Gathering done. You can't hold more %1.", ["getName", _item] call AP_fnc_virtItemCfg], "PLAIN", 0.3];
    playSound "ziptie";
    playSound "ziptie";
    playSound "ziptie";} else {titleText["Gathering cancelled.", "PLAIN"];};
AP_action_gathering = false;
AP_action_in_use = false; [
    ["-GATHER-", player, profileName, format["gathered %1 %2 at position %3.", _totalGathered, ["getName", _item] call AP_fnc_virtItemCfg, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;