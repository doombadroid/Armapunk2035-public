/*
    AP_fnc_fabBurn -- turn a schematic you know back into a tradeable shard.

    Confirms first, because this is the only destructive button in the window: the schematic is
    forgotten, and the shard you get back rolls a RANDOM schematic of that tier when someone uses
    it -- so burning and immediately using the shard is not a round trip, it is a re-roll. That is
    unavoidable (virtual items here are bare counters with no per-instance storage, so an item
    cannot carry which recipe it encodes), and it is worth stating in the confirmation rather than
    discovering afterwards.

    Sends the key and nothing else. The server re-checks that you know it, forgets it, PROVES the
    forget committed, and only then grants the shard -- in that order, because the reverse would
    let a failure between the two leave you holding both.
*/
disableSerialization;
private _d = findDisplay 1810;
if (isNull _d) exitWith {};
private _list = _d displayCtrl 1850;
private _sel = lbCurSel _list;
if (_sel < 0) exitWith {};
private _key = _list lbData _sel;
if (_key isEqualTo "") exitWith {};

if ((missionNamespace getVariable ["AP_fabMode", "print"]) isEqualTo "shop") exitWith {
    ["You do not own that schematic yet.", "basic"] spawn AP_fnc_handleMessage;
};
if !(_key in (missionNamespace getVariable ["AP_fabSchem", []])) exitWith {
    ["That recipe needs no schematic -- there is nothing to burn.", "basic"] spawn AP_fnc_handleMessage;
};

private _rarity = (["get", _key] call AP_fnc_fabSchemCfg) param [2, "common"];
private _ok = [format [
    "Burn the %1 schematic?\n\nYou will FORGET it and receive one %2 shard.\n\nThe shard is tradeable, but it rolls a RANDOM %2 schematic when used -- it will not necessarily give this one back.",
    _key, _rarity], "Burn Schematic", "Burn", "Cancel"] call BIS_fnc_guiMessage;
if (!_ok) exitWith {};

[["burn", [player, _key]], "APS_fnc_fabGrantSRV", 2] spawn AP_fnc_MP;
closeDialog 0;
