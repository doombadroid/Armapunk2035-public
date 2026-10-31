params[["_item", "", [""]]];
if (_item isEqualTo "") exitWith {};
closeDialog 0;
closeDialog 0;
if !(isNull AP_placing) exitWith {["You are already placing another object.", "basic"] spawn AP_fnc_handleMessage};
if (AP_effSide isEqualTo west && ((player distance(getMarkerPos "armory_marker")) < 200)) exitWith {
    ["You cannot place checkpoint materials inside of the Evidence Lockup!", "basic"] spawn AP_fnc_handleMessage};
if (AP_effSide isEqualTo west && ({player distance getMarkerPos format["police_hq_%1", _x] < 75}
count[1, 2, 3, 4, 5, 6] > 0)) exitWith {
    ["You cannot place checkpoint materials inside of Police HQ's!", "basic"] spawn AP_fnc_handleMessage};
if (AP_effSide isEqualTo west && ({player distance getMarkerPos format["police_hq_%1", _x] < 125}
count[5] > 0)) exitWith {["You cannot place checkpoint materials inside of Police HQ's!", "basic"] spawn AP_fnc_handleMessage};
// LooneyBin furniture: must be at YOUR house (20m), exempt from the cartel-radius rule below
// (#154 family: was `_x in AP_vehicles` -- the VEHICLE array never contains houses -> gate always
// blocked placement. Match AP_homeOwner == your UID, same fix as fn_placeObject.)
if ((_item in AP_furnitureItems) && {((nearestObjects [player, ["House_F"], 20]) findIf { (_x getVariable ["AP_homeOwner", ""]) isEqualTo getPlayerUID player }) isEqualTo -1}) exitWith {
    ["Furniture can only be placed within 20m of a house you own.", "basic"] spawn AP_fnc_handleMessage};
if (!(AP_effSide isEqualTo west || AP_effSide isEqualTo independent) && (_item isNotEqualTo "boombox") && !(_item in AP_furnitureItems) && player distance arms_flag > 300 && player distance drug_flag > 300 && player distance wongs_flag > 300 && player distance oil_flag > 300) exitWith {
    ["You can only place this object within 300m of a capture area (cartel).", "basic"] spawn AP_fnc_handleMessage};
private _index = [_item, AP_placeable] call AP_fnc_index;
if (_index isEqualTo - 1) exitWith { diag_log format ["[AP-PROBE] holdObject: %1 is not in AP_placeable", _item]; };
private _object = ((AP_placeable select _index) select 1) createVehicle[0, 0, 0];
// LooneyBin 2026-06-11: Z-adjustable placement. AP_placeZ raised/lowered via the scroll-wheel
// "Raise/Lower Object" actions (re-attach with the new vertical offset); reset each time you pick a piece up.
AP_placeZ = 0;
AP_placeFwd = (AP_placeable select _index) select 4;
_object attachTo[player, [0, AP_placeFwd, AP_placeZ]];
AP_placeDir = (AP_placeable select _index) select 3;
_object setDir AP_placeDir;
_object setMass 0;
// owner 2026-06-15 (#223): make the HELD object inert -- disable physics while carried. With simulation
// left ON (+ setMass 0) it collided with players/walls as you moved -> flung/killed players (massless-
// object glitch) AND fed its own handleDamage EH = "placeable objects kill when holding around". attachTo
// still tracks the player; it can still be shot (EH stays a real vulnerability).
_object enableSimulationGlobal false;
_object addEventHandler["handleDamage", {private _damage = 0.5;
    private _plb_dmg = player;
    _plb_dmg setDamage(damage player + _damage)}];
AP_placing = _object;
_object setVariable ["AP_placeItem", _item];   // the item key: three fabricator items share one preview class, so the class cannot name it
