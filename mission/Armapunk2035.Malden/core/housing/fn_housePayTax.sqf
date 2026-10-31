/*
    fn_housePayTax.sqf — pay one house's tax (or every house), dialog-free.

    The exact chain of fn_manageHouseTax's taxPaySelected -- the txn guard, the
    restart lock, calculateTax as the only price authority, the bank debit, the
    owner-2 server call, the log line and the quest hook -- minus the listbox it
    was welded to, so the deck can call it by house index. The native menu keeps
    its own path; this is a second door into the same room.

        [3] call AP_fnc_housePayTax;     // pay AP_houses index 3
        ["all"] call AP_fnc_housePayTax; // pay everything due
*/
params [["_which", -1, [0, ""]]];

if (AP_houseTxn) exitWith { ["You are currently in the process of paying house taxes.", "basic"] spawn AP_fnc_handleMessage; false };
if (serverRestartLock) exitWith { ["You cannot pay your tax right now. Try again after the restart!", "basic"] spawn AP_fnc_handleMessage; false };
if (AP_effSide isNotEqualTo civilian) exitWith { false };

private _resolve = {
    params ["_idx"];
    private _entry = AP_houses param [_idx, []];
    if (_entry isEqualTo []) exitWith { objNull };
    private _pos = parseSimpleArray (_entry select 0);
    private _houses = nearestObjects [_pos, ["House"], 18, true];
    if (_houses isEqualTo []) exitWith { objNull };
    (_houses select { (typeOf _x) in AP_houseTypes }) param [0, (_houses select 0)]
};

private _payOne = {
    params ["_h"];
    if (isNull _h) exitWith { false };
    private _tax = ["calculateTax", [_h]] call AP_fnc_manageHouseTax;
    if (_tax <= 0) exitWith { false };
    if (AP_atmcash < _tax) exitWith {
        ["You can't afford to pay the house tax!", "basic"] spawn AP_fnc_handleMessage; false };
    // 2026-09-04 (money bug): this read AP_house_tax param 0, which is `overdue` -- a
    // BOOLEAN, not an id (the shape is documented in fn_houseTaxSRV.sqf:5 and every other
    // reader treats index 0 as a bool). The server types _houseID as [0,""], so a boolean
    // failed the check and SQF substituted the DEFAULT of -1, giving `WHERE oid='-1'`:
    // matched no row, tax_paid never written, and the client had already been charged.
    // 20 payments / $36,524 went that way on dev before it was caught. AP_houseID is what
    // every sibling housing fn uses (fn_upgradeProperty:13, fn_manageBldgKeys:106,
    // fn_manageHouseTax:47/75) and is the `oid` column the server's WHERE keys on.
    private _houseID = _h getVariable ["AP_houseID", -1];
    if (_houseID isEqualTo -1) exitWith {
        ["That house has no id yet -- try again in a moment.", "basic"] spawn AP_fnc_handleMessage; false };
    // The SERVER debits (APS_fnc_houseTaxSRV -> AP_fnc_uC) after it validated the id and wrote the
    // row, and it logs -HOUSETAX-; subtracting here as well charged every payment twice and kept
    // the money when the server refused (2026-09-04).
    [["paySingleHouse", [player, _h, _houseID]], "APS_fnc_houseTaxSRV", 2] call AP_fnc_MP;
    ["buy", "housetax", _tax] spawn AP_fnc_handleQuest;
    true
};

AP_houseTxn = true;
private _paid = 0;
if (_which isEqualType "") then {
    for "_i" from 0 to (count AP_houses - 1) do {
        if ([[_i] call _resolve] call _payOne) then { _paid = _paid + 1 };
    };
} else {
    if ([[_which] call _resolve] call _payOne) then { _paid = 1 };
};
AP_houseTxn = false;   // the server also clears it per house (netSetVar); its "You paid $..." is the receipt
_paid > 0
