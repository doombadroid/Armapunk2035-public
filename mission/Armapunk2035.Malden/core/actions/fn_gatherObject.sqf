params[["_item", "", [""]], ["_max", 0, [0]], ["_string", "", [""]]];
private _bush = cursorObject;
if ((str(_bush) find _string) isEqualTo - 1) exitWith {};
if (_item isEqualTo "") exitWith {};
if (isNull _bush) exitWith {};
if (player distance(getMarkerPos "corrections") < 200) exitWith {
    ["The roots of this plant are too sturdy for you to harvest from it.", "basic"] spawn AP_fnc_handleMessage;};
private _count = ceil(random _max);
// owner 2026-06-24 (#531): a SICKLE now GUARANTEES the +1 on grain (barley/corn/rye) -> reliably 2 instead of a
// 20%-chance bonus that gave just the base (1) most of the time. It's a harvest tool; players expect it to double.
if (AP_inv_sickle >= 1 && {_item in ["barley", "corn", "rye"]}) then {_count = _count + 1;};
// BUMPER CROP (222): +1 unit on every field harvest.
if (222 in AP_side_talents) then { _count = _count + 1; };
if !(isNull objectParent player) exitWith {["You cannot gather from within your vehicle.", "basic"] spawn AP_fnc_handleMessage;};
if !([true, _item, _count] call AP_fnc_handleInv) exitWith {["You don't have room for that.", "basic"] spawn AP_fnc_handleMessage;};
_bush setDamage 1;
private _name = ["getName", _item] call AP_fnc_virtItemCfg;
player switchMove "AinvPercMstpSnonWnonDnon_Putdown_AmovPercMstpSnonWnonDnon";
titleText[format["You gathered %1 %2.", _count, _name], "PLAIN"];
if (_item isEqualTo "berry") then {["berries", _count] call AP_fnc_statArrUpdate;};
if (_item isEqualTo "barley") then {["barley", _count] call AP_fnc_statArrUpdate;
    ["collect", "barley", _count] call AP_fnc_handleQuest;};
if (_item isEqualTo "corn") then {["corn", _count] call AP_fnc_statArrUpdate;};