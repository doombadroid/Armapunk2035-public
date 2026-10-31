if (isNull AP_placing) exitWith {};
// The item comes from the preview object (set by fn_holdObject), not from its class: the three fabricator
// items share one stand-in class and a class lookup returned the first of them, so a bench was confirmed
// as a printer_i3 the player did not own and the placement was dropped (2026-09-03).
private _item = AP_placing getVariable ["AP_placeItem", ""];
private _index = if (_item isNotEqualTo "") then { [_item, AP_placeable] call AP_fnc_index } else { [typeOf AP_placing, AP_placeable] call AP_fnc_index };
if (_index isEqualTo - 1) exitWith {};
if (_item isEqualTo "") then { _item = (AP_placeable select _index) select 0; };
if (AP_effSide isEqualTo west && ((player distance(getMarkerPos "armory_marker")) < 200)) exitWith {
    ["You cannot place checkpoint materials inside of the Evidence Lockup!", "basic"] spawn AP_fnc_handleMessage};
if (AP_effSide isEqualTo west && ({player distance getMarkerPos format["police_hq_%1", _x] < 75}
count[1, 2, 3, 4, 5, 6, 7] > 0)) exitWith {
    ["You cannot place checkpoint materials inside of Police HQ's!", "basic"] spawn AP_fnc_handleMessage};
if (AP_effSide isEqualTo west && ({player distance getMarkerPos format["police_hq_%1", _x] < 125}
count[5] > 0)) exitWith {["You cannot place checkpoint materials inside of Police HQ's!", "basic"] spawn AP_fnc_handleMessage};
// Luxe Suites: a leased floor counts as a home for furniture, but the tower is a
// SIMPLE OBJECT and so is invisible to nearestObjects ["House_F"] -- the house
// test below can never pass up there, which is why suites need their own
// locator rather than an adjustment to that test. The house path is left exactly
// as it was: this only adds a bypass.
private _suite = [player] call AP_fnc_suiteAt;
private _suiteMine = (_suite isNotEqualTo []) && {[_suite param [0, objNull], _suite param [1, -1]] call AP_fnc_suiteMine};
if ((_item in AP_furnitureItems) && {(_suite isNotEqualTo []) && {!_suiteMine}}) exitWith {
    ["You can only furnish a suite you lease.", "basic"] spawn AP_fnc_handleMessage};
// LooneyBin furniture: must be at YOUR house (20m), exempt from the cartel-radius rule below
if ((_item in AP_furnitureItems) && {!_suiteMine} && {((nearestObjects [player, ["House_F"], 20]) findIf { _x in AP_vehicles }) isEqualTo -1}) exitWith {
    ["Furniture can only be placed within 20m of a house you own.", "basic"] spawn AP_fnc_handleMessage};
if ((AP_effSide isEqualTo civilian) && (_item isNotEqualTo "boombox") && !(_item in AP_furnitureItems) && (({player distance _x < 300}
count[arms_flag, drug_flag, wongs_flag, oil_flag]) isEqualTo 0)) exitWith {
    ["You can only place this object within 300m of a capture area (cartel).", "basic"] spawn AP_fnc_handleMessage};
if !([false, _item, 1] call AP_fnc_handleInv) exitWith {
    diag_log format ["[AP-PROBE] placeObject: %1 not consumed from the inventory (have %2) -- placement dropped", _item, missionNamespace getVariable ["AP_inv_" + _item, -1]];
    deleteVehicle AP_placing;
    AP_placing = objNull;};
// LooneyBin 2026-06-11: furniture keeps the exact height it was placed at (indoors / on an elevated
// floor) -- the old z=0 dropped it onto the TERRAIN, i.e. under the house floor ("vanished"). Cones/
// barriers still snap to the ground (z=0) as before.
private _furnPlacePos = getPosASL AP_placing;
detach AP_placing;
if (_item in AP_furnitureItems) then {AP_placing setPosASL _furnPlacePos;} else {
    AP_placing setPos[(getPos AP_placing select 0), (getPos AP_placing select 1), 0];};
