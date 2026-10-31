/*
    AP_fnc_fabQueue -- load the selected recipe into the machine.

    THE CLIENT REMOVES THE MATERIALS FIRST, then sends intent. That ordering is the settled rule in
    this codebase (fn_jewelryEmporiumSRV.sqf:62-92): remove-then-refund can cost a player items if
    a refund goes missing, which is a rounding error; pay-then-remove mints value out of nothing,
    which is an economy. Every refusal inside APS_fnc_fabSRV refunds the recipe's parts list,
    re-derived server-side from the same config -- never from anything sent from here.
*/
disableSerialization;
private _d = findDisplay 1810;
if (isNull _d) exitWith {};
private _list = _d displayCtrl 1850;
private _sel = lbCurSel _list;
if (_sel < 0) exitWith {};
private _key = _list lbData _sel;
if (_key isEqualTo "") exitWith {};

// The Print button doubles as Buy. In shop mode nothing is consumed here at all -- the client
// sends only the schematic key and APS_fnc_fabGrantSRV charges the New Drachma itself, atomically,
// through the one wallet the server actually owns.
if ((missionNamespace getVariable ["AP_fabMode", "print"]) isEqualTo "shop") exitWith {
    [["buy", [player, _key]], "APS_fnc_fabGrantSRV", 2] spawn AP_fnc_MP;
};

private _anchor = missionNamespace getVariable ["AP_fabAnchor", objNull];
if (isNull _anchor) exitWith { ["No fabricator here.", "basic"] spawn AP_fnc_handleMessage; };
if ((player distance _anchor) > 6) exitWith { ["Stand at the fabricator.", "basic"] spawn AP_fnc_handleMessage; };

private _qty = round (parseNumber (ctrlText (_d displayCtrl 1815)));
if (_qty < 1) then { _qty = 1 };
if (_qty > 20) then { _qty = 20 };   // the server clamps too; this is so the field cannot look accepted

private _row = ["getRecipe", _key] call AP_fnc_fabCfg;
if (_row isEqualTo []) exitWith {};
_row params ["", "_parts", ""];

// FREE BUILD: consume nothing and send the intent straight through. The server re-reads its OWN
// copy of this flag, so a client that sets the local one gets a menu that stops greying things out
// and precisely the same refusals as before.
if (missionNamespace getVariable ["AP_fabFreeBuild", false]) exitWith {
    [["queue", [player, _anchor getVariable ["AP_fabId", -1], _key, _qty]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
};

// Check EVERYTHING before removing ANYTHING -- a partial consume that then fails its next check
// leaves the player short with no job to show for it.
private _short = _parts findIf { (missionNamespace getVariable [(_x select 0), 0]) < ((_x select 1) * _qty) };
if (_short != -1) exitWith {
    [format ["Not enough %1.", ["getName", ((_parts select _short) select 0) select [7]] call AP_fnc_virtItemCfg], "basic"] spawn AP_fnc_handleMessage;
};

private _taken = [];
private _ok = true;
{
    _x params ["_var", "_n"];
    private _item = _var select [7];
    if (_ok) then {
        if ([false, _item, _n * _qty] call AP_fnc_handleInv) then { _taken pushBack [_item, _n * _qty]; }
        else { _ok = false; };
    };
} forEach _parts;
if (!_ok) exitWith {
    // Hand back whatever did come out before the failure. Same reasoning as the server's refunds.
    { [true, _x select 0, _x select 1] call AP_fnc_handleInv; } forEach _taken;
    ["The fabricator could not take those materials. Nothing was consumed.", "basic"] spawn AP_fnc_handleMessage;
};

[["queue", [player, _anchor getVariable ["AP_fabId", -1], _key, _qty]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
// Stay open. The server pushes the machine's new state straight back (AP_fnc_fabReceive), so the
// job panel fills in a moment later and the player sees what they just loaded rather than a
// window vanishing and having to walk back into it to find out whether it worked.
