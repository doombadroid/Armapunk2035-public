params[["_cop", objNull, [objNull]], ["_val", 0, [0]]];
if (isNull _cop) exitWith {};
if (!isNull(findDisplay 2600)) exitWith {[
        [1, format["%1 currently has an active ticket displayed.", [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", _cop] call AP_fnc_MP;
};
disableSerialization;
["AP_ticket_pay"] call AP_fnc_createDialog;
waitUntil {!isNull(findDisplay 2600)};
private _display = findDisplay 2600;
private _control = _display displayCtrl 2601;
AP_ticket_paid = false;
AP_ticket_attempted = false;
AP_ticket_val = _val;
AP_ticket_cop = _cop;
_control ctrlSetStructuredText parseText format["<t align='center'><t size='.8px'>%1 has given you a ticket for $%2", [name _cop] call AP_fnc_cleanName, [AP_ticket_val] call AP_fnc_numberText];
[] spawn {disableSerialization;
    waitUntil {AP_ticket_paid || AP_ticket_attempted || (isNull(findDisplay 2600)) || ((AP_is_arrested param [0,0]) isEqualTo 1)};
    if ((AP_is_arrested param [0,0]) isEqualTo 1) exitWith {};
    if (isNull(findDisplay 2600) && !AP_ticket_attempted) then {[
            [0, format["%1 refused to pay the ticket.", [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", west] spawn AP_fnc_MP;
        [
            [1, format["%1 refused to pay the ticket.", [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", AP_ticket_cop] spawn AP_fnc_MP;
    };};