AP_placing setVariable["AP_owner", player, true];
AP_placing setVariable["AP_ownerID", getPlayerUID player, true];
AP_placing setVariable["AP_placedItem", true, true];
AP_placing removeEventHandler["HandleDamage", 0];
if !((AP_placeable select _index) select 5) then {AP_placing allowDamage false;};
if (typeOf AP_placing isEqualTo "Land_BatteryPack_01_closed_black_F") then {["initBoomBox", [AP_placing]] spawn AP_fnc_boomBox;};
// LooneyBin furniture: persist into the house's DB row (server enforces the 15-per-house cap and
// deletes + refunds if over). Sim off = zero server physics cost.
if (_item in AP_furnitureItems) then {AP_placing enableSimulationGlobal false;
    AP_placing setVariable ["AP_furniture", true, true];   // exempt from the server cleanup sweep (fn_cleanup)
    // owner 2026-07-10: ["House"] not ["House_F"] -- industrial sheds aren't reliably House_F (receiveHouses
    // lesson); "House" covers sheds + every normal home.
    // SUITE placement: hand off to the suite authority and stop. Same
    // server-spawn handoff as houses (client sends class/pos/dir and deletes its
    // preview, the server spawns the one authoritative copy -- the ladder-dupe
    // fix), but keyed on the suite oid rather than a houseID, and the server
    // re-derives the floor from our real position rather than trusting this call.
    // Position travels ASL: the tower stands on ~171 m terrain and its floors are
    // 100 m up, so ATL/AGL would be meaningless here.
    if (_suiteMine) exitWith {
        [["add", _suite param [2, ""], [typeOf AP_placing, getPosASL AP_placing, getDir AP_placing]],
            "APS_fnc_suiteFurnitureSRV", 2] spawn AP_fnc_MP;
        deleteVehicle AP_placing;
        AP_placing = objNull;
    };
    private _houses = nearestObjects [player, ["House"], 20];
    // BUGS #151: was `_x in AP_vehicles` (the VEHICLE array -- never contains houses) -> _house always
    // objNull -> the "add" was never sent -> no furniture ever persisted. Match the house YOU own.
    private _house = _houses param [_houses findIf { (_x getVariable ["AP_homeOwner", ""]) isEqualTo getPlayerUID player }, objNull];
    if (!isNull _house) then {
        // owner 2026-07-10: SERVER-SPAWN HANDOFF. The client used to keep ITS createVehicle'd object as the
        // live piece and ship the object REF to the server for tracking -- but the ref regularly arrived
        // objNull (sent the same frame the object was created), so the server's spawned-list missed it:
        // "Show Furniture" then saw nothing out and spawned a SECOND copy while "Hide" only deleted the
        // tracked one -> +1 piece per hide/show cycle, infinitely (the ladder dupe). Now the client sends
        // ONLY class/pos/dir and deletes its preview; the SERVER spawns the one authoritative copy and
        // tracks it from birth. No ref crosses the wire = no race, ever.
        // LooneyBin 2026-07-18: the crypto MINING RIG isn't furniture -- route it to its own server handler
        // (helipad-style persistence + mining accrual), NOT the house-furniture DB. The cryptoRig item was
        // already consumed above; the server spawns the composition + saves, or refunds on reject.
        if (_item isEqualTo "cryptoRig") exitWith {
            [["place", player, _house, getPosATL AP_placing, getDir AP_placing], "APS_fnc_miningSRV", 2] spawn AP_fnc_MP;
            deleteVehicle AP_placing;};
        // 2026-08-22: the fabricators (two printers and the gunsmith bench) route the same way as
        // the rig -- their own server handler and their own table, not the house-furniture DB. The
        // preview is a stock stand-in class because the real models are custom p3ds with no
        // CfgVehicles entry, so they cannot be createVehicle'd here; the server spawns the anchor
        // and each client attaches the p3d to it. The item was already consumed above, and
        // APS_fnc_fabSRV refunds on every reject.
        //
        // The parentheses around `find` are load-bearing: SQF binds `find` LOOSER than `+`, so
        // `_arr find _item + 1` parses as `_arr find (_item + 1)` -- a string plus a number.
        private _fabIdx = ["printer_i3", "printer_corexy", "gunsmith_bench"] find _item;
        if (_fabIdx > -1) exitWith {
            private _tier = _fabIdx + 1;
            diag_log format ["[AP-PROBE] placeObject: fabricator %1 tier %2 -> server (house %3)", _item, _tier, _house getVariable ["AP_houseID", -1]];
            [["place", [player, _house, _tier, getPosATL AP_placing, getDir AP_placing]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
            deleteVehicle AP_placing;};
        private _hid = _house getVariable ["AP_houseID", -1];
        // owner 2026-07-10: COMPOSITION items (AP_furnitureComps) fan out one persisted "add" per member,
        // positioned from the preview's transform (model-space offsets rotated to its facing). Each member
        // becomes a normal furniture entry. Only the FIRST member carries the placer/itemKey, so a server
        // reject can refund the consumed item exactly once (later members reject silently).
        private _ci = AP_furnitureComps findIf { (_x select 0) isEqualTo _item };
        if (_ci isNotEqualTo -1) then {private _base = getPosATL AP_placing;
            private _bdir = getDir AP_placing;
            private _c = cos _bdir; private _s = sin _bdir; {_x params ["_mCls", "_mOff", "_mRel"];
                private _wp = [(_base select 0) + ((_mOff select 0) * _c) + ((_mOff select 1) * _s),
                    (_base select 1) - ((_mOff select 0) * _s) + ((_mOff select 1) * _c), (_base select 2) + (_mOff param [2, 0])];
                private _first = _forEachIndex isEqualTo 0; [
                    ["add", _hid, _mCls, _wp, _bdir + _mRel, objNull, [objNull, player] select _first, ["", _item] select _first], "APS_fnc_houseFurnitureSRV", 2] spawn AP_fnc_MP;
            } forEach ((AP_furnitureComps select _ci) select 1);} else {[
                ["add", _hid, typeOf AP_placing, getPosATL AP_placing, getDir AP_placing, objNull, player, _item], "APS_fnc_houseFurnitureSRV", 2] spawn AP_fnc_MP;
        };
        deleteVehicle AP_placing;};};
AP_placing = objNull;